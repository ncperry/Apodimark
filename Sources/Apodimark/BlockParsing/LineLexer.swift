//
//  LineLexer.swift
//  Apodimark
//

/*
 HOW TO READ THE COMMENTS:
 
 Example:
 Lorem Ipsum blah blah
        |_<---

 Means that scanner points to “s”
 Therefore:
 - “p” has already been read
 - scanner.startIndex is the index of “s”
 - the next scanner.peek() will return “s”
 */

/// Error type used for parsing a List line
fileprivate enum ListParsingError: Error {
    case notAListMarker
    case emptyListItem(ListKind)
}

extension MarkdownParser {

    /// Advances the scanner to the end of the valid marker, or throws an error and leaves the scanner intact
    /// if the list marker is invalid.
    /// - parameter scanner: a scanner whose `startIndex` points to the first token of the list marker
    ///   (e.g. a hyphen, an asterisk, a digit)
    /// - throws: `ListParsingError.notAListMarker` if the list marker is invalid
    /// - returns: the kind of the list marker
    fileprivate func readListMarker(scanner: inout Scanner<View>) throws -> ListKind {

        guard let firstToken = scanner.pop() else {
            preconditionFailure()
        }

        var value: Int

        switch firstToken {
        case Codec.hyphen     : return .bullet(.hyphen)
        case Codec.asterisk   : return .bullet(.star)
        case Codec.plus       : return .bullet(.plus)
        case Codec.zero...Codec.nine: value = Codec.digit(representedByToken: firstToken)
        case _          : preconditionFailure()
        }

        // 1234)
        // |_<---

        var length = 1
        try scanner.popWhile { token in

            guard let token = token, token != Codec.linefeed else {
                throw ListParsingError.notAListMarker // e.g. 1234 followed by end of line / end of string
            }

            switch token {

            case Codec.fullstop, Codec.rightparen:
                return false // e.g. 1234|)| -> hurray! confirm and stop now

            case Codec.zero...Codec.nine:
                guard length < 9 else {
                    throw ListParsingError.notAListMarker // e.g. 123456789|0| -> too long
                }
                length += 1
                value = value * 10 + Codec.digit(representedByToken: token)
                return true // e.g. 12|3| -> ok, keep reading

            case _:
                throw ListParsingError.notAListMarker // e.g. 12|a| -> not a list marker
            }
        }

        // will not crash because popWhile threw an error if lastToken is not fullstop or rightparen
        let lastToken = scanner.pop()!
        switch lastToken {
        case Codec.fullstop  : return .number(.dot, value)
        case Codec.rightparen: return .number(.parenthesis, value)
        default        : fatalError()
        }
    }

    /// Tries to parse a List. Advances the scanner to the end of the line and return the parsed line.
    /// - parameter scanner: a scanner whose `startIndex` points to the start of potential List line
    /// - parameter indent: the indent of the line being parsed
    /// - return: the parsed Line
    fileprivate func parseList(scanner: inout Scanner<View>, indent: Indent) -> Line<View> {

        let initialSubView = scanner
        //  1234)
        // |_<---

        do {
            let kind = try readListMarker(scanner: &scanner)
            //  1234)
            //      |_<---

            guard let token = scanner.pop(ifNot: Codec.linefeed) else {
                throw ListParsingError.emptyListItem(kind)
            }
            guard token == Codec.space else {
                throw ListParsingError.notAListMarker
            }
            //  1234)
            //       |_<---

            let rest = parseLine(scanner: &scanner)
            return Line(.list(kind, rest), indent, initialSubView.prefix(upTo: scanner.startIndex))
        }
        catch ListParsingError.notAListMarker {
            // xxxxx…
            //    |_<--- scanner could point anywhere but not past the end of the line
            scanner.popUntil(Codec.linefeed)
            return Line(.text, indent, initialSubView.prefix(upTo: scanner.startIndex))
        }
        catch ListParsingError.emptyListItem(let kind) {
            // 1234)\n
            //     |__<---
            let finalSubview = initialSubView.prefix(upTo: scanner.startIndex)
            let rest = Line(.empty, indent, finalSubview)
            return Line(.list(kind, rest), indent, finalSubview)
        }
        catch {
            fatalError()
        }
    }
}

