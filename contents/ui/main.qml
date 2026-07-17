import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "DataFetcher.js" as DataFetcher

PlasmoidItem {
    id: widget

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property var contributionData: []
    property bool isLoading: false
    property string errorMessage: ""
    property string tooltipText: ""

    Timer {
        id: refreshTimer
        interval: Plasmoid.configuration.refreshInterval * 60 * 1000
        running: true
        repeat: true
        onTriggered: fetch()
    }

    Component.onCompleted: {
        fetch()
    }

    Connections {
        target: Plasmoid.configuration
        function onPlatformChanged() { fetch() }
        function onGithubUsernameChanged() { fetch() }
        function onGithubTokenChanged() { fetch() }
        function onGitlabUsernameChanged() { fetch() }
        function onGitlabInstanceUrlChanged() { fetch() }
    }

    function fetch() {
        var platform = Plasmoid.configuration.platform || "github"
        var isGitlab = platform === "gitlab"
        var username = isGitlab ? Plasmoid.configuration.gitlabUsername : Plasmoid.configuration.githubUsername
        var token = isGitlab ? undefined : Plasmoid.configuration.githubToken

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
            Plasmoid.configuration.gitlabInstanceUrl,
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

    PlasmaComponents.BusyIndicator {
        anchors.centerIn: parent
        running: isLoading && contributionData.length === 0
        visible: running
    }

    // White box (not theme-colored, unlike overlayTooltip below) - this
    // message can appear as soon as the widget loads, before the user has
    // set anything up, and the widget's background is transparent. If it's
    // dragged onto a light panel/wallpaper with light-on-light theme text,
    // it can look like nothing rendered at all rather than like a message
    // waiting to be read.
    Rectangle {
        anchors.centerIn: parent
        visible: errorMessage !== ""
        color: "white"
        border.color: "#cccccc"
        border.width: 1
        radius: 4
        width: errorLabel.width + 16
        height: errorLabel.height + 12

        PlasmaComponents.Label {
            id: errorLabel
            anchors.centerIn: parent
            text: errorMessage
            color: "black"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            width: Math.min(implicitWidth, widget.width * 0.9 - 16)
        }
    }

    Loader {
        id: sceneLoader
        anchors.fill: parent
        source: "Scene3D.qml"
        visible: errorMessage === "" && contributionData.length > 0
        onStatusChanged: {
            if (status === Loader.Error) {
                errorMessage = "Failed to load 3D scene. Ensure QtQuick3D is installed."
            } else if (status === Loader.Ready) {
                // One-time restore, not a Binding: the user's saved orbit/pan
                // should apply once at startup, then be free to diverge as they
                // interact. What these numbers mean (e.g. cameraZoomZ === 0
                // meaning "never saved") is Scene3D.qml's concern, not ours.
                item.restoreCameraState(
                    Plasmoid.configuration.cameraRotationX, Plasmoid.configuration.cameraRotationY,
                    Plasmoid.configuration.cameraPositionX, Plasmoid.configuration.cameraPositionY, Plasmoid.configuration.cameraPositionZ,
                    Plasmoid.configuration.cameraZoomZ
                )
            }
        }
        Binding {
            target: sceneLoader.item
            property: "contributionData"
            value: widget.contributionData
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "baseColor"
            value: Plasmoid.configuration.baseColor || "#21c55d"
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "colorMode"
            value: Plasmoid.configuration.colorMode || "fixed"
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "colorRerollSeed"
            value: Plasmoid.configuration.colorRerollSeed
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "heightMultiplier"
            value: Plasmoid.configuration.heightMultiplier || 1.0
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: sceneLoader.item
            property: "lockCamera"
            value: Plasmoid.configuration.lockCamera
            restoreMode: Binding.RestoreBinding
        }
    }

    Connections {
        target: sceneLoader.item
        ignoreUnknownSignals: true
        function onTooltipRequested(text, x, y) {
            tooltipText = text
        }
        function onTooltipCleared() {
            tooltipText = ""
        }
        // Scene3D.qml debounces this itself (dragging/zooming fire many times
        // a second) and only emits once things settle - this is just the
        // Plasmoid.configuration write, nothing else.
        function onCameraStateSettled(rotationX, rotationY, positionX, positionY, positionZ, zoom) {
            Plasmoid.configuration.cameraRotationX = rotationX
            Plasmoid.configuration.cameraRotationY = rotationY
            Plasmoid.configuration.cameraPositionX = positionX
            Plasmoid.configuration.cameraPositionY = positionY
            Plasmoid.configuration.cameraPositionZ = positionZ
            Plasmoid.configuration.cameraZoomZ = zoom
        }
    }

    // Custom overlay label (not PlasmaComponents.ToolTip - that's positioned by
    // Plasma itself, not by the mouse's actual position over the 3D scene,
    // and having both up at once rendered a duplicate: one near the top,
    // one down here).
    Rectangle {
        id: overlayTooltip
        visible: tooltipText !== ""
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.textColor
        border.width: 1
        radius: 4
        width: tooltipLabel.width + 16
        height: tooltipLabel.height + 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16

        PlasmaComponents.Label {
            id: tooltipLabel
            text: tooltipText
            anchors.centerIn: parent
        }
    }
}
