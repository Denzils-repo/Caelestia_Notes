# Caelestia Notes — Lightweight Markdown Engine Guide

> A fast, elegant, AST-free Markdown parser and renderer engineered natively in QtQuick & QML for the Caelestia Desktop Shell.

---

## 📖 Overview

The **Caelestia Notes Markdown Engine** (`MarkdownNoteView.qml`) translates plain-text Markdown into native, hardware-accelerated Material Design 3 UI components. Unlike heavy browser-based webviews or bulky AST parsers, it executes an ultra-fast, single-pass line parser that generates lightweight QML items with zero layout thrash and zero memory overhead.

---

## 🚀 Quick Reference Cheat Sheet

| Element | Markdown Syntax | Visual Output in Caelestia |
| :--- | :--- | :--- |
| **Heading 1** | `# Title` | Large headline, bold M3 typography (`Tokens.font.headline.small`) |
| **Heading 2** | `## Subtitle` | Section title (`Tokens.font.title.large`) |
| **Heading 3** | `### Section` | Subtitle in secondary variant color (`Tokens.font.title.medium`) |
| **Horizontal Divider** | `---` or `***` | Subtle 1px divider with vertical padding |
| **Bullet List** | `- Item` or `* Item` or `+ Item` | Material 3 Morphing Shape bullet (Cookie, Sunny, Slanted, Diamond) |
| **Numbered List** | `1. Step` or `1) Step` | Tonal pill badge displaying step number in accent color |
| **Blockquote** | `> Important note` | Rounded tinted card with a 3px accent bar and italicized text |
| **Code Block** | ```` ``` ````<br>`code`<br>```` ``` ```` | Monospace block in surface container with 1px border |
| **Inline Code** | `` `console.log()` `` | Monospace font inline |
| **Bold** | `**Bold text**` | Material 3 medium weight bold |
| **Italic** | `*Italic text*` | Expressive italic slant |
| **Strikethrough** | `~~Deleted text~~` | Native strike line through text |
| **Hyperlinks** | `[Label](https://...)` | Accent-tinted link opening default browser via `Qt.openUrlExternally` |

---

## 🎨 Material Design 3 Morphing Bullets

One of the unique signature features of Caelestia Notes is **dynamic M3 shape bullets**:
- When you create an unordered list (`- `, `* `, `+ `), Caelestia does not render a boring round black dot.
- Instead, each list item receives an expressive Material 3 Shape from the shape pool:
  - `Cookie4Sided`, `Cookie6Sided`, `Cookie9Sided`, `Cookie12Sided`
  - `SoftBurst`, `Sunny`, `VerySunny`
  - `Pentagon`, `Gem`, `Arch`, `Fan`, `Oval`, `Ghostish`, `Slanted`, `Triangle`, `Diamond`, `ClamShell`
- **Deterministic Hashing:** If no custom shape is chosen, each item's key is hashed deterministically. This guarantees that your shapes remain consistent every time you open the note!
- **Accent Theming:** Bullets automatically adopt your note's custom accent color.

---

## 💡 Syntax Examples

### 1. Headings & Separators
```markdown
# Project Antigravity
---
## System Architecture
### Hardware & Performance
```

### 2. Lists & Steps
```markdown
# Daily Goals
- Optimize QtQuick render thread
- Test To-do list action hover
* Verify Caelestia Shell IPC

# Setup Steps
1. Clone the repository
2. Run `caelestia shell -d`
3. Enjoy your desktop workspace
```

### 3. Quotes & Callouts
```markdown
> "Simplicity is the prerequisite for reliability."
> — Edsger W. Dijkstra
```

### 4. Code Blocks
````markdown
```
function toggleTodo(id) {
    NotesStore.toggleTodo(id);
}
```
````

### 5. Links & Inline Styles
```markdown
Check out the **[Caelestia Dotfiles](https://github.com/caelestia-dots)** repository for *new releases*!
```

---

## ⚡ Interaction & Shortcuts

| Action | How to Trigger |
| :--- | :--- |
| **Edit Note** | **Double-click** anywhere on the rendered markdown preview or empty space |
| **Save & Return** | Press <kbd>Esc</kbd> or click the back arrow in the top toolbar |
| **Open Links** | Single-click any Markdown hyperlink (`Qt.openUrlExternally`) |
| **Change Color** | Use the color palette pills in the editor header |
| **Change Bullets** | Tap the shape selector in the header to customize list item shapes |
| **Pin / Unpin** | Click the pin icon in the note toolbar or on the card |

---

## 🛠️ Architecture: How It Works Internally

1. **Parser (`parseMarkdown(text, savedShapes)`):**
   - Line-by-line single pass.
   - Detects block boundaries (fenced code blocks, headings, dividers, quotes, lists).
   - Generates a flat array of block descriptor objects:
     `{ type: "h1"|"h2"|"h3"|"quote"|"code"|"ordered_item"|"unordered_item"|"hr"|"spacer"|"p", content: string, key: string, shape?: int, number?: string }`
2. **Renderer (`Repeater` + `StyledText`):**
   - Renders each block using native QML `StyledText` components.
   - Uses Qt's built-in `Text.MarkdownText` formatting engine for inline bold, italic, links, and code, eliminating expensive HTML parsing.
   - Binds `linkColor` to the note's active accent color.
3. **Zero Resource Overhead:**
   - Does not use WebEngine, Chromium, or QWebEngineView.
   - Memory footprint is strictly under **200 KB** for a typical note.
