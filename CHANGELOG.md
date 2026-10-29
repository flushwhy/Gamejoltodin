# Changelog

## 1.0.0 (2026-10-29)


### ⚠ BREAKING CHANGES

* Native GJ_Session now stores Odin strings and booleans; C callers continue to use the fixed-layout GJ_Session declared in gamejolt.h.

### Features

* make the Game Jolt client Odin-first ([#4](https://github.com/flushwhy/Gamejoltodin/issues/4)) ([b96d7bd](https://github.com/flushwhy/Gamejoltodin/commit/b96d7bd61d3dd5c84e05a910b135799d6bdde962))


### Bug Fixes

* **api:** harden request and buffer handling ([#7](https://github.com/flushwhy/Gamejoltodin/issues/7)) ([c4f792c](https://github.com/flushwhy/Gamejoltodin/commit/c4f792cb9f09745d4f80ca89d41f78a6cba52d40))
* **ci:** repair release-please configuration ([#5](https://github.com/flushwhy/Gamejoltodin/issues/5)) ([aa4d334](https://github.com/flushwhy/Gamejoltodin/commit/aa4d3346b779862a675b1aa821d9d4f5a104eb72))
* validate required C string inputs ([#13](https://github.com/flushwhy/Gamejoltodin/issues/13)) ([c3aab69](https://github.com/flushwhy/Gamejoltodin/commit/c3aab69e698d84fcb8e016777413798eb2c95e0e))
* **windows:** select MSVC linker in CI build and tests ([#9](https://github.com/flushwhy/Gamejoltodin/issues/9)) ([95449ce](https://github.com/flushwhy/Gamejoltodin/commit/95449cea260da35dd38042bca5b78e7e49bcd6ed))
