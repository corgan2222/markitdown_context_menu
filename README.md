# MarkItDown Context Menu

Right-click any supported file or folder in Windows Explorer to convert it to
Markdown with Microsoft's [`markitdown`](https://github.com/microsoft/markitdown).

**MarkItDown** is Microsoft's open-source tool that turns documents — PDFs,
Office files, images, web pages, and more — into clean Markdown, ideal for
feeding content to LLMs or storing it as plain text. This project wires it into
the Explorer right-click menu so a conversion is one click away.

**Target OS:** Windows 10 and Windows 11.

## Features

- Convert a single file, a multi-file selection, or a whole folder (recursive).
- Three actions: save `.md` beside the source, copy Markdown to the clipboard,
  or save & open.
- One configurable direct entry plus an options submenu with all actions.
- Per-user install — no admin rights required.
- Checkbox GUI to pick which file types show the menu.
- Bilingual (German / English), auto-selecting the Windows system language.
- Toast notifications with a batch summary for multi-file runs.
- Checks for Python 3.10+ and `markitdown`, offering to install them if missing.

## Supported files

PDF · Word (`.doc`, `.docx`) · Excel (`.xlsx`) · PowerPoint (`.pptx`) ·
images (`.png`, `.jpg`, `.jpeg`) · HTML (`.html`, `.htm`) · `.csv` · `.json` ·
`.xml` · `.txt` · EPUB

Add other extensions yourself in the configuration GUI.

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
