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
        case let .referenceDefinition(title: title, definition: definition) where referenceDefinitions[title] == nil:
            referenceDefinitions[title] = definition

        case let .list(_, _, _, items):
            for item in items.data {
                for block in item {
                    addReferenceDefinitions(fromNode: block)
                }
            }

        case let .quote(content, _):
            for block in content.data {
                addReferenceDefinitions(fromNode: block)
            }

        default:
            break
        }
    }
}
