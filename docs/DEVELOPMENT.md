# Development

## Runtime targets

The distributed application targets Windows PowerShell 5.1 and .NET Framework WinForms. PowerShell 7 is also used during local tests when available, but it is not required for end users.

## Repository layout

```text
src/        Application and launcher source
scripts/    Install, uninstall, package, and test commands
tests/      Test notes and future fixtures
docs/       User and maintainer documentation
.github/    Issue templates, pull-request template, and CI workflow
```

## Running from source

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\src\ReelArrange.ps1
```

Running directly from a terminal is useful for debugging but will display a console. The installed launcher avoids that console.

## Tests

```powershell
.\scripts\test.ps1
```

The application has a `-SelfTest` mode that bypasses all dialogs and TMDB access. It currently verifies:

- Movie and TV search-query cleanup.
- `SxxEyy`, multi-episode, and `1xYY` parsing.
- Windows-safe destination names.
- Extras-folder normalization.
- Movie version naming.
- Movie folder, sidecar, artwork, and featurette planning.
- Show-level and season-level extras planning.
- Stop and add-missing collision behavior.
- Native copy and move transfer paths.

CI runs on `windows-latest` using Windows PowerShell.

## Building the launcher

The installer compiles `src\ReelArrangeLauncher.cs` with the .NET Framework C# compiler included with Windows. Generated executables belong in the installation directory or `dist/`, never in source control.

## Packaging

```powershell
.\scripts\package.ps1
```

This runs tests and creates a versioned source-install ZIP under `dist/`.

## Manual release checklist

1. Update `VERSION`.
2. Move changelog entries from Unreleased to the release version.
3. Run `scripts\test.ps1`.
4. Run `scripts\package.ps1`.
5. Test install, upgrade, and uninstall on Windows.
6. Confirm no settings, tokens, logs, personal paths, binaries, or archives are staged.
7. Tag `v<version>` and publish the ZIP as a release asset.
