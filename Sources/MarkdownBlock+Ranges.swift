//
//  MarkdownBlock+Ranges.swift
//  Apodimark
//
//  Created by Nate Perry on 11/23/16.
//  Copyright © 2016 Loïc Lecrenier. All rights reserved.
//

import Foundation

extension MarkdownBlock {
    var ranges: [Range<View.Index>] {
        switch self {
        case .paragraph(let paragraphBlock):
            return paragraphBlock.textRanges
        case .header(let headerBlock):
            return [headerBlock.span]
        case .quote(let quoteBlock):
            return quoteBlock.contentRanges
        case .list(let listBlock):
            return listBlock.listRanges
        case .fence(let fenceBlock):
            return fenceBlock.text
        case .code(let codeBlock):
            return codeBlock.text
        case .thematicBreak(let thematicBreakBlock):
            return [thematicBreakBlock.marker]
        default:
            return []
        }
    }
}

