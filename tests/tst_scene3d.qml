import QtQuick
import QtTest

Item {
    id: root
    width: 400
    height: 400

    property var sampleData: [
        { date: "2026-01-01", count: 0, level: 0 },
        { date: "2026-01-02", count: 2, level: 1 },
        { date: "2026-01-03", count: 5, level: 2 },
        { date: "2026-01-04", count: 8, level: 3 },
        { date: "2026-01-05", count: 12, level: 4 }
    ]

    // 40 contributing days, used by the random-mode diversity/reroll tests
    // where a handful of samples would be too likely to coincidentally match.
    property var manyContributingDays: {
        var days = []
        for (var i = 0; i < 40; i++) {
            days.push({ date: "2026-02-" + (i + 1), count: 3, level: 2 })
        }
        return days
    }

    Loader {
        id: sceneLoader
        source: "../contents/ui/Scene3D.qml"
        active: false
    }

    function cubeColors() {
        var repeater = sceneLoader.item.dayRepeater
        var colors = []
        for (var i = 0; i < repeater.count; i++) {
            colors.push(repeater.objectAt(i).materials[0].baseColor.toString())
        }
        return colors
    }

    TestCase {
        name: "Scene3DTests"
        when: windowShown

        function init() {
            sceneLoader.active = true
            verify(sceneLoader.item !== null, "Scene3D should load successfully")
            sceneLoader.item.baseColor = "#21c55d"
            sceneLoader.item.heightMultiplier = 1.0
            sceneLoader.item.colorMode = "fixed"
            sceneLoader.item.colorRerollSeed = 0
            sceneLoader.item.contributionData = root.sampleData
            wait(50)
        }

        function cleanup() {
            sceneLoader.active = false
        }

        function test_oneCubePerDay() {
            compare(sceneLoader.item.dayRepeater.count, root.sampleData.length)
        }

        function test_weekAndDayIndexFromFlatIndex() {
            // index 2 -> week 0, day 2 (Math.floor(2/7)=0, 2%7=2)
            var cube = sceneLoader.item.dayRepeater.objectAt(2)
            compare(cube.weekIndex, 0)
            compare(cube.dayIndex, 2)
        }

        function test_zeroContributionsRenderAsFlatTile() {
            var cube = sceneLoader.item.dayRepeater.objectAt(0)
            compare(cube.count, 0)
            compare(cube.hScale, 0.05)
        }

        function test_heightScalesWithCountAndMultiplier() {
            sceneLoader.item.heightMultiplier = 2.0
            wait(20)
            var cube = sceneLoader.item.dayRepeater.objectAt(4) // count: 12
            fuzzyCompare(cube.hScale, 0.1 + 12 * 0.1 * 2.0, 0.001)
        }

        function test_fixedMode_colorsFollowContributionLevel() {
            var expected = [
                "#ebedf0",
                Qt.lighter("#21c55d", 1.6).toString(),
                Qt.lighter("#21c55d", 1.2).toString(),
                "#21c55d",
                Qt.darker("#21c55d", 1.2).toString()
            ]
            for (var i = 0; i < expected.length; i++) {
                var actual = sceneLoader.item.dayRepeater.objectAt(i).materials[0].baseColor.toString()
                compare(actual, Qt.color(expected[i]).toString(), "level " + i + " color mismatch")
            }
        }

        function test_randomMode_zeroLevelStaysGray() {
            sceneLoader.item.colorMode = "random"
            wait(20)
            var cube = sceneLoader.item.dayRepeater.objectAt(0) // level 0
            compare(cube.materials[0].baseColor.toString(), Qt.color("#ebedf0").toString())
        }

        function test_randomMode_variesAcrossCubes() {
            sceneLoader.item.contributionData = root.manyContributingDays
            sceneLoader.item.colorMode = "random"
            wait(50)
            var colors = root.cubeColors()
            var unique = {}
            for (var i = 0; i < colors.length; i++) unique[colors[i]] = true
            verify(Object.keys(unique).length > 1,
                "expected multiple distinct colors across " + colors.length + " cubes, got: " + JSON.stringify(colors))
        }

        function test_colorRerollSeed_reshufflesColors() {
            sceneLoader.item.contributionData = root.manyContributingDays
            sceneLoader.item.colorMode = "random"
            wait(50)
            var before = root.cubeColors()

            sceneLoader.item.colorRerollSeed = sceneLoader.item.colorRerollSeed + 1
            wait(50)
            var after = root.cubeColors()

            var changed = 0
            for (var i = 0; i < before.length; i++) {
                if (before[i] !== after[i]) changed++
            }
            verify(changed > 0, "expected at least one cube to change color after a reroll")
        }

        function test_lockCamera_disablesOrbitControllerMouse() {
            compare(sceneLoader.item.cameraController.mouseEnabled, true)
            sceneLoader.item.lockCamera = true
            wait(20)
            compare(sceneLoader.item.cameraController.mouseEnabled, false)
        }
    }
}
