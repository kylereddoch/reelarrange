# 🎬 ReelArrange

[![Windows tests](https://github.com/kylereddoch/reelarrange/actions/workflows/test.yml/badge.svg)](https://github.com/kylereddoch/reelarrange/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE.svg)](https://learn.microsoft.com/powershell/)

<a href="https://github.com/sponsors/kylereddoch"><img src="https://img.shields.io/badge/GitHub%20Sponsors-30363D?style=for-the-badge&logo=GitHub-Sponsors&logoColor=white" alt="GitHub Sponsors" height="20px"></a>
<a href="https://ko-fi.com/kylereddoch"><img src="https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Ko-fi" height="20px"></a>
<a href="https://buymeacoffee.com/kylereddoch"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=000000" alt="Buy me a coffee" height="20px"></a>

ReelArrange is a Windows desktop helper that identifies downloaded movies and TV shows with TMDB, previews a Jellyfin-ready library layout, and copies or moves the media into place.

It is designed for the awkward gap between “the download finished” and “the media server understands it.” The interface handles matching, folder names, seasons, episode titles, sidecars, artwork, featurettes, trailers, collision behavior, and live transfer progress without requiring command-line use.

> [!IMPORTANT]
> ReelArrange is an early project. Always inspect the preview before moving media. Copy is the recommended transfer mode when a torrent should continue seeding.

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

ReelArrange does not need to run on the Jellyfin server itself. A mapped drive or UNC share such as `\\server\media\Movies` is supported.

## Installation

The packaged ZIP includes a ready-to-run, icon-bearing `ReelArrange.exe` beside the PowerShell application and assets. It can be launched directly from the extracted folder.

Clone or download the repository, open Windows PowerShell in the project folder, and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\install.ps1
```

The installer:

1. Parses and tests the PowerShell application.
2. Builds an icon-bearing Windows executable from the included C# source. The executable hosts the PowerShell workflow in-process, so ReelArrange owns its taskbar window and icon without showing a console.
3. Installs the executable, PowerShell application, logo, and notices under `%LOCALAPPDATA%\Programs\ReelArrange`.
4. Creates a **ReelArrange** shortcut on the current user's Desktop.
5. Creates **ReelArrange** and **About ReelArrange** shortcuts in the current user's Start menu.
6. Migrates settings from the original private “Jellyfin Media Prep” build when found.

The installed Desktop and Start menu shortcuts do not depend on the repository remaining in the same location. Their icon comes from the installed ReelArrange executable.

To upgrade after pulling a newer version, run `scripts\install.ps1` again.

## First run

1. Open **ReelArrange** from the Desktop or Start menu.
2. Choose Movie or TV show.
3. Select a file or complete release folder.
4. Paste a TMDB API Read Access Token when prompted. The dialog links directly to TMDB's API settings page.
5. Confirm the TMDB match.
6. Choose the Jellyfin library root and transfer behavior.
7. Inspect the complete destination preview.
8. Start the transfer and follow the live status window.

Selecting a complete release folder is recommended when the download contains extras or artwork. If a movie file is selected directly, ReelArrange detects recognized sibling extras folders and asks whether to include them.

Folder selection uses the modern Windows Explorer picker, including its address bar, sidebar, and normal drive navigation. ReelArrange remembers the last movie and TV source folders separately and starts there the next time that source type is selected.

After a successful transfer, choose **Process another** to return to the Movie/TV selection screen without closing ReelArrange, or choose **Close** when you are finished.

TV filenames may use `S01E01`, `1x01`, or compact three-digit archive numbering such as `101` for Season 1 Episode 1 and `203` for Season 2 Episode 3. Combined files such as `101 102` are treated as `S01E01-E02`.

If an unnumbered TV filename closely matches a TMDB Season 00 title, or its parsed regular-season episode does not exist in TMDB, ReelArrange recommends the matching special. You must confirm the proposed Season 00 assignment, and it appears again in the destination preview before any transfer begins.

If a folder contains same-named videos in multiple formats, such as matching MKV and MP4 copies of every episode, ReelArrange pauses before TMDB lookup and asks which format to keep. It recommends the format with the best episode coverage and larger source files, while making clear that file size is only a practical signal and not a full quality inspection. Unselected video copies remain untouched in the source folder.

Very long movie or multi-episode titles are shortened deterministically before transfer. ReelArrange preserves the identifying show and episode prefix, then adds a stable suffix to avoid collisions while keeping the complete destination path within reliable Windows limits.

## Existing-file behavior

ReelArrange offers three policies:

- **Add missing files; keep existing media** — recommended for adding extras to a movie that was already transferred.
- **Stop if any destination file exists** — changes nothing when a collision is found.
- **Overwrite existing files** — transfers missing files first, then displays a final warning before replacing existing destinations.

When ReelArrange stops safely, the dialog explains the reason, confirms that no files changed, suggests the appropriate next step, and shows only a manageable sample of conflicting paths.

If a transfer stops after some files complete, run the same source again with **Add missing files**. Completed destinations remain untouched and only absent files are transferred.

## Copy versus move

- **Copy** leaves the download intact and is the recommended choice while seeding.
- **Move** removes successfully transferred source files. Cross-drive moves can take several minutes for large files.

The transfer window reports the current file, byte percentage, transferred size, and overall file count.

## About ReelArrange

Choose **About** from ReelArrange's opening window or **About ReelArrange** from the Start menu. The short About window shows the current version, what ReelArrange does, the author, license and service notices, and a link to the project repository.

## Settings, logs, and privacy

User data is stored under `%LOCALAPPDATA%\ReelArrange`:

- `settings.json` contains the TMDB credential encrypted with Windows Data Protection for the current user, plus the last selected library roots.
- `activity.log` records file operations and errors. It never records the TMDB credential.

ReelArrange has no telemetry. See [Privacy](docs/PRIVACY.md) for the network and local-data model.

## Uninstall

From the repository:

```powershell
.\scripts\uninstall.ps1
```

The uninstaller removes the installed application plus its Desktop and Start menu shortcuts, but keeps settings and logs by default. To remove those too:

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

The current version is `0.3.0`. See [CHANGELOG.md](CHANGELOG.md) for changes and planned compatibility notes.

## Support ReelArrange

If ReelArrange has been useful and you want to support future updates, you can contribute through any of these optional links:

<a href="https://github.com/sponsors/kylereddoch"><img src="https://img.shields.io/badge/GitHub%20Sponsors-30363D?style=for-the-badge&logo=GitHub-Sponsors&logoColor=white" alt="GitHub Sponsors" height="24px"></a>
<a href="https://ko-fi.com/kylereddoch"><img src="https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Ko-fi" height="24px"></a>
<a href="https://buymeacoffee.com/kylereddoch"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=000000" alt="Buy me a coffee" height="24px"></a>

## License and service notices

ReelArrange is released under the [MIT License](LICENSE).

ReelArrange is not affiliated with or endorsed by Jellyfin or TMDB. “Jellyfin” and “TMDB” are used only to describe interoperability. This product uses the TMDB API but is not endorsed or certified by TMDB. See [NOTICE.md](NOTICE.md).
