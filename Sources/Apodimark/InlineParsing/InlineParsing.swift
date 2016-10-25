//
//  InlineParsing.swift
//  Apodimark
//

extension NonTextInlineNode {
    static func < (lhs: NonTextInlineNode, rhs: NonTextInlineNode) -> Bool { return lhs.start <  rhs.start }
}

extension MarkdownParser {
    
    func parseInlines(_ text: [Range<View.Index>]) -> Tree<InlineNode<View>> {
        
        let textDels: [TextDelimiter]
        var nonTextDels: [NonTextDelimiter?]
        (nonTextDels, textDels) = delimiters(in: text)
        
        guard !textDels.isEmpty else { return .init() }
        
        var nodes: [NonTextInlineNode<View>] = []
        processAllMonospacedText(&nonTextDels, appendingTo: &nodes)
        processAllReferences(&nonTextDels, appendingTo: &nodes)
        processAllEmphases(&nonTextDels, indices: nonTextDels.indices, appendingTo: &nodes)
        processAllEscapingBackslashes(nonTextDels, appendingTo: &nodes)
        
        nodes.sort(by: <)
        
        let textNodes = TextInlineNodeIterator(view: view, delimiters: textDels)
        
        return makeAST(text: textNodes, nonText: nodes)
    }

    private func delimiters(in text: [Range<View.Index>]) -> ([NonTextDelimiter?], [TextDelimiter]) {
        
        var nonTextDels: [NonTextDelimiter?] = []
        var textDels: [TextDelimiter] = []

        var scanner = Scanner(data: view)
        
        for (idx, range) in zip(text.indices, text) {
            
            (scanner.startIndex, scanner.endIndex) = (range.lowerBound, range.upperBound)
            
            var numberOfPreviousSpaces = 0
            var potentialBackslashHardbreak = false
            
            var prevTokenKind = TokenKind.whitespace
            
            textDels.append((scanner.startIndex, .start))
            
            while case let token? = scanner.pop() {
                let curTokenKind = MarkdownParser.tokenKind(token)
                defer { prevTokenKind = curTokenKind }
                
                if token == Codec.space {
                    numberOfPreviousSpaces += 1
                    continue
                } else {
                    defer { numberOfPreviousSpaces = 0 }
                }
                
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
                        potentialBackslashHardbreak = true
                        break
                    }
                    if Codec.isPunctuation(el) {
                        nonTextDels.append((scanner.startIndex, .escapingBackslash))
                        if el != Codec.backtick { _ = scanner.pop() }
                    }
                    
                case _:
                    break
                }
            }
            
            let isLastText = idx+1 < text.endIndex
            let offset = -(numberOfPreviousSpaces + ((potentialBackslashHardbreak && isLastText) ? 1 : 0))
            let lastIndex = view.index(scanner.startIndex, offsetBy: numericCast(offset))
            textDels.append((lastIndex, .end))
            
            if isLastText { // linefeed
                if potentialBackslashHardbreak || numberOfPreviousSpaces >= 2 {
                    textDels.append((view.index(after: scanner.startIndex), .hardbreak))
                }
                else {
                    textDels.append((view.index(after: scanner.startIndex), .softbreak))
                }
            }
        }
        
        return (nonTextDels, textDels)
    }
}


