# MarkItDown Context Menu

Right-click any supported file or folder in Windows Explorer to convert it to
Markdown with Microsoft's [`markitdown`](https://github.com/microsoft/markitdown).

## Install

1. Install PowerShell 7+ (`pwsh`) from https://aka.ms/powershell if you don't have it.
2. Double-click **`install.cmd`**.

That's it — no admin rights needed. On first conversion the tool checks for
Python 3.10+ and `markitdown`, and offers to install them if missing.

## Use

Right-click a file, several files, or a folder:

- **In Markdown umwandeln / Convert to Markdown** — runs the default action.
- **… (Optionen) / … (Options)** — choose: save `.md`, copy to clipboard, or save & open.

On Windows 11 the entries appear under **"Show more options"** (Shift+Right-click).

## Configure

Open **"MarkItDown Context Menu"** from the Start menu to pick which file types
show the menu, set the direct-entry action, and choose the language
(Auto / Deutsch / English).

## Uninstall

Run `uninstall.ps1`, or use the **Uninstall** button in the settings window.
