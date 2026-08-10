# Repository instructions

## Scope

ReelArrange is a Windows PowerShell 5.1-compatible WinForms application for planning and transferring media into Jellyfin-compatible layouts.

## Required checks

- Preserve Windows PowerShell 5.1 compatibility.
- Run `scripts\test.ps1` after source, installer, launcher, or test changes.
- Keep `VERSION`, `CHANGELOG.md`, and user documentation aligned for releases.
- Check the final diff for credentials, private media paths, logs, binaries, and generated archives.

## Safety contracts

- Copy remains the recommended mode when seeding matters.
- Never replace a destination unless Overwrite was selected and confirmed.
- Add-missing behavior must not modify existing destination files.
- A duplicate target within one plan must abort before transfer.
- Use literal paths for user-selected files.
- Never log or display saved TMDB credentials after setup.
- Preview all planned destinations before the operation begins.

## Repository boundaries

- `src/` contains the application and windowless launcher source.
- `scripts/` contains install, uninstall, package, and test entry points.
- `tests/` contains test documentation and future fixtures.
- `dist/` is generated and must not be committed.
