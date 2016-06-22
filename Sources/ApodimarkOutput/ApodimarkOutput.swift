
import Apodimark

// FUNCTIONS INTENDED ONLY FOR TESTING PURPOSES
// DO NOT USE “APODIMARK OUTPUT” IF YOU ARE NOT TESTING APODIMARK

extension MarkdownBlock {
    typealias Token = View.Iterator.Element

    static func combineNodeOutput(source: View) -> (acc: String, cur: MarkdownBlock) -> String {
        return { (acc: String, cur: MarkdownBlock) -> String in
            let appending = output(node: cur, source: source)
            guard !appending.isEmpty else { return acc }
            return acc + appending + ", "
        }
    }

    static func combineNodeOutput(source: View) -> (acc: String, cur: MarkdownInline<View>) -> String {
        return { (acc: String, cur: MarkdownInline<View>) -> String in
            let appending = output(node: cur, source: source)
            guard !appending.isEmpty else { return acc }
            return acc + appending
        }
    }

    public static func output(nodes: [MarkdownBlock], source: View) -> String {
        return nodes.reduce("Document { ", combine: combineNodeOutput(source: source)) + "}"
    }
    static func output(nodes: [MarkdownInline<View>], source: View) -> String {
        return nodes.reduce("", combine: combineNodeOutput(source: source))
    }

    static func output(node: MarkdownInline<View>, source: View) -> String {
        switch node {

        case .text(let indices):
            return Token.string(fromTokens: source[indices])

        case .emphasis(level: let level, content: let content):
            return "e\(level)(" + content.reduce("", combine: combineNodeOutput(source: source)) + ")"

        case .monospacedText(let children):
            return "code(" + children.reduce("") { (acc, cur) in
                let next: String
                switch cur {
                case .softbreak, .hardbreak: next = " "
                case .text(let idcs): next = Token.string(fromTokens: source[idcs])
                default: fatalError()
                }
                return acc + next
            } + ")"

        case .reference(kind: let kind, title: let title, definition: let definition):
            let kindDesc = kind == .unwrapped ? "uref" : "ref"
            let titleDesc = output(nodes: title, source: source)
            return "[\(kindDesc): \(titleDesc)(\(definition))]"

        case .hardbreak:
            return "[hardbreak]"

        case .softbreak:
            return "[softbreak]"
        }
    }

    static func output(node: MarkdownBlock, source: View) -> String {
        switch node {

        case .paragraph(text: let idcs):
            return "Paragraph(\(idcs.reduce("", combine: combineNodeOutput(source: source))))"

        case .header(level: let level, text: let text):
            return "Header(\(level), \(text.reduce("", combine: combineNodeOutput(source: source))))"

        case .code(text: let text):
            if let first = text.first {
                return "Code[" + text.dropFirst().reduce(Token.string(fromTokens: source[first])) { acc, cur in
                    return acc + "\n" + Token.string(fromTokens: source[cur])
                    } + "]"
            } else {
                return "Code[]"
            }

        case .fence(name: let name, text: let text):
            if let first = text.first {
                return "Fence[" + name + "][" + text.dropFirst().reduce(Token.string(fromTokens: source[first])) { acc, cur in
                    return acc + "\n" + Token.string(fromTokens: source[cur])
                    } + "]"
            } else {
                return "Fence[" + name + "][]"
            }

        case .quote(content: let content):
            return "Quote { " + content.reduce("", combine: combineNodeOutput(source: source)) + "}"

        case .list(kind: let kind, items: let items):
            var itemsDesc = ""
            for item in items {
                itemsDesc += "Item { " + item.reduce("", combine: combineNodeOutput(source: source)) + "}, "
            }
            return "List[\(kind)] { " + itemsDesc + "}"
            
            
        case .thematicBreak:
            return "ThematicBreak"
            
        }
    }
}


