# Privacy

ReelArrange is a local desktop application with no telemetry, analytics, advertising, account system, update service, or inbound listener.

## Network requests

ReelArrange contacts `api.themoviedb.org` to:

- Validate the user-supplied TMDB credential.
- Search for movies and television series.
- Retrieve television-season episode titles.

TMDB receives the normal information associated with an API request, including the user's public IP address, credential, query text, and requested title identifiers. Review TMDB's own terms and privacy policy before use.

The application does not send media files, local paths, activity logs, Jellyfin credentials, or Jellyfin server addresses to TMDB.

## Local storage

ReelArrange stores user state in `%LOCALAPPDATA%\ReelArrange`.

The TMDB credential is encrypted using Windows Data Protection through `ConvertFrom-SecureString`. It can be decrypted only in the same Windows user context under normal Windows security assumptions.

Library roots are stored as plain text because they are needed to prefill destination selection. The activity log contains source and destination paths and should be treated as private when those paths reveal usernames, hostnames, or share names.

## Removing data

Run:

```powershell
.\scripts\uninstall.ps1 -RemoveUserData
```

or manually remove `%LOCALAPPDATA%\ReelArrange` after closing the application.
