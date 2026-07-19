import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtCore
import Qt.labs.platform as Platform
import "../contents/ui/DataFetcher.js" as DataFetcher

Window {
    id: window

    // Frameless + translucent + parked below normal windows + hidden from the
    // taskbar/alt-tab: the closest a plain top-level QWindow gets to "looks
    // like a desktop widget, not an app". There's no real shell-embedding
    // equivalent to a Plasma containment outside Plasma - this is the ceiling.
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint | Qt.Tool
    color: "transparent"

    // No panel to size this for, unlike the Plasmoid - remember whatever the
    // user resizes/moves it to instead.
    x: settings.windowX
    y: settings.windowY
    width: settings.windowWidth
    height: settings.windowHeight
    visible: true

    onXChanged: settings.windowX = x
    onYChanged: settings.windowY = y
    onWidthChanged: settings.windowWidth = width
    onHeightChanged: settings.windowHeight = height

    property var contributionData: []
    property bool isLoading: false
    property string errorMessage: ""
    property string tooltipText: ""

    // Mirrors contents/config/main.xml's "General" group - same keys, same
    // defaults, just QSettings-backed (ini/registry) instead of KConfigXT.
    Settings {
        id: settings
        category: "General"

        property string platform: "github"
        property string githubUsername: ""
        property string githubToken: ""
        property string gitlabUsername: ""
        property string gitlabInstanceUrl: "https://gitlab.com"
        property string colorMode: "fixed"
        property int colorRerollSeed: 0
        property color baseColor: "#21c55d"
        property real heightMultiplier: 1.0
        property int refreshInterval: 360
        property bool lockCamera: false

        property int windowX: 100
        property int windowY: 100
        property int windowWidth: 900
        property int windowHeight: 300

        onPlatformChanged: window.fetch()
        onGithubUsernameChanged: window.fetch()
        onGithubTokenChanged: window.fetch()
        onGitlabUsernameChanged: window.fetch()
        onGitlabInstanceUrlChanged: window.fetch()
    }

    // Mirrors main.xml's "Camera" group - not user-facing, just persisted
    // orbit/pan/zoom so it survives an app restart. See Scene3D.qml's
    // restoreCameraState for what the cameraZoomZ === 0 sentinel means.
    Settings {
        id: cameraSettings
        category: "Camera"

        property real rotationX: 0
        property real rotationY: 0
        property real positionX: 0
        property real positionY: 0
        property real positionZ: 0
        property real zoomZ: 0
    }

    Timer {
        id: refreshTimer
        interval: settings.refreshInterval * 60 * 1000
        running: true
        repeat: true
        onTriggered: window.fetch()
    }

    Component.onCompleted: fetch()

    function fetch() {
        var platform = settings.platform || "github"
        var isGitlab = platform === "gitlab"
        var username = isGitlab ? settings.gitlabUsername : settings.githubUsername
        var token = isGitlab ? undefined : settings.githubToken

        if (!username) {
            errorMessage = isGitlab ? "Please configure a GitLab username." : "Please configure a GitHub username."
            return
        }

        isLoading = true
        errorMessage = ""
        DataFetcher.fetchContributions(
            platform,
            username,
            token,
            settings.gitlabInstanceUrl,
            function(data) {
                contributionData = data
                isLoading = false
            },
            function(err) {
                errorMessage = err
                isLoading = false
            }
        )
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: isLoading && contributionData.length === 0
        visible: running
    }

    // Same "white box regardless of theme" reasoning as the Plasmoid's
    // main.qml: this can appear over any wallpaper before the user has
    // configured anything, and there's no Kirigami.Theme to blend with here.
    Rectangle {
        anchors.centerIn: parent
        visible: errorMessage !== ""
        color: "white"
        border.color: "#cccccc"
        border.width: 1
        radius: 4
        width: errorLabel.width + 16
        height: errorLabel.height + 12

        Label {
            id: errorLabel
            anchors.centerIn: parent
            text: errorMessage
            color: "black"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            width: Math.min(implicitWidth, window.width * 0.9 - 16)
        }
    }

    Loader {
        id: sceneLoader
        anchors.fill: parent
        source: "../contents/ui/Scene3D.qml"
        visible: errorMessage === "" && contributionData.length > 0
        onStatusChanged: {
            if (status === Loader.Error) {
                errorMessage = "Failed to load 3D scene. Ensure the Qt Quick 3D runtime is installed."
            } else if (status === Loader.Ready) {
                item.restoreCameraState(
                    cameraSettings.rotationX, cameraSettings.rotationY,
                    cameraSettings.positionX, cameraSettings.positionY, cameraSettings.positionZ,
                    cameraSettings.zoomZ
                )
            }
        }
        Binding {
            target: sceneLoader.item
            property: "contributionData"
            value: window.contributionData
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "baseColor"
            value: settings.baseColor || "#21c55d"
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "colorMode"
            value: settings.colorMode || "fixed"
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "colorRerollSeed"
            value: settings.colorRerollSeed
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "heightMultiplier"
            value: settings.heightMultiplier || 1.0
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "lockCamera"
            // Also locked while repositioning the window itself, below -
            // otherwise dragging to move would also orbit the scene underneath.
            value: settings.lockCamera || moveHandle.active
            restoreMode: Binding.RestoreBinding
        }
    }

    Connections {
        target: sceneLoader.item
        ignoreUnknownSignals: true
        function onTooltipRequested(text, x, y) {
            window.tooltipText = text
        }
        function onTooltipCleared() {
            window.tooltipText = ""
        }
        function onCameraStateSettled(rotationX, rotationY, positionX, positionY, positionZ, zoom) {
            cameraSettings.rotationX = rotationX
            cameraSettings.rotationY = rotationY
            cameraSettings.positionX = positionX
            cameraSettings.positionY = positionY
            cameraSettings.positionZ = positionZ
            cameraSettings.zoomZ = zoom
        }
    }

    Rectangle {
        id: overlayTooltip
        visible: window.tooltipText !== ""
        color: "#2b2b2b"
        border.color: "#888888"
        border.width: 1
        radius: 4
        width: tooltipLabel.width + 16
        height: tooltipLabel.height + 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16

        Label {
            id: tooltipLabel
            text: window.tooltipText
            color: "white"
            anchors.centerIn: parent
        }
    }

    // There's no panel/containment to drag this out of, unlike the Plasmoid -
    // "Move Window" from the tray menu is the substitute. While active this
    // MouseArea sits above the scene (and above lockCamera, via the Binding
    // above) so dragging repositions the window instead of orbiting the scene.
    MouseArea {
        id: moveHandle
        property bool active: false
        anchors.fill: parent
        visible: active
        enabled: active
        cursorShape: Qt.SizeAllCursor
        onPressed: window.startSystemMove()
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.source: "../contents/assets/icon.png"
        tooltip: "Contriburg"

        menu: Platform.Menu {
            Platform.MenuItem {
                text: "Move Window"
                checkable: true
                checked: moveHandle.active
                onTriggered: moveHandle.active = !moveHandle.active
            }
            Platform.MenuItem {
                text: "Settings..."
                onTriggered: {
                    settingsWindow.show()
                    settingsWindow.raise()
                    settingsWindow.requestActivate()
                }
            }
            Platform.MenuItem {
                text: "Refresh Now"
                onTriggered: window.fetch()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Quit"
                onTriggered: Qt.quit()
            }
        }

        onActivated: function(reason) {
            if (reason === Platform.SystemTrayIcon.Trigger) {
                settingsWindow.show()
                settingsWindow.raise()
                settingsWindow.requestActivate()
            }
        }
    }

    SettingsWindow {
        id: settingsWindow
        settings: settings
    }
}
