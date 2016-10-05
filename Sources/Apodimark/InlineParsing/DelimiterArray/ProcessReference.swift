//
//  ProcessReference.swift
//  Apodimark
//

extension MarkdownParser {

    func processAllReferences(_ delimiters: inout DelimiterSlice) -> [InlineNode<View>] {
        var all: [InlineNode<View>] = []
        var start = delimiters.startIndex
        while let (ref, newStart) = processReference(&delimiters[start ..< delimiters.endIndex]) {
            all.append(contentsOf: ref)
            start = newStart
        }
        return all
    }

    fileprivate func processReference(_ delimiters: inout DelimiterSlice) -> ([InlineNode<View>], newStart: Int)? {

        guard let (newStart, openingTitleDelIdx, openingTitleDel, closingTitleDelIdx, closingTitleDel, refKind) = {
            () -> (Int, Int, Delimiter, Int, Delimiter, ReferenceKind)? in
            
            var firstOpeningReferenceIdx: Int? = nil
            var opener: (index: Int, del: Delimiter, kind: ReferenceKind)?
            
            for case let (i, del?) in zip(delimiters.indices, delimiters) {
    
                switch del.kind {
                case .refCloser:
                    if let o = opener {
                        return (firstOpeningReferenceIdx!, o.index, o.del, i, del, o.kind)
                    }
                    
                case .refOpener:
                    if firstOpeningReferenceIdx == nil { firstOpeningReferenceIdx = i }
                    opener = (i, del, .normal)
                    
                case .unwrappedRefOpener:
                    if firstOpeningReferenceIdx == nil { firstOpeningReferenceIdx = i }
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
            return ([], newStart)
        }
        
        let suffix = delimiters.suffix(from: nextDelIdx)
        
        guard let (definition, span, spanEndDelIdx) = {
            () -> (ReferenceDefinition, Range<View.Index>, Int)? in
         
            switch nextDel.kind {
                
            case .refValueOpener:
                delimiters[nextDelIdx] = nil
                guard let (valueCloserDelIdx, valueCloserDel) = { () -> (Int, Delimiter)? in
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
                    let lowerbound = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(-refKind.textWidth.toIntMax()))
                    return lowerbound ..< valueCloserDel.idx
                }()

                return (definition, span, valueCloserDelIdx)
                
            case .refOpener where nextDel.idx == view.index(after: closingTitleDel.idx):
                
                delimiters[nextDelIdx] = nil
                guard let (aliasCloserIdx, aliasCloserDel) = { () -> (Int, Delimiter)? in
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
                let span = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(-width.toIntMax())) ..< aliasCloserDel.idx

                return (definition, span, aliasCloserIdx)
                
            default:
                let s = Codec.string(fromTokens: view[openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)]).lowercased()
                guard let definition = referenceDefinitions[s] else {
                    return nil
                }
                
                delimiters[openingTitleDelIdx] = nil
                let width = refKind == .unwrapped ? 2 : 1
                let span = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(-width.toIntMax())) ..< closingTitleDel.idx
                
                return (definition, span, closingTitleDelIdx)
            }
        }()
        else {
            return ([], newStart)
        }
            
        let title = openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)
        
        let refNode = InlineNode<View>(
            kind: .reference(refKind, title: title, definition: definition),
            start: span.lowerBound,
            end: span.upperBound)
        
        let delimiterRangeForTitle = (openingTitleDelIdx + 1) ..< closingTitleDelIdx
        var inlineNodes = processAllEmphases(&delimiters[delimiterRangeForTitle])
        
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
        return (inlineNodes, newStart)
    }
}
