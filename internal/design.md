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

```
This is an example of a *string that will be ___parsed___ to a `Markdown` AST*.
- > It contains some nested blocks
  > # Like this header inside a quote inside a list
- ``` swift
  // Hello
  ``` 
```

```
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
```
   Some plain text
```
will be parsed into this `Line` structure:
```
{
	indent: 3 [space, space, space]
	kind: Text
}
```
and this line:
```
>	>  Quote in quote
```
will be parsed into:
```
{
	indent: 0 []
	kind: Quote {
		indent: 4 [tab]
		kind: Quote {
			indent: 2 [space, space]
			kind: Text
		} 
	}
}
```

### Adding a Line to the AST

One Line structure might not always result in the same node.

For example, here:
```
> hello

> world
```
The third line will be inserted into the AST as a new Quote node

But here:
```
> hello
> world
```
The second line will be inserted into the existing Quote node


## Inline Parsing

Inline Parsing is done in three steps:

1. Read every character inside the node and add those who may carry a special meaning to the *delimiter array*
1. Create a *list of InlineNodes* from the delimiter array
1. Build an AST from the list

### Creating the delimiter array

This paragraph:
```
This is a **strong emphasis containing a *nested emphasis* and some text**. \
   And here is a second line with a [fake reference].
``` 
contains these delimiters:
```
[start, emph(2, opening), emph(1, opening), emph(1, closing), emph(2, closing), hardbreak, end, start, refOpener, refCloser, end]
```

- `start` indicates the start of some text
- `end` indicates the end of some text
- `hardbreak` was added because of the backslash at the end of the first line
- a delimiter also contain its index in the original view, but these have been omitted for clarity  

### Creating the list of Inline Nodes

Building on the previous example:
```
[start, emph(2, opening), emph(1, opening), emph(1, closing), emph(2, closing), hardbreak, end, start, refOpener, refCloser, end]
```
will create this list of Inline Nodes:
```
(Text, Emphasis(2), Emphasis(1), Hardbreak, Text)
```

- this is a list, not a tree
- an Inline Node contain its indices in the original view. They were omitted here for clarity. However, these indices will be critical later to build the AST
- no Reference Node was created, because it was an invalid reference (it didn't have any matching definition)

### Building the Inline AST

From the nodes in the previous example (now with their indices):

```
This is a **strong emphasis containing a *nested emphasis* and some text**. \
   And here is a second line with a [fake reference].

(Text(0...80), Emphasis(2, 10...77), Emphasis(1, 46...65), Hardbreak(80...80), Text(84...138))
```

We create a tree in two steps:

1. Create a tree with the non-text nodes using the node indices
   ```
   - emphasis(2, 10...77)
     - emphasis(1, 46...65)
   - hardbreak(80...80)
   ```

2. Add the text nodes
   ```
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