/// State used for read the content of a Header line
fileprivate enum HeaderTextReadingState { // e.g. for # Hello  World ####    \n
    case text         // # He|_
    case textSpaces   // # Hello |_
    case hashes       // # Hello   World #|_
    case endSpaces    // # Hello   World #### |_
}

extension MarkdownParser {
    /// Reads the content of a Header line
    /// - parameter scanner: a scanner whose `startIndex` points to to the start of the text in a Header line
    /// - returns: the index pointing to the end of the text in the header
    fileprivate func readHeaderText(scanner: inout Scanner<View>) -> View.Index {

        var state = HeaderTextReadingState.textSpaces
        var end = scanner.startIndex

        while let token = scanner.pop(ifNot: Codec.linefeed) {
            switch state {

            case .text:
                if token == Codec.space { state = .textSpaces }
                else { end = scanner.startIndex }

            case .textSpaces:
                if token == Codec.space { break }
                else if token == Codec.hash { state = .hashes }
                else { (state, end) = (.text, scanner.startIndex) }

            case .hashes:
                if token == Codec.hash { state = .hashes }
                else if token == Codec.space { state = .endSpaces }
                else { (state, end) = (.text, scanner.startIndex) }

            case .endSpaces:
                if token == Codec.space { break }
                else if token == Codec.hash { (state, end) = (.hashes, scanner.data.index(before: scanner.startIndex)) }
                else { (state, end) = (.text, scanner.startIndex) }
            }
        }

        return end
    }
}

/// Error type used for parsing a header line
fileprivate enum HeaderParsingError: Error {
    case notAHeader
    case emptyHeader(Int)
}

extension MarkdownParser {

