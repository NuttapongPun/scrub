# Contributing to Scrub

Thanks for your interest in improving Scrub — a macOS menu-bar app for
"cleaning mode" that locks the keyboard/trackpad and dims the screen while you
wipe a machine.

## Ways to contribute

- **Report a bug** or **request a feature** via
  [GitHub Issues](https://github.com/NuttapongPun/scrub/issues) — pick the
  matching template. Anyone can open an issue.
- **Report a security vulnerability** privately — see [SECURITY.md](SECURITY.md).
  Do not file security reports as public issues.
- **Submit a code change** via a pull request (see below).

## Pull requests use a fork-and-PR flow

Direct pushes to `main` are blocked; every change lands through a pull request.

1. **Fork** the repository to your own account.
2. Create a branch off `main` for your change.
3. Make your change and make sure it builds and the tests pass (see below).
4. Open a pull request against `main` with a clear description of the change
   and the motivation.

The maintainer reviews and merges PRs. Release tagging is restricted to the
maintainer, so please don't push `v*` tags.

## Build & test

Scrub is a Swift Package Manager project that wraps its binary into a runnable
`Scrub.app` bundle.

```sh
./build.sh     # compile and assemble Scrub.app (ad-hoc signed)
swift build    # compile only
swift test     # run the ScrubTests suite (pure session logic)
```

Running the app requires granting **Accessibility** permission so it can block
input; because of that it cannot be sandboxed or App Store distributed.

Please keep PRs green: `swift build && swift test` must pass (CI runs the same
on every PR).

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) — e.g.
`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.

## Design docs are the source of truth

Before changing behavior, read the engineering docs — they override the
user-facing `README.md` where they differ:

- `CONTEXT.md` — the domain glossary
- `docs/adr/` — the architecture decision records (ADR-0001–0007)

If your change alters a documented decision, update the relevant ADR (or add a
new one) as part of the PR.

## Issue triage

Maintainers label incoming issues with a small vocabulary: `needs-triage`,
`needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. New issues start
as `needs-triage`; you don't need to apply labels yourself.
