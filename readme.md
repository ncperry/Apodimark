# Apodimark

Apodimark is a markdown parser written in pure Swift 3. It is still a work in progress, but should be stable by the time Swift 3 is officially released.

## Contribute

This is a young project, and there’s still a lot of work to be done. **Contributions are welcomed and encouraged ♡**

If you want to contribute, you can start by looking at the [internal documentation], which includes a roadmap and a detailed description of the parser.

[internal documentation]: contributing/index.md

## Goals

Apodimark should be fast, robust, and flexible.
- **fast**: can parse a million-character string in a fraction of a second
- **robust**: withstands pathological inputs
- **flexible**: does not impose strict requirements on the type of the input or output

## Non-Goals

- **100% Commonmark compliance**  
  Apodimark may differ a little bit from Commonmark. However, apart from a few features, Apodimark should behave exactly like Commonmark. You can see the complete list of differences [here][commonmark-delta]

[commonmark-delta]: differences-commonmark.md

- **HTML generation**  
Apodimark only provides an abstract syntax tree. Output generation is left as an exercise to the user.




