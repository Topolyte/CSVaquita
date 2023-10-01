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

    func testAdHoc() throws {
        let s = """
        one,two
        "abc",xyz
        """
        
        let rdr = try CSVReader(makeStream(s))
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
    let stream = InputStream(data: s.data(using: .utf8)!)
    stream.open()
    return stream
}
