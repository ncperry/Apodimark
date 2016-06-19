//
//  ProcessReference.swift
//  Apodimark
//

private struct NoReferenceDelimiterError: ErrorProtocol {}
private struct ReferenceNotDefinedError: ErrorProtocol {}

extension MarkdownParser {

    func processAllReferences(delimiters: inout DelimiterSlice) -> [InlineNode<View>] {
        var all: [InlineNode<View>] = []
        while let ref = try? processReference(delimiters: &delimiters) {
            all.append(contentsOf: ref)
        }
        return all
    }

    private func processReference(delimiters: inout DelimiterSlice) throws -> [InlineNode<View>] {

        guard let (closingTitleDelIdx, closingTitleDel, _) = findFirst(in: delimiters, whereNotNil: { (kind) -> Void? in
            if case .refCloser = kind { return () } else { return nil }
        }) else {
            throw NoReferenceDelimiterError()
        }

        delimiters[closingTitleDelIdx] = nil

        let prefix = delimiters.prefix(upTo: closingTitleDelIdx).reversed()

        guard let (openingTitleDelIdxReversed, openingTitleDel, refKind) = findFirst(in: prefix, whereNotNil: {
            (kind) -> ReferenceKind? in
            switch kind {

            case .refOpener:
                return .normal

            case .unwrappedRefOpener:
                return .unwrapped

            default:
                return nil
            }
        }) else {
            return []
        }

        let openingTitleDelIdx = openingTitleDelIdxReversed.base - 1

        delimiters[openingTitleDelIdx] = nil

        let definition: ReferenceDefinition
        let span: Range<View.Index>
        let spanEndDelIdx: Int

        do {
            func findNextNonNilDelIdx() -> (Int, Delimiter)? {
                for idx in delimiters.indices.suffix(from: closingTitleDelIdx + 1) {
                    guard let del = delimiters[idx] else {
                        continue
                    }
                    return (idx, del)
                }
                return nil
            }
            guard let (nextDelIdx, nextDel) = findNextNonNilDelIdx() else {
                throw ReferenceNotDefinedError()
            }
            switch nextDel.kind {

            case .refValueOpener:
                let (valueOpenerDelIdx, valueOpenerDel) = (nextDelIdx, nextDel)
                delimiters[valueOpenerDelIdx] = nil

                let suffix = delimiters.suffix(from: valueOpenerDelIdx + 1)
                guard let (valueCloserDelIdx, valueCloserDel, _) = findFirst(in: suffix, whereNotNil: { (kind) -> Void? in
                    if case .rightParen = kind {
                        return ()
                    } else {
                        return nil
                    }
                }) else {
                    throw ReferenceNotDefinedError()
                }
                delimiters[valueCloserDelIdx] = nil

                definition = Token.string(fromTokens: view[valueOpenerDel.idx ..< view.index(before: valueCloserDel.idx)])
                let width = refKind == .unwrapped ? 2 : 1
                span = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(IntMax(-width))) ..< valueCloserDel.idx
                spanEndDelIdx = valueCloserDelIdx


            case .refOpener where nextDel.idx == view.index(after: closingTitleDel.idx):
                let (aliasOpenerDelIdx, aliasOpenerDel) = (nextDelIdx, nextDel)
                let suffix = delimiters.suffix(from: aliasOpenerDelIdx + 1)
                guard let (aliasCloserIdx, aliasCloserDel, _) = findFirst(in: suffix, whereNotNil: { (kind) -> Void? in
                    if case .refCloser = kind {
                        return ()
                    } else {
                        return nil
                    }
                }) else {
                    delimiters[aliasOpenerDelIdx] = nil
                    throw ReferenceNotDefinedError()
                }
                let s = Token.string(fromTokens: view[aliasOpenerDel.idx ..< view.index(before: aliasCloserDel.idx)]).lowercased()
                guard let tmpDefinition = referenceDefinitions[s] else {
                    delimiters[aliasOpenerDelIdx]!.kind = .refOpener
                    throw ReferenceNotDefinedError()
                }
                delimiters[openingTitleDelIdx] = nil
                delimiters[aliasOpenerDelIdx] = nil
                delimiters[aliasCloserIdx] = nil

                definition = tmpDefinition
                let width = refKind == .unwrapped ? 2 : 1
                span = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(IntMax(-width))) ..< aliasCloserDel.idx
                spanEndDelIdx = aliasCloserIdx


            default:
                let s = Token.string(fromTokens: view[openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)]).lowercased()
                guard let tmpDefinition = referenceDefinitions[s] else {
                    throw ReferenceNotDefinedError()
                }
                delimiters[openingTitleDelIdx] = nil
                definition = tmpDefinition
                let width = refKind == .unwrapped ? 2 : 1
                span = view.index(openingTitleDel.idx, offsetBy: View.IndexDistance(IntMax(-width))) ..< closingTitleDel.idx
                spanEndDelIdx = closingTitleDelIdx
            }

            let title = openingTitleDel.idx ..< view.index(before: closingTitleDel.idx)
            let refNode = InlineNode<View>(kind: .reference(refKind, title: title, definition: definition), span: span)

            let delimiterRangeForTitle = (openingTitleDelIdx + 1) ..< closingTitleDelIdx
            var inlineNodes: [InlineNode<View>] = processAllEmphases(delimiters: &delimiters[delimiterRangeForTitle])
            let delimiterRangeForSpan = openingTitleDelIdx ..< spanEndDelIdx

            for i in delimiterRangeForTitle {
                guard let del = delimiters[i] else { continue }
                switch del.kind {
                case .start, .end, .softbreak, .hardbreak, .ignored: continue
                default: delimiters[i] = nil
                }
            }
            for i in delimiterRangeForTitle.upperBound ..< delimiterRangeForSpan.upperBound {
                delimiters[i] = nil
            }
            //delimiters.replaceSubrange(delimiterRangeForSpan, with: repeatElement(nil, count: delimiterRangeForSpan.count))

            inlineNodes.append(refNode)
            return inlineNodes
            
        }
        catch {
            return []
        }
        
    }
}
