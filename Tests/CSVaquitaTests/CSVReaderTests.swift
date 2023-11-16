import XCTest
@testable import CSVaquita

final class csvaquitaTests: XCTestCase {
    func testUnquoted() throws {
        let s = """
        id,country,capital,population,GDP
        1,United Kindom,London,67508936,$3158bn
        2,United States,Washington,338289857,
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .firstRow,
            columnCount: .exactly(5)
        )
        
        let expected = [
            ["1","United Kindom","London","67508936","$3158bn"],
            ["2","United States","Washington","338289857",""]
        ]
        
        let headers = ["id","country","capital","population","GDP"]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
        XCTAssertEqual(headers, reader.headerFields)
    }
    
    func testQuoted() throws {
        let s = """
        "1","United Kindom","\"\"London\"\"","67,508,936","$3158bn"
        "2","United States","Washington","338,289,857",""
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .none,
            quoting: .character("\""),
            columnCount: .exactly(5))
        
        let expected = [
            ["1","United Kindom","\"London\"","67,508,936","$3158bn"],
            ["2","United States","Washington","338,289,857",""]
        ]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
    }

    func testHeaders() throws {
        let s = """
        id,country,capital,population,GDP
        1,United Kindom,"\"\"London\"\"","67,508,936",$3158bn
        2,United States,Washington,"338,289,857",
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .firstRow,
            quoting: .character("\""),
            columnCount: .exactly(5))
        
        let expected = ["id", "country", "capital", "population", "GDP"]
        
        _ = try readAll(reader)
        
        XCTAssertEqual(expected, reader.headerFields)
    }
    
    func testNoHeaders() throws {
        let s = """
        1,United Kindom,"\"\"London\"\"","67,508,936",$3158bn
        2,United States,Washington,"338,289,857",
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .none,
            quoting: .character("\""),
            columnCount: .exactly(5))
        
        let expected = ["0", "1", "2", "3", "4"]
        
        _ = try readAll(reader)
        
        XCTAssertEqual(expected, reader.headerFields)
    }
    
    func testLax() throws {
        let s = """
        id,country,capital,population,GDP
        1,United Kindom
        2,United States,Washington,"338,289,857",more,"yet more"
        """

        let reader = try CSVReader(
            makeStream(s),
            header: .firstRow,
            columnCount: .lax)

        let expected = [
            ["1","United Kindom"],
            ["2","United States","Washington","338,289,857","more","yet more"]
        ]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
    }

    func testStrict() throws {
        let s = """
        id,country,capital,population,GDP
        1,United Kindom
        2,United States,Washington,"338,289,857",more,"yet more"
        """

        var reader = try CSVReader(
            makeStream(s),
            header: .firstRow,
            columnCount: .strict)
        
        XCTAssertThrowsError(try readAll(reader))
        
        reader = try CSVReader(
            makeStream(s),
            header: .firstRow,
            columnCount: .lax)

        XCTAssertNoThrow(try readAll(reader))
    }
    
    func testNoOpRows() throws {
        let s = """
        
        id,country,capital,population,GDP
        
        1,United Kindom,London,"67,508,936",$3158bn
        # What a great comment
        2,United States,Washington,"338,289,857",
        
        """

        let reader = try CSVReader(
            makeStream(s),
            header: .firstRow,
            commenting: .character("#"))

        let expected = [
            ["1","United Kindom","London","67,508,936","$3158bn"],
            ["2","United States","Washington","338,289,857",""]
        ]
        
        let headers = ["id", "country", "capital", "population", "GDP"]
        
        let rows = try readAll(reader)

        XCTAssertEqual(expected, rows)
        XCTAssertEqual(headers, reader.headerFields)
    }

    func testTrimming() throws {
        let s = """
         1 ,United Kindom , London,  "67,508,936"  ,$3158bn
        2 , United States, Washington ,"338,289,857" ,
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .none,
            quoting: .character("\""),
            trimming: .both,
            columnCount: .exactly(5))

        let expected = [
            ["1","United Kindom","London","67,508,936","$3158bn"],
            ["2","United States","Washington","338,289,857",""]
        ]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
    }

    func testEmptyFields() throws {
        let s = """
         1 ,United Kindom ,,  ,$3158bn
        2 , United States, Washington ,,
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .none,
            quoting: .character("\""),
            trimming: .both,
            columnCount: .exactly(5))

        let expected = [
            ["1","United Kindom","","","$3158bn"],
            ["2","United States","Washington","",""]
        ]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
    }

    func testEmptyFieldsNoTrimming() throws {
        let s = """
        1,United Kindom,, ,$3158bn
        ,United States,Washington,,
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .none,
            quoting: .character("\""),
            trimming: .none,
            columnCount: .exactly(5))

        let expected = [
            ["1","United Kindom",""," ","$3158bn"],
            ["","United States","Washington","",""]
        ]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
    }

    func testOneColumn() throws {
        let s = """
        1
        "United Kingdom"
         2
         United States
        3
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .none)

        let expected = [
            ["1"],
            ["United Kingdom"],
            [" 2"],
            [" United States"],
            ["3"]
        ]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
    }

    func testOneColumnTrimmed() throws {
        let s = """
        1
        "United Kingdom"
         2
         United States
        3
        """
        
        let reader = try CSVReader(
            makeStream(s),
            header: .none,
            trimming: .both)

        let expected = [
            ["1"],
            ["United Kingdom"],
            ["2"],
            ["United States"],
            ["3"]
        ]
        
        let rows = try readAll(reader)
        
        XCTAssertEqual(expected, rows)
    }

    func testEmptyInput() throws {
        let reader = try CSVReader(makeStream(""))
        let expected = [[String]]()
        
        let rows = try readAll(reader)
        XCTAssertEqual(expected, rows)
    }
    
    func testForIn() throws {
        let s = """
        id,country,capital,population,GDP
        1,United Kindom,London,67508936,$3158bn
        2,United States,Washington,338289857,
        """

        let reader = try CSVReader(makeStream(s))
        
        var rows = [[String]]()
        
        for result in reader {
            switch result {
            case let .success(row):
                rows.append(row)
            case let .failure(error):
                throw error
            }
        }
        
        let expected = [
            ["1","United Kindom","London","67508936","$3158bn"],
            ["2","United States","Washington","338289857",""]
        ]

        XCTAssertEqual(expected, rows)
    }
    
    func testBOM() throws {
        let s = "\u{FEFF}abc"
        let reader = try CSVReader(makeStream(s), header: .none)
        if let row = try reader.readRow() {
            XCTAssertEqual("abc", row[0])
        } else {
            XCTFail("No rows read")
        }
    }

    func testAdHoc() throws {
        let s = "\u{FEFF}abc"
        let rdr = try CSVReader(makeStream(s), header: .none)
        while let row = try rdr.readRow() {
            print("\(row)")
        }
    }

}

