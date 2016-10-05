//
//  InlineDelimiters.swift
//  Apodimark
//

extension MarkdownParser {

    func delimiters(in text: [Range<View.Index>]) -> [Delimiter?] {

        var delimiters: [Delimiter?] = []

        var scanners = text.lazy.map { Scanner(data: self.view, startIndex: $0.lowerBound, endIndex: $0.upperBound) }.makeIterator()
        var optScanner: Scanner? = scanners.next()!

        while var scanner = optScanner {

            var numberOfPreviousSpaces = 0
            var potentialBackslashHardbreak = false

            var prevTokenKind = TokenKind.whitespace

            delimiters.append((.start, scanner.startIndex))

            while let token = scanner.pop() {
                let curTokenKind = tokenKind(token)
                defer { prevTokenKind = curTokenKind }

                if token == Codec.space {
                    numberOfPreviousSpaces += 1
                    continue
                } else {
                    defer { numberOfPreviousSpaces = 0 }
                }

                switch token {

                case Codec.underscore, Codec.asterisk:
                    let idxBeforeRun = view.index(before: scanner.startIndex)
                    scanner.popWhile(token)
                    let nextTokenKind: TokenKind = scanner.peek().flatMap { tokenKind($0) } ?? .whitespace
        
                    let delimiterState = DelimiterState(token: token, prev: prevTokenKind, next: nextTokenKind, codec: Codec.self)
                    let lvl = view.distance(from: idxBeforeRun, to: scanner.startIndex)
                    let kind: EmphasisKind = token == Codec.underscore ? .underscore : .asterisk
                    delimiters.append((.emph(kind, delimiterState, Int(lvl.toIntMax())), scanner.startIndex))

                case Codec.backtick:
                    let idxBeforeRun = view.index(before: scanner.startIndex)
                    scanner.popWhile(Codec.backtick)
                    let lvl = Int(view.distance(from: idxBeforeRun, to: scanner.startIndex).toIntMax())
                    delimiters.append((.code(lvl), scanner.startIndex))

                case Codec.exclammark:
                    if scanner.pop(Codec.leftsqbck) {
                        delimiters.append((.unwrappedRefOpener, scanner.startIndex))
                    }

                case Codec.leftsqbck:
                    delimiters.append((.refOpener, scanner.startIndex))

                case Codec.rightsqbck:
                    delimiters.append((.refCloser, scanner.startIndex))
                    if scanner.pop(Codec.leftparen) {
                        delimiters.append((.refValueOpener, scanner.startIndex))
                    }

                case Codec.leftparen:
                    delimiters.append((.leftParen, scanner.startIndex))

                case Codec.rightparen:
                    delimiters.append((.rightParen, scanner.startIndex))

                case Codec.backslash:
                    guard let el = scanner.peek() else {
                        potentialBackslashHardbreak = true
                        break
                    }
                    if Codec.isPunctuation(el) {
                        delimiters.append((.ignored, scanner.startIndex))
                        if el != Codec.backtick { _ = scanner.pop() }
                    }

                case _:
                    break
                }
            }

            optScanner = scanners.next()
            let offset =  IntMax(-(numberOfPreviousSpaces + ((potentialBackslashHardbreak && optScanner != nil) ? 1 : 0)))
            let lastIndex = view.index(scanner.startIndex, offsetBy: View.IndexDistance(offset))
            delimiters.append((.end, lastIndex))

            if optScanner != nil { // linefeed
                if potentialBackslashHardbreak || numberOfPreviousSpaces >= 2 {
                    delimiters.append((.hardbreak, scanner.startIndex))
                }
                else {
                    delimiters.append((.softbreak, scanner.startIndex))
                }
            }
        }
        
        return delimiters
    }
}
