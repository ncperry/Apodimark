//
//  InlineParsing.swift
//  Apodimark
//

extension MarkdownParser {
    typealias DelimiterSlice = ArraySlice<Delimiter?>

    func processInlines(scanners: [Scanner<View>]) -> LinkedList<InlineNode<View>> {
        guard let data = scanners.first?.view else { return [] }

        var dels = delimiters(inScanners: scanners)
        var nodes: [InlineNode<View>] = []

        nodes += processAllMonospacedText(delimiters: &dels[dels.indices])
        nodes += processAllReferences(delimiters: &dels[dels.indices])
        nodes += processAllEmphases(delimiters: &dels[dels.indices])
        nodes += processText(delimiters: &dels[dels.indices])

        nodes.sort { $0.span.lowerBound < $1.span.lowerBound }

        return makeAST(with: nodes, inView: data)
    }

    func findFirst <C: Collection, T where C.Iterator.Element == Delimiter?> (in delimiters: C, whereNotNil predicate: @noescape (DelimiterKind) -> T?) -> (C.Index, Delimiter, T)? {

        var (optDel, optExtracted): (Delimiter?, T?)
        var delIdx = delimiters.startIndex
        for del in delimiters {
            guard let kind = del?.kind, extracted = predicate(kind) else {
                delimiters.formIndex(after: &delIdx)
                continue
            }
            (optDel, optExtracted) = (del, extracted)
            break
        }
        guard let del = optDel, extracted = optExtracted else { return nil }

        return (delIdx, del, extracted)
    }
}


