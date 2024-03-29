//
//  SDEFinitely
//
//  Originally written by has for SwiftAutomation.framework,
//  Reworked and extended by ThatsJustCheesy
//

import Foundation

public protocol TermProtocol {
    
    var name: String { get }
    var termDescription: String? { get }
    
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
    
    public let termDescription: String?
    
    public init(name: String, code: OSType, kind: Kind, description: String?) {
        self.name = name
        self.code = code
        self.kind = kind
        self.termDescription = description
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
    /// The name of the class that this class inherits from, if any.
    public let inheritsFromName: String?
    
    public let termDescription: String?
    
    public init(name: String, pluralName: String, code: OSType, inheritsFromName: String?, description: String?) {
        self.name = name
        self.pluralName = pluralName
        self.code = code
        self.inheritsFromName = inheritsFromName
        self.termDescription = description
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
    
    public let termDescription: String?

    public init(name: String, eventClass: OSType, eventID: OSType, description: String?) {
        self.name = name
        self.eventClass = eventClass
        self.eventID = eventID
        self.termDescription = description
    }
    
    public var description: String {
        let params = self.parameters.map({ "\($0.name)=\(String(fourCharCode: $0.code))" }).joined(separator: ",")
        return "<Command:\(self.name)=\(String(fourCharCode: self.eventClass))\(String(fourCharCode: self.eventID))(\(params))>"
    }
    
    public mutating func addParameter(_ name: String, code: OSType) {
        let paramDef = KeywordTerm(name: name, code: code, kind: .parameter, description: termDescription)
        self.parameters.append(paramDef)
    }
    
}

extension CommandTerm: Hashable {
}
