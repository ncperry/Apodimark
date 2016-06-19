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

    private func processEmphasis(delimiters: inout DelimiterSlice) -> InlineNode<View>? {
        var sawOneOpeningEmph = (underscore: false, asterisk: false)
        guard let (sndDelIdx, sndDel, sndDelInfo) = findFirst(in: delimiters, whereNotNil: { (kind) -> (kind: EmphasisKind, state: DelimiterState, lvl: Int)? in
            if case let .emph(kind, state, lvl) = kind where state.contains(.closing) {
                let ok = kind == .underscore ? sawOneOpeningEmph.underscore : sawOneOpeningEmph.asterisk
                if ok { return (kind, state, lvl) }
            }
            if case let .emph(kind, state, _) = kind where state.contains(.opening) {
                if kind == .underscore { sawOneOpeningEmph.underscore = true }
                else { sawOneOpeningEmph.asterisk = true }
            }
            return nil
        }) else {
            return nil
        }

        let prefix = delimiters.prefix(upTo: sndDelIdx)

        guard let (fstDelIdxReversed, fstDel, fstDelInfo) = findFirst(in: prefix.reversed(), whereNotNil: { (kind: DelimiterKind) -> (lvl: Int, state: DelimiterState)? in
            if case .emph(sndDelInfo.kind, let state, let lvl) = kind where state.contains(.opening) { return (lvl, state) }
            else { return nil }
        }) else {
            fatalError()
        }
        let firstDelIdx = fstDelIdxReversed.base - 1

        defer {
            for idx in delimiters[firstDelIdx+1 ..< sndDelIdx].indices {
                if case .emph(_)? = delimiters[idx]?.kind {
                    delimiters[idx] = nil
                }
            }
        }

        switch (fstDelInfo.lvl, sndDelInfo.lvl) {

        case let (l1, l2) where l1 == l2:
            delimiters[firstDelIdx] = nil
            delimiters[sndDelIdx] = nil
            let span: Range = view.index(fstDel.idx, offsetBy: View.IndexDistance(IntMax(-l1))) ..< sndDel.idx

            return InlineNode(kind: .emphasis(l1), span: span)


        case let (l1, l2) where l1 < l2:
            delimiters[firstDelIdx] = nil
            delimiters[sndDelIdx]!.kind = .emph(sndDelInfo.kind, sndDelInfo.state, l2 - l1)
            let startOffset = View.IndexDistance(IntMax(-l1))
            let endOffset1 = IntMax(-(l2 - l1))
            let endOffset = View.IndexDistance(endOffset1)
            let span: Range = view.index(fstDel.idx, offsetBy: startOffset) ..< view.index(sndDel.idx, offsetBy: endOffset)

            return InlineNode(kind: .emphasis(l1), span: span)


        case let (l1, l2) where l1 > l2:
            delimiters[sndDelIdx] = nil
            view.formIndex(&delimiters[firstDelIdx]!.idx, offsetBy: View.IndexDistance(IntMax(-l2)))
            delimiters[firstDelIdx]!.kind = .emph(sndDelInfo.kind, fstDelInfo.state, l1 - l2)
            let span: Range = view.index(fstDel.idx, offsetBy: View.IndexDistance(IntMax(-l2))) ..< sndDel.idx

            return InlineNode(kind: .emphasis(l2), span: span)


        default:
            fatalError()
        }

        return nil
    }
}
