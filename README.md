# Simple Texts

A minimal native macOS scratchpad for quickly pasting text and switching between notes.

- Sidebar tabs, with titles taken from each note's first nonempty line.
- Section headings to group notes.
- Pinned notes at the top, with their original position restored when unpinned.
- Drag to reorder notes and headings.
- A plain text editor without formatting controls.

Notes live only in memory and are discarded when you quit. Closing the window keeps
them available; click the Dock icon to reopen it. The app asks for confirmation
before quitting if any note contains text.

Requires macOS 14 or later. The interface is currently in Russian.

## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| New note | ⌘N |
| New heading | ⇧⌘N |
| Pin / unpin note | ⇧⌘P |
| Previous / next note | ⌥⌘↑ / ⌥⌘↓ |
| Delete note | ⌥⌘⌫, or Delete in the sidebar |
| Rename heading | Double-click the heading |

## Build

Built with Swift and SwiftUI. Requires Xcode and XcodeGen.

```sh
./scripts/build.sh
```

Creates `Simple Texts.app` in the project root.

Run the tests:

```sh
./scripts/test.sh
```
