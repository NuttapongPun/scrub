# Security Policy

## Supported versions

Scrub is maintained by a single author. Only the **latest release** receives
security fixes; please upgrade before reporting an issue.

| Version | Supported |
| ------- | --------- |
| Latest release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Report privately through GitHub's
[private vulnerability reporting](https://github.com/NuttapongPun/scrub/security/advisories/new).
This keeps the report confidential until a fix is available.

Please include:

- A description of the vulnerability and its impact
- Steps to reproduce (or a proof of concept)
- The Scrub version and macOS version affected

You can expect an initial acknowledgement within a few days. Once the report is
confirmed, a fix will be prepared and released, and the advisory published so
users can update.

## Scope notes

Scrub requires **Accessibility** permission to block keyboard and pointer input,
so it cannot be sandboxed. Builds are currently unsigned / ad-hoc (no Developer
ID signing or notarization yet). Reports about the trust model — input locking,
the unlock chord, the dead-man's-switch fail-open behavior, or session
history handling — are especially welcome.
