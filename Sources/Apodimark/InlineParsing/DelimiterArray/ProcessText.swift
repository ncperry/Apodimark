//
//  ProcessText.swift
//  Apodimark
//

extension MarkdownParser {


    func processText(_ delimiters: [Delimiter?]) -> [TextInlineNode<View>] {
        guard let first: Delimiter = {
            for case let del? in delimiters {
                return del
            }
            return nil
        }()
        else {
            return []
        }

        var textNodes = [TextInlineNode<View>]()
        var startViewIndex = first.idx

        for case let del? in delimiters {

            switch del.kind {
            case .start:
                startViewIndex = del.idx
                
            case .end:
                textNodes.append(TextInlineNode(kind: .text, start: startViewIndex, end: del.idx))
                startViewIndex = del.idx
                
            case .softbreak:
                textNodes.append(TextInlineNode(kind: .softbreak, start: startViewIndex, end: del.idx))
                startViewIndex = del.idx
                
            case .hardbreak:
                textNodes.append(TextInlineNode(kind: .hardbreak, start: startViewIndex, end: del.idx))
                startViewIndex = del.idx
                
            case .ignored:
                textNodes.append(TextInlineNode(kind: .text, start: startViewIndex, end: view.index(before: del.idx)))
                startViewIndex = del.idx
                
            default:
                break
            }
        }

        return textNodes
    }
}

