# Performance

Performance can vary greatly depending on three factors: 

- performance of the collection used for the source
- whether `parsedMarkdown` was specialized by the compiler
- and, of course, the complexity of the source document

On my 2012 Macbook Air, parsing a typical 10MB markdown document can take 
between 1s and 50s, so be careful about your compilation settings and source type. 

Typically:
- an unspecialized `parsedMarkdown` will be at least 10x slower than a specialized one
- String.UTF16View is the fastest String view
- String.CharacterView is the slowest one (about 5x slower than UTF16View)
- an Array is faster to parse than any String view

By default, `parsedMarkdown` is only specialized when using `String.UTF16View`. 
If you want to use another collection, you should find the function declaration
in `Apodimark.swift`, add `@_specialize(MyCollectionType, MyMarkdownCodecType)`, 
and then recompile Apodimark with whole-module-optimization enabled. This will 
ensure that Apodimark is properly optimized for your use case.
