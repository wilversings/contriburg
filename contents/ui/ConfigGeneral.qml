import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

Kirigami.FormLayout {
    id: page

    property string cfg_platform: "github"
    property alias cfg_githubUsername: usernameField.text
    property alias cfg_githubToken: tokenField.text
    property alias cfg_gitlabUsername: gitlabUsernameField.text
    property alias cfg_gitlabInstanceUrl: gitlabInstanceField.text
    property alias cfg_heightMultiplier: heightSlider.value
    property alias cfg_refreshInterval: refreshSpinBox.value
    property alias cfg_lockCamera: lockCameraCheckBox.checked
    property string cfg_colorMode: "fixed"
    property int cfg_colorRerollSeed: 0

    property color cfg_baseColor: "#21c55d"

    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Data Source"
    }

    ComboBox {
        id: platformComboBox
        Kirigami.FormData.label: "Source:"
        model: ["GitHub", "GitLab"]
        property var values: ["github", "gitlab"]
        currentIndex: Math.max(0, values.indexOf(page.cfg_platform))
        onActivated: page.cfg_platform = values[currentIndex]
    }

    TextField {
        id: usernameField
        visible: page.cfg_platform === "github"
        Kirigami.FormData.label: "GitHub Username:"
        placeholderText: "e.g. torvalds"
    }

    TextField {
        id: tokenField
        visible: page.cfg_platform === "github"
        Kirigami.FormData.label: "Personal Access Token (optional):"
        placeholderText: "ghp_..."
        echoMode: TextInput.Password
    }

    TextField {
        id: gitlabUsernameField
        visible: page.cfg_platform === "gitlab"
        Kirigami.FormData.label: "GitLab Username:"
        placeholderText: "e.g. gitlab-org"
    }

    TextField {
        id: gitlabInstanceField
        visible: page.cfg_platform === "gitlab"
        Kirigami.FormData.label: "GitLab Instance URL:"
        placeholderText: "https://gitlab.com"
    }

    SpinBox {
        id: refreshSpinBox
        Kirigami.FormData.label: "Refresh Interval (minutes):"
        from: 10
        to: 1440
        stepSize: 10
    }

    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Appearance"
    }

    Slider {
        id: heightSlider
        Kirigami.FormData.label: "Height Multiplier:"
        from: 0.1
        to: 5.0
        stepSize: 0.1
    }

    CheckBox {
        id: lockCameraCheckBox
        Kirigami.FormData.label: "Lock Camera:"
        text: "Prevent moving the scene with the mouse"
    }

    RowLayout {
        Kirigami.FormData.label: "Color Mode:"

        ComboBox {
            id: colorModeComboBox
            model: ["Fixed", "Random"]
            property var values: ["fixed", "random"]
            currentIndex: Math.max(0, values.indexOf(page.cfg_colorMode))
            onActivated: page.cfg_colorMode = values[currentIndex]
        }

        Rectangle {
            visible: page.cfg_colorMode === "fixed"
            width: 32
            height: 32
            color: page.cfg_baseColor
            border.color: Kirigami.Theme.textColor
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: colorDialog.open()
            }
        }

        Button {
            visible: page.cfg_colorMode === "random"
            text: "Reroll"
            icon.name: "view-refresh"
            onClicked: page.cfg_colorRerollSeed = page.cfg_colorRerollSeed + 1
        }
    }

    ColorDialog {
        id: colorDialog
        title: "Choose a Base Color"
        selectedColor: page.cfg_baseColor
        onAccepted: page.cfg_baseColor = selectedColor
    }
}