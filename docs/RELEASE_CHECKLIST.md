# Gamejoltodin 1.0 release checklist

Do not publish `v1.0.0` until the release candidate satisfies every required check below.

## Required before tagging

- [ ] The Windows, Linux, and macOS jobs in the [CI workflow](../.github/workflows/ci.yml) pass on the exact release commit.
- [ ] Run the native Odin tests and C ABI integration tests from a clean checkout on all three supported platforms.
- [ ] Verify the public Odin API and `gamejolt.h` signatures, C struct layouts, error codes, buffer behavior, and ownership contracts are intentional and documented.
- [ ] Run the [DapperO integration example](https://github.com/flushwhy/DapperO/tree/main/examples/gamejoltodin) against a test Game Jolt game: login, open session, submit a test score, and close session.
- [ ] Verify the documentation site is published and its quick-start instructions match the release source.
- [ ] Review the generated release notes and ensure each platform artifact contains the library, `gamejolt.h`, and README.
- [ ] Confirm no real credentials or player tokens are committed to the repository or release package.

## Publish

1. Merge only after the required checks pass.
2. Review the release-please PR and generated changelog.
3. Publish `v1.0.0` from the verified commit.
4. Download each platform artifact and smoke-test it outside the build environment.

This checklist is a release gate, not evidence that the release is already verified.
