# Unit Tests for Contriburg

This directory contains unit tests for the Contriburg KDE Plasma widget,
covering the two files that hold real logic and no Plasma-specific
dependencies: `contents/ui/DataFetcher.js` and `contents/ui/Scene3D.qml`.

## Prerequisites

You need a Qt 6 QML Test environment:

### Fedora
```bash
sudo dnf install qt6-qtdeclarative-devel
```

### Arch Linux / Manjaro
```bash
sudo pacman -S qt6-declarative
```

### Ubuntu / Debian
```bash
sudo apt install qt6-declarative-dev
```

## Running Tests

```bash
./run_tests.sh
```

Or manually:

```bash
qmltestrunner-qt6 -input . -import ../contents/ui
```

Or via CMake/ctest:

```bash
cmake -S . -B build
ctest --test-dir build --output-on-failure
```

## Test Files

| File | Description |
|------|-------------|
| `tst_datafetcher.qml` | Tests for `DataFetcher.js`: input validation, the GitLab `https://`-only check, contribution-level thresholds, and the GitHub HTML-scraper parser. |
| `tst_scene3d.qml` | Tests for `Scene3D.qml`: cube count/grid placement, height scaling, fixed-mode level colors, random-mode color diversity and reroll, and the lock-camera toggle. |
| `CMakeLists.txt` | Registers the tests with `ctest` by shelling out to `qmltestrunner-qt6`. |
| `run_tests.sh` | Standalone script to run the tests without CMake. |

## What's intentionally not covered

- **`main.qml`** is not unit-tested. It reads configuration through the
  `Plasmoid.configuration` **attached property**, which — unlike the classic
  Plasma 5-style `plasmoid` context property — is resolved through the real
  `org.kde.plasma.plasmoid` C++ plugin tied to an actual `PlasmoidItem`
  applet instance. It can't be swapped for a plain mock QML object the way
  `Scene3D.qml`'s plain properties can. Verify `main.qml` changes by actually
  running the applet (`plasmoidviewer -a .` from the repo root) instead —
  see `AGENTS.md`.
- **Network-dependent paths** (`fetchWithGraphQL`'s and
  `fetchGithubContributionsPage`'s success responses, `fetchGitlabCalendar`'s
  200 branch) aren't covered — only their synchronous, pre-network
  validation logic is. Testing the success paths would mean either hitting
  real APIs from a unit test (flaky, slow, rate-limited) or mocking
  `XMLHttpRequest`, which QML doesn't make easy to intercept.

## Writing New Tests

Tests use Qt's QML Test framework (`QtTest`). Each test function should:

1. Use `compare()` to verify expected values.
2. Use `verify()` to check boolean conditions.
3. Use `fuzzyCompare()` for floating-point math (like `hScale`).
4. Use `wait()` after changing a property that a binding depends on, to let
   the binding re-evaluate before asserting on it.

`tst_scene3d.qml` loads `Scene3D.qml` through a `Loader` (it's a plain QML
component, no mocking needed) and reaches individual day cubes via
`Scene3D.qml`'s `dayRepeater` alias — `dayRepeater.objectAt(i)` — since QML
`id`s aren't visible outside the file that declares them.
