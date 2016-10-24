//
//  ProcessMonospacedText.swift
//  Apodimark
//

extension MarkdownParser {

    func processAllMonospacedText(_ delimiters: inout [NonTextDelimiter?], appendingTo nodes: inout [NonTextInlineNode<View>]) {
        var start = delimiters.startIndex
        while let (r, newStart) = processMonospacedText(&delimiters, indices: start ..< delimiters.endIndex) {
            nodes.append(r)
            start = newStart
        }
    }

    func processMonospacedText(_ delimiters: inout [NonTextDelimiter?], indices: CountableRange<Int>) -> (NonTextInlineNode<View>, newStart: Int)? {

        guard let (openingDelIdx, openingDel, closingDelIdx, closingDel, level) = {
            () -> (Int, NonTextDelimiter, Int, NonTextDelimiter, Int32)? in
            
            var escaping: View.Index? = nil

            for i in indices {
                
                guard let del = delimiters[i] else {
                    escaping = nil
                    continue
                }
                
                switch del.kind {
                case .ignored:
                    escaping = del.idx
                    
                case .code(let level):
                    defer { escaping = nil }
                    var level = level
                    if let escapingIdx = escaping, escapingIdx == view.index(before: del.idx) {
                        level -= 1
                        view.formIndex(after: &delimiters[i]!.idx)
                    }
                    guard level > 0 else {
                        delimiters[i] = nil
                        break
                    }
                    guard let closingDelIdx = { () -> Int? in
                        for j in i+1 ..< indices.upperBound {
                            if case .code(level)? = delimiters[j]?.kind {
                                return j
                            }
                        }
                        return nil
                    }()
                    else {
                        delimiters[i] = nil
                        return nil
                    }
                    return (i, delimiters[i]!, closingDelIdx, delimiters[closingDelIdx]!, level)
                    
                default:
                    escaping = nil
                }
            }
            return nil
        }()
        else {
            return nil
        }
  
        for i in openingDelIdx ... closingDelIdx {
            delimiters[i] = nil
        }
        
        return (
            NonTextInlineNode(
                kind: .code(level),
                start: view.index(openingDel.idx, offsetBy: numericCast(-level)),
                end: closingDel.idx
            ),
            closingDelIdx
        )
    }
}
