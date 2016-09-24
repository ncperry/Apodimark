//
//  ProcessMonospacedText.swift
//  Apodimark
//

extension MarkdownParser {

    func processAllMonospacedText(delimiters: inout DelimiterSlice) -> [InlineNode<View>] {
        var all: [InlineNode<View>] = []
        while let r = processMonospacedText(delimiters: &delimiters) {
            all.append(r)
        }
        return all
    }

    func processMonospacedText(delimiters: inout DelimiterSlice) -> InlineNode<View>? {

        guard let (openingDelIdx, openingDel, closingDelIdx, closingDel, level) = {
            () -> (DelimiterSlice.Index, Delimiter, DelimiterSlice.Index, Delimiter, Int)? in
            
            var ignoring = false
            
            for i in delimiters.indices {
                guard ignoring == false else {
                    ignoring = false
                    continue
                }
                
                guard let del = delimiters[i] else {
                    continue
                }
                
                switch del.kind {
                case .ignored:
                    ignoring = true
                    
                case .code(let level):
                    guard let closingDelIdx = { () -> DelimiterSlice.Index? in
                        for j in i+1 ..< delimiters.endIndex {
                            guard case .code(level)? = delimiters[j]?.kind else { continue }
                            return j
                        }
                        return nil
                    }()
                    else {
                        delimiters[i] = nil
                        return nil
                    }
                    return (i, delimiters[i]!, closingDelIdx, delimiters[closingDelIdx]!, level)
                    
                default:
                    break
                }
            }
            return nil
        }()
        else {
            return nil
        }
  
        let range = openingDelIdx ... closingDelIdx
        for i in range {
            guard let kind = delimiters[i]?.kind else { continue }
            switch kind {
            case .softbreak, .hardbreak, .start, .end: continue
            default: delimiters[i] = nil
            }
        }
        
        return InlineNode(
            kind: .code(level),
            start: view.index(openingDel.idx, offsetBy: View.IndexDistance(IntMax(-level))),
            end: closingDel.idx)
    }
}
