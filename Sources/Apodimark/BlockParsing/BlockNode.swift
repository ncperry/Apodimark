//
//  BlockAST.swift
//  Apodimark
//

final class Box<T> {
    var data: T
    init(_ data: T) { self.data = data }
}

enum ListState {
    case normal, followedByEmptyLine, closed
}

/// A block-level node in the internal abstract syntax tree
///
/// - important: 
/// Instances of this type do *NOT* have value semantics.
indirect enum BlockNode <View: BidirectionalCollection where
    View.Iterator.Element: MarkdownParserToken,
    View.SubSequence: Collection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
> {
    typealias Indices = Range<View.Index>

    case paragraph(text: Box<[Indices]>, closed: Bool)

    case header(text: Indices, level: Int)

    case quote(content: Box<[BlockNode]>, closed: Bool)

    case list(kind: ListKind, minIndent: Int, state: ListState, items: Box<[[BlockNode]]>)

    case fence(kind: FenceKind, name: Indices?, text: Box<[Indices]>, indentLevel: Int, fenceLevel: Int, closed: Bool)

    case code(text: Box<[Indices]>, trailingEmptyLines: Box<[Indices]>)

    case thematicBreak

    case referenceDefinition(title: String, definition: ReferenceDefinition)
}

extension BlockNode {

    /// Add a line to `self`.
    ///
    /// - parameter line: the line to add to `self`
    /// - returns: `true` if `self` added the line, `false` otherwise
    mutating func add(line: Line<View>) -> Bool {

        // Note: this function is awful
        // To make it more palatable, consider each `case` as a separate function, ignore the rest
        // TODO: find a better way to add a line to the AST

        switch self {

        // MARK: Adding a line to a paragraph
        case let .paragraph(text: text, closed: closed):
            guard !closed else {
                return false
            }

            switch line.kind {
            case .text, .reference:
                text.data.append(line.scanner.indices)

            case .empty:
                self = .paragraph(text: text, closed: true)

            default:
                guard line.indent.level >= 4 else { return false }
                text.data.append(line.removingFirstIndents(n: 4).scanner.indices)
            }
            return true



        // MARK: Adding a line to a header
        case .header:
            return false



        // MARK: Adding a line to a quote
        case let .quote(content: content, closed: closed):

            func addLineToQuote(line: Line<View>) {
                if content.data[content.data.endIndex - 1].add(line: line) == false && !line.kind.isEmpty() {
                    content.data.append(line.node())
                }
            }

            guard !closed else {
                return false
            }

            let lazyContinuationIsPossible = self.allowsLazyContinuations()

            guard !(line.indent.level >= 4 && lazyContinuationIsPossible) else {
                let line = Line(.text, line.indent, line.scanner)
                addLineToQuote(line: line)
                return true
            }

            switch line.kind {

            case .empty:
                self = .quote(content: content, closed: true)

            case .quote(let rest):
                addLineToQuote(line: rest)

            case .text:
                guard lazyContinuationIsPossible else {
                    return false
                }
                addLineToQuote(line: line)

            default:
                return false
            }
            return true



        // MARK: adding a line to a list
        case let .list(kind: kind, minIndent: minIndent, state: state, items: items):

            func lastChild(of items: Box<[[BlockNode]]>) -> BlockNode? {
                return items.data.last?.last
            }
            func withLastChild <T> (of items: Box<[[BlockNode]]>, apply: @noescape (inout BlockNode) -> T) -> T {
                guard let lastArr = items.data.last else { fatalError() }
                return apply(&items.data[items.data.endIndex - 1][lastArr.endIndex - 1])
            }

            func preparedLine(from initialLine: Line<View>) -> Line<View>? {
                guard state != .closed else {
                    return nil
                }
                guard !initialLine.kind.isEmpty() else {
                    return initialLine
                }
                guard !(initialLine.indent.level >= minIndent + 4 && allowsLazyContinuations()) else {
                    return initialLine.removingFirstIndents(n: minIndent)
                }

                let lineWithoutIndent = initialLine.removingFirstIndents(n: minIndent)
                let isWellIndented = lineWithoutIndent.indent.level >= 0

                switch lineWithoutIndent.kind {

                case .text:
                    return isWellIndented || (state == .normal && allowsLazyContinuations()) ? lineWithoutIndent : nil

                case let .list(k, _):
                    if isWellIndented {
                        return lineWithoutIndent
                    }
                    else {
                        return k ~= kind ? lineWithoutIndent : nil
                    }

                case .quote, .header, .fence, .reference:
                    return isWellIndented ? lineWithoutIndent : nil

                default:
                    return nil
                }
            }

            func addPreparedLineToList(preparedLine: Line<View>) {
                switch preparedLine.kind {

                case .empty:
                    var shallowestNonListChild: BlockNode? = lastChild(of: items)
                    while case .list(_, _, _, items: let items)? = shallowestNonListChild {
                        shallowestNonListChild = lastChild(of: items)
                    }

                    guard state == .normal || (shallowestNonListChild?.isFence() ?? false) else {
                        return self = .list(kind: kind, minIndent: minIndent, state: .closed, items: items)
                    }
                    guard !items.data.isEmpty && !(items.data.last!.isEmpty) else {
                        return
                    }

                    let state = ListState.followedByEmptyLine
                    _ = withLastChild(of: items) { $0.add(line: preparedLine) }
                    self = .list(kind: kind, minIndent: minIndent, state: state, items: items)

                case .list(_, let rest) where preparedLine.indent.level < 0:
                    let state = ListState.normal
                    let minIndent = minIndent + preparedLine.indent.level + kind.width + rest.indent.level
                    items.data.append(rest.kind.isEmpty() ? [] : [rest.node()])
                    self = .list(kind: kind, minIndent: minIndent, state: state, items: items)

                default:
                    let state = ListState.normal
                    let lastItem = items.data.last!
                    if lastItem.isEmpty || !withLastChild(of: items, apply: {$0.add(line: preparedLine)}) {
                        items.data[items.data.endIndex-1].append(preparedLine.node())
                    }
                    self = .list(kind: kind, minIndent: minIndent, state: state, items: items)
                }
            }

            guard let line = preparedLine(from: line) else {
                return false
            }
            addPreparedLineToList(preparedLine: line)
            return true



        // MARK: adding a line to a fence
        case let .fence(kind: kind, name: name, text: text, indentLevel: indentLevel, fenceLevel: fenceLevel, closed: closed):

            guard line.indent.level >= 0 && !closed else {
                return false
            }

            let line = line.removingFirstIndents(n: indentLevel).restoringIndentInSubview()

            switch line.kind {

            case let .fence(lineFenceKind, lineFenceName, lineFenceLevel) where
                    line.indent.level < 4 &&
                    lineFenceKind == kind &&
                    lineFenceName.isEmpty &&
                    lineFenceLevel >= fenceLevel:
                self = .fence(kind: kind, name: name, text: text, indentLevel: indentLevel, fenceLevel: fenceLevel, closed: true)

            default:
                text.data.append(line.scanner.indices)
            }
            return true



        // MARK: adding a line to a code block
        case let .code(text: text, trailingEmptyLines: trailingEmptyLines):
            switch line.kind {

            case .empty:
                let line = line.removingFirstIndents(n: 4).restoringIndentInSubview()
                trailingEmptyLines.data.append(line.scanner.indices)

            case _ where line.indent.level >= 4:
                let line = line.removingFirstIndents(n: 4).restoringIndentInSubview()
                text.data.append(contentsOf: trailingEmptyLines.data)
                text.data.append(line.scanner.indices)
                trailingEmptyLines.data.removeAll()

            default:
                return false
            }
            return true



        // MARK: adding a line to a thematic break
        case .thematicBreak:
            return false



        // MARK: adding a line to a reference definition
        case .referenceDefinition:
            return false
        }
    }

