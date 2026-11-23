# Thoughts

Thoughts is a Mac menu bar app with no Dock icon, for keeping text and screenshots from any app. Press a key, or choose Show Thoughts from the menu bar icon, to open the panel, type a thought or save what you have selected, and search it all later. Each thought is a Markdown file in a folder you choose, so you can open, sync and back it up like any other file.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/images/panel-dark.png">
  <img src=".github/images/panel-light.png" alt="The Thoughts panel with a todo, a note and a screenshot" width="360">
</picture>

## Install

Thoughts needs macOS 15.4 or later.

Install it with Homebrew:

```sh
brew install --cask hlakarki/tap/thoughts
```

The cask also puts the `thoughts` command line tool on your `PATH`.

You can also download `Thoughts-<version>.zip` from the [releases page](https://github.com/HlaKarki/thoughts/releases), unzip it and move Thoughts.app to your Applications folder. The command line tool is inside the app. To run it from a shell, link it into a folder on your `PATH`:

```sh
sudo ln -s /Applications/Thoughts.app/Contents/Helpers/thoughts /usr/local/bin/thoughts
```

Thoughts checks for updates once a day. When one is ready, "Update available" appears in the ⋯ menu and in the menu bar icon's menu, and the icon shows a dot. You can also choose "Check for updates…" in either menu. The update check is the only network request Thoughts makes.

## First run

The first time Thoughts opens, it walks you through five steps.

1. **Pick a key to open Thoughts.** The default is ⌥Space. Press it in any app to show or hide the panel. You can also choose Show Thoughts from the Thoughts icon in the menu bar.
2. **Pick how to save from any app.** Press Shift twice, or record your own shortcut. It saves the selected text, or a copied image, as a thought. JetBrains IDEs use double Shift for Search Everywhere, so pick a shortcut if you work in one.
3. **Allow one permission.** Thoughts asks for Accessibility so the capture works in other apps. It reads the text you select and the title of the window you're in, so each thought records where it came from. Turn on Thoughts in System Settings, then come back.
4. **Choose where thoughts are saved.** The default is `~/Thoughts`. Thoughts makes the folder if it isn't there. A folder inside iCloud Drive or Dropbox syncs to your other Macs.
5. **Saving copied images.** When you copy an image, a small offer appears at the edge of the screen. Click it, or press your capture key, to keep it. Thoughts also offers new images saved in your screenshot folder, which is the Desktop unless you changed it. That is why macOS may ask for access to that folder at this step.

The first time you keep a copied image, macOS asks if Thoughts can paste from other apps. Choose Always Allow and the offer shows a preview of the image. You can change this later in Settings.

Thoughts never asks for Input Monitoring.

## Menu bar icon

The menu bar icon is on by default. Its menu has Show Thoughts, Settings…, Check for updates… and Quit Thoughts. To remove it, turn off "Show Thoughts in the menu bar" in Settings or Command-drag it out of the menu bar. The summon key, or opening Thoughts again from Applications, still shows the panel.

## Keys

Anywhere:

| Key | What it does |
| --- | --- |
| ⌥Space | Show or hide the panel. Change it in Settings. |
| Shift twice, or your shortcut | Save the selected text, or a copied image, as a thought. |

In the panel:

| Key | What it does |
| --- | --- |
| Return | Add what you typed as a thought. |
| ↑ | Select the newest thought, when the field is empty. |
| ⌘F | Search thoughts. Esc clears the search. |
| Esc | Hide the panel, or remove an attached image first. |

With a thought selected:

| Key | What it does |
| --- | --- |
| ↑ ↓ | Move the selection. Hold Shift to select more than one. |
| Return | Edit the text. Return saves and Esc cancels. |
| ⌘Return | Mark done, or mark not done. |
| Space | Preview the thought. |
| ⌘C | Copy. |
| ⇧⌘C | Copy the file path. |
| ⌘O | Open the original: the page or app it came from. |
| ⌘R | Show in Finder. |
| ⌘⌫ | Delete. The file goes to the Trash. |
| ⌘K | Show every action for the selection. |
| Esc | Go back to the text field. |

You can also drop text, images or files on the panel. Images and text are saved as they are, and any other file is saved as its path. In other apps, choose "Add to Thoughts" in the Share menu.

## Your files

Thoughts saves to `~/Thoughts` unless you picked another folder. To move it, open Settings from the ⋯ menu or the menu bar icon and change the storage folder. Thoughts moves the files and leaves a link at the old path.

Each thought is one Markdown file named after the time it was saved and its ID. A screenshot is a PNG with the same name, next to its Markdown file. A thought saved from a web page looks like this:

`20261122-181403-ke6s0pcg.md`

```markdown
---
id: ke6s0pcg
created: 2026-11-22T18:14:03.120-05:00
done: null
cleared: false
source:
  app: Safari
  bundle: com.apple.Safari
  window: Keyboard navigation guide
  url: https://example.com/guide
  title: Keyboard navigation guide
---
Read the section on keyboard navigation again
```

`done` holds the time you marked the thought done. `cleared` turns true when "Clear done" in the ⋯ menu hides it from the panel. A screenshot thought adds `image:` with the PNG's file name, and its note is the body.

You can edit the files in any editor, and the panel picks up the change. Thoughts keeps any front matter keys it doesn't know. The search index in `~/Library/Application Support/Thoughts` is a cache that Thoughts rebuilds from the files.

## Command line and MCP

The `thoughts` tool reads and writes the same folder as the app.

| Command | What it does |
| --- | --- |
| `thoughts list` | List thoughts, open ones by default. Add `--done` or `--all` to see more. |
| `thoughts add <text>` | Add a thought from text. `--image <file>` adds a screenshot thought, with `--note <text>`. With no text, it reads text piped to it. |
| `thoughts show <id>` | Show one thought. |
| `thoughts path <id>` | Print the file path of a thought, or of its image. |
| `thoughts done <id>` | Mark a thought done. `--undo` opens it again. |
| `thoughts search <words>` | Search thoughts, including text in screenshots. |
| `thoughts mcp` | Serve thoughts over MCP on standard input and output. |

An ID can be the first 4 or more characters of one. Add `--json` to `list`, `add`, `show`, `done` or `search` for JSON output. Set `THOUGHTS_DIR` to use another folder.

`thoughts mcp` gives an MCP client six tools: `list_thoughts`, `add_thought`, `show_thought`, `thought_path`, `mark_done` and `search_thoughts`. Thoughts added through MCP record the client's name as their source. To add it to an MCP client that reads an `mcpServers` config:

```json
{
  "mcpServers": {
    "thoughts": {
      "command": "/Applications/Thoughts.app/Contents/Helpers/thoughts",
      "args": ["mcp"]
    }
  }
}
```

## Building from source

You need Xcode 26.6 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
git clone https://github.com/HlaKarki/thoughts.git
cd thoughts
xcodegen generate
mkdir -p Thoughts.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp Config/Package.resolved Thoughts.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
xcodebuild -project Thoughts.xcodeproj -scheme Thoughts -configuration Debug build
```

Copying `Config/Package.resolved` pins the package versions the project was tested with. Without a team the app signs ad hoc. To sign with your own team, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM`.

A Debug build is named Thoughts Dev. It keeps its own folder, `~/Thoughts Dev`, and its own settings, so it never touches an installed copy of Thoughts.

## License

Thoughts is released under the [MIT License](LICENSE).
