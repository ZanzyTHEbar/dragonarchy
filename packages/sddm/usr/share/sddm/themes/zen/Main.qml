import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Rectangle {
    id: root
    anchors.fill: parent
    color: "#0f1117" // background

    property color textColor: "#e6edf3"
    property color accentColor: "#79c0ff"

    // Simple clock at top
    Text {
        id: clock
        anchors.top: parent.top
        anchors.topMargin: 48
        anchors.horizontalCenter: parent.horizontalCenter
        color: root.textColor
        font.pixelSize: 48
        text: Qt.formatDateTime(new Date(), "hh:mm")
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm")
    }

    // Login panel (minimal)
    Rectangle {
        id: panel
        width: Math.min(parent.width * 0.32, 520)
        height: implicitHeight
        radius: 14
        color: "#151923"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 24
        border.color: "#1e2633"
        border.width: 1

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Text {
                text: "Welcome"
                color: root.textColor
                font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: userField
                placeholderText: "Username"
                color: root.textColor
                selectionColor: root.accentColor
                Layout.fillWidth: true
                focus: true
                onAccepted: passwordField.focus = true
            }

            TextField {
                id: passwordField
                placeholderText: "Password"
                echoMode: TextInput.Password
                color: root.textColor
                selectionColor: root.accentColor
                Layout.fillWidth: true
                onAccepted: login()
            }

            Button {
                id: loginButton
                text: "Log In"
                Layout.fillWidth: true
                contentItem: Text { text: loginButton.text; color: "#0f1117"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 8; color: root.accentColor }
                onClicked: login()
            }

            Text {
                id: statusText
                color: root.textColor
                opacity: 0.8
                font.pixelSize: 12
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }

    function login() {
        // Third arg (session) left empty to use default session
        if (typeof sddm !== "undefined" && sddm.login !== undefined) {
            sddm.login(userField.text, passwordField.text, "");
        }
    }

    // Basic feedback hooks (best-effort)
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() { statusText.text = "Login failed. Try again."; passwordField.selectAll(); passwordField.forceActiveFocus() }
    }
}


