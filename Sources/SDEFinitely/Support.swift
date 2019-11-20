//
//  SDEFinitely
//
//  Originally written by has for SwiftAutomation.framework,
//  Reworked and extended by ThatsJustCheesy
//

import Foundation

extension FourCharCode {
    
    init(fourByteString string: String) throws {
        // convert four-character string containing MacOSRoman characters to OSType
        // (this is safer than using UTGetOSTypeFromString, which silently fails if string is malformed)
        guard let data = string.data(using: .macOSRoman) else {
            throw SDEFError(message: "Invalid four-char code (bad encoding): \(string.debugDescription)")
        }
        guard data.count == 4 else {
            throw SDEFError(message: "Invalid four-char code (wrong length): \(string.debugDescription)")
        }
        let reinterpreted = data.withUnsafeBytes { $0.bindMemory(to: FourCharCode.self).first! }
        self.init(reinterpreted.bigEndian)
    }
    
}

extension String {
    
    init(fourCharCode: OSType) {
        // convert an OSType to four-character string containing MacOSRoman characters
        self.init(UTCreateStringForOSType(fourCharCode).takeRetainedValue() as String)
    }
    
}