func readAll(_ reader: CSVReader, printRow: Bool = false) throws -> [[String]] {
    var rows = [[String]]()
    
    while let row = try reader.readRow() {
        rows.append(row)
        if printRow {
            print(row)
        }
    }
    
    return rows
}

func makeStream(_ s: String) -> InputStream {
    return InputStream(data: s.data(using: .utf8)!)
}

func makeDefaultConf() throws -> CSVReader.Configuration {
    let conf = CSVReader.Configuration(
        // delimiter can be any ASCII character
        delimiter: ",",
        
        // header is either .firstRow or .none. If .firstRow is chosen, the first significant
        // (i.e non-empty and non-comment) row is stored in CSVReader.headerFields
        // and will not be returned by readRow(). When choosing .none, all significant
        // rows are returned by readRow() and CSVReader.headerFields will be an array
        // containing the column indices of the first significant row: ["0", "1", "2", ... "n-1"]
        header: .firstRow,
        
        // quoting can be either .none or .character(c) where c can be any ASCII character.
        // Columns enclosed between quote characters can contain the delimiter character as well
        // as line breaks. The quote character itself can be escaped by doubling it.
        // If you don't use trimming, the initial quote character must not be preceded by
        // whitespace or it will be considered part of the field content.
        quoting: .character("\""),
        
        // commenting is either .none or .character(c) where c can be any ASCII character.
        // Lines starting with c will be ignored.
        commenting: .none,
        
        // trimming can be .none, .left, .right or .both removing space and tab from
        // the beginning and/or end of a field
        trimming: .none,
        
        // columnCount can be .lax, .strict or .exactly(n)
        // .lax means that rows can have varying numbers of columns. CSVReader.headerFields
        // always reflects the number of columns in the first row.
        // Using .strict causes an exception to be thrown if a row doesn't have the same
        // number of columns as the first row.
        // .exactly(n) requires that all rows, including the first one, have exactly n columns.
        // Otherwise an exception will be thrown.
        columnCount: .lax,
        
        // The capacity of the reader buffer. You probably won't need to change this.
        bufferCapacity: 1024 * 1024
    )
    
    let _ = try CSVReader(makeStream(""), conf)
    
    return conf
}
