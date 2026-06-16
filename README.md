# Clip 📋
Confesso que vibecodei esse aqui com claude hehe

A keyboard-driven script manager for Windows. Store, search, and paste text snippets instantly.

## Requirements

- Windows 10 or 11
- [AutoHotkey v2](https://www.autohotkey.com/) installed

## How to run

1. Clone the repository or download `scripts.ahk`
2. Double-click `scripts.ahk` to run

The script will start silently in the background (check the system tray).

## Usage

Press `Alt + Space` to open the search bar, then type:

| Command | Action |
|---|---|
| `script name` + Enter | Copies the script content to clipboard |
| `view <name>` | Opens a window to preview the script |
| `all` | Lists all saved scripts |
| `create` | Opens the editor to create a new script |
| `update <name>` | Opens the editor to update a script |
| `delete <name>` | Deletes a script permanently |

### Tips
- Press `Esc` to close any window
- Use `↑` / `↓` arrow keys to navigate search history
- If a script has a **trigger** configured (e.g. `@@`), typing it anywhere + `Enter` or `Tab` will automatically expand it

## Auto-start with Windows

To run Clip automatically on startup:

1. Press `Win + R`, type `shell:startup` and hit Enter
2. Create a shortcut to `scripts.ahk` in that folder

## Data

Scripts are saved locally in `scripts.json`.
Search history is saved in `history.json`.
Both files are ignored by git.