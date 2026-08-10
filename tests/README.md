# Tests

ReelArrange currently uses dependency-free self-tests embedded in `src\ReelArrange.ps1` so the same checks can run on a clean Windows installation and in GitHub Actions without installing Pester.

Run all checks through:

```powershell
.\scripts\test.ps1
```

Future fixture-based tests should use synthetic filenames and tiny generated files. Do not commit real media, TMDB credentials, personal paths, or activity logs.
