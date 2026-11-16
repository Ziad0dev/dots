#set document(title: "Untitled", author: "ziad0dev")
#set page(paper: "a4", margin: 2.4cm, numbering: "1")
#set text(font: "New Computer Modern", size: 11pt, lang: "en")
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")

#show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
#show link: set text(fill: rgb("#33b1ff"))

= Introduction

Replace this. Everything above the first heading is the document preamble;
`typst compile main.typ` and `nix build` both produce the same PDF from it.

== Maths

Inline maths like $e^(i pi) + 1 = 0$ sits in the text, and a block form gets
its own line:

$ integral_0^infinity e^(-x^2) dif x = sqrt(pi) / 2 $

== Code

```rust
fn main() {
    println!("hello");
}
```

== References

Bibliography works by dropping a `refs.bib` alongside this file and
uncommenting the line below.

// #bibliography("refs.bib", style: "ieee")
