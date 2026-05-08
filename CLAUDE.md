# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A portable Windows terminal configuration kit. It manages PowerShell profiles, Starship prompt, and Windows Terminal settings (profiles, schemes, keybindings, actions) as version-controlled source files, then applies them to the local machine via an installer script.

**This is a pure config repo** — no build system, no test suite, no package manager. Files are JSON, TOML, and PowerShell (`.ps1`).

## Key Commands

```powershell
# Run the installer (primary way to apply configs)
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -SetPowerShellAsDefault

# Dry-run / preview changes without writing
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -WhatIf

# Skip specific modules
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -SkipWindowsTerminal -SkipStarship -SkipWezTerm
```

## Architecture

### Config files (repo root)

- `powershell/` — PowerShell 7 profile (loads starship), `powershell.config.json`, and `profile.winps.ps1` (Windows PowerShell 5 compat)
- `starship/starship.toml` — Dracula-style prompt with full modules (username, path, Git, memory, duration, time, language versions) and named color palettes for scheme switching
- `windows-terminal/` — Windows Terminal settings split into composable fragments:
  - `base-settings.json` — Top-level WT settings (theme, copy behavior)
  - `profiles/defaults.json`, `profiles/powershell.json`, `profiles/windows-powershell.json` — Profile definitions
  - `schemes/*.json` — Color schemes (one file per theme, auto-discovered by installer)
  - `actions.json`, `keybindings.json`, `new-tab-menu.json` — Input and menu config
- `wezterm/wezterm.lua` — WezTerm config (Dracula theme, JetBrains Mono, acrylic backdrop)

### Installer (`scripts/Install-TerminalConfig.ps1`)

The script does **merge, not overwrite**. It reads the target machine's existing `settings.json`, then deep-merges repo fragments on top using `Merge-Map` (recursive dict merge) and `Upsert-ArrayItemsByKey` (array merge by a key field like `name` or `id`). Existing profiles/settings not touched by the repo are preserved.

Backups go to `~/.terminal-config-backups/<timestamp>/`.

**Schemes are auto-discovered**: any `.json` file in `windows-terminal/schemes/` is picked up automatically — no need to edit the script when adding a new theme.

### Adding a new color scheme

1. Create a new `.json` file in `windows-terminal/schemes/` following the Windows Terminal color scheme format (must include a `"name"` field).
2. Add a matching color palette in `starship/starship.toml` under `[palettes.<scheme_name>]`.
3. Run the installer. The scheme is auto-merged.

## Design Constraints

- Machine-specific config (SSH profiles, WSL profiles, Conda paths) is intentionally excluded.
- All shell commands target **PowerShell** (not Bash/Zsh). Use `pwsh` syntax.
- Default theme is **Dracula**. One Dark HC has been removed; use `dracula.json` or other scheme files.
