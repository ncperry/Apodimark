//
//  ProcessEmphasis.swift
//  Apodimark
//

extension MarkdownParser {
    
    func processAllEmphases(delimiters: inout DelimiterSlice) -> [InlineNode<View>] {
        var all: [InlineNode<View>] = []
        while let r = processEmphasis(delimiters: &delimiters) {
            all.append(r)
        }
        return all
    }

    fileprivate func processEmphasis(delimiters: inout DelimiterSlice) -> InlineNode<View>? {
        
        guard let (openingDelIdx, closingDelIdx) = { () -> (DelimiterSlice.Index, DelimiterSlice.Index)? in

            var openingEmph: (underscore: DelimiterSlice.Index?, asterisk: DelimiterSlice.Index?) = (nil, nil)
            var dels: (DelimiterSlice.Index, DelimiterSlice.Index)?
            
            for case let (i, del?) in zip(delimiters.indices, delimiters) {
                guard case let .emph(kind, state, lvl) = del.kind else { continue }
                
                if state.contains(.closing), let fstDelIdx = (kind == .underscore ? openingEmph.underscore : openingEmph.asterisk) {
                    dels = (fstDelIdx, i)
                    break
                }
                if state.contains(.opening) {
                    if kind == .underscore { openingEmph.underscore = i }
                    else { openingEmph.asterisk = i }
                }
            }
            return dels
        }()
        else {
            return nil
        }
        
        guard
            let openingDel = delimiters[openingDelIdx],
            let closingDel = delimiters[closingDelIdx],
            case .emph(let kind, let state1, let l1) = openingDel.kind,
            case .emph(kind, let state2, let l2) = closingDel.kind
        else {
            fatalError("This should never happen.")
        }
        
        defer {
            for idx in delimiters[openingDelIdx+1 ..< closingDelIdx].indices {
                if case .emph? = delimiters[idx]?.kind {
                    delimiters[idx] = nil
                }
            }
        }

        switch Int.compare(l1, l2) {
        
        case .equal:
            delimiters[openingDelIdx] = nil
            delimiters[closingDelIdx] = nil
            
            return InlineNode(
                kind: .emphasis(l1),
                start: view.index(openingDel.idx, offsetBy: View.IndexDistance(IntMax(-l1))),
                end: closingDel.idx)
            
            
        case .lessThan:
            delimiters[openingDelIdx] = nil
            delimiters[closingDelIdx]!.kind = .emph(kind, state2, l2 - l1)
            let startOffset = View.IndexDistance(IntMax(-l1))
            let endOffset1 = IntMax(-(l2 - l1))
            let endOffset = View.IndexDistance(endOffset1)
            
            return InlineNode(
                kind: .emphasis(l1),
                start: view.index(openingDel.idx, offsetBy: startOffset),
                end: view.index(closingDel.idx, offsetBy: endOffset))
            
            
        case .greaterThan:
            delimiters[closingDelIdx] = nil
            view.formIndex(&delimiters[openingDelIdx]!.idx, offsetBy: View.IndexDistance(IntMax(-l2)))
            delimiters[openingDelIdx]!.kind = .emph(kind, state1, l1 - l2)
            
            return InlineNode(
                kind: .emphasis(l2),
                start: view.index(openingDel.idx, offsetBy: View.IndexDistance(IntMax(-l2))),
                end: closingDel.idx)
        }
    }
}
