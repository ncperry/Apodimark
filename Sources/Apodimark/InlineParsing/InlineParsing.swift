//
//  InlineParsing.swift
//  Apodimark
//

extension MarkdownParser {
    typealias DelimiterSlice = ArraySlice<Delimiter?>

    func parseInlines(text: [Range<View.Index>]) -> LinkedList<InlineNode<View>> {

        guard !text.isEmpty else { return [] }

        let scanners = text.map { Scanner(data: view, startIndex: $0.lowerBound, endIndex: $0.upperBound) }

        var dels = delimiters(inScanners: scanners)
        var nodes: [InlineNode<View>] = []

        nodes += processAllMonospacedText(delimiters: &dels[dels.indices])
        nodes += processAllReferences(delimiters: &dels[dels.indices])
        nodes += processAllEmphases(delimiters: &dels[dels.indices])
        nodes += processText(delimiters: &dels[dels.indices])

        nodes.sort { $0.start < $1.start }

        return makeAST(with: nodes)
    }

    func findFirst <C: Collection, T where C.Iterator.Element == Delimiter?> (in delimiters: C, whereNotNil predicate: @noescape (DelimiterKind) -> T?) -> (C.Index, Delimiter, T)? {

        var (optDel, optExtracted): (Delimiter?, T?)
        var delIdx = delimiters.startIndex
        for del in delimiters {
            guard let kind = del?.kind, let extracted = predicate(kind) else {
                delimiters.formIndex(after: &delIdx)
                continue
            }
            (optDel, optExtracted) = (del, extracted)
            break
        }
        guard let del = optDel, let extracted = optExtracted else { return nil }

        return (delIdx, del, extracted)
    }
}


