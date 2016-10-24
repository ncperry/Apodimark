//
//  ProcessReference.swift
//  Apodimark
//

extension MarkdownParser {

    func processAllReferences(_ delimiters: inout [NonTextDelimiter?], appendingTo nodes: inout [NonTextInlineNode<View>]) {
        var start = delimiters.startIndex
        while let newStart = processReference(&delimiters, indices: start ..< delimiters.endIndex, appendingTo: &nodes) {
            start = newStart
        }
    }

    private func processReference(_ delimiters: inout [NonTextDelimiter?], indices: CountableRange<Int>, appendingTo nodes: inout [NonTextInlineNode<View>]) -> Int? {

        guard let (newStart, openingTitleDelIdx, openingTitleDel, closingTitleDelIdx, closingTitleDel, refKind) = {
            () -> (Int, Int, NonTextDelimiter, Int, NonTextDelimiter, ReferenceKind)? in
            
            var firstOpeningReferenceIdx: Int? = nil
            var opener: (index: Int, del: NonTextDelimiter, kind: ReferenceKind)?
            
            for i in indices {
                guard let del = delimiters[i] else { continue }
    
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

        guard let (definition, span, spanEndDelIdx) = {
            () -> (ReferenceDefinition, Range<View.Index>, Int)? in
        
            let nextDelIdx = closingTitleDelIdx+1
            let nextDel = nextDelIdx < delimiters.endIndex ? delimiters[nextDelIdx] : nil
            
            switch nextDel?.kind {
                
            case .refValueOpener?:

                delimiters[nextDelIdx] = nil
                guard let (valueCloserDelIdx, valueCloserDel) = { () -> (Int, NonTextDelimiter)? in
                    for i in nextDelIdx ..< indices.upperBound {
                        guard let del = delimiters[i] else { continue }
                        if case .rightParen = del.kind { return (i, del) }
                    }
                    return nil
                }() else {
                    return nil
                }
                
                delimiters[valueCloserDelIdx] = nil
                
                let definition = Codec.string(fromTokens: view[nextDel!.idx ..< view.index(before: valueCloserDel.idx)])
                let span = { () -> Range<View.Index> in
                    let lowerbound = view.index(openingTitleDel.idx, offsetBy: numericCast(-refKind.textWidth))
                    return lowerbound ..< valueCloserDel.idx
                }()

                return (definition, span, valueCloserDelIdx)
                
            case .refOpener? where nextDel!.idx == view.index(after: closingTitleDel.idx):
    
                delimiters[nextDelIdx] = nil
                guard let (aliasCloserIdx, aliasCloserDel) = { () -> (Int, NonTextDelimiter)? in
                    for i in nextDelIdx ..< indices.upperBound {
                        guard let del = delimiters[i] else { continue }
                        if case .refCloser = del.kind { return (i, del) }
                    }
                    return nil
                }()
                else {
                    return nil
                }
                
                let s = Codec.string(fromTokens: view[nextDel!.idx ..< view.index(before: aliasCloserDel.idx)]).lowercased()
                guard let definition = referenceDefinitions[s] else {
                    var newNextDel = nextDel!
                    newNextDel.kind = .refOpener
                    delimiters[nextDelIdx] = newNextDel
                    return nil
                }
                
                delimiters[openingTitleDelIdx] = nil
                delimiters[aliasCloserIdx] = nil
            
                let width = refKind == .unwrapped ? 2 : 1
                let span = view.index(openingTitleDel.idx, offsetBy: numericCast(-width)) ..< aliasCloserDel.idx

                return (definition, span, aliasCloserIdx)
                
            default:
                let s = Codec.string(fromTokens: view[openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)]).lowercased()
                guard let definition = referenceDefinitions[s] else {
                    return nil
                }
                
                delimiters[openingTitleDelIdx] = nil
                let width = refKind == .unwrapped ? 2 : 1
                let span = view.index(openingTitleDel.idx, offsetBy: numericCast(-width)) ..< closingTitleDel.idx
                
                return (definition, span, closingTitleDelIdx)
            }
        }()
        else {
            return newStart
        }
            
        let title = openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)
        
        let refNode = NonTextInlineNode<View>(
            kind: .reference(refKind, title: title, definition: definition),
            start: span.lowerBound,
            end: span.upperBound)
        
        let delimiterRangeForTitle: CountableRange<Int> = (openingTitleDelIdx + 1) ..< closingTitleDelIdx
        processAllEmphases(&delimiters, indices: delimiterRangeForTitle, appendingTo: &nodes)
        
        let delimiterRangeForSpan = openingTitleDelIdx ... spanEndDelIdx
        
        for i in delimiterRangeForTitle {
            guard let del = delimiters[i] else { continue }
            switch del.kind {
            case .ignored: continue
            default: delimiters[i] = nil
            }
        }
        for i in delimiterRangeForTitle.upperBound ..< delimiterRangeForSpan.upperBound {
            delimiters[i] = nil
        }
        
        nodes.append(refNode)
        return newStart
    }
}
