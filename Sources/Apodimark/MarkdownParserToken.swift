//
//  MarkdownParserToken.swift
//  Apodimark
//

/**
 A `MarkdownParserToken` is an element of a Collection representing a `String`.
 
 For example, these types could be `MarkdownParserToken`s:
 `UTF8.CodeUnit`, `UTF16.CodeUnit`, `UnicodeScalar`, `Character`, `Int8` (for ASCII strings), etc.
 */
public protocol MarkdownParserToken: Comparable, Hashable {
    /**
     Return the MarkdownParserToken corresponding to the ASCII character `char`.
     - precondition: 0 <= `char` < 128
     */
    static func fromASCII(_ char: UInt8) -> Self

    /**
     Return the digit represented by `token`
     - precondition: `token` corresponds to a digit.
     ```
     (fromASCII(zero) ... fromASCII(nine)).contains(token)
     ```
     - postcondition: return value is contained in 0 ... 9
     */
    static func digit(representedByToken token: Self) -> Int

    /**
     Return the string corresponding to `tokens`
     
     - Note: 
     The collection “`tokens`” might not represent a valid String. 
     If that happens, this function should not crash.
     */
    static func string <C: Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == Self
}

extension UTF8.CodeUnit: MarkdownParserToken {
    public static func digit(representedByToken token: UTF8.CodeUnit) -> Int {
        return Int(token) - 0x30
    }
    public static func string<C : Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == UTF8.CodeUnit
    {
        var codec = UTF8()
        var iterator = tokens.makeIterator()
        var result = ""

        while case let .scalarValue(scalar) = codec.decode(&iterator) {
            result.append(scalar)
        }
        return result
    }

    public static func fromASCII(_ char: UInt8) -> UTF8.CodeUnit {
        return char
    }

    static let linefeed   : UTF8.CodeUnit = 0x0A
    static let carriage   : UTF8.CodeUnit = 0x0D
    static let tab        : UTF8.CodeUnit = 0x09
    static let space      : UTF8.CodeUnit = 0x20
    static let exclammark : UTF8.CodeUnit = 0x21
    static let hash       : UTF8.CodeUnit = 0x23
    static let leftparen  : UTF8.CodeUnit = 0x28
    static let rightparen : UTF8.CodeUnit = 0x29
    static let asterisk   : UTF8.CodeUnit = 0x2A
    static let plus       : UTF8.CodeUnit = 0x2B
    static let hyphen     : UTF8.CodeUnit = 0x2D
    static let fullstop   : UTF8.CodeUnit = 0x2E
    static let zero       : UTF8.CodeUnit = 0x30
    static let nine       : UTF8.CodeUnit = 0x39
    static let colon      : UTF8.CodeUnit = 0x3A
    static let quote      : UTF8.CodeUnit = 0x3E
    static let leftsqbck  : UTF8.CodeUnit = 0x5B
    static let backslash  : UTF8.CodeUnit = 0x5C
    static let rightsqbck : UTF8.CodeUnit = 0x5D
    static let underscore : UTF8.CodeUnit = 0x5F
    static let backtick   : UTF8.CodeUnit = 0x60
    static let tilde      : UTF8.CodeUnit = 0x7E
}


extension UTF16.CodeUnit: MarkdownParserToken {

    public static func fromASCII(_ char: UInt8) -> UTF16.CodeUnit {
        return UTF16.CodeUnit(char)
    }

    public static func digit(representedByToken token: UTF16.CodeUnit) -> Int {
        return Int(token) - 0x30
    }

    public static func string <C : Collection> (fromTokens tokens: C) -> String
        where C.Iterator.Element == UTF16.CodeUnit
    {
        var codec = UTF16()
        var iterator = tokens.makeIterator()
        var result = ""
        while case let .scalarValue(scalar) = codec.decode(&iterator) {
            result.append(scalar)
        }
        return result
    }
}
