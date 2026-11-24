# Changelog

This file lists what changes in each version of Thoughts. A minor version, like 1.1, adds features. A patch version, like 1.0.1, only fixes bugs.

## 1.0.0

The first release. Thoughts needs macOS 15.4 or later.

### Added

- A panel at the edge of the screen. Press ⌥Space in any app, or choose Show Thoughts from the menu bar icon, to show it.
- Press Shift twice in any app to save the selected text, or what you copied in the last 2 minutes, as a thought. You can record your own shortcut instead.
- When you copy an image or save a screenshot, an offer appears at the edge of the screen. Click it, or press your capture key, to keep the image.
- Type a thought and press Return, paste an image with ⌘V, or drop text, images and files on the panel.
- Search with ⌘F, including the text inside screenshots.
- Copy, mark done, delete, preview, open the original and show in Finder, with a key or from the ⌘K menu. Copy, mark done and delete work on many thoughts at once.
- ⌘Z undoes a delete, Clear done, marking done and a saved edit.
- Each thought is a Markdown file in a folder you choose. Edit a file in any editor and the panel shows the change.
- The `thoughts` command line tool and an MCP server read and write the same folder.
- "Add to Thoughts" in the Share menu of other apps.
- Thoughts checks for updates once a day. Install it with Homebrew or from the releases page.
