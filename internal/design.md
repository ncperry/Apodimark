# Design of Apodimark

## Abstract Syntax Tree (AST)

The abstract syntax tree describes the markdown document. It contains **Block Nodes** and **Inline Nodes**.

Block Nodes can be: 
- Paragraph
- List
- Quote
- Block Code
- etc.

Inlines Nodes can be:
- Text
- Emphasis
- Monospaced Text
- etc.

Block Nodes are created and added to the AST during the **Block Parsing** phase.
Inline Nodes are created and added to the AST during the **Inline Parsing** phase.

### Example AST

```text
This is an example of a *string that will be ___parsed___ to a `Markdown` AST*.
- > It contains some nested blocks
  > # Like this header inside a quote inside a list
- ``` swift
  // Hello
  ``` 
```

```text
- Paragraph
  - Text
  - Emphasis(1)
    - Text
    - Emphasis(3)
      - Text
    - Monospaced Text
    - Text
  - Text
- List
  - Item
    - Quote
      - Paragraph
        - Text
      - Header
        - Text
  - Item
    - Fence(swift)
``` 

## Block Parsing

This phase is done in two steps:

1. Parse a line into a `Line` structure
2. Add the Line to the AST

### Creating the Line structure

This line:
```text
   Some plain text
```
will be parsed into this `Line` structure:
```text
{
    indent: 3
    kind: Text
}
```
and this line:
```text
>	>  Quote in quote
```
will be parsed into:
```text
{
    indent: 0
    kind: Quote {
        indent: 4
        kind: Quote {
            indent: 2
            kind: Text
        } 
    }
}
```

### Adding a Line to the AST

One Line structure might not always result in the same node.

For example, here:
```text
> hello

> world
```
The third line will be inserted into the AST as a new Quote node

But here:
```text
> hello
> world
```
The second line will be inserted into the previous, existing Quote node

The logic for how to create the block abstract syntax tree is located in `BlockParsing.swift`.

## Inline Parsing

Inline Parsing is done in three steps:

1. Read every character inside the node and add those who may carry a special meaning to the *delimiter array*
1. Create a *list of InlineNode* from the delimiter array
1. Build an AST from the list

### Creating the delimiter array

This paragraph:
```text
This is a **strong emphasis containing a *nested emphasis* and some text**. \
   And here is a second line with a [fake reference].
``` 
contains these delimiters:
```text
[emph(2, opening), emph(1, opening), emph(1, closing), emph(2, closing), refOpener, refCloser]
```

A delimiter also contain its index in the original view, but these have been omitted for clarity.  

### Creating the list of Inline Nodes

Building on the previous example:
```text
[emph(2, opening), emph(1, opening), emph(1, closing), emph(2, closing), refOpener, refCloser]
```
will create this list of Inline Nodes:
```text
[Emphasis(2), Emphasis(1)]
```

- this is still an array, not a tree
- an Inline Node contain its indices in the original view. They were omitted here for clarity. However, these indices will be critical later to build the AST
- no Reference Node was created, because it was an invalid reference (it didn't have any matching definition)

### Building the Inline AST

From the nodes in the previous example (now with their indices):

```text
This is a **strong emphasis containing a *nested emphasis* and some text**. \
   And here is a second line with a [fake reference].

[Emphasis(2, 10...77), Emphasis(1, 46...65)]
```

We create a tree in two steps:

1. Create a tree with the non-text nodes using the node indices
   ```text
   - emphasis(2, 10...77)
     - emphasis(1, 46...65)
   ```

2. Add the “text” nodes around the non-text nodes 
   ```text
   - text(0...9)
   - emphasis(2, 10...77)
     - text(12...45)
     - emphasis(1, 46...65)
       - text(47...64)
     - text(66...75)
   - text(78...79)
   - hardbreak(80...80)
   - text(84...138)
   ```

The logic for how to create the inline abstract syntax tree is located in `InlineAST.swift`.

### Creating the final, public AST

In practice, the internal Inline and Block AST do not have the desired structure for 
the public API.

The steps to create the final AST are:
1. create the Block AST only
2. transform the Block AST into an array of `MarkdownBlock`  

It is at the second step that the Inline AST is created and immediately transformed into
an array of `MarkdownInline`. 
