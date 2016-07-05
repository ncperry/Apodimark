//
//  BlockParsing.swift
//  Apodimark
//

extension MarkdownParser {

    func parseBlocks() -> [BlockNode<View>] {

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
            _ = scanner.pop(linefeed)
        }

        for child in children {
            addReferenceDefinitions(fromNode: child)
        }

        return children
    }

    private func addReferenceDefinitions(fromNode node: BlockNode<View>) {
        switch node {
        case let node as ReferenceDefinitionBlockNode<View> where referenceDefinitions[node.title] == nil:
            referenceDefinitions[node.title] = node.definition

        case let node as ListBlockNode<View>:
            for item in node.items {
                for block in item {
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
