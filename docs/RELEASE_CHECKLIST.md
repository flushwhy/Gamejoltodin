# Gamejoltodin 1.0 release checklist

Do not publish `v1.0.0` until the release candidate satisfies every required check below.

## Required before tagging

- [ ] The Windows, Linux, and macOS jobs in the [CI workflow](../.github/workflows/ci.yml) pass on the exact release commit.
- [ ] Run the native Odin tests and C ABI integration tests from a clean checkout on all three supported platforms.
- [ ] Verify the public Odin API and `gamejolt.h` signatures, C struct layouts, error codes, buffer behavior, and ownership contracts are intentional and documented.
- [ ] Run the [DapperO integration example](https://github.com/flushwhy/DapperO/tree/main/examples/gamejoltodin) against a test Game Jolt game: login, open session, submit a test score, and close session.
- [ ] Verify the documentation site is published and its quick-start instructions match the release source.
- [ ] Review the generated release notes and ensure the release artifacts contain the platform library, `gamejolt.h`, and README.
- [ ] Confirm no real game credentials, player tokens, or private keys are committed to the repository or release package.

## Publish

1. Merge only after the required checks pass.
2. Review the release-please PR and generated changelog.
3. Tag and publish `v1.0.0` from the verified commit.
4. Download each platform artifact from the release page and smoke-test it outside the build environment.

## Current gate

The checklist is a release gate, not evidence that the release is already verified. The DapperO integration PR and the cross-platform CI results must be reviewed before calling Gamejoltodin 1.0 ready.
