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

    readonly property var accentPalette: [
        "#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6", "#3b82f6", "#a855f7"
    ]

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

        PerspectiveCamera {
            id: camera
            z: 600
            y: 300
            eulerRotation.x: -30
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

                    x: (weekIndex - 26) * 12
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
