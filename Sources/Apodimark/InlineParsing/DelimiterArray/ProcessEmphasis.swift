//
//  ProcessEmphasis.swift
//  Apodimark
//

extension MarkdownParser {
    
    func processAllEmphases(_ delimiters: inout DelimiterSlice) -> [NonTextInlineNode<View>] {
        var all: [NonTextInlineNode<View>] = []
        var start = delimiters.startIndex
        while let (r, newStart) = processEmphasis(&delimiters[start ..< delimiters.endIndex]) {
            all.append(r)
            start = newStart
        }
        return all
    }

    fileprivate func processEmphasis(_ delimiters: inout DelimiterSlice) -> (NonTextInlineNode<View>, newStart: Int)? {
        
        guard let (newStart, openingDelIdx, closingDelIdx) = {
            () -> (Int, Int, Int)? in
            
            var openingEmph: (underscore: Int?, asterisk: Int?) = (nil, nil)
            
            var firstOpeningEmph: Int? = nil
            
            for i in delimiters.indices {
                guard let del = delimiters[i], case let .emph(kind, state, lvl) = del.kind else {
                    continue
                }
                if state.contains(.closing), let fstDelIdx = (kind == .underscore ? openingEmph.underscore : openingEmph.asterisk) {
                    return (firstOpeningEmph!, fstDelIdx, i)
                }
                if state.contains(.opening) {
                    if firstOpeningEmph == nil { firstOpeningEmph = i }
                    if kind == .underscore { openingEmph.underscore = i }
                    else { openingEmph.asterisk = i }
                }
            }
            return nil
        }() else {
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
        
        switch View.IndexDistance.compare(l1, l2) {
            
        case .equal:
            delimiters[openingDelIdx] = nil
            delimiters[closingDelIdx] = nil
            return (
                NonTextInlineNode(
                    kind: .emphasis(l1),
                    start: view.index(openingDel.idx, offsetBy: -l1),
                    end: closingDel.idx),
                newStart
            )
            
        case .lessThan:
            delimiters[openingDelIdx] = nil
            delimiters[closingDelIdx]!.kind = .emph(kind, state2, l2 - l1)
            let startOffset = -l1
            let endOffset = -(l2 - l1)
            return (
                NonTextInlineNode(
                    kind: .emphasis(l1),
                    start: view.index(openingDel.idx, offsetBy: startOffset),
                    end: view.index(closingDel.idx, offsetBy: endOffset)),
                newStart
            )
            
            
        case .greaterThan:
            delimiters[closingDelIdx] = nil
            view.formIndex(&delimiters[openingDelIdx]!.idx, offsetBy: -l2)
            delimiters[openingDelIdx]!.kind = .emph(kind, state1, l1 - l2)
            return (
                NonTextInlineNode(
                    kind: .emphasis(l2),
                    start: view.index(openingDel.idx, offsetBy: -l2),
                    end: closingDel.idx
                ),
                newStart
            )
        }
    }
}
