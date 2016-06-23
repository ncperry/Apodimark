//
//  InlineDelimiters.swift
//  Apodimark
//

extension MarkdownParser {

    typealias Delimiter = (kind: DelimiterKind, idx: View.Index)

    func delimiters(inScanners scanners: [Scanner<View>]) -> [Delimiter?] {

        var delimiters = [Delimiter?]()

        var scannersIterator = scanners.makeIterator()
        var optScanner: Scanner? = scannersIterator.next()!

        while var scanner = optScanner {

            var numberOfPreviousSpaces = 0
            var potentialBackslashHardbreak = false

            var prevTokenKind = TokenKind.whitespace

            delimiters.append((.start, scanner.startIndex))

            while let token = scanner.pop() {
                let curTokenKind = tokenKind(token)
                defer { prevTokenKind = curTokenKind }

                if token == space {
                    numberOfPreviousSpaces += 1
                    continue
                } else {
                    defer { numberOfPreviousSpaces = 0 }
                }

                switch token {

                case underscore, asterisk:
                    let idxBeforeRun = scanner.data.index(before: scanner.startIndex)
                    scanner.popWhile(token)
                    let nextTokenKind: TokenKind
                    if let nextToken = scanner.peek() {
                        nextTokenKind = tokenKind(nextToken)
                    } else {
                        nextTokenKind = .whitespace
                    }
                    let delimiterState = DelimiterState(token: token, prev: prevTokenKind, next: nextTokenKind)
                    let lvl = scanner.data.distance(from: idxBeforeRun, to: scanner.startIndex)
                    let kind: EmphasisKind = token == underscore ? .underscore : .asterisk
                    delimiters.append((.emph(kind, delimiterState, Int(lvl.toIntMax())), scanner.startIndex))

                case backtick:
                    let idxBeforeRun = scanner.data.index(before: scanner.startIndex)
                    scanner.popWhile(backtick)
                    let lvl = Int(scanner.data.distance(from: idxBeforeRun, to: scanner.startIndex).toIntMax())
                    delimiters.append((.code(lvl), scanner.startIndex))

                case exclammark:
                    if scanner.pop(leftsqbck) {
                        delimiters.append((.unwrappedRefOpener, scanner.startIndex))
                    }

                case leftsqbck:
                    delimiters.append((.refOpener, scanner.startIndex))

                case rightsqbck:
                    delimiters.append((.refCloser, scanner.startIndex))
                    if scanner.pop(leftparen) {
                        delimiters.append((.refValueOpener, scanner.startIndex))
                    }

                case leftparen:
                    delimiters.append((.leftParen, scanner.startIndex))

                case rightparen:
                    delimiters.append((.rightParen, scanner.startIndex))

                case backslash:
                    guard let el = scanner.peek() else {
                        potentialBackslashHardbreak = true
                        break
                    }
                    if isPunctuation(el) {
                        delimiters.append((.ignored, scanner.startIndex))
                        if el != backtick { _ = scanner.pop() }
                    }

                case _:
                    break
                }
            }

            optScanner = scannersIterator.next()
            let offset =  IntMax(-(numberOfPreviousSpaces + ((potentialBackslashHardbreak && optScanner != nil) ? 1 : 0)))
            let lastIndex = scanner.data.index(scanner.startIndex, offsetBy: View.IndexDistance(offset))
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
