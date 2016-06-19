//
//  ProcessText.swift
//  Apodimark
//

extension MarkdownParser {

    func processText (delimiters: inout DelimiterSlice) -> [InlineNode<View>] {

        let findFirstNonNilDelimiter: () -> Delimiter? = {
            var f: Delimiter?
            for case let del? in delimiters {
                f = del
                break
            }
            return f
        }

        guard let first = findFirstNonNilDelimiter() else {
            fatalError()
        }

        var textNodes = [InlineNode<View>]()
        var startViewIndex = first.idx

        for case let del? in delimiters {
            let span: Range = startViewIndex ..< del.idx
            switch del.kind {
            case .start:
                startViewIndex = del.idx

            case .end:
                textNodes.append(InlineNode(kind: .text, span: span))
                startViewIndex = del.idx

            case .softbreak:
                textNodes.append(InlineNode(kind: .softbreak, span: span))
                startViewIndex = del.idx

            case .hardbreak:
                textNodes.append(InlineNode(kind: .hardbreak, span: span))
                startViewIndex = del.idx

            case .ignored:
                let span: Range = startViewIndex ..< view.index(before: del.idx)
                textNodes.append(InlineNode(kind: .text, span: span))
                startViewIndex = del.idx

            default:
                break
            }
        }
        return textNodes
    }
}

