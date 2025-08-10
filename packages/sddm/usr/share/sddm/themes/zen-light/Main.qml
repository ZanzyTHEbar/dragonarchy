import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0

Rectangle {
    id: root
    anchors.fill: parent

    // Config
    property string fontFamily: (config && config.Font) ? config.Font : "Noto Sans"
    property int fontSize: (config && config.FontSize) ? parseInt(config.FontSize) : 11
    property bool customBg: (config && config.CustomBackground === "true")
    property string bgPath: (config && config.Background) ? config.Background : ""
    property color textColor: (config && config["Colors.foreground"]) ? config["Colors.foreground"] : "#0f1117"
    property color accentColor: (config && config["Colors.accent"]) ? config["Colors.accent"] : "#2563eb"

    // Background with optional image/parallax
    Item { id: bgLayer; anchors.fill: parent
        Rectangle { anchors.fill: parent; visible: !customBg; gradient: Gradient { GradientStop { position: 0; color: "#f7f9fb" } GradientStop { position: 1; color: "#eef2f7" } } }
        Image { id: bgImage; anchors.centerIn: parent; width: parent.width*1.08; height: parent.height*1.08; x: parallaxX; y: parallaxY; visible: customBg && bgPath.length>0; source: bgPath; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; mipmap: true }
    }
    Rectangle { anchors.fill: parent; color: "#ffffff"; opacity: 0.06 }

    // Parallax
    property real parallaxFactor: 0.02
    property real parallaxX: 0
    property real parallaxY: 0
    Behavior on parallaxX { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    Behavior on parallaxY { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: { var cx=width/2; var cy=height/2; parallaxX=-(mouse.x-cx)*parallaxFactor; parallaxY=-(mouse.y-cy)*parallaxFactor; } }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.34, 560)
        radius: 16
        color: "#ffffff"
        opacity: 0.92
        border.color: "#e5e7eb"
        border.width: 1
        RectangularGlow { anchors.fill: parent; glowRadius: 22; spread: 0.10; cornerRadius: panel.radius; color: Qt.rgba(0.15,0.35,0.92,0.10); z: -1 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16
            TextField { id: u; placeholderText: "Username"; Layout.fillWidth: true; color: textColor; selectionColor: accentColor; font.family: fontFamily; font.pixelSize: fontSize; background: Rectangle { radius: 10; color: "#f2f4f7"; border.color: "#e5e7eb" } }
            TextField { id: p; placeholderText: "Password"; echoMode: TextInput.Password; Layout.fillWidth: true; color: textColor; selectionColor: accentColor; font.family: fontFamily; font.pixelSize: fontSize; background: Rectangle { radius: 10; color: "#f2f4f7"; border.color: "#e5e7eb" }; onAccepted: login() }
            Button { text: "Log In"; Layout.fillWidth: true; contentItem: Text { text: parent.text; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.family: fontFamily; font.pixelSize: fontSize }; background: Rectangle { radius: 10; color: accentColor }; onClicked: login() }
            RowLayout { Layout.fillWidth: true; spacing: 10
                ComboBox { id: sessionBox; Layout.fillWidth: true; visible: typeof sessionModel !== "undefined"; textRole: "name"; model: typeof sessionModel !== "undefined" ? sessionModel : []; displayText: currentIndex===-1?"Session":currentText }
                Button { text: "⏻"; background: Rectangle { radius: 10; color: "#f2f4f7"; border.color: "#e5e7eb" }; onClicked: if (typeof sddm!=='undefined'&&sddm.powerOff) sddm.powerOff() }
                Button { text: "↻"; background: Rectangle { radius: 10; color: "#f2f4f7"; border.color: "#e5e7eb" }; onClicked: if (typeof sddm!=='undefined'&&sddm.reboot) sddm.reboot() }
                Button { text: "⏾"; background: Rectangle { radius: 10; color: "#f2f4f7"; border.color: "#e5e7eb" }; onClicked: if (typeof sddm!=='undefined'&&sddm.suspend) sddm.suspend() }
            }
        }
    }

    function login() { if (typeof sddm !== "undefined" && sddm.login) { var sess=(typeof sessionBox!=='undefined'&&sessionBox.currentIndex>=0)?sessionBox.currentIndex:""; sddm.login(u.text, p.text, sess) } }
}


