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
private enum ListParsingError: Error {
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
    private func readListMarker(scanner: inout Scanner<View>) throws -> ListKind {

        guard let firstToken = scanner.pop() else {
            preconditionFailure()
        }

        var value: Int

        switch firstToken {
        case hyphen     : return .bullet(.hyphen)
        case asterisk   : return .bullet(.star)
        case plus       : return .bullet(.plus)
        case zero...nine: value = Token.digit(representedByToken: firstToken)
        case _          : preconditionFailure()
        }

        // 1234)
        // |_<---

        var length = 1
        try scanner.popWhile { token in

            guard let token = token, token != linefeed else {
                throw ListParsingError.notAListMarker // e.g. 1234 followed by end of line / end of string
            }

            switch token {

            case fullstop, rightparen:
                return false // e.g. 1234|)| -> hurray! confirm and stop now

            case zero...nine:
                guard length < 9 else {
                    throw ListParsingError.notAListMarker // e.g. 123456789|0| -> too long
                }
                length += 1
                value = value * 10 + Token.digit(representedByToken: token)
                return true // e.g. 12|3| -> ok, keep reading

            case _:
                throw ListParsingError.notAListMarker // e.g. 12|a| -> not a list marker
            }
        }

        // will not crash because popWhile threw an error if lastToken is not fullstop or rightparen
        let lastToken = scanner.pop()!
        switch lastToken {
        case fullstop  : return .number(.dot, value)
        case rightparen: return .number(.parenthesis, value)
        default        : fatalError()
        }
    }

