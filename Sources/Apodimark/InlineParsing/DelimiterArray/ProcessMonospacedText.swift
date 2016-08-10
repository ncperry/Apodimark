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
        guard let (firstDelIdx, firstDel, level) = findFirst(in: delimiters, whereNotNil: { (kind) -> Int? in
            if case let .code(l) = kind { return l } else { return nil }
        }) else {
            return nil
        }
        if firstDelIdx > delimiters.startIndex,
            let del = delimiters[firstDelIdx - 1],
            case .ignored = del.kind, del.idx == view.index(before: firstDel.idx) {
            return processMonospacedText(delimiters: &delimiters[firstDelIdx+1 ..< delimiters.endIndex])
        }

        guard let (matchingDelIdx, matchingDel, _) = findFirst(in: delimiters.suffix(from: firstDelIdx + 1), whereNotNil: { (kind) -> Void? in
            if case .code(level) = kind { return () } else { return nil }
        }) else {
            _ = delimiters.remove(at: firstDelIdx)
            return nil
        }

        let range = firstDelIdx ... matchingDelIdx
        for i in range {
            switch delimiters[i]?.kind {
            case .softbreak?, .hardbreak?, .start?, .end?: continue
            default: delimiters[i] = nil
            }
        }

        return InlineNode(
            kind: .code(level),
            start: view.index(firstDel.idx, offsetBy: View.IndexDistance(IntMax(-level))),
            end: matchingDel.idx
        )
    }
}
