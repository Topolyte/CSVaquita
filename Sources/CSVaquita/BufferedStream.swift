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

public enum BufferedStreamError: Error {
    case io(String)
}

public final class BufferedStream {
    let stream: InputStream
    var closeStream: Bool
    let buf: UnsafeMutableBufferPointer<UInt8>
    
    var pos = 0
    var end = 0
    
    public init(_ stream: InputStream, bufferCapacity: Int = 1024 * 1024) {
        self.stream = stream
        
        if self.stream.streamStatus == .notOpen {
            self.stream.open()
            self.closeStream = true
        } else {
            self.closeStream = false
        }

        self.buf = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bufferCapacity)
    }
    
    deinit {
        if closeStream {
            stream.close()
        }
        buf.deallocate()
    }
    
    public func readByte() throws -> UInt8? {
        if pos == end {
            try readStream()
            if pos == end {
                return nil
            }
        }
        
        pos += 1
        return buf[pos - 1]
    }
    
    public func readBytes(_ n: Int) throws -> [UInt8] {
        if pos == end {
            try readStream()
        }
        let available = min(n, end - pos)
        if available > 0 {
            pos += available
            return Array(buf[pos..<(pos + available)])
        }
        return []
    }
    
    public func pushback(_ n: Int = 1) {
        if n < 1 {
            return
        }
        if pos > n {
            pos -= n
        } else {
            pos = 0
        }
    }

    @discardableResult
    func readStream() throws -> Bool {
        let n = stream.read(buf.baseAddress!, maxLength: buf.count)
        
        guard n > -1 else {
            throw makeStreamError(stream: self.stream)
        }
        
        end = n
        pos = 0
        
        return end > 0
    }
}

func makeStreamError(stream: InputStream) -> BufferedStreamError {
    let statusString = statusDescription(stream.streamStatus)
    
    if let error = stream.streamError {
        return BufferedStreamError.io(String(describing: error) + " Status: \(statusString)")
    } else {
        return BufferedStreamError.io("Status: \(statusString)")
    }
}

func statusDescription(_ status: Stream.Status) -> String {
    switch status {
    case .atEnd: return "atEnd"
    case .closed: return "closed"
    case .error: return "error"
    case .notOpen: return "notOpen"
    case .open: return "open"
    case .opening: return "opening"
    case .reading: return "reading"
    case .writing: return "writing"
    default: return "unknown"
    }
}
