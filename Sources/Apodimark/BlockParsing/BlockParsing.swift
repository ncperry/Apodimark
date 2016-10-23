//
//  BlockParsingTree.swift
//  Apodimark
//

enum ListState {
    case normal, followedByEmptyLine, closed
}

enum AddLineResult {
    case success
    case failure
}

extension MarkdownParser {
    
    func parseBlocks() {
        var scanner = Scanner(data: view)
        while case .some = scanner.peek() {
            _ = add(line: MarkdownParser.parseLine(&scanner))
            // TODO: handle different line endings than LF
            scanner.popUntil(Codec.linefeed)
            _ = scanner.pop(Codec.linefeed)
        }
        
        for case .referenceDefinition(let ref) in blockTree.buffer.lazy.map({ $0.data })
            where referenceDefinitions[ref.title] == nil
        {
            referenceDefinitions[ref.title] = ref.definition
        }
    }
}

extension BlockNode {
    func allowsLazyContinuation() -> Bool {
        switch self {
        case .paragraph(let x):
            return !x.closed
        case .header:
            return false
        case .quote(let x):
            return x._allowsLazyContinuation
        case .list(let x):
            return x._allowsLazyContinuations
        case .listItem:
            fatalError()
        case .fence:
            return false
        case .code:
            return false
        case .thematicBreak:
            return false
        case .referenceDefinition:
            return false
        }
    }
}

extension MarkdownParser {
    
    fileprivate func add(line: Line<View>) {
        let last = blockTree.last(depthLevel: .root)
        
        let addResult = last.map({ add(line: line, to: $0, depthLevel: .root) }) ?? .failure
        
        if case .failure = addResult, !line.kind.isEmpty() {
            _ = appendStrand(from: line, level: .root)
        }
    }
    
    fileprivate func add(line: Line<View>, to block: BlockNode<View>, depthLevel: DepthLevel) -> AddLineResult {
        switch block {
        case .paragraph(let x):
            return add(line: line, to: x)
        case .header:
            return .failure
        case .quote(let x):
            return add(line: line, to: x, quoteLevel: depthLevel)
        case .list(let x):
            return add(line: line, to: x, listLevel: depthLevel)
        case .listItem:
            fatalError()
        case .fence(let x):
            return add(line: line, to: x)
        case .code(let x):
            return add(line: line, to: x)
        case .thematicBreak:
            return .failure
        case .referenceDefinition:
            return .failure
        }
    }
}

// PARAGRAPH
extension MarkdownParser {
    fileprivate func add(line: Line<View>, to paragraph: ParagraphNode<View>) -> AddLineResult {
        
        guard !paragraph.closed else { return .failure }
        
        switch line.kind {
        case .text, .reference:
            paragraph.text.append(line.indices)
            
        case .empty:
            paragraph.closed = true
            
        default:
            guard line.indent.level >= TAB_INDENT else { return .failure }
            var line = line
            line.indent.level -= TAB_INDENT
            paragraph.text.append(line.indices)
        }
        return .success
    }
}


// QUOTE
extension MarkdownParser {
    fileprivate func directlyAddLine(line: Line<View>, to quote: QuoteNode<View>, quoteLevel: DepthLevel) {
        let quoteContentLevel = quoteLevel.incremented()

        let last = blockTree.last(depthLevel: quoteContentLevel)!
        if case .success = add(line: line, to: last, depthLevel: quoteContentLevel) {
            quote._allowsLazyContinuation = last.allowsLazyContinuation()
        } else {
            guard !line.kind.isEmpty() else { return }
            appendStrand(from: line, level: quoteContentLevel)
            quote._allowsLazyContinuation = blockTree.last(depthLevel: quoteContentLevel)!.allowsLazyContinuation()
        }
    }
    
    fileprivate func add(line: Line<View>, to quote: QuoteNode<View>, quoteLevel: DepthLevel) -> AddLineResult {
        
        guard !quote.closed else { return .failure }
        
        guard !(line.indent.level >= TAB_INDENT && quote._allowsLazyContinuation) else {
            directlyAddLine(line: Line(.text, line.indent, line.indices), to: quote, quoteLevel: quoteLevel)
            return .success
        }
        
        switch line.kind {
            
        case .empty:
            quote.closed = true
            quote._allowsLazyContinuation = false
            
        case .quote(let rest):
            quote.markers.append(line.indices.lowerBound)
            directlyAddLine(line: rest, to: quote, quoteLevel: quoteLevel)
            
        case .text:
            guard quote._allowsLazyContinuation else {
                return .failure
            }
            directlyAddLine(line: line, to: quote, quoteLevel: quoteLevel)
            
        default:
            return .failure
        }
        return .success
    }
}


// LIST
extension MarkdownParser {
    
