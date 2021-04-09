//
//  SDEFinitely
//
//  Originally written by has for SwiftAutomation.framework,
//  Reworked and extended by ThatsJustCheesy
//

import Foundation
import Carbon.OpenScripting

public protocol SDEFParserDelegate {
    
    mutating func addType(_ term: KeywordTerm)
    mutating func addClass(_ term: ClassTerm)
    mutating func addProperty(_ term: KeywordTerm)
    mutating func addEnumerator(_ term: KeywordTerm)
    mutating func addCommand(_ term: CommandTerm)
    
}

public class SDEFParser {
    
    private var delegate: SDEFParserDelegate
    
    public init(delegate: SDEFParserDelegate) {
        self.delegate = delegate
    }
    
    // parse an OSType given as 4/8-character "MacRoman" string, or 10/18-character hex string
    
    func parse(fourCharCode string: String) throws -> OSType { // class, property, enum, param, etc. code
        if string.utf8.count == 10 && (string.hasPrefix("0x") || string.hasPrefix("0X")) { // e.g. "0x00000001"
            let digitStartIndex = string.utf8.index(string.utf8.startIndex, offsetBy: 2)
            let digitEndIndex = string.utf8.index(digitStartIndex, offsetBy: 8)
            guard let result = UInt32(string[digitStartIndex..<digitEndIndex], radix: 16) else {
                throw SDEFError(message: "Invalid four-char code (bad representation): \(string.debugDescription)")
            }
            return result
        } else {
            return try FourCharCode(fourByteString: string)
        }
    }
    
    func parse(eightCharCode string: NSString) throws -> (OSType, OSType) { // eventClass and eventID code
        if string.length == 8 {
            return (try FourCharCode(fourByteString: string.substring(to: 4)), try FourCharCode(fourByteString: string.substring(from: 4)))
        } else if string.length == 18 && (string.hasPrefix("0x") || string.hasPrefix("0X")) { // e.g. "0x0123456701234567"
            guard let eventClass = UInt32(string.substring(with: NSRange(location: 2, length: 8)), radix: 16),
                let eventID = UInt32(string.substring(with: NSRange(location: 10, length: 8)), radix: 16) else {
                    throw SDEFError(message: "Invalid eight-char code (bad representation): \(string.debugDescription)")
            }
            return (eventClass, eventID)
        } else {
            throw SDEFError(message: "Invalid eight-char code (wrong length): \((string as String).debugDescription)")
        }
    }
    
    private var codesForClassNames: [String : OSType] = [:]
    
    // extract name and code attributes from a class/enumerator/command/etc XML element
    
    private func attribute(_ name: String, of element: XMLElement) -> String? {
        return element.attribute(forName: name)?.stringValue
    }
    
    private func parse(keywordElement element: XMLElement) throws -> (String, OSType) {
        guard let name = self.attribute("name", of: element), let codeString = self.attribute("code", of: element), name != "" else {
            throw SDEFError(message: "Missing 'name'/'code' attribute.")
        }
        return (name, try parse(fourCharCode: codeString))
    }
    
    private func parse(commandElement element: XMLElement) throws -> (String, OSType, OSType) {
        guard let name = self.attribute("name", of: element), let codeString = self.attribute("code", of: element), name != "" else {
            throw SDEFError(message: "Missing 'name'/'code' attribute.")
        }
        let (eventClass, eventID) = try parse(eightCharCode: codeString as NSString)
        return (name, eventClass, eventID)
    }
    
    //
    
    private func parse(typeOfElement element: XMLElement) throws -> (String, OSType) { // class, record-type, value-type
        let (name, code) = try parse(keywordElement: element)
        delegate.addType(KeywordTerm(name: name, code: code, kind: .type))
        codesForClassNames[name] = code
        try parse(synonymsOfTypeElement: element, name: name, code: code)
        return (name, code)
    }
    
    private func parse(synonymsOfTypeElement element: XMLElement, name: String, code: OSType) throws {
        for element in element.elements(forName: "synonym") {
            let synName = self.attribute("name", of: element).flatMap { $0 == "" ? nil : $0 }
            let synCode = try self.attribute("code", of: element).map { try parse(fourCharCode: $0)}
            
            if let synName = synName {
                if let synCode = synCode {
                    delegate.addType(KeywordTerm(name: synName, code: synCode, kind: .type))
                } else {
                    delegate.addType(KeywordTerm(name: synName, code: code, kind: .type))
                }
            } else {
                if let synCode = synCode {
                    delegate.addType(KeywordTerm(name: name, code: synCode, kind: .type))
                } else {
                    throw SDEFError(message: "Missing 'name'/'code' attribute for synonym.")
                }
            }
        }
    }
    
