# AGENTS.md

Instructions for coding agents working in this repository.

## What this is

A per-user Windows 10/11 Explorer context menu that converts files and folders
to Markdown with [`markitdown`](https://github.com/microsoft/markitdown). No
admin rights. It installs to `%LOCALAPPDATA%\MarkItDownMenu` and runs on
PowerShell 7 (`pwsh`) throughout.

## Build and check

There is no build step. A change is ready when the suite is green:

```powershell
pwsh -NoProfile -File tests/RunTests.ps1                    # Pester 5, the PowerShell suite
python -m unittest discover -s tests -p "test_*.py"         # the DOCX comments helper; needs markitdown[docx] 0.1.8+
```

Parse-check a script without running it:

```powershell
pwsh -NoProfile -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('src/Configure.ps1',[ref]$null,[ref]$e) | Out-Null; $e"
```

Empty output means it parses.

The menu runs the installed copy, not the checkout. After editing anything
under `src/`, `config/`, `lang/` or `images/`, reinstall so the copy under
`%LOCALAPPDATA%\MarkItDownMenu` is current, then reopen the settings window:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

## Where things live

| Path | Content |
|---|---|
| `install.ps1`, `install.cmd`, `uninstall.ps1` | copy files, register or remove the menu, Start-menu shortcut |
| `src/Launcher.ps1` | entry point the menu verbs call (save, clipboard, open) |
| `src/Configure.ps1` | settings window (WinForms), single instance, update check |
| `src/ConvertDocxWithComments.py` | DOCX body plus comments through the markitdown Python API |
| `src/Hidden*.vbs` | `wscript` shims that start the two scripts without a console flash |
| `src/modules/Registry.psm1` | menu verbs under `HKCU` `SystemFileAssociations` and `Directory` |
| `src/modules/Runtime.psm1` | Python and markitdown detection, install, version helpers |
| `src/modules/Config.psm1` | `settings.json`, file type catalogue |
| `src/modules/*.psm1` | paths, i18n, conversion, batching, toasts, icons |
| `config/filetypes.default.json` | default extension catalogue |
| `lang/de.json`, `lang/en.json` | string tables; every key exists in both |
| `tests/` | Pester tests and `RunTests.ps1` |
| `doc/` | README screenshots (tracked; `docs/` is ignored) |

## Rules

**Tests never touch the real `HKCU:\Software\Classes`.** Every function in
`Registry.psm1` takes `-ClassesRoot`. A test passes a scratch root.

**Python output is read as UTF-8.** `Invoke-MarkItDownCli` sets
`PYTHONIOENCODING` and switches `[Console]::OutputEncoding` to UTF-8 around
the call. The hidden launcher runs with the OEM code page, so without that
umlauts and CJK text arrive broken.

**A new string goes into both language files.** `lang/de.json` and
`lang/en.json` carry the same keys.

**Versions come from releases.** `VERSION` holds the tool version and is
bundled at install. Release Drafter builds the next draft from the labels of
merged pull requests (`major`; `feature`/`enhancement` for minor;
`fix`/`bug`/`chore` for patch). Publishing the draft runs `sync-version.yml`,
which writes the tag into `VERSION` on `main`. Never edit `VERSION` by hand.

## Git

- Every change goes through a pull request. Never commit to `main` directly.
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `test:`.
- The repository is LF. The CRLF warning on a Windows checkout is harmless.

## When you find a trap

Stop at the first rung that holds:

1. A test that fails when the trap springs.
2. A comment at the code that explains it, if no test can reach it.