    fileprivate func preparedLine(from initialLine: Line<View>, for list: ListNode<View>) -> Line<View>? {
        guard list.state != .closed else {
            return nil
        }
        var line = initialLine
        guard !initialLine.kind.isEmpty() else {
            return line
        }
        guard !(initialLine.indent.level >= list.minimumIndent + TAB_INDENT && list._allowsLazyContinuations) else {
            line.indent.level -= list.minimumIndent
            return line
        }

        line.indent.level -= list.minimumIndent
        let isWellIndented = line.indent.level >= 0
        
        switch line.kind {
            
        case .text:
            return isWellIndented || (list.state == .normal && list._allowsLazyContinuations) ? line : nil
            
        case let .list(k, _):
            if isWellIndented {
                return line
            }
            else {
                return k ~= list.kind ? line : nil
            }
            
        case .quote, .header, .fence, .reference:
            return isWellIndented ? line : nil
            
        default:
            return nil
        }
    }

    fileprivate func addPreparedLine(_ preparedLine: Line<View>, to list: ListNode<View>, listLevel: DepthLevel) {
        switch preparedLine.kind {
        
        case .empty:
            
            guard case .normal = list.state else {
                guard case let lastLeaf = blockTree.buffer.last!.data,
                      case let .fence(fenceNode) = lastLeaf
                else {
                    list.state = .closed
                    list._allowsLazyContinuations = false
                    return
                }
                _ = add(line: preparedLine, to: fenceNode)
                return
            }

            let itemContentLevel = listLevel.incremented().incremented()
            guard let lastItemContent = blockTree.last(depthLevel: itemContentLevel) else {
                return
            }
            list.state = .followedByEmptyLine
            _ = add(line: preparedLine, to: lastItemContent, depthLevel: itemContentLevel)
            list._allowsLazyContinuations = lastItemContent.allowsLazyContinuation()
        
        case .list(let kind, let rest) where preparedLine.indent.level < 0:
            list.state = .normal
            list.minimumIndent += preparedLine.indent.level + kind.width + 1
            let idcs = preparedLine.indices
            let markerSpan = idcs.lowerBound ..< view.index(idcs.lowerBound, offsetBy: numericCast(kind.width))
            if case .empty = rest.kind {
                list._allowsLazyContinuations = true
                _ = blockTree.append(.listItem(.init(markerSpan: markerSpan)), depthLevel: listLevel.incremented())
            } else {
                let listItemLevel = listLevel.incremented()
                let itemChildIdx = blockTree.buffer.endIndex+1
                blockTree.append(.listItem(.init(markerSpan: markerSpan)), depthLevel: listItemLevel)
                appendStrand(from: rest, level: listItemLevel.incremented())
                list._allowsLazyContinuations = blockTree.buffer[itemChildIdx].data.allowsLazyContinuation()
            }
            
        default:
            list.state = .normal
            let itemContentLevel = listLevel.incremented().incremented()
            let lastItemContent = blockTree.last(depthLevel: itemContentLevel)
            
            let addResult = lastItemContent.map { add(line: preparedLine, to: $0, depthLevel: itemContentLevel) } ?? .failure
            
            if case .failure = addResult {
                let itemContentIdx = blockTree.buffer.endIndex
                appendStrand(from: preparedLine, level: itemContentLevel)
                list._allowsLazyContinuations = blockTree.buffer[itemContentIdx].data.allowsLazyContinuation()
            }
        }
    }
    
    fileprivate func add(line: Line<View>, to list: ListNode<View>, listLevel: DepthLevel) -> AddLineResult {
        guard let line = preparedLine(from: line, for: list) else {
            return .failure
        }
        addPreparedLine(line, to: list, listLevel: listLevel)
        return .success
    }
}

// FENCE
extension MarkdownParser {
    fileprivate func add(line: Line<View>, to fence: FenceNode<View>) -> AddLineResult {
        
        guard line.indent.level >= 0 && !fence.closed else {
            return .failure
        }
        var line = line
        line.indent.level -= fence.indent
        restoreIndentInLine(&line)
        
        switch line.kind {
            
        case .fence(fence.kind, let lineFenceName, let lineFenceLevel) where line.indent.level < TAB_INDENT && lineFenceName.isEmpty && lineFenceLevel >= fence.level:
            fence.markers.1 = line.indices
            fence.closed = true
            
        default:
            fence.text.append(line.indices)
        }
        return .success
    }
}

// CODE BLOCK
extension MarkdownParser {
    fileprivate func add(line: Line<View>, to code: CodeNode<View>) -> AddLineResult {
        switch line.kind {
            
        case .empty:
            var line = line
            line.indent.level -= TAB_INDENT
            restoreIndentInLine(&line)
            code.trailingEmptyLines.append(line.indices)
            
        case _ where line.indent.level >= TAB_INDENT:
            var line = line
            line.indent.level -= TAB_INDENT
            restoreIndentInLine(&line)
            
            code.text.append(contentsOf: code.trailingEmptyLines)
            code.text.append(line.indices)
            code.trailingEmptyLines.removeAll()
            
        default:
            return .failure
        }
        return .success
    }
}
