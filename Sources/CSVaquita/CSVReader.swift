/*
Copyright (c) 2023 Topolyte Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

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


public class CSVReader: Sequence, IteratorProtocol {
    let stream: BufferedStream
    let delimiter: UInt8
    let header: Header
    let quote: UInt8?
    let comment: UInt8?
    let columnCount: ColumnCount
    let trimming: Trimming
    
    public class Configuration {
        public var delimiter: Character
        public var header: Header
        public var quoting: Quoting
        public var commenting: Commenting
        public var trimming: Trimming
        public var columnCount: ColumnCount
        public var bufferCapacity: Int
        
        public init(delimiter: Character = ",",
                    header: Header = .firstRow,
                    quoting: Quoting = .character("\""),
                    commenting: Commenting = .none,
                    trimming: Trimming = .none,
                    columnCount: ColumnCount = .lax,
                    bufferCapacity: Int = 1024 * 1024)
        {
            self.delimiter = delimiter
            self.header = header
            self.quoting = quoting
            self.commenting = commenting
            self.trimming = trimming
            self.columnCount = columnCount
            self.bufferCapacity = bufferCapacity
        }
    }
    
    public var headerFields = [String]()
    var firstRowColumnCount = 0
    var line = 1
    var row = 0
    var stringBuffer = ContiguousArray<UInt8>()
    
    public init(_ stream: InputStream, _ conf: Configuration = Configuration()) throws {
        self.delimiter = try requireAscii(conf.delimiter,
            errorMessage: "The delimiter must be within the ASCII range")
        
        self.header = conf.header
        self.columnCount = conf.columnCount
        self.trimming = conf.trimming
        self.stream = BufferedStream(stream, bufferCapacity: conf.bufferCapacity)
        
        if case let .character(c) = conf.quoting {
            self.quote = try requireAscii(c,
                errorMessage: "The quote character must be within the ASCII range")
        } else {
            self.quote = nil
        }
        
        if case let .character(c) = conf.commenting {
            self.comment = try requireAscii(c,
                errorMessage: "The comment character must be within the ASCII range")
        } else {
            self.comment = nil
        }
        
        try skipBOM()
    }
    
    public convenience init(_ stream: InputStream,
        delimiter: Character = ",",
        header: Header = .firstRow,
        quoting: Quoting = .character("\""),
        commenting: Commenting = .none,
        trimming: Trimming = .none,
        columnCount: ColumnCount = .lax,
        bufferCapacity: Int = 1024 * 1024) throws
    {
        try self.init(stream, Configuration(
            delimiter: delimiter,
            header: header,
            quoting: quoting,
            commenting: commenting,
            trimming: trimming,
            columnCount: columnCount,
            bufferCapacity: bufferCapacity
        ))
    }

    public func next() -> Result<[String], Error>? {
        do {
            if let row = try readRow() {
                return .success(row)
            }
            return nil
        } catch {
            return .failure(error)
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
                        stream.pushback()
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
            if c == delimiter || c == Ascii.lf {
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
    
    let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
    
    func skipBOM() throws {
        let bytes = try stream.readBytes(3)
        if bom == bytes {
            return
        }
        stream.pushback(bytes.count)
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
