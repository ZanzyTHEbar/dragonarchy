import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Rectangle {
    anchors.fill: parent
    color: "#0b0d12"
    property color textColor: "#d0d6e1"
    property color accentColor: "#6cb6ff"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 14
        width: Math.min(parent.width * 0.32, 520)
        TextField { id: u; placeholderText: "Username"; Layout.fillWidth: true; color: textColor; selectionColor: accentColor }
        TextField { id: p; placeholderText: "Password"; echoMode: TextInput.Password; Layout.fillWidth: true; color: textColor; selectionColor: accentColor; onAccepted: login() }
        Button { text: "Log In"; Layout.fillWidth: true; background: Rectangle { radius: 8; color: accentColor }; onClicked: login() }
    }

    function login() { if (typeof sddm !== "undefined" && sddm.login) sddm.login(u.text, p.text, "") }
}


