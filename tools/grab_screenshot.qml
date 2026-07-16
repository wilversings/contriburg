import QtQuick

// Renders Scene3D.qml offscreen and saves it as a transparent PNG - useful
// for KDE Store listing screenshots, README images, etc. See
// tools/README.md for usage. Doesn't touch a live Plasmoid/panel at all:
// Scene3D.qml has no Plasmoid.configuration dependency, so it loads here
// exactly like it does under tests/tst_scene3d.qml.
Item {
    id: root
    // Qt.application.arguments is [executable, this script's path, ...args],
    // so user-supplied args start at index 2. Usage:
    //   qml-qt6 grab_screenshot.qml [outputPath] [width] [height] [colorMode] [baseColor]
    width: Qt.application.arguments.length > 3 ? parseInt(Qt.application.arguments[3]) : 1200
    height: Qt.application.arguments.length > 4 ? parseInt(Qt.application.arguments[4]) : 600
    visible: false

    property string outputPath: Qt.application.arguments.length > 2 ? Qt.application.arguments[2] : "scene.png"
    property string colorMode: Qt.application.arguments.length > 5 ? Qt.application.arguments[5] : "fixed"
    property string baseColor: Qt.application.arguments.length > 6 ? Qt.application.arguments[6] : "#21c55d"

    // A plausible-looking year of contributions, weighted toward "some
    // activity most days" so the rendered grid doesn't look sparse/fake.
    property var sampleData: {
        var days = []
        var start = new Date(2025, 6, 16) // 52 weeks back from today's date
        for (var i = 0; i < 364; i++) {
            var d = new Date(start)
            d.setDate(d.getDate() + i)
            var roll = Math.random()
            var count = roll < 0.15 ? 0
                : roll < 0.45 ? Math.floor(Math.random() * 3) + 1
                : roll < 0.75 ? Math.floor(Math.random() * 5) + 4
                : roll < 0.93 ? Math.floor(Math.random() * 6) + 9
                : Math.floor(Math.random() * 8) + 15
            var level = count === 0 ? 0 : count < 4 ? 1 : count < 9 ? 2 : count < 15 ? 3 : 4
            days.push({
                date: d.toISOString().slice(0, 10),
                count: count,
                level: level
            })
        }
        return days
    }

    Loader {
        id: scene
        anchors.fill: parent
        source: "../contents/ui/Scene3D.qml"
    }

    Component.onCompleted: {
        if (scene.status !== Loader.Ready) {
            console.log("ERROR: failed to load Scene3D.qml (status " + scene.status + ") - is QtQuick3D installed?")
            Qt.exit(1)
            return
        }
        scene.item.contributionData = root.sampleData
        scene.item.colorMode = root.colorMode
        scene.item.baseColor = root.baseColor
        // Give the Repeater3D delegates and the camera auto-fit one frame to
        // actually render before grabbing - grabbing on the same tick as
        // the data assignment can capture an empty/partial frame.
        Qt.callLater(function() {
            root.grabToImage(function(result) {
                if (!result.saveToFile(root.outputPath)) {
                    console.log("ERROR: failed to save " + root.outputPath)
                    Qt.exit(1)
                    return
                }
                console.log("Saved " + root.outputPath)
                Qt.exit(0)
            })
        })
    }
}
