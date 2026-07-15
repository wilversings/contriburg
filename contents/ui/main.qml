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
        function onGitlabTokenChanged() { fetch() }
        function onGitlabInstanceUrlChanged() { fetch() }
    }

    function fetch() {
        var platform = Plasmoid.configuration.platform || "github"
        var isGitlab = platform === "gitlab"
        var username = isGitlab ? Plasmoid.configuration.gitlabUsername : Plasmoid.configuration.githubUsername
        var token = isGitlab ? Plasmoid.configuration.gitlabToken : Plasmoid.configuration.githubToken

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

    PlasmaComponents.Label {
        anchors.centerIn: parent
        text: errorMessage
        visible: errorMessage !== ""
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: parent.width * 0.9
    }

    Loader {
        id: sceneLoader
        anchors.fill: parent
        source: "Scene3D.qml"
        visible: !isLoading && errorMessage === "" && contributionData.length > 0
        onStatusChanged: {
            if (status === Loader.Error) {
                errorMessage = "Failed to load 3D scene. Ensure QtQuick3D is installed."
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
    }

    PlasmaComponents.ToolTip {
        id: sceneTooltip
        visible: tooltipText !== ""
        text: tooltipText
        // Optional: position mapping
    }

    // A simple overlay label since native tooltip might be tricky with mouse area inside Loader
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
