//
//  MarkdownParserToken.swift
//  Apodimark
//


public protocol MarkdownParserToken: Comparable, Hashable {
    static func fromUTF8CodePoint(_ char: UInt8) -> Self
    static func digit(representedByToken _: Self) -> Int
    static func string <C: Collection where C.Iterator.Element == Self> (fromTokens _: C) -> String
}

extension UTF8.CodeUnit: MarkdownParserToken {
    public static func digit(representedByToken token: UTF8.CodeUnit) -> Int {
        return Int(token) - 0x30
    }
    public static func string<C : Collection where C.Iterator.Element == UTF8.CodeUnit> (fromTokens tokens: C) -> String {
        var codec = UTF8()
        var iterator = tokens.makeIterator()
        var result = ""

        while case let .scalarValue(scalar) = codec.decode(&iterator) {
            result.append(scalar)
        }
        return result
    }
    public static func fromUTF8CodePoint(_ char: UInt8) -> UTF8.CodeUnit {
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
    static let one        : UTF8.CodeUnit = 0x30
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

    public static func fromUTF8CodePoint(_ char: UInt8) -> UTF16.CodeUnit {
        return UTF16.CodeUnit(char)
    }

    public static func digit(representedByToken token: UTF16.CodeUnit) -> Int {
        return Int(token) - 0x30
    }

    public static func string <C : Collection where C.Iterator.Element == UTF16.CodeUnit> (fromTokens tokens: C) -> String {
        var codec = UTF16()
        var iterator = tokens.makeIterator()
        var result = ""

        while case let .scalarValue(scalar) = codec.decode(&iterator) {
            result.append(scalar)
        }
        return result
    }
}
