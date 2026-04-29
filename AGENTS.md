# Repository Guidelines

## Project Structure & Module Organization

`configs/` stores the source-of-truth terminal configuration. Keep PowerShell 7 files in `configs/powershell/`, legacy Windows PowerShell compatibility in `configs/windows-powershell/`, Starship prompt settings in `configs/starship/`, and Windows Terminal JSON fragments in `configs/windows-terminal/` (`profiles/`, `schemes/`, `themes/`, plus shared settings files). `scripts/` contains operational PowerShell scripts such as `Install-TerminalConfig.ps1` and `Fix-ConsoleEncoding.ps1`. Do not commit machine-specific paths, ad hoc SSH/WSL profiles, or backup output.

## Build, Test, and Development Commands

This repository has no compile step; validation is script-driven.

- `pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -WhatIf`
  Preview installer changes without writing files.
- `pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -SetPowerShellAsDefault`
  Apply repo configs to the current machine.
- `pwsh -ExecutionPolicy Bypass -File .\scripts\Fix-ConsoleEncoding.ps1`
  Verify the UTF-8 encoding fix in the current session.
- `git diff`
  Review config-only changes before committing.

## Coding Style & Naming Conventions

Use PowerShell-compatible changes first; this repo targets Windows + PowerShell. Prefer simple, minimal edits and keep each change scoped to one intent. All functions and key logic in scripts must include Chinese comments. Use `Set-StrictMode -Version Latest` patterns already present in scripts. Keep JSON fragments formatted consistently and named with lowercase kebab-case, for example `catppuccin-mocha.json` and `one-dark-hc.json`.

## Testing Guidelines

There is no automated test suite yet. For script changes, run the relevant `pwsh` command and capture observable evidence such as `-WhatIf` output or encoding status output. For terminal config changes, re-run the installer, reopen Windows Terminal, and verify the affected profile, scheme, or theme renders as expected. Treat manual verification as required before marking work complete.

## Commit & Pull Request Guidelines

Recent history uses short imperative subjects and occasional Conventional Commit prefixes, for example `feat: add UTF-8 console encoding fix for Chinese garbled text` and `Add Nord terminal scheme and starship palette`. Prefer concise, descriptive subjects in that style. PRs should state the user-visible config change, list touched paths, mention any manual verification command used, and include screenshots when visual terminal appearance changes.

## Repository-Specific Notes

Default to editing source files under `configs/` instead of patching local machine outputs directly. Use the installer’s merge behavior rather than replacing a full `settings.json`, and avoid documentation churn unless the change explicitly requires it.
