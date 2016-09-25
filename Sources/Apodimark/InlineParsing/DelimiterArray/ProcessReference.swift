//
//  ProcessReference.swift
//  Apodimark
//

extension MarkdownParser {

    func processAllReferences(delimiters: inout DelimiterSlice) -> [InlineNode<View>] {
        var all: [InlineNode<View>] = []
        while case let ref? = processReference(delimiters: &delimiters) {
            all.append(contentsOf: ref)
        }
        return all
    }

    fileprivate func processReference(delimiters: inout DelimiterSlice) -> [InlineNode<View>]? {

        guard let (openingTitleDelIdx, openingTitleDel, closingTitleDelIdx, closingTitleDel, refKind) = {
            () -> (DelimiterSlice.Index, Delimiter, DelimiterSlice.Index, Delimiter, ReferenceKind)? in
            
            var opener: (index: DelimiterSlice.Index, del: Delimiter, kind: ReferenceKind)?
            
            for case let (i, del?) in zip(delimiters.indices, delimiters) {
                switch del.kind {
                case .refCloser:
                    if let o = opener {
                        return (o.index, o.del, i, del, o.kind)
                    }
                    
                case .refOpener:
                    opener = (i, del, .normal)
                    
                case .unwrappedRefOpener:
                    opener = (i, del, .unwrapped)
                    
                default:
                    continue
                }
            }
            return nil
        }()
        else {
            return nil
        }
 
        delimiters[openingTitleDelIdx] = nil
        delimiters[closingTitleDelIdx] = nil
        
        let nextDelIdx = closingTitleDelIdx+1
        guard nextDelIdx < delimiters.endIndex, let nextDel = delimiters[nextDelIdx] else {
            return []
        }
        
        let suffix = delimiters.suffix(from: nextDelIdx)
        
        guard let (definition, span, spanEndDelIdx) = {
            () -> (ReferenceDefinition, Range<View.Index>, DelimiterSlice.Index)? in
         
            switch nextDel.kind {
                
            case .refValueOpener:
                delimiters[nextDelIdx] = nil
                guard let (valueCloserDelIdx, valueCloserDel) = { () -> (DelimiterSlice.Index, Delimiter)? in
                    for case let (i, del?) in zip(suffix.indices, suffix) {
                        if case .rightParen = del.kind { return (i, del) }
                    }
                    return nil
                }() else {
                    return nil
                }
                
                delimiters[valueCloserDelIdx] = nil
                
                let definition = Codec.string(fromTokens: view[nextDel.idx ..< view.index(before: valueCloserDel.idx)])
                let span = { () -> Range<View.Index> in
                    let lowerbound = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(IntMax(-refKind.textWidth)))
                    return lowerbound ..< valueCloserDel.idx
                }()

                return (definition, span, valueCloserDelIdx)
                
            case .refOpener where nextDel.idx == view.index(after: closingTitleDel.idx):
                
                delimiters[nextDelIdx] = nil
                guard let (aliasCloserIdx, aliasCloserDel) = { () -> (DelimiterSlice.Index, Delimiter)? in
                    for case let (i, del?) in zip(suffix.indices, suffix) {
                        if case .refCloser = del.kind { return (i, del) }
                    }
                    return nil
                }()
                else {
                    return nil
                }
                
                let s = Codec.string(fromTokens: view[nextDel.idx ..< view.index(before: aliasCloserDel.idx)]).lowercased()
                guard let definition = referenceDefinitions[s] else {
                    var newNextDel = nextDel
                    newNextDel.kind = .refOpener
                    delimiters[nextDelIdx] = newNextDel
                    return nil
                }
                
                delimiters[openingTitleDelIdx] = nil
                delimiters[aliasCloserIdx] = nil
                
                let width = refKind == .unwrapped ? 2 : 1
                let span = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(IntMax(-width))) ..< aliasCloserDel.idx
                
                return (definition, span, aliasCloserIdx)
                
            default:
                let s = Codec.string(fromTokens: view[openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)]).lowercased()
                guard let definition = referenceDefinitions[s] else {
                    return nil
                }
                
                delimiters[openingTitleDelIdx] = nil
                let width = refKind == .unwrapped ? 2 : 1
                let span = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(IntMax(-width))) ..< closingTitleDel.idx
                
                return (definition, span, closingTitleDelIdx)
            }
        }()
        else {
            return []
        }
            
        let title = openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)
        
        let refNode = InlineNode<View>(
            kind: .reference(refKind, title: title, definition: definition),
            start: span.lowerBound,
            end: span.upperBound)
        
        let delimiterRangeForTitle = (openingTitleDelIdx + 1) ..< closingTitleDelIdx
        var inlineNodes = processAllEmphases(delimiters: &delimiters[delimiterRangeForTitle])
        
        let delimiterRangeForSpan = openingTitleDelIdx ... spanEndDelIdx
        
        for i in delimiterRangeForTitle {
            guard let del = delimiters[i] else { continue }
            switch del.kind {
            case .start, .end, .softbreak, .hardbreak, .ignored: continue
            default: delimiters[i] = nil
            }
        }
        for i in delimiterRangeForTitle.upperBound ..< delimiterRangeForSpan.upperBound {
            delimiters[i] = nil
        }
        
        inlineNodes.append(refNode)
        return inlineNodes
    }
}
