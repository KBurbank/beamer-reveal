# Beamer to Reveal.js

A standalone Quarto extension for using Beamer-style presentation syntax in Reveal.js presentations.

## Features

Directly converts Beamer LaTeX commands to Reveal.js HTML fragments:

- **`\pause`** → Creates fragment pauses (`. . .`)
- **`\only<n>{content}`** → Fragment with current-visible class
- **`\onslide<n>{content}`** → Fragment with fade-in effect  
- **`\hid<n>{content}`** → Fragment with fade-out effect
- **Index ranges** → Use `<n->` for dash suffix (changes to fade-out behavior for `\only`)

## Installation

```bash
quarto add path/to/beamer-reveal
```

This is a **standalone extension** with no dependencies.

## Usage

Simply add the filter to your document:

```yaml
---
format: 
  revealjs:
    filters:
      - beamer-reveal
---

## My Slide

First content appears

\pause

Second content after pause

This is \only<1>{only visible on fragment 1} cool!

This will \onslide<2>{fade in on fragment 2}.
```

## How It Works

The filter runs **before** LaTeX processing and directly converts Beamer commands:

1. Detects raw LaTeX blocks/inlines containing Beamer commands
2. Parses the command syntax (e.g., `\only<1>{content}`)
3. Converts directly to raw HTML with appropriate Reveal.js fragment classes:
   - `\pause` → `<p>. . .</p>` 
   - `\only<n>{text}` → `<span class="fragment current-visible" data-fragment-index="n">text</span>`
   - `\onslide<n>{text}` → `<span class="fragment" data-fragment-index="n">text</span>`
   - `\hid<n>{text}` → `<span class="fragment fade-out" data-fragment-index="n">text</span>`

## Architecture

This extension is completely independent of LaTeX macro expansion. It directly processes raw LaTeX syntax, making it:
- **Fast**: No macro expansion overhead
- **Predictable**: Direct one-to-one conversion
- **Standalone**: No external dependencies
- **Compatible**: Works alongside other LaTeX processing if needed

## Use with Other LaTeX

If you need to process other LaTeX commands (beyond Beamer fragments), you can combine this with the `latex-macros` extension:

```yaml
---
format: 
  revealjs:
    filters:
      - beamer-reveal  # Runs FIRST to handle Beamer
      - latex-macros   # Then handles other LaTeX
---
```

