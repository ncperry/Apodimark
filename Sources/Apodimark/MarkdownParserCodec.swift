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
     Return the string corresponding to `tokens`
     
     - Note:
     The collection “`tokens`” might not represent a valid String.
     If that happens, this function should not crash.
     */
    static func string <S: Sequence> (fromTokens tokens: S) -> String
        where S.Iterator.Element == CodeUnit
    
    static func unicodeScalar(from token: CodeUnit) -> UnicodeScalar?
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

private let asciiPunctuationTokens: [Bool] = {
    var map = Array(repeating: false, count: 128)
    let punctuationSigns = [
        0x21, 0x22, 0x23, 0x24,
        0x25, 0x26, 0x27, 0x28,
        0x29, 0x2A, 0x2B, 0x2C,
        0x2D, 0x2E, 0x2F, 0x3A,
        0x3B, 0x3C, 0x3D, 0x3E,
        0x3F, 0x40, 0x5B, 0x5C,
        0x5D, 0x5E, 0x5F, 0x60,
        0x7B, 0x7C, 0x7D, 0x7E,
        ]
    for codeUnit in punctuationSigns {
        map[codeUnit] = true
    }
    return map
}()


extension MarkdownParserCodec {
    
    public static func isPunctuation(_ token: CodeUnit) -> Bool {
        guard let scalar = unicodeScalar(from: token), scalar.value < 128 else { return false }
        return asciiPunctuationTokens[Int(scalar.value)]
    }
    
    /**
     Return the digit represented by `token`
     - precondition: `token` corresponds to a digit.
     ```
     (fromASCII(zero) ... fromASCII(nine)).contains(token)
     ```
     - postcondition: return value is contained in 0 ... 9
     */
    static func digit(representedByToken token: CodeUnit) -> Int {
        let scalar = unicodeScalar(from: token)!
        return Int(scalar.value - 0x30)
    }
}

public enum UTF8MarkdownCodec: MarkdownParserCodec {
    
    public static func unicodeScalar(from token: UInt8) -> UnicodeScalar? {
        return UnicodeScalar(token)
    }
    
    public typealias CodeUnit = UInt8
    
    public static func fromASCII(_ char: UInt8) -> CodeUnit {
        return char
    }
    
    public static func string <S: Sequence> (fromTokens tokens: S) -> String
        where S.Iterator.Element == CodeUnit
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

public enum UTF16MarkdownCodec: MarkdownParserCodec {
    
    public typealias CodeUnit = UInt16

    public static func unicodeScalar(from token: UInt16) -> UnicodeScalar? {
        return UnicodeScalar(token)
    }
    
    public static func string <S: Sequence> (fromTokens tokens: S) -> String
        where S.Iterator.Element == CodeUnit
    {
        var iter = tokens.makeIterator()
        var codec = UTF16()
        var s = ""
        while case let .scalarValue(scalar) = codec.decode(&iter) {
            s.unicodeScalars.append(scalar)
        }
        return s
    }

    public static func fromASCII(_ char: UInt8) -> CodeUnit {
        return UInt16(char)
    }
}

public enum UTF32MarkdownCodec: MarkdownParserCodec {

    public typealias CodeUnit = UInt32
    
    public static func unicodeScalar(from token: UInt32) -> UnicodeScalar? {
        return UnicodeScalar(token)
    }
    
    public static func string <S: Sequence> (fromTokens tokens: S) -> String
        where S.Iterator.Element == CodeUnit
    {
        var iter = tokens.makeIterator()
        var codec = UTF32()
        var s = ""
        while case let .scalarValue(scalar) = codec.decode(&iter) {
            s.unicodeScalars.append(scalar)
        }
        return s
    }

    public static func fromASCII(_ char: UInt8) -> CodeUnit {
        return UInt32(char)
    }
}

public enum CharacterMarkdownCodec: MarkdownParserCodec {
    
    public typealias CodeUnit = Character

    public static func unicodeScalar(from token: Character) -> UnicodeScalar? {
        return String(token).unicodeScalars.first
    }
    
    public static func fromASCII(_ char: UInt8) -> Character {
        return Character(UnicodeScalar(char))
    }
    
    public static func string <S: Sequence> (fromTokens tokens: S) -> String
        where S.Iterator.Element == CodeUnit
    {
        return String(tokens)
    }
}

public enum UnicodeScalarMarkdownCodec: MarkdownParserCodec {
    
    public typealias CodeUnit = UnicodeScalar

    public static func unicodeScalar(from token: UnicodeScalar) -> UnicodeScalar? {
        return token
    }
    
    public static func fromASCII(_ char: UInt8) -> UnicodeScalar {
        return UnicodeScalar(char)
    }
    
    public static func string <S: Sequence> (fromTokens tokens: S) -> String
        where S.Iterator.Element == CodeUnit
    {
        var s = ""
        s.unicodeScalars.append(contentsOf: tokens)
        return s
    }
}
