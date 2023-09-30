import Foundation

public enum ColumnCount {
    case lax
    case strict
    case exactly(Int)
}

public enum Header {
    case none
    case firstRow
}

public enum Trimming {
    case none, left, right, both
}

public enum Quoting {
    case none
    case character(Character)
}

public enum Commenting {
    case none
    case character(Character)
}

public enum Escaping {
    case double
    case character(Character)
}

public enum CSVReaderError: Error {
    case configuration(String)
    case data(String, line: Int)
    case io(String)
}

public class CSVReader {
    let stream: BufferedStream
    let delimiter: UInt8
    let header: Header
    let quote: UInt8?
    let comment: UInt8?
    let columnCount: ColumnCount
    let trimming: Trimming
    
    public var headerFields = [String]()
    var firstRowColumnCount = 0
    var line = 1
    var row = 0
    var stringBuffer = ContiguousArray<UInt8>()
    
    public init(_ stream: InputStream,
                delimiter: Character = ",",
                header: Header = .firstRow,
                quoting: Quoting = .character("\""),
                commenting: Commenting = .none,
                trimming: Trimming = .none,
                columnCount: ColumnCount = .lax,
                bufferCapacity: Int = 1024 * 1024) throws
    {
        self.delimiter = try requireAscii(delimiter,
            errorMessage: "The delimiter must be within the ASCII range")
        
        self.header = header
        self.columnCount = columnCount
        self.trimming = trimming
        self.stream = BufferedStream(stream, bufferCapacity: bufferCapacity)
        
        if case let .character(c) = quoting {
            self.quote = try requireAscii(c,
                errorMessage: "The quote character must be within the ASCII range")
        } else {
            self.quote = nil
        }
        
        if case let .character(c) = commenting {
            self.comment = try requireAscii(c,
                errorMessage: "The comment character must be within the ASCII range")
        } else {
            self.comment = nil
        }
    }
        
    public func readRow() throws -> [String]? {
        try skipNoOpLines()
        var fields = [String]()
        
        guard let field = try readField(fieldIndex: fields.count) else {
            return nil
        }
        fields.append(field)
        
        while let field = try readField(fieldIndex: fields.count) {
            fields.append(field)
        }
        
        row += 1
        
        if row == 1 {
            firstRowColumnCount = fields.count
            
            switch header {
            case .none:
                headerFields = fields.enumerated().map { String($0.offset) }
            case .firstRow:
                headerFields = fields
                return try readRow()
            }
        }
        
        var expectedColumnCount: Int
        
        switch self.columnCount {
        case .lax:
            expectedColumnCount = fields.count
        case .strict:
            expectedColumnCount = firstRowColumnCount
        case .exactly(let n):
            expectedColumnCount = n
        }
        
        if fields.count != expectedColumnCount {
            throw CSVReaderError.data(
                "Unexpected number of columns. Expected \(expectedColumnCount), found \(fields.count)",
                line: line - 1)
        }
        
        return fields
    }
    
    func readField(fieldIndex: Int) throws -> String? {
        stringBuffer.removeAll(keepingCapacity: true)
        
        guard var c = try stream.readByte() else {
            return nil
        }
                
        if c == Ascii.lf {
            line += 1
            return nil
        }
        
        if (trimming == .left || trimming == .both) && isLineSpace(c){
            try skipLineSpace()
            guard let next = try stream.readByte() else {
                return nil
            }
            c = next
        }

        if c == delimiter {
            if fieldIndex == 0 {
                return ""
            }
            if trimming == .left || trimming == .both {
                try skipLineSpace()
            }
            guard let next = try stream.readByte() else {
                return ""
            }
            if next == delimiter {
                stream.pushback()
                return ""
            }
            c = next
        }
                
        if let quoteChar = self.quote, c == quoteChar {
            return try readQuotedField(quoteChar)
        }
        
        stream.pushback()
        return try readUnquotedField()
    }
    
    func readQuotedField(_ quoteChar: UInt8) throws -> String? {
        while let c = try stream.readByte() {
            if c == quoteChar {
                if let c = try stream.readByte() {
                    if c == quoteChar {
                        stringBuffer.append(quoteChar)
                    } else if c == delimiter {
                        stream.pushback()
                        break
                    } else if c == Ascii.lf {
                        line += 1
                        break
                    } else if isLineSpace(c) {
                        try skipLineSpace()
                        break
                    } else {
                        throw CSVReaderError.data("Content found after closing quote", line: line)
                    }
                } else {
                    break
                }
            } else if c == Ascii.lf {
                stringBuffer.append(c)
                line += 1
            } else if c != Ascii.cr {
                stringBuffer.append(c)
            }
        }
        
        return stringBuffer.string()
    }
    
    func readUnquotedField() throws -> String? {
        while let c = try stream.readByte() {
            if c == Ascii.lf {
                line += 1
                stream.pushback()
                break
            } else if c == delimiter {
                stream.pushback()
                break
            } else if c != Ascii.cr {
                stringBuffer.append(c)
            }
        }
        
        var end = stringBuffer.count
        if trimming == .both || trimming == .right {
            while end > 0 && isLineSpace(stringBuffer[end - 1]) {
                end -= 1
            }
        }
        
        return stringBuffer[0..<end].string()
    }
    
    func skipLineSpace() throws {
        while let c = try stream.readByte() {
            if !isLineSpace(c) {
                stream.pushback()
                return
            }
        }
    }
        
    func skipNoOpLines() throws {
        while let c = try stream.readByte() {
            if let commentChar = comment, c == commentChar {
                try nextLine()
            } else if c == Ascii.lf {
                line += 1
            } else {
                stream.pushback()
                break
            }
        }
    }
    
    func nextLine() throws {
        while let c = try stream.readByte() {
            if c == Ascii.lf {
                line += 1
                break
            }
        }
    }
}

func isLineSpace(_ c: UInt8) -> Bool {
    return c == Ascii.space || c == Ascii.tab
}

fileprivate func requireAscii(_ c: Character, errorMessage: String) throws -> UInt8 {
    guard let c = c.asciiValue else {
        throw CSVReaderError.configuration(errorMessage)
    }
    return c
}

struct Ascii {
    static let comma = Character(",").asciiValue!
    static let space = Character(" ").asciiValue!
    static let tab = Character("\t").asciiValue!
    static let semicolon = Character(";").asciiValue!
    static let bar = Character("|").asciiValue!
    static let quote = Character("\"").asciiValue!
    static let cr = Character("\r").asciiValue!
    static let lf = Character("\n").asciiValue!
}

extension Collection<UInt8> {
    func string() -> String {
        String(unsafeUninitializedCapacity: count) {
            _ = $0.initialize(from: self)
            return count
        }
    }
}
