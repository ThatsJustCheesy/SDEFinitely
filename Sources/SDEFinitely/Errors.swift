//
//  SDEFinitely
//
//  Originally written by has for SwiftAutomation.framework,
//  Reworked and extended by ThatsJustCheesy
//

import Foundation

public class SDEFError: Error {
    
    public let message: String
    public let cause: Error? // the error that triggered this failure, if any
    
    public init(message: String, cause: Error? = nil) {
        self.message = message
        self.cause = cause
    }
    
}

extension SDEFError: CustomStringConvertible {
    
    public var description: String {
        return self.description(0)
    }
    
    private func description(_ previousCode: Int) -> String {
        var string = "Error: \(message)"
        if let error = self.cause as? SDEFError {
            string += " \(error.description(self._code))"
        } else if let error = self.cause {
            string += " \(error)"
        }
        return string
    }
    
}

public struct NoSDEF: LocalizedError {
    
    public var errorDescription: String? {
        "Resource has no SDEF data."
    }
    
}
