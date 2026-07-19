import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Plain QtQuick.Controls re-expression of contents/ui/ConfigGeneral.qml -
// same fields, same layout intent, minus Kirigami.FormLayout/KCM (KDE
// Frameworks aren't available outside Plasma). Binds straight to the
// Settings object from Main.qml instead of going through cfg_* aliases,
// since there's no KDeclarative config loader here to matter for.
ApplicationWindow {
    id: page
    title: "Contriburg Settings"
    width: 420
    height: 480
    visible: false

    // Injected by Main.qml: the QtCore `Settings` instance holding the
    // General group (see Main.qml for the matching Camera group, which has
    // no control here - same "persisted but not user-facing" pattern as
    // contents/config/main.xml's Camera group).
    property var settings

    GridLayout {
        anchors.fill: parent
        anchors.margins: 16
        columns: 2
        columnSpacing: 12
        rowSpacing: 10

        Label { text: "Data Source"; font.bold: true; Layout.columnSpan: 2 }

        Label { text: "Source:" }
        ComboBox {
            id: platformComboBox
            Layout.fillWidth: true
            model: ["GitHub", "GitLab"]
            property var values: ["github", "gitlab"]
            currentIndex: Math.max(0, values.indexOf(page.settings ? page.settings.platform : "github"))
            onActivated: page.settings.platform = values[currentIndex]
        }

        Label {
            text: "GitHub Username:"
            visible: page.settings && page.settings.platform === "github"
        }
        TextField {
            Layout.fillWidth: true
            visible: page.settings && page.settings.platform === "github"
            placeholderText: "e.g. torvalds"
            text: page.settings ? page.settings.githubUsername : ""
            onEditingFinished: page.settings.githubUsername = text
        }

        Label {
            text: "Personal Access Token (optional):"
            visible: page.settings && page.settings.platform === "github"
        }
        TextField {
            Layout.fillWidth: true
            visible: page.settings && page.settings.platform === "github"
            placeholderText: "ghp_..."
            echoMode: TextInput.Password
            text: page.settings ? page.settings.githubToken : ""
            onEditingFinished: page.settings.githubToken = text
        }

        Label {
            text: "GitLab Username:"
            visible: page.settings && page.settings.platform === "gitlab"
        }
        TextField {
            Layout.fillWidth: true
            visible: page.settings && page.settings.platform === "gitlab"
            placeholderText: "e.g. gitlab-org"
            text: page.settings ? page.settings.gitlabUsername : ""
            onEditingFinished: page.settings.gitlabUsername = text
        }

        Label {
            text: "GitLab Instance URL:"
            visible: page.settings && page.settings.platform === "gitlab"
        }
        TextField {
            Layout.fillWidth: true
            visible: page.settings && page.settings.platform === "gitlab"
            placeholderText: "https://gitlab.com"
            text: page.settings ? page.settings.gitlabInstanceUrl : ""
            onEditingFinished: page.settings.gitlabInstanceUrl = text
        }

        Label { text: "Refresh Interval (minutes):" }
        SpinBox {
            Layout.fillWidth: true
            from: 10
            to: 1440
            stepSize: 10
            value: page.settings ? page.settings.refreshInterval : 360
            onValueModified: page.settings.refreshInterval = value
        }

        Label { text: "Appearance"; font.bold: true; Layout.columnSpan: 2; Layout.topMargin: 8 }

        Label { text: "Height Multiplier:" }
        Slider {
            id: heightSlider
            Layout.fillWidth: true
            from: 0.1
            to: 5.0
            stepSize: 0.1
            value: page.settings ? page.settings.heightMultiplier : 1.0
            onMoved: page.settings.heightMultiplier = value
        }

        Label { text: "Lock Camera:" }
        CheckBox {
            text: "Prevent moving the scene with the mouse"
            checked: page.settings ? page.settings.lockCamera : false
            onToggled: page.settings.lockCamera = checked
        }

        Label { text: "Color Mode:" }
        RowLayout {
            ComboBox {
                id: colorModeComboBox
                model: ["Fixed", "Random"]
                property var values: ["fixed", "random"]
                currentIndex: Math.max(0, values.indexOf(page.settings ? page.settings.colorMode : "fixed"))
                onActivated: page.settings.colorMode = values[currentIndex]
            }

            Rectangle {
                visible: page.settings && page.settings.colorMode === "fixed"
                width: 32
                height: 32
                color: page.settings ? page.settings.baseColor : "#21c55d"
                border.color: "#888888"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: colorDialog.open()
                }
            }

            Button {
                visible: page.settings && page.settings.colorMode === "random"
                text: "Reroll"
                onClicked: page.settings.colorRerollSeed = page.settings.colorRerollSeed + 1
            }
        }

        Item { Layout.fillHeight: true; Layout.columnSpan: 2 }
    }

    ColorDialog {
        id: colorDialog
        title: "Choose a Base Color"
        selectedColor: page.settings ? page.settings.baseColor : "#21c55d"
        onAccepted: page.settings.baseColor = selectedColor
    }
}
