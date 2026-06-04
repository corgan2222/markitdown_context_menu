# Handover — MarkItDown Context Menu

Quick context for resuming development later.

## What it is

Per-user (no-admin) Windows 10/11 Explorer context-menu tool that converts files
and folders to Markdown via Microsoft's [`markitdown`](https://github.com/microsoft/markitdown).
Installs to `%LOCALAPPDATA%\MarkItDownMenu`. PowerShell 7 (`pwsh`) throughout.

Repo: https://github.com/corgan2222/markitdown_context_menu

## Layout

```
install.ps1 / install.cmd   Installer: copies files, registers menu, Start-menu shortcut, bundles VERSION
uninstall.ps1               Removes registry entries + install dir
VERSION                     Plain-text tool version, kept in sync with latest GitHub release tag
src/
  Configure.ps1             Settings GUI (WinForms). Single-instance mutex. Version display + update check.
  Launcher.ps1              Entry point invoked by menu verbs (save/clip/open modes)
  HiddenLaunch.vbs          wscript shim -> runs Launcher.ps1 hidden (no console flash)
  HiddenConfigure.vbs       wscript shim -> runs Configure.ps1 hidden
  modules/
    Paths.psm1              Install dir + settings/queue/log paths
    Config.psm1             settings.json read/write, filetype catalog, selection diff
    I18n.psm1               Language resolve/import, Get-String
    Registry.psm1           Register/unregister menu verbs under HKCU SystemFileAssociations + Directory
    Runtime.psm1            Python/markitdown detection + install/upgrade; version helpers (see below)
    Converter.psm1          Runs markitdown on a file
    Batch.psm1              Multi-file/folder batching + summary
    Toast.psm1              Toast notifications
    Icons.psm1              Light/dark icon set selection
config/filetypes.default.json   Default supported extensions catalog
lang/{de,en}.json               Bilingual string tables (keys like gui.*, menu.*, toast.*)
images/                         Menu icons (light/dark)
doc/                            README screenshots (NOT gitignored; `docs/` IS ignored)
tests/                          Pester tests + RunTests.ps1 (46 tests, all green)
.github/release-drafter.yml          release-drafter config
.github/workflows/release-drafter.yml  Drafts next release from merged PR labels
.github/workflows/sync-version.yml     On release publish: writes tag (minus v) into VERSION on main
```

## Versioning & releases

- **Source of truth at runtime:** the `VERSION` file (bundled at install, shown
  offline in the GUI under "Installed versions").
- **Release flow:** merge PRs to `main` → release-drafter updates a draft release
  (version from PR labels: `feature`/`enhancement`→minor, `fix`/`bug`/`chore`→patch,
  `major`→major). You publish the draft manually. On publish, `sync-version.yml`
  writes the tag into `VERSION` on `main`.
- **Update check in GUI:** "Check for updates" compares `VERSION` with the latest
  GitHub release (`Get-LatestToolVersion`) and PyPI for markitdown. If the tool is
  behind, a download button opens `.../releases/latest`.
- Relevant helpers in `Runtime.psm1`: `Get-ToolVersion`, `Get-LatestToolVersion`,
  `Get-LatestMarkItDownVersion`, `Test-UpdateAvailable`, `Update-MarkItDown`.

## Conventions / rules

- **Always use PRs** — never commit or push directly to `main`. Branch → PR → merge.
- **No `Co-Authored-By`** trailer in commits.
- Tests must **never** touch the real `HKCU:\Software\Classes`; they use a test
  registry root (param `-ClassesRoot`).
- Commit style: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).
- Line endings: repo is LF; Windows checkout warns about CRLF — harmless.

## Dev workflow

```powershell
# Run the full test suite
pwsh -NoProfile -File tests/RunTests.ps1

# Parse-check a script
pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('src/Configure.ps1',[ref]$null,[ref]([ref]$e).Value)"

# Reinstall locally to test changes (settings.json is preserved)
pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

After editing `Configure.ps1` or any module, reinstall so the copy under
`%LOCALAPPDATA%\MarkItDownMenu` is updated, then reopen the settings window.

## Current state (v0.1.x)

- Core conversion, multi-file/folder batching, toasts: done.
- Settings GUI: filetype checkboxes, custom extension add, default action,
  language (auto/de/en), runtime check/install, version display, update check
  with download button, single-instance guard for multi-file selection.
- v0.1.1 published; v0.1.2 draft prepared.

## Ideas / possible next steps

- Combined "Update" command (uninstall→install) that backs up/restores
  `settings.json` for a clean upgrade without leaving stale files.
- Auto-update from within the GUI (download + run installer), not just a link.
- Stale-file cleanup on reinstall (remove files deleted in newer versions).
- More output options (e.g. choose target folder, filename template).
- CI: run Pester tests on PRs via GitHub Actions.
- Re-apply menu labels/icons for user-added custom extensions on reinstall.
