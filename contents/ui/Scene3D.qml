import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

Item {
    id: root
    property var contributionData: []
    property color baseColor: "#21c55d"
    property real heightMultiplier: 1.0
    property bool lockCamera: false
    property string colorMode: "fixed"
    property int colorRerollSeed: 0

    // Exposed for tests: ids aren't visible outside this file, so the day
    // cubes and camera controller need an explicit alias to be inspectable.
    property alias dayRepeater: repeater3d
    property alias cameraController: orbitController

    // sceneRotation/scenePosition are what OrbitCameraController's drag and
    // pan actually mutate (on sceneRoot, not the camera - see the cameraRig
    // comment below for why); cameraDistance is what its zoom mutates.
    property alias sceneRotation: sceneRoot.eulerRotation
    property alias scenePosition: sceneRoot.position
    property alias cameraDistance: camera.z

    // Camera position persistence. main.qml can't hold this logic itself (it
    // has no unit tests - Plasmoid.configuration is an attached property tied
    // to a real applet instance, unmockable) and Scene3D.qml can't touch
    // Plasmoid.configuration directly without importing org.kde.plasma.plasmoid,
    // which would make *this* file require a real Plasmoid context too and
    // break its own Loader-based tests. So the split is: main.qml only ever
    // reads/writes Plasmoid.configuration (thin pass-through, see its
    // Loader.onStatusChanged and onCameraStateSettled), and everything about
    // *what the camera does* with those numbers lives here, where it's
    // testable.
    signal cameraStateSettled(real rotationX, real rotationY, real positionX, real positionY, real positionZ, real zoom)

    function restoreCameraState(rotationX, rotationY, positionX, positionY, positionZ, zoom) {
        sceneRotation = Qt.vector3d(rotationX, rotationY, 0)
        scenePosition = Qt.vector3d(positionX, positionY, positionZ)
        // 0 means "never saved" - keep the auto-fit distance computed below
        // instead of stomping it with a stale default from a previous size.
        if (zoom > 0) {
            cameraDistance = zoom
        }
    }

    // Debounced: orbit/pan/zoom fire many times a second while dragging or
    // scrolling, and there's no need to persist on every one - only once
    // things settle.
    Timer {
        id: cameraSaveTimer
        interval: 800
        onTriggered: root.cameraStateSettled(
            root.sceneRotation.x, root.sceneRotation.y,
            root.scenePosition.x, root.scenePosition.y, root.scenePosition.z,
            root.cameraDistance
        )
    }

    onSceneRotationChanged: cameraSaveTimer.restart()
    onScenePositionChanged: cameraSaveTimer.restart()
    onCameraDistanceChanged: cameraSaveTimer.restart()

    readonly property var accentPalette: [
        "#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6", "#3b82f6", "#a855f7"
    ]

    // Grid layout constants, shared between the cube placement below and the
    // camera auto-fit math, so the two can't silently drift out of sync.
    readonly property int weekCount: 52
    readonly property real weekSpacing: 12
    readonly property real gridHalfWidth: (weekCount / 2) * weekSpacing + weekSpacing / 2 + 5

    // World-space height of the tallest bar in the current data, used by the
    // camera auto-fit below. Mirrors the per-cube hScale formula in the
    // Repeater3D delegate (count -> scale -> *100 world units) - keep the two
    // in sync if that formula ever changes.
    readonly property real maxBarHeight: {
        var maxCount = 0
        for (var i = 0; i < contributionData.length; i++) {
            var c = (contributionData[i] && contributionData[i].count) || 0
            if (c > maxCount) maxCount = c
        }
        var hScale = maxCount === 0 ? 0.05 : (0.1 + maxCount * 0.1 * heightMultiplier)
        return hScale * 100
    }

    // seed is otherwise unused: passing it lets a caller's binding depend on it
    // (see cubeColor below), so bumping colorRerollSeed forces a fresh roll.
    function randomShade(seed) {
        var swatch = accentPalette[Math.floor(Math.random() * accentPalette.length)]
        var factor = 1.0 + Math.random() * 0.7
        return Math.random() < 0.5 ? Qt.lighter(swatch, factor) : Qt.darker(swatch, factor)
    }

    signal tooltipRequested(string text, real x, real y)
    signal tooltipCleared()

    View3D {
        id: view3D
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "transparent"
            backgroundMode: SceneEnvironment.Transparent
            lightProbe: Texture {
                // simple ambient
            }
            // Ambient light workaround for missing property if needed, but usually DirectionalLight is enough
        }

        // The camera itself carries no rotation of its own - only translates
        // along its local Z axis (which is exactly what OrbitCameraController's
        // zoom does). All the "look downward at an angle" framing lives on this
        // rig instead. That split matters: if the camera held its own fixed
        // pitch, zooming (changing distance) would drift the look-at point off
        // the rig's pivot and the content would slide toward frame's edge as
        // you zoom in - the rig keeps whatever's at its own origin centered in
        // frame at any zoom level.
        Node {
            id: cameraRig
            eulerRotation.x: -30
            // Whatever world Y this is set to always renders at the exact
            // vertical center of frame (the camera below only ever translates
            // straight back from this point, never re-aims). Matches the
            // camera's heightFitZ below, which was derived assuming the frame
            // is split evenly around maxBarHeight / 2 - keep the two in sync,
            // or the tallest bar and the ground plane won't both fit anymore.
            y: root.maxBarHeight / 2

            PerspectiveCamera {
                id: camera
                fieldOfView: 55
                // Horizontal, not vertical: the grid is very wide and short, so
                // width should stay a fixed, sane angle (locking to vertical
                // instead would make the horizontal FOV balloon to 100°+ at a
                // typical wide/short panel aspect ratio - a fisheye, not "zoomed
                // in", and the actual cause of an earlier attempt at this that
                // rendered a distorted, clipped mess). With horizontal locked,
                // the vertical FOV instead auto-shrinks for wide/short viewports,
                // which is exactly the "don't waste vertical space" behavior we
                // want, and grows again for taller/squarer ones.
                fieldOfViewOrientation: PerspectiveCamera.Horizontal

                // Initial distance only: chosen so the full week-wide grid - and
                // the tallest bar currently in the data - fit the viewport.
                // Recomputed whenever the widget is resized or the data changes -
                // but once the user zooms, OrbitCameraController writes camera.z
                // directly, which drops this binding; that's intended, manual
                // zoom should stick rather than snap back on resize.
                readonly property real halfFovH: fieldOfView / 2 * Math.PI / 180
                readonly property real aspect: Math.max(view3D.width / Math.max(view3D.height, 1), 0.3)
                readonly property real halfFovV: Math.atan(Math.tan(halfFovH) / aspect)
                readonly property real widthFitZ: root.gridHalfWidth / Math.tan(halfFovH) * 1.3
                readonly property real heightFitZ: (root.maxBarHeight / 2 + 15) / Math.tan(halfFovV) * 1.3

                z: Math.min(3000, Math.max(150, Math.max(widthFitZ, heightFitZ)))
            }
        }

        DirectionalLight {
            eulerRotation.x: -45
            eulerRotation.y: -45
            castsShadow: true
            brightness: 1.2
            ambientColor: "#808080" // provides ambient light
        }

        Node {
            id: sceneRoot

            Repeater3D {
                id: repeater3d
                model: root.contributionData

                Model {
                    source: "#Cube"
                    pickable: true

                    // Each block represents one day
                    // The data is basically an array of 365/366 days, we arrange them in a grid 52 cols x 7 rows
                    // Assuming data starts from oldest to newest, standard git punchcard is left-to-right
                    // i = index. week = Math.floor(index / 7), dayOfWeek = index % 7
                    property int weekIndex: Math.floor(index / 7)
                    property int dayIndex: index % 7

                    x: (weekIndex - root.weekCount / 2) * root.weekSpacing
                    z: (dayIndex - 3) * 12
                    
                    // Base cube is 100x100x100. Let's scale it.
                    property real count: modelData.count || 0
                    property real level: modelData.level || 0
                    
                    // Height minimum is 0.1 so days with 0 contributions show as a flat tile
                    property real hScale: count === 0 ? 0.05 : (0.1 + count * 0.1 * root.heightMultiplier)
                    
                    scale: Qt.vector3d(0.1, hScale, 0.1)
                    y: (hScale * 100) / 2 // Move up so bottom is at y=0

                    property string dateStr: modelData.date || ""
                    property int contribCount: count

                    // Rolled once per cube when it's created (each fetch/refresh recreates
                    // the Repeater3D delegates, so this reshuffles then too) or whenever
                    // colorRerollSeed changes (the config UI's manual "Reroll" button bumps it).
                    property color cubeColor: root.colorMode === "random"
                        ? root.randomShade(root.colorRerollSeed)
                        : root.baseColor

                    materials: PrincipledMaterial {
                        baseColor: {
                            if (level === 0) return "#ebedf0"
                            if (root.colorMode === "random") return cubeColor
                            if (level === 1) return Qt.lighter(root.baseColor, 1.6)
                            if (level === 2) return Qt.lighter(root.baseColor, 1.2)
                            if (level === 3) return root.baseColor
                            return Qt.darker(root.baseColor, 1.2)
                        }
                        roughness: 0.4
                    }
                }
            }
        }

        OrbitCameraController {
            id: orbitController
            anchors.fill: parent
            origin: sceneRoot
            camera: camera
            mouseEnabled: !root.lockCamera
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton // Let OrbitCameraController handle clicks/drags

            onPositionChanged: function(mouse) {
                var pickResult = view3D.pick(mouse.x, mouse.y)
                if (pickResult.objectHit) {
                    var hitModel = pickResult.objectHit
                    if (hitModel.dateStr) {
                        var text = hitModel.contribCount + " contributions on " + hitModel.dateStr
                        root.tooltipRequested(text, mouse.x, mouse.y)
                    }
                } else {
                    root.tooltipCleared()
                }
            }
        }
    }
}
