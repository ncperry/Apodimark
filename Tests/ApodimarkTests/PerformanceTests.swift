
import XCTest
import Apodimark

private func baseStringForTest(_ name: String, result: Bool = false) -> String {
    let dirUrl = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let fileUrl = dirUrl.appendingPathComponent("test-files/performance/" + name + ".txt")
    
    return try! String(contentsOf: fileUrl)
}

private func testString(size: Int) -> String {
    let base = baseStringForTest("mixed1")
    var s = ""
    while s.utf16.count < size {
        s += base
    }
    return s
}

class PerformanceTests : XCTestCase {
    
    func testMixed1ArrayUTF8_100_000() {
        let s = testString(size: 100_000)
        let a = Array(s.utf8)
        measure {
            _ = parsedMarkdown(source: a, codec: UTF8MarkdownCodec.self)
        }
    }
    
    func testMixed1ArrayUTF8_1_000_000() {
        let s = testString(size: 1_000_000)
        let a = Array(s.utf8)
        measure {
            _ = parsedMarkdown(source: a, codec: UTF8MarkdownCodec.self)
        }
    }
    
    func testMixed1ArrayUTF8_10_000_000() {
        let s = testString(size: 10_000_000)
        let a = Array(s.utf8)
        measure {
            _ = parsedMarkdown(source: a, codec: UTF8MarkdownCodec.self)
        }
    }
    
    func testMixed1Character_100_000() {
        let s = testString(size: 100_000)
        measure {
            _ = parsedMarkdown(source: s.characters, codec: CharacterMarkdownCodec.self)
        }
    }
    
    func testMixed1Character_1_000_000() {
        let s = testString(size: 1_000_000)
        measure {
            _ = parsedMarkdown(source: s.characters, codec: CharacterMarkdownCodec.self)
        }
    }
    
    func testMixed1Character_10_000_000() {
        let s = testString(size: 10_000_000)
        measure {
            _ = parsedMarkdown(source: s.characters, codec: CharacterMarkdownCodec.self)
        }
    }
    
    func testMixed1UnicodeScalar_100_000() {
        let s = testString(size: 100_000)
        measure {
            _ = parsedMarkdown(source: s.unicodeScalars, codec: UnicodeScalarMarkdownCodec.self)
        }
    }
    
    func testMixed1UnicodeScalar_1_000_000() {
        let s = testString(size: 1_000_000)
        measure {
            _ = parsedMarkdown(source: s.unicodeScalars, codec: UnicodeScalarMarkdownCodec.self)
        }
    }
    
    func testMixed1UnicodeScalar_10_000_000() {
        let s = testString(size: 10_000_000)
        measure {
            _ = parsedMarkdown(source: s.unicodeScalars, codec: UnicodeScalarMarkdownCodec.self)
        }
    }
    
    func testMixed1UTF16_100_000() {
        let s = testString(size: 100_000)
        measure {
            _ = parsedMarkdown(source: s.utf16, codec: UTF16MarkdownCodec.self)
        }
    }
    
    func testMixed1UTF16_1_000_000() {
        let s = testString(size: 1_000_000)
        measure {
            _ = parsedMarkdown(source: s.utf16, codec: UTF16MarkdownCodec.self)
        }
    }
    
    func testMixed1UTF16_10_000_000() {
        let s = testString(size: 10_000_000)
        measure {
            _ = parsedMarkdown(source: s.utf16, codec: UTF16MarkdownCodec.self)
        }
    }
}
