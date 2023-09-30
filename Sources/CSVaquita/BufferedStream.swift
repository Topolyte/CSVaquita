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
    
    public func pushback() {
        guard pos > 0 else {
            return
        }
        
        pos -= 1
    }

    @discardableResult
    func readStream() throws -> Bool {
        let n = stream.read(buf.baseAddress!, maxLength: buf.count)
        
        guard n > -1 else {
            let status = " [\(stream.streamStatus)]"
            
            if let error = stream.streamError {
                throw BufferedStreamError.io(String(describing: error) + status)
            } else {
                throw BufferedStreamError.io("Stream error: " + status)
            }
        }
        
        end = n
        pos = 0
        
        return end > 0
    }
}

