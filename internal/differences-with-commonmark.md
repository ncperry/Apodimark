## Differences with Commonmark 0.24

The spec for Commonmark 0.24 is [here](http://spec.commonmark.org/0.24/).

Note: Fenced Code Blocks are called “Fence” in the Apodimark documentation. “Links” and “Images” are called, respectively, “References” and “Unwrapped References”.

These differences are caused by:
- bugs
- yet unimplemented features
- design

1. Setext Headers are not supported (section 4.3)
1. HTML blocks are not supported (section 4.6)
1. Reference definitions must not span multiple lines
1. Reference definitions do not impose any constraint on their destination and do not parse the destination text
1. Only four spaces are needed after the “>” in a quote to produce a code block (example 209)
1. Lists do not have a “tightness” attribute
1. The characters in the name of a fence cannot be escaped (example 294)
1. Entity references are not supported (section 6.2)
1. Unicode no-break spaces do not count as whitespace (example 325)
1. Reference destinations may not contain matching parentheses (example 460)
1. References may contain other references (example 481)
1. Whitespace is not stripped inside reference titles
1. Autolinks are not supported (section 6.7)
1. Raw HTML is not supported (section 6.8)
1. Multi-line monospaced text is terribly handled (example 601)
