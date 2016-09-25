//
//  BlockParsing.swift
//  Apodimark
//

extension MarkdownParser {

    mutating func parseBlocks() -> [BlockNode<View>] {

        var children: [BlockNode<View>] = []

        var scanner = Scanner<View>(data: view)

        while let _ = scanner.peek() {
            let line = parseLine(scanner: &scanner)

            if children.isEmpty || !children[children.endIndex - 1].add(line: line) {
                if !line.kind.isEmpty() {
                    children.append(line.node())
                }
            }
            // TODO: handle different line endings than LF
            _ = scanner.pop(Codec.linefeed)
        }

        for child in children {
            addReferenceDefinitions(fromNode: child)
        }

        return children
    }

    fileprivate mutating func addReferenceDefinitions(fromNode node: BlockNode<View>) {
        switch node {
        case let node as ReferenceDefinitionBlockNode<View> where referenceDefinitions[node.title] == nil:
            referenceDefinitions[node.title] = node.definition

        case let node as ListBlockNode<View>:
            for item in node.items {
                for block in item.content {
                    addReferenceDefinitions(fromNode: block)
                }
            }

        case let node as QuoteBlockNode<View>:
            for block in node.content {
                addReferenceDefinitions(fromNode: block)
            }

        default:
            break
        }
    }
}
