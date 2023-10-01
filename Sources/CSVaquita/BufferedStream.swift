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
