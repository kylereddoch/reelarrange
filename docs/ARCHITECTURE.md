# Architecture

## Components

```text
Desktop or Start menu shortcut
    ↓
ReelArrange.exe (icon-bearing windowless C# launcher)
    ↓
ReelArrange.ps1 (PowerShell 5.1 + WinForms)
    ├── Source selection and filename parsing
    ├── TMDB search and episode metadata
    ├── Jellyfin destination planning
    ├── Collision-policy confirmation
    └── Native Windows file transfer with progress callbacks
```

The launcher is a Windows GUI-subsystem executable with ReelArrange product metadata, an embedded multi-resolution icon, and an explicit ReelArrange taskbar identity. It hosts the Windows PowerShell 5.1 runspace inside `ReelArrange.exe` on the main STA thread, so WinForms windows belong to the ReelArrange process instead of `powershell.exe` and no console is allocated. The `--about` launcher option opens the About window directly.

The installed `assets` folder provides the PNG used inside the About window and the ICO used by WinForms. The installer creates a Desktop shortcut plus launch and About entries under the current user's Start menu.

## Data flow

1. The source picker returns video files, a source root, and whether folder companions should be scanned.
2. Filename cleanup suggests a TMDB query and optional year.
3. The user selects a TMDB result.
4. Movie or TV plan builders produce immutable source-to-target file records.
5. Companion planning adds extras and artwork while avoiding already-planned sidecars.
6. Duplicate targets are rejected.
7. The selected collision policy resolves existing targets.
8. Missing files are ordered before replacements.
9. Windows `CopyFileEx` or `MoveFileWithProgress` provides byte callbacks to the WinForms status window.

## External services

The only required network service is TMDB API v3. Requests use either a Bearer API Read Access Token or a v3 API key supplied by the user.

## Local state

`%LOCALAPPDATA%\ReelArrange\settings.json` stores:

- The DPAPI-encrypted TMDB credential.
- The last Movies library root.
- The last Shows library root.

`activity.log` stores completed source-to-target operations and errors. It does not store the TMDB credential.

## Safety boundaries

- Plans contain files, not recursive directory move operations.
- Existing destinations are checked before the first transfer.
- Add-missing never invokes an overwrite-capable native call.
- Overwrite requires a final confirmation after the actual destination plan exists.
- Native transfers operate on literal, fully resolved file paths.
- The application does not launch, parse, remux, or modify media-file contents.
