# User guide

## Overview

ReelArrange prepares downloaded movies and TV shows for a Jellyfin library. It identifies the title with TMDB, creates a proposed destination layout, and transfers the selected media only after confirmation.

The installed app is available from both the Desktop and the **ReelArrange** Start menu folder. The Start menu also includes **About ReelArrange**, which opens the About window without starting a media-planning workflow.

## Preparing a movie

1. Choose **Movie**.
2. Choose a movie file or complete movie folder.
3. If a single file is selected and recognized extras exist beside it, choose whether to include them.
4. Confirm the TMDB result by checking the title, year, overview, and numeric ID.
5. Choose the Jellyfin Movies library root.
6. Choose Copy or Move.
7. Choose how existing destinations should be handled.
8. Inspect every planned destination in the preview.
9. Start the transfer.

For a complete release containing artwork or extras, selecting the folder is the most reliable option.

## Preparing television

1. Choose **TV show**.
2. Select episode files or a show/season folder.
3. Confirm the TMDB series result.
4. Review recognized season and episode numbers.
5. Choose the Jellyfin Shows library root and transfer behavior.
6. Inspect the preview and start the transfer.

Episode filenames should normally contain `S01E01` or `1x01`. A single unnumbered file prompts for season and episode. Unnumbered files in a batch are reported and skipped unless the user cancels.

## Extras

ReelArrange recognizes these Jellyfin folder roles, including common spacing, case, underscore, and hyphen variations:

- `behind the scenes`
- `deleted scenes`
- `interviews`
- `scenes`
- `samples`
- `shorts`
- `featurettes`
- `clips`
- `other`
- `extras`
- `trailers`
- `theme-music`
- `backdrops`

Everything inside a recognized extras folder is transferred with its nested structure. For television, the nearest season folder determines whether an extra belongs to a season or the series.

## Artwork and sidecars

Recognized root and season artwork includes common names such as `poster`, `cover`, `backdrop`, `fanart`, `banner`, `logo`, `landscape`, and `thumb` with JPG, PNG, or WebP extensions.

Subtitles, NFO files, and artwork whose filenames match the selected video are renamed with the video and transferred beside it.

## Duplicate video formats

Some downloads contain the same episode or movie in more than one container, such as matching MKV and MP4 files with identical base names. ReelArrange detects these sets before TMDB lookup and asks which format to keep in the plan.

The dialog shows file counts, combined sizes, duplicate-name coverage, and how often each format is the largest candidate. The preselected recommendation favors complete coverage and larger files. This is a practical recommendation only; ReelArrange does not inspect codecs, bitrates, audio tracks, or subtitle streams. Choosing a format excludes the alternate video copies from the plan but never changes the source files.

## Long titles and paths

TMDB can return very long combined titles for files containing many episodes. ReelArrange shortens only filenames that would push the complete destination beyond reliable Windows path limits. The shortened name keeps the show and episode identifier at the front and ends with a stable eight-character suffix so separate titles do not collapse onto the same destination.

The transfer layer also supports extended absolute local and UNC source paths. If the selected destination root is itself too long to leave room for a useful filename, ReelArrange stops during planning and asks for a shorter root before transferring anything.

## Existing destinations

### Add missing files

Existing destinations remain untouched. Only absent planned files are transferred. This is the recommended option when adding featurettes or artwork to media that is already in the library.

### Stop

Any collision stops the complete operation before a transfer begins. The safe-stop dialog explains the cause, confirms that nothing changed, suggests next actions, and shows a limited sample rather than an unreadable full path list.

### Overwrite

Missing destinations are handled first. ReelArrange then shows the exact number and a sample of paths that would be replaced. Choosing No cancels without replacing them.

If an individual file fails during Copy or Move, the safe-stop dialog identifies that source and destination, reports how many files completed, and explains whether earlier source files remain. After correcting the problem, rerun with **Add missing files** to preserve completed destinations and continue with absent files.

## Copy and move behavior

Copy leaves sources intact. Move removes each source only after its transfer completes. A move between drives or network locations performs a full copy before deleting the source, so large media can take several minutes.

The transfer-status window shows the active path, bytes transferred, percentage, and overall file count.

## Logs

The activity log is located at:

```text
%LOCALAPPDATA%\ReelArrange\activity.log
```

Each completed file transfer is logged after the operation returns successfully. A destination file may appear at its full final size while Windows is still writing data; use the transfer-status window rather than Explorer alone to determine completion.

## About and version

Choose **About** on ReelArrange's opening window to see the application logo, current version, short product description, author, license and service notices, and repository link. The same window is available through **About ReelArrange** in the Start menu.
