# Changelog

All notable changes to ReelArrange will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Signed release artifacts.
- Optional poster preview in the TMDB match window.
- Expanded episode-pattern fixtures.
- Localization groundwork.

## [0.2.0] - 2026-08-14

### Added

- Duplicate video-format detection with a preselected recommendation based on episode coverage and relative file size.
- Deterministic shortening for destination filenames that would exceed reliable Windows path limits.
- Original ReelArrange application mark in PNG and multi-resolution Windows ICO formats.
- Start menu shortcuts for launching ReelArrange and opening its About window.
- A concise About window with product purpose, version, author, license, notices, and repository link.
- A ready-to-run icon-bearing `ReelArrange.exe` in packaged archives.

### Changed

- Standardized the display branding as **ReelArrange** and adopted 🎬 as the project mark.

- Safe-stop dialogs now explain why the transfer was blocked, confirm that nothing changed, suggest next actions, and limit long path samples.

- Transfer failures now identify the exact source and destination, report completed-file counts, and explain how Copy and Move modes affect earlier files.
- Native transfers now normalize absolute local and UNC paths with Windows extended-path syntax.

## [0.1.0] - 2026-08-10

### Added

- Windows movie and TV source pickers.
- TMDB movie/show search and match confirmation.
- Jellyfin metadata-provider identifiers in destination folders.
- Movie, series, season, episode, version, and split-part naming.
- Recognized extras, artwork, subtitle, and NFO handling.
- Copy and move operations for local, mapped, and UNC paths.
- Add-missing, stop-on-conflict, and confirmed-overwrite policies.
- Missing-first ordering during overwrite runs.
- Native byte-level transfer progress and overall file progress.
- Windows-account encryption for saved TMDB credentials.
- Windowless launcher and Desktop installer.
- Built-in self-tests and Windows GitHub Actions workflow.

[Unreleased]: https://github.com/kylereddoch/reelarrange/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/kylereddoch/reelarrange/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kylereddoch/reelarrange/releases/tag/v0.1.0
