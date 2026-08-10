# Contributing to Reelarrange

Thank you for helping improve Reelarrange. Changes should preserve the project's central safety property: the application must show users what it intends to do and must not replace existing media without explicit confirmation.

## Before opening an issue

- Search existing issues.
- Remove TMDB tokens, private server names, usernames, and sensitive paths from screenshots and logs.
- Confirm whether the problem occurs with Copy, Move, or both.
- Include the Reelarrange version, Windows version, source layout, and expected destination layout.

Use the repository's structured bug or feature templates whenever possible.

## Development setup

Requirements:

- Windows 10 or Windows 11
- Git
- Windows PowerShell 5.1
- Optional PowerShell 7 for compatibility checks

Clone the repository and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\test.ps1
```

No TMDB credential is needed for the built-in self-tests.

## Pull requests

1. Create a focused branch.
2. Keep changes narrow and explain user-visible behavior.
3. Add or update self-test coverage for parsing, planning, collision, or transfer changes.
4. Run `scripts\test.ps1` successfully.
5. Update README, user guide, or changelog when behavior changes.
6. Do not commit credentials, personal media paths, generated logs, installation output, or release archives.

Pull requests should state:

- What changed.
- Why the existing behavior was insufficient.
- How the change was tested.
- Any data-loss, overwrite, seeding, or compatibility implications.

## Code style

- Maintain Windows PowerShell 5.1 compatibility.
- Use `-LiteralPath` for user-selected filesystem paths.
- Keep overwrite behavior opt-in and confirmation-gated.
- Never log TMDB credentials.
- Prefer official Jellyfin and TMDB documentation when behavior depends on an external contract.
- Keep the WinForms interface understandable without command-line knowledge.

## License

By contributing, you agree that your contribution is licensed under the project's MIT License.
