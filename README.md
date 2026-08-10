# Reelarrange

[![Windows tests](https://github.com/kylereddoch/reelarrange/actions/workflows/test.yml/badge.svg)](https://github.com/kylereddoch/reelarrange/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE.svg)](https://learn.microsoft.com/powershell/)

Reelarrange is a Windows desktop helper that identifies downloaded movies and TV shows with TMDB, previews a Jellyfin-ready library layout, and copies or moves the media into place.

It is designed for the awkward gap between “the download finished” and “the media server understands it.” The interface handles matching, folder names, seasons, episode titles, sidecars, artwork, featurettes, trailers, collision behavior, and live transfer progress without requiring command-line use.

> [!IMPORTANT]
> Reelarrange is an early project. Always inspect the preview before moving media. Copy is the recommended transfer mode when a torrent should continue seeding.

## Features

- Searches TMDB and requires confirmation of the selected title.
- Uses Jellyfin metadata identifiers such as `[tmdbid-687163]`.
- Accepts a movie file, movie folder, selected episodes, season folder, or complete show folder.
- Produces Jellyfin-style movie, series, season, and episode names.
- Retrieves episode titles from TMDB when available.
- Preserves matching subtitles, NFO files, and artwork sidecars.
- Carries recognized extras including featurettes, trailers, deleted scenes, interviews, clips, shorts, samples, theme music, and backdrops.
- Keeps show-level and season-level extras in the correct place.
- Handles movie versions and common split-part names such as `cd1` and `cd2`.
- Supports copy and move operations, including mapped drives and UNC paths.
- Provides add-missing, stop-on-conflict, and confirmed-overwrite policies.
- Displays live per-file byte progress and overall file progress.
- Encrypts the TMDB credential for the current Windows account.
- Does not overwrite anything unless the user explicitly selects and confirms overwrite.

## Example layouts

Movie:

```text
Movies/
└── Movie Title (2026) [tmdbid-123456]/
    ├── Movie Title (2026) [tmdbid-123456].mkv
    ├── poster.jpg
    └── featurettes/
        └── Making Of.mkv
```

TV show:

```text
Shows/
└── Series Title (2026) [tmdbid-654321]/
    ├── trailers/
    │   └── Official Trailer.mkv
    └── Season 01/
        ├── Series Title (2026) S01E01 Episode Title.mkv
        └── behind the scenes/
            └── Episode Making Of.mkv
```

The naming behavior follows Jellyfin's current [movie](https://jellyfin.org/docs/general/server/media/movies/), [TV show](https://jellyfin.org/docs/general/server/media/shows/), and [metadata identifier](https://jellyfin.org/docs/general/server/metadata/identifiers/) documentation.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or newer PowerShell for development
- A free TMDB account and either an API Read Access Token or v3 API key
- Internet access for TMDB searches
- An existing Movies or Shows library folder, locally or over the network

Reelarrange does not need to run on the Jellyfin server itself. A mapped drive or UNC share such as `\\server\media\Movies` is supported.

## Installation

Clone or download the repository, open Windows PowerShell in the project folder, and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\install.ps1
```

The installer:

1. Parses and tests the PowerShell application.
2. Builds a small windowless launcher from the included C# source.
3. Installs the runnable files under `%LOCALAPPDATA%\Programs\Reelarrange`.
4. Creates a **Reelarrange** shortcut on the current user's Desktop.
5. Migrates settings from the original private “Jellyfin Media Prep” build when found.

The Desktop shortcut does not depend on the repository remaining in the same location.

To upgrade after pulling a newer version, run `scripts\install.ps1` again.

## First run

1. Open **Reelarrange** from the Desktop.
2. Choose Movie or TV show.
3. Select a file or complete release folder.
4. Paste a TMDB API Read Access Token when prompted. The dialog links directly to TMDB's API settings page.
5. Confirm the TMDB match.
6. Choose the Jellyfin library root and transfer behavior.
7. Inspect the complete destination preview.
8. Start the transfer and follow the live status window.

Selecting a complete release folder is recommended when the download contains extras or artwork. If a movie file is selected directly, Reelarrange detects recognized sibling extras folders and asks whether to include them.

## Existing-file behavior

Reelarrange offers three policies:

- **Add missing files; keep existing media** — recommended for adding extras to a movie that was already transferred.
- **Stop if any destination file exists** — changes nothing when a collision is found.
- **Overwrite existing files** — transfers missing files first, then displays a final warning before replacing existing destinations.

## Copy versus move

- **Copy** leaves the download intact and is the recommended choice while seeding.
- **Move** removes successfully transferred source files. Cross-drive moves can take several minutes for large files.

The transfer window reports the current file, byte percentage, transferred size, and overall file count.

## Settings, logs, and privacy

User data is stored under `%LOCALAPPDATA%\Reelarrange`:

- `settings.json` contains the TMDB credential encrypted with Windows Data Protection for the current user, plus the last selected library roots.
- `activity.log` records file operations and errors. It never records the TMDB credential.

Reelarrange has no telemetry. See [Privacy](docs/PRIVACY.md) for the network and local-data model.

## Uninstall

From the repository:

```powershell
.\scripts\uninstall.ps1
```

The uninstaller removes the installed application and Desktop shortcut but keeps settings and logs by default. To remove those too:

```powershell
.\scripts\uninstall.ps1 -RemoveUserData
```

## Development

Run the complete local checks with:

```powershell
.\scripts\test.ps1
```

See [Development](docs/DEVELOPMENT.md), [Architecture](docs/ARCHITECTURE.md), and [Contributing](CONTRIBUTING.md) before submitting a change.

## Reporting problems and requesting features

- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) for reproducible defects.
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.yml) for proposed behavior.
- Read [Support](SUPPORT.md) before including logs or paths.
- Report vulnerabilities privately as described in [Security](SECURITY.md).

## Project status

The current version is `0.1.0`. See [CHANGELOG.md](CHANGELOG.md) for changes and planned compatibility notes.

## License and service notices

Reelarrange is released under the [MIT License](LICENSE).

Reelarrange is not affiliated with or endorsed by Jellyfin or TMDB. “Jellyfin” and “TMDB” are used only to describe interoperability. This product uses the TMDB API but is not endorsed or certified by TMDB. See [NOTICE.md](NOTICE.md).
