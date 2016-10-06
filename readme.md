# Apodimark

Apodimark is a markdown parser written in pure Swift 3. It is fast, flexible,
easy to use, and works with indices instead of String, which is ideal for 
syntax highlighting.

## Contribute

This is a young project, and there’s still a lot of work to 
be done. **Contributions are welcomed and encouraged ♡**

If you want to contribute, you can start by looking at 
the [internal documentation], which includes a small guide to 
contributing and a description of the parser.

[internal documentation]: internal/readme.md

## Usage

Parsing a `String.UTF16View` is easy:

``` swift
let ast = parsedMarkdown(source: string.utf16, codec: UTF16MarkdownCodec.self)
```

In fact, you can parse any `BidirectionalCollection` whose elements can be 
interpreted by the `MarkdownParserCodec` given as second argument.


``` swift
let s = Array(string.unicodeScalars)
let ast = parsedMarkdown(source: s, codec: UnicodeScalarMarkdownCodec.self)
```

However, note that:
- Performance can vary significantly based on the performance characteristics 
  of the collection and whether the function can be specialized by the compiler.
  For more details on this, see [performance.md][performance].

- Currently, only `String.UTF16View` and `UTF16MarkdownCodec` provide good 
  performance because they are “manually” specialized in `Apodimark.swift` 
  (when using whole-module-optimization). 

The return value of the `parsedMarkdown` function is an abstract syntax tree
of the document represented by an array of `MarkdownBlock`.
A markdown block can be:
- paragraph
- header
- list
- quote
- indented code block
- fenced code block
- thematic break

Some markdown blocks (lists, quotes) contain other markdown blocks, 
and some (headers, paragraphs) contain `MarkdownInline` elements.
A markdown inline can be:
- emphasis
- monospaced text
- plain text
- reference (link/image)
- softbreak
- hardbreak

Each element of the AST stores some relevant indices. For example, an emphasis is
defined by:
```swift
struct EmphasisInline <View: BidirectionalCollection> where
    View.SubSequence: BidirectionalCollection,
    View.SubSequence.Iterator.Element == View.Iterator.Element
{
    let level: Int
    let content: [MarkdownInline<View>]
    let markers: (Range<View.Index>, Range<View.Index>)
}
```

where `markers` contains the indices to the opening and closing characters of 
the emphasis.

```
this is an **emphasis**
           ^^        ^^
    markers.0        markers.1
```

[performance]: internal/performance.md

## Getting Started

Apodimark is currently only available via the Swift Package Manager.

## Goals

Apodimark should be fast, robust, and flexible.
- **fast**: can parse a million-character string in a fraction of a second
- **robust**: withstands pathological inputs
- **flexible**: does not impose strict requirements on the type of the input/output

It should also be very well tested and well documented. There are currently
over 400 tests ensuring that Apodimark behaves like Commonmark where it matters.
The documentation needs some work right now, but it should be 100% documented 
very soon.

Finally, it should not have any dependencies.

## Non-Goals

- **100% Commonmark compliance**  
  Apodimark may differ a little bit from Commonmark. However, apart from a few 
  features, Apodimark should behave exactly like Commonmark. You can see the 
  complete list of differences [here][commonmark-delta].

[commonmark-delta]: internal/differences-with-commonmark.md

- **HTML generation**  
  Apodimark only provides an abstract syntax tree containing 
  indices to the original collection. Output generation is 
  left as an exercise to the user.
