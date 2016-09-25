//
//  MarkdownParserCodec.swift
//  Apodimark
//

public protocol MarkdownParserCodec {
    
    associatedtype CodeUnit: Comparable, Hashable
    
    /**
     Return the CodeUnit corresponding to the ASCII character `char`.
     - precondition: 0 <= `char` < 128
     */
    static func fromASCII(_ char: UInt8) -> CodeUnit
    
    /**
     Return the digit represented by `token`
     - precondition: `token` corresponds to a digit.
     ```
     (fromASCII(zero) ... fromASCII(nine)).contains(token)
     ```
     - postcondition: return value is contained in 0 ... 9
     */
    static func digit(representedByToken token: CodeUnit) -> Int
    
    /**
     Return the string corresponding to `tokens`
     
     - Note:
     The collection “`tokens`” might not represent a valid String.
     If that happens, this function should not crash.
     */
    static func string <C: Collection> (fromTokens tokens: C) -> String
    where C.Iterator.Element == CodeUnit
}

extension MarkdownParserCodec {
    
    static var linefeed   : CodeUnit { return Self.fromASCII(0x0A) }
    static var carriage   : CodeUnit { return Self.fromASCII(0x0D) }
    static var tab        : CodeUnit { return Self.fromASCII(0x09) }
    static var space      : CodeUnit { return Self.fromASCII(0x20) }
    static var exclammark : CodeUnit { return Self.fromASCII(0x21) }
    static var hash       : CodeUnit { return Self.fromASCII(0x23) }
    static var leftparen  : CodeUnit { return Self.fromASCII(0x28) }
    static var rightparen : CodeUnit { return Self.fromASCII(0x29) }
    static var asterisk   : CodeUnit { return Self.fromASCII(0x2A) }
    static var plus       : CodeUnit { return Self.fromASCII(0x2B) }
    static var hyphen     : CodeUnit { return Self.fromASCII(0x2D) }
    static var fullstop   : CodeUnit { return Self.fromASCII(0x2E) }
    static var zero       : CodeUnit { return Self.fromASCII(0x30) }
    static var nine       : CodeUnit { return Self.fromASCII(0x39) }
    static var colon      : CodeUnit { return Self.fromASCII(0x3A) }
    static var quote      : CodeUnit { return Self.fromASCII(0x3E) }
    static var leftsqbck  : CodeUnit { return Self.fromASCII(0x5B) }
    static var backslash  : CodeUnit { return Self.fromASCII(0x5C) }
    static var rightsqbck : CodeUnit { return Self.fromASCII(0x5D) }
    static var underscore : CodeUnit { return Self.fromASCII(0x5F) }
    static var backtick   : CodeUnit { return Self.fromASCII(0x60) }
    static var tilde      : CodeUnit { return Self.fromASCII(0x7E) }
}

enum CharacterCodec: MarkdownParserCodec {
    typealias CodeUnit = Character
    
    public static func fromASCII(_ char: UInt8) -> Character {
        return Character(UnicodeScalar(char))
    }
    
    public static func digit(representedByToken token: Character) -> Int {
        return Int(String(token))!
    }
    
    public static func string <C: Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == Character
    {
        return String(tokens)
    }
}

enum UnicodeScalarCodec: MarkdownParserCodec {
    typealias CodeUnit = UnicodeScalar
    
    public static func fromASCII(_ char: UInt8) -> UnicodeScalar {
        return UnicodeScalar(char)
    }
    
    public static func digit(representedByToken token: UnicodeScalar) -> Int {
        return Int(token.value - 0x30)
    }
    
    public static func string <C: Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == UnicodeScalar
    {
        var s = ""
        s.unicodeScalars.append(contentsOf: tokens)
        return s
    }
}

extension UTF8: MarkdownParserCodec {
    public static func fromASCII(_ char: UInt8) -> CodeUnit {
        return char
    }
    
    public static func digit(representedByToken token: CodeUnit) -> Int {
        return Int(token - 0x30)
    }
    
    public static func string <C: Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == CodeUnit
    {
        var codec = UTF8()
        var iter = tokens.makeIterator()
        var s = ""
        while case .scalarValue(let scalar) = codec.decode(&iter) {
            s.unicodeScalars.append(scalar)
        }
        return s
    }
    
}
extension UTF16: MarkdownParserCodec {

    public static func string <C : Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == UTF16.CodeUnit
    {
        var iter = tokens.makeIterator()
        var codec = UTF16()
        var s = ""
        while case let .scalarValue(scalar) = codec.decode(&iter) {
            s.unicodeScalars.append(scalar)
        }
        return s
    }

    public static func digit(representedByToken token: CodeUnit) -> Int {
        return Int(token - 0x30)
    }

    public static func fromASCII(_ char: UInt8) -> CodeUnit {
        return UInt16(char)
    }
}

extension UTF32: MarkdownParserCodec {
    
    public static func string <C : Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == UTF32.CodeUnit
    {
        var iter = tokens.makeIterator()
        var codec = UTF32()
        var s = ""
        while case let .scalarValue(scalar) = codec.decode(&iter) {
            s.unicodeScalars.append(scalar)
        }
        return s
    }
    
    public static func digit(representedByToken token: CodeUnit) -> Int {
        return Int(token - 0x30)
    }
    
    public static func fromASCII(_ char: UInt8) -> CodeUnit {
        return UInt32(char)
    }
}






