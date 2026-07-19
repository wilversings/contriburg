# Contriburg (standalone)

A non-Plasma build of Contriburg: a frameless, transparent, always-on-bottom
window showing the same 3D skyline, for Windows/macOS/non-Plasma Linux. It
reuses `contents/ui/Scene3D.qml` and `contents/ui/DataFetcher.js` unchanged
via relative imports (see `Main.qml`) - only the Plasma-specific shell
(`main.qml`, `ConfigGeneral.qml`, KConfigXT) was reimplemented, as
`Main.qml`/`SettingsWindow.qml` here, on plain Qt Quick + `QtCore.Settings`
(QSettings) instead.

## What's different from the Plasmoid

- **No shell embedding.** Plasma widgets live inside a containment (panel or
  desktop) managed by `plasmashell`; there's no equivalent outside Plasma.
  This is a standalone top-level window instead: frameless, transparent,
  `Qt.WindowStaysOnBottomHint | Qt.Tool` (parked below normal windows, hidden
  from the taskbar/alt-tab) - it *looks* like a desktop widget but isn't
  shell-integrated (no widget picker, no panel docking).
- **Dragging to reposition.** There's no panel to drag it out of. Right-click
  the tray icon → "Move Window" toggles a full-window drag handle (also
  disables scene-orbit while active, so the two gestures don't fight).
- **Settings** live in `QtCore.Settings` (an ini file / the platform's native
  settings store - `%APPDATA%\Contriburg\Contriburg.ini` on Windows), not
  KConfigXT, and are edited from a tray-menu window
  (`SettingsWindow.qml`) built on plain `QtQuick.Controls` rather than
  Kirigami/KCM.
- **System tray icon** (`Qt.labs.platform.SystemTrayIcon`) stands in for the
  Plasma "Configure..." context menu: left-click or "Settings..." opens
  `SettingsWindow.qml`, "Refresh Now" re-fetches, "Quit" exits.

## Requirements

Same as the Plasmoid, minus KDE Frameworks: Qt 6 with Qml, Quick,
QuickControls2, Widgets, and the **Qt Quick 3D** runtime module (loaded as a
QML plugin at runtime - no Qt Quick 3D *development* package is needed to
build this, since `main.cpp` never calls its C++ API directly).

## Run without building (quick check, any platform with a Qt install)

Qt ships a generic QML runner that can load this directly - useful for
iterating on `Main.qml`/`SettingsWindow.qml` without a compile step, same
spirit as the Plasmoid's "no build step" workflow. It must run in **widget**
app mode: the tray icon (`Qt.labs.platform.SystemTrayIcon`) pulls in `QMenu`
from QtWidgets on every platform, and the default `QGuiApplication` mode
aborts the moment it initializes.

```sh
qml -a widget standalone/Main.qml   # run from the repo root
```

## Building a real executable

A real distributable needs an actual `QApplication` host (for the tray icon)
and a `QSurfaceFormat` with an alpha channel set *before* the QML engine
starts (for the transparent window to actually composite instead of painting
opaque black) - both of which `main.cpp` handles; that's the only reason this
needs a compile step at all.

```sh
cmake -S standalone -B standalone/build
cmake --build standalone/build
```

This produces `standalone/build/contriburg-standalone` plus a
`standalone/build/{standalone,contents}/` tree copied alongside it - the
executable loads `standalone/Main.qml` from disk relative to itself (not
compiled in as a Qt resource), and `Main.qml`'s own `"../contents/ui/..."`
imports need that sibling `contents/` directory to resolve. Keep that layout
intact when moving the build elsewhere.

### Packaging for Windows

Cross-compile or build natively on Windows with the same CMake invocation,
then run Qt's deployment tool from the *output* directory (next to the
built `.exe`) so it picks up the `standalone/` + `contents/` layout above:

```sh
windeployqt --qmldir standalone contriburg-standalone.exe
```

`--qmldir` is required (not just `--qml-files`) so `windeployqt` scans the
loose `.qml` files for their imports (including `QtQuick3D`) and bundles the
matching plugin DLLs - it can't discover them from `main.cpp` alone, since
that file never references Quick3D types itself.

## Known limitation

Confirmed (via testing under the `qml` runtime and the compiled binary
alike, on Wayland/KDE) to load and run without QML warnings or crashes. One
benign warning shows up in the log - `Failed to create grabbing popup...` on
opening the tray menu - a known `Qt.labs.platform` popup-parenting quirk on
Wayland; it doesn't affect functionality and wasn't seen with either build on
X11-style backends. Not yet verified transparency renders correctly on an
actual Windows box (nothing here should stop it - `View3D`'s
`SceneEnvironment.Transparent` plus the alpha `QSurfaceFormat` above is the
standard recipe - but GPU driver quirks are exactly the kind of thing to
sanity-check on real hardware before relying on it).
