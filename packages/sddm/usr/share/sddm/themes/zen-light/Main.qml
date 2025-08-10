import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Rectangle {
    anchors.fill: parent
    color: "#f7f7f9"
    property color textColor: "#0f1117"
    property color accentColor: "#2563eb"

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


