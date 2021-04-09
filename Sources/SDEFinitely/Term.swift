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

public struct NoSDEF: LocalizedError {
    
    public var errorDescription: String? {
        "Resource has no SDEF data."
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

public protocol TermProtocol {
    
    var name: String { get }
    
}

public protocol KeywordTermProtocol: TermProtocol {
    
    var code: OSType { get }
    
}

public struct KeywordTerm: KeywordTermProtocol { // type/enumerator/property/element/parameter name
    
    public enum Kind {
        case type
        case enumerator
        case property
        case parameter
    }
    
    public let name: String
    public let code: OSType
    public let kind: Kind
    
    public init(name: String, code: OSType, kind: Kind) {
        self.name = name
        self.code = code
        self.kind = kind
    }
    
}

extension KeywordTerm: Hashable {
}

extension KeywordTerm: CustomStringConvertible {
    
    public var description: String {
        return "<\(type(of: self))=\(self.kind):\(self.name)=\(String(fourCharCode: self.code))>"
    }
    
}

public struct ClassTerm: KeywordTermProtocol {
    
    public let name: String
    public let pluralName: String
    public let code: OSType
    
    public init(name: String, pluralName: String, code: OSType) {
        self.name = name
        self.pluralName = pluralName
        self.code = code
    }
}

extension ClassTerm: Hashable {
}

extension ClassTerm: CustomStringConvertible {
    
    public var description: String {
        return "<\(type(of: self)) \(self.name)=\(String(fourCharCode: self.code))>"
    }
    
}

public struct CommandTerm: TermProtocol {
    
    public let name: String
    public let eventClass: OSType
    public let eventID: OSType
    
    private(set) public var parameters: [KeywordTerm] = []

    public init(name: String, eventClass: OSType, eventID: OSType) {
        self.name = name
        self.eventClass = eventClass
        self.eventID = eventID
    }
    
    public var description: String {
        let params = self.parameters.map({ "\($0.name)=\(String(fourCharCode: $0.code))" }).joined(separator: ",")
        return "<Command:\(self.name)=\(String(fourCharCode: self.eventClass))\(String(fourCharCode: self.eventID))(\(params))>"
    }
    
    public mutating func addParameter(_ name: String, code: OSType) {
        let paramDef = KeywordTerm(name: name, code: code, kind: .parameter)
        self.parameters.append(paramDef)
    }
    
}

extension CommandTerm: Hashable {
}
