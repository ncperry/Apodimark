
import Apodimark

// FUNCTIONS INTENDED ONLY FOR TESTING PURPOSES
// DO NOT USE “APODIMARK OUTPUT” IF YOU ARE NOT TESTING APODIMARK

extension MarkdownBlock {
    typealias Token = View.Iterator.Element

    static func combineNodeOutput(acc: String, cur: MarkdownBlock) -> String {
        let appending = output(node: cur)
        guard !appending.isEmpty else { return acc }
        return acc + appending + ", "
    }

    static func combineNodeOutput(acc: String, cur: MarkdownInline<View>) -> String {
        let appending = output(node: cur)
        guard !appending.isEmpty else { return acc }
        return acc + appending
    }

    public static func output(nodes: [MarkdownBlock]) -> String {
        return nodes.reduce("Document { ", combine: combineNodeOutput) + "}"
    }
    static func output(nodes: [MarkdownInline<View>]) -> String {
        return nodes.reduce("", combine: combineNodeOutput)
    }

    static func output(node: MarkdownInline<View>) -> String {
        switch node {

        case .text(let view):
            return Token.string(fromTokens: view)

        case .emphasis(level: let level, content: let content):
            return "e\(level)(" + content.reduce("", combine: combineNodeOutput) + ")"

        case .monospacedText(let views):
            var viewsDesc = ""
            for view in views {
                viewsDesc += Token.string(fromTokens: view)
            }
            return "code(" + viewsDesc + ")"

        case .reference(kind: let kind, title: let title, definition: let definition):
            let kindDesc = kind == .unwrapped ? "uref" : "ref"
            let titleDesc = output(nodes: title)
            return "[\(kindDesc): \(titleDesc)(\(definition))]"

        case .hardbreak:
            return "[hardbreak]"

        case .softbreak:
            return "[softbreak]"
        }
    }

    static func output(node: MarkdownBlock) -> String {
        switch node {

        case .paragraph(text: let text):
            return "Paragraph(\(text.reduce("", combine: combineNodeOutput)))"

        case .header(level: let level, text: let text):
            return "Header(\(level), \(text.reduce("", combine: combineNodeOutput)))"

        case .code(text: let text):
            if let first = text.first {
                return "Code[" + text.dropFirst().reduce(Token.string(fromTokens: first)) { acc, cur in
                    return acc + "\n" + Token.string(fromTokens: cur)
                    } + "]"
            } else {
                return "Code[]"
            }

        case .fence(name: let name, text: let text):
            if let first = text.first {
                return "Fence[" + name + "][" + text.dropFirst().reduce(Token.string(fromTokens: first)) { acc, cur in
                    return acc + "\n" + Token.string(fromTokens: cur)
                    } + "]"
            } else {
                return "Fence[" + name + "][]"
            }

        case .quote(content: let content):
            return "Quote { " + content.reduce("", combine: combineNodeOutput) + "}"

        case .list(kind: let kind, items: let items):
            var itemsDesc = ""
            for item in items {
                itemsDesc += "Item { " + item.reduce("", combine: combineNodeOutput) + "}, "
            }
            return "List[\(kind)] { " + itemsDesc + "}"
            
            
        case .thematicBreak:
            return "ThematicBreak"
            
        }
    }
}


