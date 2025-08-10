import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Rectangle {
    id: root
    anchors.fill: parent

    // Theme config (from theme.conf)
    property string fontFamily: (config && config.Font) ? config.Font : "Noto Sans"
    property int fontSize: (config && config.FontSize) ? parseInt(config.FontSize) : 11
    property bool showClock: (config && config.ClockEnabled === "true")
    property bool customBg: (config && config.CustomBackground === "true")
    property string bgPath: (config && config.Background) ? config.Background : ""

    // Palette (from theme.conf [Colors])
    property color backgroundColor: (config && config["Colors.background"]) ? config["Colors.background"] : "#0f1117"
    property color textColor: (config && config["Colors.foreground"]) ? config["Colors.foreground"] : "#e6edf3"
    property color accentColor: (config && config["Colors.accent"]) ? config["Colors.accent"] : "#79c0ff"

    // Background
    // Solid color fallback with layered overlay; avoid inline Gradient for broader compatibility
    color: customBg ? backgroundColor : "#0f141d"

    Image {
        id: bgImage
        anchors.fill: parent
        visible: customBg && bgPath.length > 0
        source: bgPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        mipmap: true
    }

    // Subtle overlay for tranquil look
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.18
    }

    // Top clock (optional)
    Text {
        id: clock
        visible: showClock
        anchors.top: parent.top
        anchors.topMargin: 48
        anchors.horizontalCenter: parent.horizontalCenter
        color: textColor
        font.family: fontFamily
        font.pixelSize: 44
        text: Qt.formatDateTime(new Date(), "hh:mm")
    }

    Timer {
        interval: 60000
        running: showClock
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm")
    }

    // Login panel (modern, subtle, centered)
    Rectangle {
        id: panel
        width: Math.min(parent.width * 0.34, 560)
        radius: 16
        color: "#141a24"
        opacity: 0.92
        border.color: "#1f2833"
        border.width: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Text {
                text: "Welcome"
                color: textColor
                font.family: fontFamily
                font.pixelSize: fontSize + 10
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: userField
                placeholderText: "Username"
                text: (typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : ""
                color: textColor
                selectionColor: accentColor
                Layout.fillWidth: true
                focus: true
                font.family: fontFamily
                font.pixelSize: fontSize
                onAccepted: passwordField.focus = true
                background: Rectangle { radius: 10; color: "#0f141c"; border.color: "#1c2532" }
            }

            TextField {
                id: passwordField
                placeholderText: "Password"
                echoMode: TextInput.Password
                color: textColor
                selectionColor: accentColor
                Layout.fillWidth: true
                font.family: fontFamily
                font.pixelSize: fontSize
                onAccepted: login()
                background: Rectangle { radius: 10; color: "#0f141c"; border.color: "#1c2532" }
            }

            Button {
                id: loginButton
                text: "Log In"
                Layout.fillWidth: true
                contentItem: Text {
                    text: loginButton.text
                    color: "#0f1117"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: fontFamily
                    font.pixelSize: fontSize
                    font.bold: true
                }
                background: Rectangle { radius: 10; color: accentColor }
                onClicked: login()
            }

            Text {
                id: statusText
                color: textColor
                opacity: 0.85
                font.pixelSize: fontSize - 1
                font.family: fontFamily
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }

    function login() {
        if (typeof sddm !== "undefined" && sddm.login !== undefined) {
            sddm.login(userField.text, passwordField.text, "");
        }
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() { statusText.text = "Login failed. Try again."; passwordField.selectAll(); passwordField.forceActiveFocus() }
    }
}


