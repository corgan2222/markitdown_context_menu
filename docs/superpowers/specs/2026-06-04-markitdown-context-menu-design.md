# MarkItDown Context Menu — Design

**Date:** 2026-06-04
**Status:** Approved (design), pending implementation plan

## Purpose

A Windows Explorer right-click integration for Microsoft's
[`markitdown`](https://github.com/microsoft/markitdown) tool. Right-clicking a
supported file, multiple files, or a folder offers a **"In Markdown umwandeln"**
submenu that converts the input to Markdown. Must be easy for other people to
install and use, and configurable as to which file types show the menu.

## Goals

- One-step, no-admin install that another person can run by double-clicking.
- Detect whether a supported Python version is installed; if missing or too old,
  offer to install Python.
- Detect whether `markitdown` is installed; if not, offer to install it.
- A checkbox GUI to choose which file types trigger the menu.
- Developed on Windows 10, compatible with Windows 11.

## Non-Goals (v1)

- Bundling Python / shipping a standalone `.exe` (Python is **assumed present**;
  `markitdown` is installed on demand).
- A native Windows 11 top-level context menu via a compiled COM handler. v1
  ships the classic registry menu (on Win11 it appears under "Weitere Optionen
  anzeigen"). The architecture leaves a clean seam to add an `IExplorerCommand`
  COM handler later (the **Hybrid** decision).

## Runtime / Dependency Strategy

- **Windows built-ins only for the tool itself.** Everything except `markitdown`
  uses PowerShell, WinForms, WinRT toasts, and the registry. No extra pip
  packages are required for the menu, GUI, toast, or batching.
- **Python checked, with version gate.** `markitdown` requires Python **>= 3.10**.
  On first conversion (and via a GUI button) the runtime guard:
  1. Looks for a usable `python` and reads its version.
  2. If Python is **missing or older than 3.10**, a dialog offers to install a
     current Python — preferring `winget install --id Python.Python.3.12`
     (per-user, no admin), falling back to opening the python.org download page
     if `winget` is unavailable.
- **markitdown on demand.** Once a supported Python is present, the guard checks
  for the `markitdown` module. If missing, a dialog asks to install it
  (`pip install markitdown[all]`). Result is cached.

## Windows 11 Compatibility (Hybrid)

- v1 uses **classic registry context-menu entries** under `HKCU` (per-user, no
  admin). On Windows 10 this is the normal right-click menu; on Windows 11 it
  appears under "Weitere Optionen anzeigen" / Shift+Right-click.
- The conversion logic, runtime guard, and toast notifier are pure, reusable
  functions. A future C#/.NET `IExplorerCommand` COM handler can call the same
  `Launcher.ps1`/modules to provide a native Win11 top-level entry **without
  rewriting the core**. This COM handler is explicitly out of scope for v1.

## Architecture

```
Explorer right-click
  → submenu entry (registry verb)
    → HiddenLaunch.vbs            (starts PowerShell with no console flash)
      → Launcher.ps1 <mode> <path>
        → Batch aggregator        (coalesces multi-select into one run)
          → Runtime guard         (ensure python + markitdown)
            → Converter           (file or folder → .md / clipboard / open)
              → Toast             (success / error summary)
```

### Components

| Component | Responsibility | Depends on |
|---|---|---|
| `src/HiddenLaunch.vbs` | Launch `Launcher.ps1` with a hidden window (no flicker) | wscript |
| `src/Launcher.ps1` | Parse `<mode> <path>` args; run aggregator → guard → converter → toast | all modules |
| `src/modules/Converter.psm1` | `Convert-Item -Path -Mode (save\|clip\|open)`; single file → `x.md` beside source; folder → recurse over configured extensions | markitdown CLI |
| `src/modules/Runtime.psm1` | `Test-Python` (version >= 3.10) / `Install-Python` (winget, fallback python.org); `Test-MarkItDown` / `Install-MarkItDown` (`pip install markitdown[all]`); caches result | python, winget, pip |
| `src/modules/Toast.psm1` | `Show-Toast -Title -Message [-Error]` via WinRT `Windows.UI.Notifications`; MessageBox fallback | WinRT |
| `src/modules/Registry.psm1` | Add/remove the cascading submenu per extension and for folders | registry |
| `src/modules/Config.psm1` | Read/write the active file-type selection (registry is source of truth); load type catalog from `config/filetypes.default.json` | Registry.psm1 |
| `src/Configure.ps1` | WinForms checkbox GUI; install/repair, uninstall, markitdown check/install buttons | Registry, Config, Runtime |

## Menu Structure

Two top-level context-menu entries are registered:

1. **In Markdown umwandeln** — a single direct action (no submenu). Default is
   **Speichern (.md)** beside the source. The action this entry triggers is
   **configurable in the GUI** (save | clip | open).
2. **In Markdown umwandeln (Optionen)** — a cascading submenu offering all
   actions explicitly:
   - **Speichern (.md)** — write `<name>.md` beside the source.
   - **In Zwischenablage** — put the Markdown on the clipboard.
   - **Speichern & öffnen** — write `.md` and open it in the default editor.

Both entries are registered for single files, multi-selection, and folders.

## Registry Layout (per-user, HKCU)

- Per file type, two parent verbs under
  `HKCU\Software\Classes\SystemFileAssociations\<.ext>\shell\`:
  - `MarkItDown` — direct action; its `command` invokes the configured default
    mode.
  - `MarkItDownOptions` — has `SubCommands` enabling child verbs
    `...\shell\MarkItDownOptions\shell\{01_save,02_clip,03_open}\command`.
  - Using `SystemFileAssociations\.<ext>` avoids touching per-type ProgIDs.
- Folders: the same two parent verbs under
  `HKCU\Software\Classes\Directory\shell\` (command receives the folder path;
  converter recurses over configured extensions).
- Each `command` invokes `wscript HiddenLaunch.vbs <mode> "%1"` (folders use the
  appropriate folder placeholder). The direct entry's `<mode>` is read from the
  saved default-action setting at registration time.

## Multi-Select / Batch

Classic registry verbs launch the handler **once per selected file**. To avoid N
windows / N toasts:

- A **named Mutex** guards a temp **queue file** in `%LOCALAPPDATA%\MarkItDownMenu`.
- Each launched instance appends its path. The instance that found the queue
  empty becomes the **owner**: it waits a short debounce window (~800 ms) for
  siblings to enqueue, then processes the whole queue, clears it, and shows a
  single summary toast. Non-owner instances append and exit immediately.
- This is COM-free and keeps batch UX to one notification.

## Configuration GUI (`Configure.ps1`)

- WinForms window (no extra packages). A scrollable checkbox list of common
  types from `config/filetypes.default.json` (pdf, docx, doc, xlsx, pptx, png,
  jpg/jpeg, html/htm, csv, json, xml, txt, epub, …) plus a field to add a custom
  extension.
- On load: checkbox state reflects what is currently registered (read via
  `Registry.psm1`).
- A **default-action selector** (radio/dropdown: Speichern | Zwischenablage |
  Speichern & öffnen) controls what the direct **"In Markdown umwandeln"** entry
  does. Default: Speichern.
- **Speichern**: diff selection against registry → add/remove keys accordingly,
  and re-register the direct entry's command with the chosen default action.
- Buttons: **markitdown prüfen / installieren** (calls Runtime guard),
  **Deinstallieren** (removes all keys + files).

## Configuration Data

- **Registry is the source of truth** for which extensions are enabled and for
  the direct entry's default action (encoded in the `MarkItDown` command line).
- `config/filetypes.default.json` is the catalog the GUI offers (friendly name +
  extension), shipped as defaults; it is read-only reference, not live state.
- Install directory: `%LOCALAPPDATA%\MarkItDownMenu` (files, queue, logs).

## Installation / Uninstallation

- `install.cmd` (double-click) → runs `install.ps1` with
  `-ExecutionPolicy Bypass`.
- `install.ps1`: copies `src/` + `config/` to `%LOCALAPPDATA%\MarkItDownMenu`,
  registers a default set of extensions, creates a Start-menu shortcut to the
  configuration GUI. No admin required.
- `uninstall.ps1`: removes all `MarkItDown` registry keys (all extensions +
  folders) and deletes the install directory + shortcut.

## Error Handling & Feedback

- All user feedback is via **toast** (success summary / error). Errors include:
  Python missing/too old (with install offer), markitdown missing (with install
  offer), per-file conversion
  failure (batch toast reports counts: "8/10 konvertiert, 2 Fehler").
- A rolling log file in the install dir captures details for troubleshooting.

## Testing

- **Pester** unit tests:
  - `Converter`: output path derivation; folder enumeration filtering by
    configured extensions; `markitdown` invocation mocked.
  - `Registry`: add → read → remove roundtrip in a throwaway HKCU subtree.
  - `Config`: catalog parsing; selection diff logic.
- Manual smoke test: install → right-click each selection type → verify submenu,
  conversion output, and toast on Windows 10 (and Win11 under "more options").

## Open Items / Future

- Optional Win11-native COM `IExplorerCommand` handler (reuses core logic).
- Optional `*` (all files) toggle in the GUI.
- Optional custom menu icon.
