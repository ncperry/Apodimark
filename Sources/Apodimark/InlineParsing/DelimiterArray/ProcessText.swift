//
//  ProcessText.swift
//  Apodimark
//

extension MarkdownParser {

    func processText(delimiters: inout DelimiterSlice) -> [InlineNode<View>] {

        let findFirstNonNilDelimiter: @noescape () -> Delimiter? = {
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
            switch del.kind {
            case .start:
                startViewIndex = del.idx

            case .end:
                textNodes.append(InlineNode(kind: .text, start: startViewIndex, end: del.idx))
                startViewIndex = del.idx

            case .softbreak:
                textNodes.append(InlineNode(kind: .softbreak, start: startViewIndex, end: del.idx))
                startViewIndex = del.idx

            case .hardbreak:
                textNodes.append(InlineNode(kind: .hardbreak, start: startViewIndex, end: del.idx))
                startViewIndex = del.idx

            case .ignored:
                textNodes.append(InlineNode(kind: .text, start: startViewIndex, end: view.index(before: del.idx)))
                startViewIndex = del.idx

            default:
                break
            }
        }
        return textNodes
    }
}

