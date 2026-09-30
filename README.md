# <p align="left"><img src="logo.png" width="80" height="80" alt="Caelestia Notes logo" /></p> Caelestia Notes

> A fast, elegant, local-first Notes and To-Do plugin engineered natively in **QtQuick & QML** for the **Caelestia Desktop Shell** on Linux.

[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Wayland-blue.svg)](https://github.com/Denzils-repo/Caelestia_Notes)
[![Framework](https://img.shields.io/badge/framework-Quickshell%20%2F%20QtQuick-41cd52.svg)](https://outfoxxed.me/quickshell/)
[![Design](https://img.shields.io/badge/UI-Material%20Design%203-6750A4.svg)](https://m3.material.io/)
[![Storage](https://img.shields.io/badge/storage-100%25%20Local%20JSON-orange.svg)](#architecture--storage)

---

## 📖 Overview

**Caelestia Notes** integrates a comprehensive, distraction-free productivity tab directly into your Caelestia Shell dashboard. Built entirely with native QML components and powered by a dedicated reactive state store, it combines:
- **A Pinnable, Color-Coded Markdown Notebook** with single-pass hardware-accelerated rendering and zero typing lag.
- **An Intelligent To-Do & Daily Habit Tracker** with due-date scheduling, animated clover date picking, midnight habit rollover, and split trash management.
- **Deep Material 3 Theming** dynamically harmonized with your Caelestia system colors in dark and light modes.

Everything runs 100% offline with zero cloud telemetry, storing your notes and checklists locally on disk.

---

## ✨ Features

### 📝 Notes & Markdown Notebook
- **Zero-Lag Markdown Editor**: Text editing runs independently of the parser. Markdown preview renders lazily on demand, guaranteeing butter-smooth typing even on extensive documents.
- **Hardware-Accelerated AST-Free Parser**: Single-pass line engine (`MarkdownNoteView.qml`) translates markdown headings, bold, italics, inline code, fenced code blocks, dividers, blockquotes, and links into native QtQuick primitives.
- **Expressive M3 Morphing Bullets**: Unordered lists render with rotating Material 3 algorithmic shapes (*Cookie*, *SoftBurst*, *Sunny*, *Diamond*, *Gem*) that morph deterministically with list depth.
- **Color Coding & Tinting**: Color-code individual cards with 7 expressive Material 3 tonal profiles (*Slate, Cyan, Cream, Teal, Peach, Mauve, Mint*).
- **Pinning & Organization**: Pin critical notes to the top of the board; toggle between responsive masonry card grid and compact list layouts.
- **Instant Search & Category Filtering**: Filter cards in real time across titles, bodies, and tags.

### 📅 Smart To-Dos & Habit Tracking
- **Due Date Engine**: Assign tasks to *Today*, *Tomorrow*, or pick any custom calendar date.
- **Interactive Calendar Picker**: Custom date picker featuring an animated, slowly rotating 4-leaf clover indicator in tertiary accent color. The picker stays open while selecting to allow fluid date toggling.
- **Repeating Daily Habits**: Mark recurring daily goals (reading, workouts, habits). Once completed, habits automatically reset at midnight for the next day while tracking completion history.
- **Dual / Split Trash Bin**: Completed recurring habits and discarded tasks are separated into dedicated pools. Restore accidental deletions or purge history with one click.
- **Sorting Modes**: Toggle instantly between chronological creation order and intelligent due-date bucket prioritization (*Overdue → Today → Tomorrow → Upcoming*).

---

## 🏗️ Architecture & Storage

All data is managed locally and reactively through single-store architecture:

```
~/.config/caelestia/notes.json   <─── (Atomic JSON disk read/write)
              │
              ▼
    services/NotesStore.qml      <─── (Reactive state, rollover & sort logic)
              │
     ┌────────┴────────┐
     ▼                 ▼
NotesPanel.qml    TodoPanel.qml  <─── (UI presentation in NotesTab.qml)
```

- **Persistence File**: `~/.config/caelestia/notes.json`
- **Fallback Template**: `config/notes.default.json` (bundled in this repository)
- **Zero Lock-in**: Raw JSON format makes it trivial to back up, script, or sync via Git / Syncthing.

---

## 📂 Repository Structure

```text
Caelestia_Notes/
├── Caelestia Notes.png          # High-resolution brand emblem
├── logo.png                     # Square logo asset for docs and web
├── index.html                   # Interactive showcase webpage (GitHub Pages)
├── README.md                    # Project documentation
├── guide.md                     # Complete Markdown syntax & engine guide
│
├── config/
│   └── notes.default.json       # Default starter notes and sample tasks
│
├── services/
│   └── NotesStore.qml           # Global reactive singleton store & persistence
│
└── modules/
    └── dashboard/
        ├── NotesTab.qml         # Main dashboard tab container
        └── notes/
            ├── NotesPanel.qml       # Notes board, search & filter toolbar
            ├── NoteCardItem.qml     # Interactive note card component
            ├── NoteStackCard.qml    # Visual stack representation
            ├── NoteDetailView.qml   # Full-screen note viewer & editor sheet
            ├── MarkdownNoteView.qml # Native single-pass Markdown renderer
            ├── TodoPanel.qml        # To-Do list, quick adder & trash drawer
            ├── TodoDetailView.qml   # Task inspector & repeat scheduler
            └── TodoDatePicker.qml   # Calendar popup with animated clover
```

---

## 🚀 Installation & Shell Integration

### Step 1: Copy Plugin Files
Clone or copy this repository into your local Caelestia Shell configuration:

```bash
# 1. Copy the background service
cp services/NotesStore.qml ~/.config/quickshell/caelestia/services/

# 2. Copy the dashboard module and components
mkdir -p ~/.config/quickshell/caelestia/modules/dashboard/notes
cp modules/dashboard/NotesTab.qml ~/.config/quickshell/caelestia/modules/dashboard/
cp modules/dashboard/notes/*.qml ~/.config/quickshell/caelestia/modules/dashboard/notes/

# 3. Ensure default config exists
mkdir -p ~/.config/caelestia
cp -n config/notes.default.json ~/.config/caelestia/notes.json
```

### Step 2: Register in Dashboard
In `~/.config/quickshell/caelestia/modules/dashboard/Dashboard.qml` (or your tab registry), add the Notes tab:

```qml
import "./notes"

// In your tab models or switcher:
TabButton {
    text: qsTr("Notes")
    icon.name: "edit-note-symbolic"
}
```

Reload Quickshell to activate:
```bash
qsctl reload || killall quickshell && quickshell &
```

---

## 🌐 Web Showcase

This repository includes a standalone interactive showcase page (`index.html`) demonstrating the live Notes tab, Material 3 theme switching, animated to-do list, and color palettes directly in any modern browser.

To preview locally:
```bash
python3 -m http.server 8080
# Open http://localhost:8080 in your browser
```

---

## ⌨️ Keyboard Shortcuts & Quick Tips

| Action | Shortcut / Gesture |
| :--- | :--- |
| **New Task** | Press `+` button or hit `Enter` inside the input bar |
| **Pick Due Date** | Click chip (*Today / Tomorrow*) or click calendar icon |
| **New Note** | Click `+ Note` or click empty card slot |
| **Edit Note** | Click any note card to open editor sheet |
| **Toggle Markdown** | Press `Edit` / `Preview` button |
| **Pin / Unpin** | Click pin icon on top-right of note card |
| **Close Editor** | Click outside the sheet or press `Escape` |
| **Empty Trash** | Open Trash drawer → click `Empty Trash` |

---

## 📄 License

Open-source and distributed under the **GPL-3.0 License** in alignment with the Caelestia ecosystem.