    /// Tries to parse a List. Advances the scanner to the end of the line and return the parsed line.
    /// - parameter scanner: a scanner whose `startIndex` points to the start of potential List line
    /// - parameter indent: the indent of the line being parsed
    /// - return: the parsed Line
    private func parseList(scanner: inout Scanner<View>, indent: Indent) -> Line<View> {

        let initialSubView = scanner
        //  1234)
        // |_<---

        do {
            let kind = try readListMarker(scanner: &scanner)
            //  1234)
            //      |_<---

            guard let token = scanner.pop(ifNot: linefeed) else {
                throw ListParsingError.emptyListItem(kind)
            }
            guard token == space else {
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
            scanner.popUntil(linefeed)
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
private enum HeaderTextReadingState { // e.g. for # Hello  World ####    \n
    case text         // # He|_
    case textSpaces   // # Hello |_
    case hashes       // # Hello   World #|_
    case endSpaces    // # Hello   World #### |_
}

extension MarkdownParser {
    /// Reads the content of a Header line
    /// - parameter scanner: a scanner whose `startIndex` points to to the start of the text in a Header line
    /// - returns: the index pointing to the end of the text in the header
    private func readHeaderText(scanner: inout Scanner<View>) -> View.Index {

        var state = HeaderTextReadingState.textSpaces
        var end = scanner.startIndex

        while let token = scanner.pop(ifNot: linefeed) {
            switch state {

            case .text:
                if token == space { state = .textSpaces }
                else { end = scanner.startIndex }

            case .textSpaces:
                if token == space { break }
                else if token == hash { state = .hashes }
                else { (state, end) = (.text, scanner.startIndex) }

            case .hashes:
                if token == hash { state = .hashes }
                else if token == space { state = .endSpaces }
                else { (state, end) = (.text, scanner.startIndex) }

            case .endSpaces:
                if token == space { break }
                else if token == hash { (state, end) = (.hashes, scanner.data.index(before: scanner.startIndex)) }
                else { (state, end) = (.text, scanner.startIndex) }
            }
        }

        return end
    }
}

/// Error type used for parsing a header line
private enum HeaderParsingError: Error {
    case notAHeader
    case emptyHeader(Int)
}

extension MarkdownParser {

    /// Tries to parse a Header. Advances the scanner to the end of the line.
    /// - parameter scanner: a scanner whose `startIndex` points the start of a potential Header line
    /// - parameter indent: the indent of the line being parsed
    /// - return: the parsed Line
    private func parseHeader(scanner: inout Scanner<View>, indent: Indent) -> Line<View> {

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

                case hash where level < 6:
                    level += 1
                    return true

                case space:
                    return false

                case linefeed:
                    throw HeaderParsingError.emptyHeader(level)

                case _:
                    throw HeaderParsingError.notAHeader
                }
            }
            // ##  Hello
            //  |_<---

            scanner.popWhile(space)
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
            scanner.popUntil(linefeed)
            return Line(.text, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch HeaderParsingError.emptyHeader(let level) {
            // scanner could point anywhere but not past end of line
            scanner.popUntil(linefeed)
            let lineKind = LineKind<View>.header(scanner.startIndex ..< scanner.startIndex, level)
            return Line(lineKind, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch {
            fatalError()
        }
    }
}

/// Error type used for a parsing a Fence
private enum FenceParsingError: Error {
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
    private func readFenceName(scanner: inout Scanner<View>) throws -> View.Index {

        // ```  name
        //     |_<---
        var end = scanner.startIndex

        while let token = scanner.pop(ifNot: linefeed) {
            switch token {

            case space:
                break

            case backtick:
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
    private func parseFence(scanner: inout Scanner<View>, indent: Indent) -> Line<View> {

        let initialSubview = scanner

        guard let firstLetter = scanner.pop() else { preconditionFailure() }
        let kind: FenceKind = firstLetter == backtick ? .Backtick : .Tilde

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

                case linefeed:
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

            scanner.popWhile(space)
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
            scanner.popUntil(linefeed)
            return Line(.text, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch let FenceParsingError.emptyFence(kind, level) {
            // scanner could point anywhere but not past end of line
            scanner.popUntil(linefeed)
            let linekind = LineKind<View>.fence(kind, scanner.startIndex ..< scanner.startIndex, level)
            return Line(linekind, indent, initialSubview.prefix(upTo: scanner.startIndex))
        }
        catch {
            fatalError()
        }
    }
}

/// Error type used for parsing a ThematicBreak line
private struct NotAThematicBreakError: Error {}

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
    private func readThematicBreak(scanner: inout Scanner<View>, firstToken: Token) throws {

        //  * * *
        // |_<--- (start of line)

        var level = 0
        try scanner.popWhile { token in

            guard let token = token, token != linefeed else {
                guard level >= 3 else {
                    throw NotAThematicBreakError() // e.g. * * -> not enough stars -> not a thematic break
                }
                return false // e.g. *  *  * * -> hurray! confirm and stop now
            }

            switch token {

            case firstToken: // e.g. * * |*| -> ok, keep reading
                level += 1
                return true

            case space, tab: // e.g. * * | | -> ok, keep reading
                return true

            default:
                throw NotAThematicBreakError() // e.g. * * |g| -> not a thematic break!
            }
        }
    }
}

/// Error type used when parsing a ReferenceDefinition line
private struct NotAReferenceDefinitionError: Error {}

extension MarkdownParser {

    /// Tries to parse a ReferenceDefinition line.
    ///
    /// Advances the scanner to the end of line if it succeeded, throws an error otherwise.
    ///
    /// - parameter scanner: a scanner pointing to the first token of what might be a ReferenceDefinition line
    /// - parameter indent: the indent of the line being parsed
    /// - throws: `NotAReferenceDefinitionError()` if the line is not a ReferenceDefinition line
    /// - returns: the parsed line
    private func parseReferenceDefinition(scanner: inout Scanner<View>, indent: Indent) throws -> Line<View> {

        //  [hello]:  world
        // |_<---
        let viewAfterIndent = scanner
        _ = scanner.pop()

        //  [hello]:  world
        //  |_<---
        let idxBeforeTitle = scanner.startIndex

        var escapeNext = false
        try scanner.popWhile { (token: Token?) throws -> Bool in

            guard let token = token, token != linefeed else {
                throw NotAReferenceDefinitionError()
            }

            guard !escapeNext else {
                escapeNext = false
                return true
            }

            guard token != leftsqbck else {
                throw NotAReferenceDefinitionError()
            }

            guard token != rightsqbck else {
                return false
            }

            escapeNext = (token == backslash)
            return true
        }

        let idxAfterTitle = scanner.startIndex
        guard idxAfterTitle > scanner.data.index(after: idxBeforeTitle) else {
            throw NotAReferenceDefinitionError()
        }

        _ = scanner.pop(rightsqbck)
        // [hello]:  world
        //       |_<---

        guard scanner.pop(colon) else { throw NotAReferenceDefinitionError() }

        scanner.popWhile(space)

        let idxBeforeDefinition = scanner.startIndex
        // [hello]:  world
        //          |_<---
        scanner.popUntil(linefeed)

        let idxAfterDefinition = scanner.startIndex
        guard idxBeforeDefinition < idxAfterDefinition else {
            throw NotAReferenceDefinitionError()
        }

        let definition = Token.string(fromTokens: scanner.data[idxBeforeDefinition ..< idxAfterDefinition])
        let title = Token.string(fromTokens: scanner.data[idxBeforeTitle ..< idxAfterTitle]).lowercased()

        return Line(.reference(title, definition), indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
    }

    func parseLine(scanner: inout Scanner<View>) -> Line<View> {
        //      xxxxx
        // |_<--- (start of line)

        var indent = Indent()
        scanner.popWhile { (token: Token?) -> Bool in

            guard let token = token else {
                return false
            }

            guard let indentKind = IndentKind(token) else {
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

        case quote:
            _ = scanner.pop()!
            let rest = parseLine(scanner: &scanner)
            return Line(.quote(rest), indent, viewAfterIndent.prefix(upTo: scanner.startIndex))


        case underscore:
            guard let _ = try? readThematicBreak(scanner: &scanner, firstToken: firstToken) else {
                scanner.popUntil(linefeed)
                return Line(.text, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
            }
            return Line(.thematicBreak, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))


        case hyphen, asterisk:
            guard let _ = try? readThematicBreak(scanner: &scanner, firstToken: firstToken) else {
                return parseList(scanner: &scanner, indent: indent)
            }
            return Line(.thematicBreak, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))


        case plus, zero...nine:
            return parseList(scanner: &scanner, indent: indent)


        case hash:
            return parseHeader(scanner: &scanner, indent: indent)


        case linefeed:
            return Line(.empty, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))


        case backtick, tilde:
            return parseFence(scanner: &scanner, indent: indent)


        case leftsqbck:
            guard let line = try? parseReferenceDefinition(scanner: &scanner, indent: indent) else {
                scanner.popUntil(linefeed)
                return Line(.text, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
            }
            return line


        case _:
            scanner.popUntil(linefeed)
            return Line(.text, indent, viewAfterIndent.prefix(upTo: scanner.startIndex))
        }
    }
}

