//
//  InlineParsing.swift
//  Apodimark
//

extension NonTextInlineNode {
    static func < (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start <  rhs.start }
}

extension MarkdownParser {
    
    func parseInlines(_ text: [Range<View.Index>]) -> Tree<InlineNode<View>> {
        
        var dels = delimiters(in: text)
        
        var nodes = processAllMonospacedText(&dels[dels.indices])
        nodes += processAllReferences(&dels[dels.indices])
        nodes += processAllEmphases(&dels[dels.indices])
        
        nodes.sort(by: <)
        
        let textNodes = processText(dels)
        
        return makeAST(text: textNodes, nonText: nodes)
    }

    private func delimiters(in text: [Range<View.Index>]) -> [Delimiter?] {
        
        var delimiters: [Delimiter?] = []
        
        for (idx, range) in zip(text.indices, text) {
    
            var scanner = Scanner(data: view, startIndex: range.lowerBound, endIndex: range.upperBound)
            
            var numberOfPreviousSpaces = 0
            var potentialBackslashHardbreak = false
            
            var prevTokenKind = TokenKind.whitespace
            
            delimiters.append((scanner.startIndex, .start))
            
            while let token = scanner.pop() {
                let curTokenKind = MarkdownParser.tokenKind(token)
                defer { prevTokenKind = curTokenKind }
                
                if token == Codec.space {
                    numberOfPreviousSpaces += 1
                    continue
                } else {
                    defer { numberOfPreviousSpaces = 0 }
                }
                
                // TODO evaluate if necessary, this is a micro-optimization
                guard case .punctuation = curTokenKind else {
                    continue
                }
                
                switch token {
                    
                case Codec.underscore, Codec.asterisk:
                    let idxBeforeRun = view.index(before: scanner.startIndex)
                    scanner.popWhile(token)
                    let nextTokenKind = scanner.peek().flatMap(MarkdownParser.tokenKind) ?? .whitespace
                    
                    let delimiterState = DelimiterState(token: token, prev: prevTokenKind, next: nextTokenKind, codec: Codec.self)
                    let lvl = view.distance(from: idxBeforeRun, to: scanner.startIndex)
                    let kind: EmphasisKind = token == Codec.underscore ? .underscore : .asterisk
                    delimiters.append((scanner.startIndex, .emph(kind, delimiterState, numericCast(lvl))))
                    
                case Codec.backtick:
                    let idxBeforeRun = view.index(before: scanner.startIndex)
                    scanner.popWhile(Codec.backtick)
                    let lvl = view.distance(from: idxBeforeRun, to: scanner.startIndex)
                    delimiters.append((scanner.startIndex, .code(numericCast(lvl))))
                    
                case Codec.exclammark:
                    if scanner.pop(Codec.leftsqbck) {
                        delimiters.append((scanner.startIndex, .unwrappedRefOpener))
                    }
                    
                case Codec.leftsqbck:
                    delimiters.append((scanner.startIndex, .refOpener))
                    
                case Codec.rightsqbck:
                    delimiters.append((scanner.startIndex, .refCloser))
                    if scanner.pop(Codec.leftparen) {
                        delimiters.append((scanner.startIndex, .refValueOpener))
                    }
                    
                case Codec.leftparen:
                    delimiters.append((scanner.startIndex, .leftParen))
                    
                case Codec.rightparen:
                    delimiters.append((scanner.startIndex, .rightParen))
                    
                case Codec.backslash:
                    guard let el = scanner.peek() else {
                        potentialBackslashHardbreak = true
                        break
                    }
                    if Codec.isPunctuation(el) {
                        delimiters.append((scanner.startIndex, .ignored))
                        if el != Codec.backtick { _ = scanner.pop() }
                    }
                    
                case _:
                    break
                }
            }
            
            let isLastText = idx+1 < text.endIndex
            let offset = -(numberOfPreviousSpaces + ((potentialBackslashHardbreak && isLastText) ? 1 : 0))
            let lastIndex = view.index(scanner.startIndex, offsetBy: numericCast(offset))
            delimiters.append((lastIndex, .end))
            
            if isLastText { // linefeed
                if potentialBackslashHardbreak || numberOfPreviousSpaces >= 2 {
                    delimiters.append((view.index(after: scanner.startIndex), .hardbreak))
                }
                else {
                    delimiters.append((view.index(after: scanner.startIndex), .softbreak))
                }
            }
        }
        
        return delimiters
    }
}