    /// Tries to parse a Header. Advances the scanner to the end of the line.
    /// - parameter scanner: a scanner whose `startIndex` points the start of a potential Header line
    /// - parameter indent: the indent of the line being parsed
    /// - return: the parsed Line
    fileprivate func parseHeader(scanner: inout Scanner<View>, indent: Indent) -> Line<View> {

        let initialSubview = scanner
        //  xxxxxx
        // |_<--- (start of line)

        do {
            var level = 0
            try scanner.popWhile { token in

                guard let token = token else {
                    throw HeaderParsingError.emptyHeader(level)
                }

                switch token {

                case Codec.hash where level < 6:
                    level += 1
                    return true

                case Codec.space:
                    return false

                case Codec.linefeed:
                    throw HeaderParsingError.emptyHeader(level)

                default:
                    throw HeaderParsingError.notAHeader
                }
            }
            // ##  Hello
            //  |_<---

            scanner.popWhile(Codec.space)
            // ##  Hello
            //    |_<---

            let start = scanner.startIndex
            let end = readHeaderText(scanner: &scanner)
            // ##  Hello World ####\n
            //    |          |    |__<---
            //    |_         |_
            //    start    end

            let headerkind = LineKind<View>.header(start ..< end, level)
            return Line(headerkind, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch HeaderParsingError.notAHeader {
            // scanner could point anywhere but not past end of line
            scanner.popUntil(Codec.linefeed)
            return Line(.text, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch HeaderParsingError.emptyHeader(let level) {
            // scanner could point anywhere but not past end of line
            scanner.popUntil(Codec.linefeed)
            let lineKind = LineKind<View>.header(scanner.startIndex ..< scanner.startIndex, level)
            return Line(lineKind, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch {
            fatalError()
        }
    }
}

/// Error type used for a parsing a Fence
fileprivate enum FenceParsingError: Error {
    case notAFence
    case emptyFence(FenceKind, Int)
}

extension MarkdownParser {

    /// Tries to read the name of Fence line. 
    ///
    /// Advances the scanner to the end of the line if it succeeded, throws an error otherwise.
    ///
    /// - parameter scanner: a scanner pointing to the first letter of a potential Fence’s name
    /// - throws: `FenceParsingError.notAFence` if the line is not a Fence line
    /// - returns: the index pointing to the end of the name
    fileprivate func readFenceName(scanner: inout Scanner<View>) throws -> View.Index {

        // ```  name
        //     |_<---
        var end = scanner.startIndex

        while let token = scanner.pop(ifNot: Codec.linefeed) {
            switch token {

            case Codec.space:
                break

            case Codec.backtick:
                throw FenceParsingError.notAFence

            case _:
                end = scanner.startIndex
            }
        }
        // ```  name    \n
        //         |_  |__<---
        //        end
        return end
    }
}

extension MarkdownParser {

    /// Tries to parse a Fence line.
    ///
    /// Advances the scanner to the end of the line.
    ///
    /// - parameter scanner: a scanner whose pointing to the start of what might be a Fence line
    /// - parameter indent: the indent of the line being parsed
    /// - returns: the parsed line
    fileprivate func parseFence(scanner: inout Scanner<View>, indent: Indent) -> Line<View> {

        let initialSubview = scanner

        guard let firstLetter = scanner.pop() else { preconditionFailure() }
        let kind: FenceKind = firstLetter == Codec.backtick ? .backtick : .tilde

        // ```   name
        // |_<---

        do {
            var level = 1
            try scanner.popWhile { token in

                guard let token = token else {
                    throw FenceParsingError.emptyFence(kind, level)
                }

                switch token {

                case firstLetter:
                    level += 1
                    return true

                case Codec.linefeed:
                    guard level >= 3 else {
                        throw FenceParsingError.notAFence
                    }
                    throw FenceParsingError.emptyFence(kind, level)

                case _:
                    guard level >= 3 else {
                        throw FenceParsingError.notAFence
                    }
                    return false
                }
            }
            // ```   name
            //   |_<---

            scanner.popWhile(Codec.space)
            // ```   name
            //      |_<---

            let start = scanner.startIndex
            let end = try readFenceName(scanner: &scanner)
            // ```   name    \n
            //      |   |   |__<---
            //      |_  |_
            //  start   end

            let linekind = LineKind<View>.fence(kind, start ..< end, level)
            return Line(linekind, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch FenceParsingError.notAFence {
            // scanner could point anywhere but not past end of line
            scanner.popUntil(Codec.linefeed)
            return Line(.text, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch let FenceParsingError.emptyFence(kind, level) {
            // scanner could point anywhere but not past end of line
            scanner.popUntil(Codec.linefeed)
            let linekind = LineKind<View>.fence(kind, scanner.startIndex ..< scanner.startIndex, level)
            return Line(linekind, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch {
            fatalError()
        }
    }
}

/// Error type used for parsing a ThematicBreak line
fileprivate struct NotAThematicBreakError: Error {}

extension MarkdownParser {

    /// Tries to read a ThematicBreak line.
    /// 
    /// Advances the scanner to the end of the line if it succeeded, throws an error otherwise.
    /// 
    /// - precondition: `firstToken == scanner.pop()`
    ///
    /// (not checked at runtime)
    ///
    /// - parameter scanner: a scanner pointing to the start of what might be a ThematicBreak line
    /// - parameter firstToken: the first token of the potential ThematicBreak line
    /// - throws: `NotAThematicBreakError()` if the line is not a ThematicBreak line
    fileprivate func readThematicBreak(scanner: inout Scanner<View>, firstToken: Codec.CodeUnit) throws {

        //  * * *
        // |_<--- (start of line)

        var level = 0
        try scanner.popWhile { token in

            guard let token = token, token != Codec.linefeed else {
                guard level >= 3 else {
                    throw NotAThematicBreakError() // e.g. * * -> not enough stars -> not a thematic break
                }
                return false // e.g. *  *  * * -> hurray! confirm and stop now
            }

            switch token {

            case firstToken: // e.g. * * |*| -> ok, keep reading
                level += 1
                return true

            case Codec.space, Codec.tab: // e.g. * * | | -> ok, keep reading
                return true

            default:
                throw NotAThematicBreakError() // e.g. * * |g| -> not a thematic break!
            }
        }
    }
}

/// Error type used when parsing a ReferenceDefinition line
fileprivate struct NotAReferenceDefinitionError: Error {}

extension MarkdownParser {

    /// Tries to parse a ReferenceDefinition line.
    ///
    /// Advances the scanner to the end of line if it succeeded, throws an error otherwise.
    ///
    /// - parameter scanner: a scanner pointing to the first token of what might be a ReferenceDefinition line
    /// - parameter indent: the indent of the line being parsed
    /// - throws: `NotAReferenceDefinitionError()` if the line is not a ReferenceDefinition line
    /// - returns: the parsed line
    fileprivate func parseReferenceDefinition(scanner: inout Scanner<View>, indent: Indent) throws -> Line<View> {

        //  [hello]:  world
        // |_<---
        let viewAfterIndent = scanner
        _ = scanner.pop()

        //  [hello]:  world
        //  |_<---
        let idxBeforeTitle = scanner.startIndex

        var escapeNext = false
        try scanner.popWhile { (token: Codec.CodeUnit?) throws -> Bool in

            guard let token = token, token != Codec.linefeed else {
                throw NotAReferenceDefinitionError()
            }

            guard !escapeNext else {
                escapeNext = false
                return true
            }

            guard token != Codec.leftsqbck else {
                throw NotAReferenceDefinitionError()
            }

            guard token != Codec.rightsqbck else {
                return false
            }

            escapeNext = (token == Codec.backslash)
            return true
        }

        let idxAfterTitle = scanner.startIndex
        guard idxAfterTitle > scanner.data.index(after: idxBeforeTitle) else {
            throw NotAReferenceDefinitionError()
        }

        _ = scanner.pop(Codec.rightsqbck)
        // [hello]:  world
        //       |_<---

        guard scanner.pop(Codec.colon) else { throw NotAReferenceDefinitionError() }

        scanner.popWhile(Codec.space)

        let idxBeforeDefinition = scanner.startIndex
        // [hello]:  world
        //          |_<---
        scanner.popUntil(Codec.linefeed)

        let idxAfterDefinition = scanner.startIndex
        guard idxBeforeDefinition < idxAfterDefinition else {
            throw NotAReferenceDefinitionError()
        }

        let definition = Codec.string(fromTokens: scanner.data[idxBeforeDefinition ..< idxAfterDefinition])
        let title = Codec.string(fromTokens: scanner.data[idxBeforeTitle ..< idxAfterTitle]).lowercased()

        return Line(.reference(title, definition), indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
    }

    func parseLine(scanner: inout Scanner<View>) -> Line<View> {
        //      xxxxx
        // |_<--- (start of line)

        var indent = Indent()
        scanner.popWhile { (token: Codec.CodeUnit?) -> Bool in

            guard let token = token else {
                return false
            }

            guard let indentKind = IndentKind(token, codec: Codec.self) else {
                return false
            }

            indent.add(indentKind)
            return true
        }

        let viewAfterIndent = scanner
        //       xxxx
        //      |_<--- (after indent)

        guard let firstToken = scanner.peek() else {
            return Line(.empty, Indent(), scanner)
        }

        switch firstToken {

        case Codec.quote:
            _ = scanner.pop()!
            let rest = parseLine(scanner: &scanner)
            return Line(.quote(rest), indent, viewAfterIndent.prefix(upTo: scanner.startIndex))


        case Codec.underscore:
            guard let _ = try? readThematicBreak(scanner: &scanner, firstToken: firstToken) else {
                scanner.popUntil(Codec.linefeed)
                return Line(.text, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
            }
            return Line(.thematicBreak, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))


        case Codec.hyphen, Codec.asterisk:
            if case .some = try? readThematicBreak(scanner: &scanner, firstToken: firstToken) {
                return Line(.thematicBreak, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
            } else {
                return parseList(scanner: &scanner, indent: indent)
            }


        case Codec.plus, Codec.zero...Codec.nine:
            return parseList(scanner: &scanner, indent: indent)


        case Codec.hash:
            return parseHeader(scanner: &scanner, indent: indent)


        case Codec.linefeed:
            return Line(.empty, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))


        case Codec.backtick, Codec.tilde:
            return parseFence(scanner: &scanner, indent: indent)


        case Codec.leftsqbck:
            guard let line = try? parseReferenceDefinition(scanner: &scanner, indent: indent) else {
                scanner.popUntil(Codec.linefeed)
                return Line(.text, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
            }
            return line


        case _:
            scanner.popUntil(Codec.linefeed)
            return Line(.text, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
        }
    }
}