    private func parse(propertiesOfElement element: XMLElement) throws { // class, class-extension, record-type, value-type
        for element in element.elements(forName: "property") {
            let (name, code) = try parse(keywordElement: element)
            delegate.addProperty(KeywordTerm(name: name, code: code, kind: .property))
        }
    }
    
    // parse a class/enumerator/command/etc element of a dictionary suite
    
    func parse(definition node: XMLNode) throws {
        if let element = node as? XMLElement, let tagName = element.name {
            switch tagName {
            case "class":
                let (name, code) = try parse(typeOfElement: element)
                try parse(propertiesOfElement: element)
                // use plural class name as elements name (if not given, append "s" to singular name)
                // (note: record and value types also define plurals, but we only use plurals for element names and elements should always be classes, so we ignore those)
                let plural = element.attribute(forName: "plural")?.stringValue ?? (
                    (name == "text" || name.hasSuffix("s")) ? name : "\(name)s") // SDEF spec says to append 's' to name when plural attribute isn't given; in practice, appending 's' doesn't work so well for names already ending in 's' (e.g. 'print settings'), nor for 'text' (which is AppleScript-defined), so special-case those here (note that macOS's SDEF->AETE converter will append "s" to singular names that already end in "s"; nothing we can do about that)
                delegate.addClass(ClassTerm(name: name, pluralName: plural, code: code))
            case "class-extension":
                guard let name = self.attribute("extends", of: element) else {
                    throw SDEFError(message: "Missing 'extends' attribute for class-extension.")
                }
                guard let code = codesForClassNames[name] else {
                    throw SDEFError(message: "class-extension extends unknown class '\(name)'")
                }
                try parse(propertiesOfElement: element)
                try parse(synonymsOfTypeElement: element, name: name, code: code)
            case "record-type":
                _ = try parse(typeOfElement: element)
                try parse(propertiesOfElement: element)
            case "value-type":
                _ = try parse(typeOfElement: element)
            case "enumeration":
                for element in element.elements(forName: "enumerator") {
                    let (name, code) = try parse(keywordElement: element)
                    delegate.addEnumerator(KeywordTerm(name: name, code: code, kind: .enumerator))
                }
            case "command", "event":
                let (name, eventClass, eventID) = try parse(commandElement: element)
                var command = CommandTerm(name: name, eventClass: eventClass, eventID: eventID)
                for element in element.elements(forName: "parameter") {
                    let (name, code) = try parse(keywordElement: element)
                    command.addParameter(name, code: code)
                }
                delegate.addCommand(command)
                /* TODO: Move this logic to consumers
                // Note: overlapping command definitions (e.g. 'path to') should be processed as follows:
                // - If their names and codes are the same, only the last definition is used; other definitions are ignored
                //   and will not compile.
                // - If their names are the same but their codes are different, only the first definition is used; other
                //   definitions are ignored and will not compile.
                let previousDef = self.commandsDict[name]
                if previousDef == nil || (previousDef!.eventClass == eventClass && previousDef!.eventID == eventID) {
                    let command = CommandTerm(name: name, eventClass: eventClass, eventID: eventID)
                    self.commandsDict[name] = command
                    for element in element.elements(forName: "parameter") {
                        let (name, code) = try parse(keywordElement: element)
                        command.addParameter(name, code: code)
                    }
                } // else ignore duplicate declaration
                */
            default:
                break
            }
        }
    }
    
    // parse the given SDEF XML data
    
    public func parse(_ sdef: Data) throws {
        do {
            let parser = try XMLDocument(data: sdef, options: XMLNode.Options.documentXInclude)
            guard let dictionary = parser.rootElement() else { throw SDEFError(message: "Missing `dictionary` element.") }
            for suite in dictionary.elements(forName: "suite") {
                if let nodes = suite.children {
                    for node in nodes { try parse(definition: node) }
                }
            }
        } catch {
            throw SDEFError(message: "An error occurred while parsing SDEF. \(error)")
        }
    }
}

// convenience function

public func readSDEF(from url: URL) throws -> Data {
    var sdef: Unmanaged<CFData>?
    let err = OSACopyScriptingDefinitionFromURL(url as NSURL, 0, &sdef)
    guard err == 0 else {
        throw SDEFError(message: "Can't retrieve SDEF (error \(err)).")
    }
    guard let sdef_ = sdef else {
        throw NoSDEF()
    }
    return sdef_.takeRetainedValue() as Data
}
