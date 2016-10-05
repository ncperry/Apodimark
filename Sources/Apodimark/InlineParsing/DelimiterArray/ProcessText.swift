//
//  ProcessText.swift
//  Apodimark
//

extension MarkdownParser {

    func processText(_ delimiters: inout DelimiterSlice) -> [InlineNode<View>] {

        guard let first: Delimiter = {
            for case let del? in delimiters {
                return del
            }
            return nil
        }()
        else {
            fatalError()
        }

        var textNodes = [InlineNode<View>]()
        var startViewIndex = first.idx

        for i in delimiters.indices {
            guard case let del? = delimiters[i] else { continue }

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

