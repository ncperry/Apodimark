//
//  InlineParsing.swift
//  Apodimark
//

extension NonTextInlineNode {
    static func < (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start <  rhs.start }
}

extension MarkdownParser {
    
    func parseInlines(_ text: [Range<View.Index>]) -> Tree<Inline> {
        
        var nonTextDels = nonTextDelimiters(in: text)

        var nodes: [NonTextInline] = []
        
        processAllMonospacedText(&nonTextDels, appendingTo: &nodes)
        processAllReferences(&nonTextDels, appendingTo: &nodes)
        processAllEmphases(&nonTextDels, indices: nonTextDels.indices, appendingTo: &nodes)
        processAllEscapingBackslashes(nonTextDels, appendingTo: &nodes)
        
        nodes.sort(by: <)
        
        let textNodes = TextInlineNodeIterator<View, Codec>(view: view, text: text)
        
        return makeAST(text: textNodes, nonText: nodes)
    }

    private func nonTextDelimiters(in text: [Range<View.Index>]) -> [NonTextDel?] {
        
        var nonTextDels: [NonTextDel?] = []
    
        var scanner = Scanner(data: view)
        
        for (idx, range) in zip(text.indices, text) {
            
            (scanner.startIndex, scanner.endIndex) = (range.lowerBound, range.upperBound)
            
            var prevTokenKind = TokenKind.whitespace
            
            while case let token? = scanner.pop() {
                let curTokenKind = MarkdownParser.tokenKind(token)
                defer { prevTokenKind = curTokenKind }

                // avoid going into the switch if token is not punctuation (optimization)
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
                    nonTextDels.append((scanner.startIndex, .emph(kind, delimiterState, numericCast(lvl))))
                    
                case Codec.backtick:
                    let idxBeforeRun = view.index(before: scanner.startIndex)
                    scanner.popWhile(Codec.backtick)
                    let lvl = view.distance(from: idxBeforeRun, to: scanner.startIndex)
                    nonTextDels.append((scanner.startIndex, .code(numericCast(lvl))))
                    
                case Codec.exclammark:
                    if scanner.pop(Codec.leftsqbck) {
                        nonTextDels.append((scanner.startIndex, .unwrappedRefOpener))
                    }
                    
                case Codec.leftsqbck:
                    nonTextDels.append((scanner.startIndex, .refOpener))
                    
                case Codec.rightsqbck:
                    nonTextDels.append((scanner.startIndex, .refCloser))
                    if scanner.pop(Codec.leftparen) {
                        nonTextDels.append((scanner.startIndex, .refValueOpener))
                    }
                    
                case Codec.leftparen:
                    nonTextDels.append((scanner.startIndex, .leftParen))
                    
                case Codec.rightparen:
                    nonTextDels.append((scanner.startIndex, .rightParen))
                    
                case Codec.backslash:
                    guard case let el? = scanner.peek() else {
                        break
                    }
                    if Codec.isPunctuation(el) {
                        nonTextDels.append((scanner.startIndex, .escapingBackslash))
                        if el != Codec.backtick { _ = scanner.pop() }
                    }
                    
                default:
                    break
                }
            }
        }
        
        return nonTextDels
    }
}


