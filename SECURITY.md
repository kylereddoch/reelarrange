# Security Policy

## Supported versions

Security fixes are provided for the latest released version.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| Earlier private builds | No |

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose credentials, replace unintended files, escape selected source/destination boundaries, or execute untrusted content.

When the repository is published, use GitHub's **Report a vulnerability** private security-advisory workflow. Until then, contact the repository owner privately through the contact methods on the owner's GitHub profile.

Include:

- The affected version or commit.
- Reproduction steps using non-sensitive test files.
- Expected and observed behavior.
- The potential impact.
- Any suggested mitigation.

Never include a real TMDB credential or private server address.

## Security model

- TMDB credentials are encrypted with Windows Data Protection for the current user.
- Credentials are not written to activity logs.
- Destination overwrites require an explicit policy selection and a final confirmation.
- The application does not execute selected media files.
- The application has no update mechanism, telemetry, server component, or inbound network listener.
