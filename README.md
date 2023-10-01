# CSVaquita

A reasonably fast streaming CSV parser for Swift. 

## Installation

### Swift Package Manager

```
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        .package(url: "https://github.com/Topolyte/CSVaquita.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(name: "<your target>", dependencies: [
            .product(name: "CSVaquita", package: "https://github.com/Topolyte/CSVaquita.git"),
        ])
    ]
)
``` 


## Usage

```
// Create an InputStream to read from a UTF-8 encoded file

let filePath = "/my/file.csv"

guard let stream = InputStream(fileAtPath: filePath) else {
    // handle file not found error
    print("Failed to open \(filePath)")
    exit(1)
} 

// Or create a stream from any other UTF-8 source such as a String

let csv = """
id,country,capital,population,GDP
1,United Kindom,London,67508936,$3.1tn
2,United States,Washington,338289857,$23tn
"""

let stream = InputStream(data: csv.data(using: .utf8)!)

// You can call stream.open() if you prefer but if you do, you're going to have to close it as well
// If you pass the stream to the CSVReader constructor unopened, the stream will be opened automatically
// and closed when the CSVReader itself is destroyed.

let reader = try CSVReader(stream)

// Read rows as [String] until nil is returned

while let row = try reader.readRow() {
    print(row)
}

// for-in loops are not supported because Swift's IteratorProtocol doesn't permit exceptions
```

The CSVReader can be configured using constructor arguments directly or by passing
a CSVReader.Configuration object to the constructor. Configuration objects can be reused
as well as modified to create multiple readers.

```

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

let reader = try CSVReader(stream, conf)

```

