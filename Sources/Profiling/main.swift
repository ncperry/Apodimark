
import Foundation
import Apodimark

private func stringForTest(_ name: String, result: Bool = false) -> String {
    let dirUrl = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let fileUrl = dirUrl.appendingPathComponent("test-files/performance/" + name + ".txt")

    return try! String(contentsOf: fileUrl)
}

// Step 1: get the document
let mixed1 = stringForTest("emphases")
var s = ""
// Step 2: repeat the string until it reaches 10 million code points
while s.utf16.count < 10_000_000 {
    s += mixed1
}
// Step 3: measure the time it takes to build the AST
_ = parsedMarkdown(source: s.utf16, codec: UTF16MarkdownCodec.self)
// Step 4: look at result, cry.

