//
//  BlockParsing.swift
//  Apodimark
//

extension MarkdownParser {

    mutating func parseBlocks() -> [BlockNode<View>] {

        var children: [BlockNode<View>] = []

        var scanner = Scanner<View>(data: view)

        while case .some = scanner.peek() {
            let line = parseLine(scanner: &scanner)

            if
                case .failure = children.last?.add(line: line) ?? .failure,
                !line.kind.isEmpty()
            {
                children.append(line.node())
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
        case let .referenceDefinition(ref) where referenceDefinitions[ref.title] == nil:
            referenceDefinitions[ref.title] = ref.definition

        case let .list(l):
            for item in l.items {
                for block in item.content {
                    addReferenceDefinitions(fromNode: block)
                }
            }

        case let .quote(q):
            for block in q.content {
                addReferenceDefinitions(fromNode: block)
            }

        default:
            break
        }
    }
}
