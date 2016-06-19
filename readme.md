# Apodimark

Apodimark is a markdown parser written in pure Swift 3. 
It is still a work in progress, but it should be stable 
by the time Swift 3 is officially released.

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
let document = parsedMarkdown(source: string.utf16)
```

In fact, you can parse any `BidirectionalCollection` whose elements conform 
to `MarkdownParserToken`. So these can be valid arguments:
- `UnsafeBufferPointer<UnicodeScalar>`
- `String.CharacterView`
- `Data`

``` swift
let arr = Array(string.utf16)
let document = arr.withUnsafeBufferPointer { parsedMarkdown(source: $0) }
```

However, note that:
- Only `UInt8` and `UInt16` conform to `MarkdownParserToken` out of the box
- Performance can vary significantly based on the performance characteristics 
  of the collection and whether the function can be specialized by the compiler.

  Currently, only `String.UTF16View` provides good performance because it is
  “manually” specialized in `Apodidown.swift` (when using whole-module-optimization). 

The return value of the `parsedMarkdown` function is an abstract syntax tree
of the document represented by an array of `MarkdownBlock`.
A markdown block can be:
- paragraph
- list
- quote
- block of code
- etc.

Some markdown blocks (paragraph, header) contain other markdown blocks, 
and some contain `MarkdownInline` elements.
A markdown inline can be:
- emphasis
- monospaced text
- plain text
- reference (link/image)
- etc.

The leaves of the abstract syntax tree contain the indices of their contents (**not a String**). 
However, this will change soon so that every node provides this functionality.
This should make it easy to provide fast syntax highlighting.

## Getting Started

**`TODO`**

## Goals

Apodimark should be fast, robust, and flexible.
- **fast**: can parse a million-character string in a fraction of a second
- **robust**: withstands pathological inputs
- **flexible**: does not impose strict requirements on the type of the input/output

It should also be very well tested and well documented. There are currently
over 400 tests ensuring that Apodimark behaves like Commonmark where it matters.
The documentation needs some work right now, but it should be 100% documented very soon.  

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