    /// Returns `true` iff `self` allows a lazy continuation to occur.
    ///
    /// A lazy continuation
    private func allowsLazyContinuations() -> Bool {
        switch self {

        case .header, .fence, .code, .thematicBreak, .referenceDefinition:
            return false

        case .paragraph(_, closed: let closed):
            return !closed

        case .quote(content: let content, closed: let closed):
            return !closed && (content.data.last?.allowsLazyContinuations() ?? true)

        case .list(_, _, _, let items):
            return items.data.last?.last?.allowsLazyContinuations() ?? false
        }
    }

    /// - returns `true` iff `case .fence = self`
    private func isFence() -> Bool {
        if case .fence = self { return true }
        else { return false }
    }
}


extension Line {

    /// - returns: the node that corresponds to `self`
    func node() -> BlockNode<View> {

        guard indent.level < 4 else {
            let newline = self.removingFirstIndents(n: 4).restoringIndentInSubview()
            return .code(text: Box([newline.scanner.indices]), trailingEmptyLines: Box([]))
        }

        switch kind {

        case .text:
            return .paragraph(text: Box([scanner.indices]), closed: false)

        case let .list(kind, rest):
            let state: ListState = rest.kind.isEmpty() ? .followedByEmptyLine : .normal
            let items = [rest.kind.isEmpty() ? [] : [rest.node()]]
            let minIndent: Int

            if case .code? = items.last?.last {
                minIndent = indent.level + kind.width
            } else {
                minIndent = indent.level + kind.width + rest.indent.level
            }
            return .list(kind: kind, minIndent: minIndent, state: state, items: Box(items))

        case .header(let text, let level):
            return .header(text: text, level: level)

        case .quote(let rest):
            return .quote(content: Box([rest.node()]), closed: false)

        case let .fence(kind, name, level):
            return .fence(kind: kind, name: name, text: Box([]), indentLevel: indent.level, fenceLevel: level, closed: false)

        case .thematicBreak:
            return .thematicBreak

        case .empty:
            return .paragraph(text: Box([]), closed: false)

        case let .reference(title, definition):
            return .referenceDefinition(title: title, definition: definition)
        }
    }
}


