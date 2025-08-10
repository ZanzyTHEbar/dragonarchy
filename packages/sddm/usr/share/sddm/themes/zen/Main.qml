import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0

Rectangle {
    id: root
    anchors.fill: parent

    // Theme config (from theme.conf)
    property string fontFamily: (config && config.Font) ? config.Font : "Inter"
    property int fontSize: (config && config.FontSize) ? parseInt(config.FontSize) : 11
    property bool showClock: (config && config.ClockEnabled === "true")
    // Treat CustomBackground as boolean or string, and default to true when a path is set
    property bool customBg: (config && (config.CustomBackground === true || config.CustomBackground === "true")) || (bgPath && bgPath.length > 0)
    property string bgPath: (config && config.Background) ? config.Background : ""

    // Palette (from theme.conf [Colors])
    property color backgroundColor: (config && config["Colors.background"]) ? config["Colors.background"] : "#0f1117"
    // Base palette
    property color baseTextColor: (config && config["Colors.foreground"]) ? config["Colors.foreground"] : "#e6edf3"
    property color baseAccentColor: (config && config["Colors.accent"]) ? config["Colors.accent"] : "#79c0ff"
    // Adaptive colors computed from background luminance
    property real bgLum: (0.2126 * bgSample.r + 0.7152 * bgSample.g + 0.0722 * bgSample.b)
    property color textColor: bgLum > 0.6 ? Qt.rgba(0.1,0.12,0.14,1.0) : baseTextColor
    property color accentColor: bgLum > 0.6 ? Qt.rgba(0.16,0.43,0.86,1.0) : baseAccentColor

    // Background: image with subtle parallax and gradient fallback
    color: customBg ? backgroundColor : "#0f141d"

    Item {
        id: bgLayer
        anchors.fill: parent

        Rectangle {
            id: gradientBg
            anchors.fill: parent
            visible: !customBg
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0f141d" }
                GradientStop { position: 1.0; color: "#0b1220" }
            }
        }

        Image {
            id: bgImage
            anchors.centerIn: parent
            width: parent.width * 1.08
            height: parent.height * 1.08
            x: parallaxX
            y: parallaxY
            visible: true
            source: (bgPath && bgPath.length > 0) ? Qt.resolvedUrl(bgPath) : Qt.resolvedUrl("backgrounds/zen.jpg")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: true
        }
    }

    // Sample central background pixel to adapt text/accent color for contrast
    ShaderEffectSource { id: sampleSrc; sourceItem: bgLayer; sourceRect: Qt.rect(width/2-1, height/2-1, 2, 2); hideSource: true; live: true }
    ColorOverlay { id: bgSampleOverlay; anchors.fill: parent; visible: false; source: sampleSrc; color: "white" }
    property color bgSample: (bgSampleOverlay.color !== undefined) ? bgSampleOverlay.color : Qt.rgba(0.0,0.0,0.0,1.0)

    // Vignette (fallback without Vignette type): four soft edge gradients
    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: parent.height * 0.22; z: 0
        gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.18) } GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.0) } }
        color: "transparent" }
    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: parent.height * 0.22; z: 0
        gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.0) } GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.18) } }
        color: "transparent" }
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * 0.12; z: 0
        rotation: 90; transformOrigin: Item.TopLeft
        gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.16) } GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.0) } }
        color: "transparent" }
    Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * 0.12; z: 0
        rotation: 270; transformOrigin: Item.TopRight
        gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.16) } GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.0) } }
        color: "transparent" }

    // Subtle overlay for tranquil look
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.03
    }

    // Parallax motion
    property real parallaxFactor: 0.008
    property real parallaxX: 0
    property real parallaxY: 0
    Behavior on parallaxX { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    Behavior on parallaxY { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: {
            var cx = width/2; var cy = height/2;
            parallaxX = -(mouse.x - cx) * parallaxFactor;
            parallaxY = -(mouse.y - cy) * parallaxFactor;
        }
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
        layer.enabled: true
        layer.effect: DropShadow { samples: 16; radius: 8; color: "#40000000"; horizontalOffset: 0; verticalOffset: 2 }
    }

    // Frosted glass behind the clock for legibility over busy backgrounds
    Rectangle {
        id: clockGlass
        anchors.centerIn: clock
        width: Math.max(140, clock.paintedWidth + 28)
        height: clock.paintedHeight + 12
        radius: 10
        z: -1
        color: "transparent"
        clip: true

        ShaderEffectSource {
            id: clockSrc
            anchors.fill: parent
            sourceItem: bgLayer
            hideSource: false
            visible: false
        }
        FastBlur {
            anchors.fill: parent
            source: clockSrc
            radius: 28
            transparentBorder: true
        }
        Rectangle { anchors.fill: parent; radius: 10; color: "#ffffff"; opacity: 0.06 }
        Rectangle { anchors.fill: parent; radius: 10; color: "#000000"; opacity: 0.05 }
        Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border.color: "#FFFFFF26"; border.width: 1 }
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
        opacity: 0.80
        border.color: "#1f2833"
        border.width: 1
        anchors.centerIn: parent

        // Bloom/Glow behind panel
        RectangularGlow {
            anchors.fill: parent
            glowRadius: 22
            spread: 0.12
            cornerRadius: panel.radius
            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
            visible: true
            z: -1
        }

        // Background blur behind the panel area
        ShaderEffectSource {
            id: panelSource
            anchors.fill: parent
            sourceItem: bgLayer
            hideSource: false
            visible: false
        }
        FastBlur {
            anchors.fill: parent
            source: panelSource
            radius: 36
            transparentBorder: true
            z: -1
        }

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
                layer.enabled: true
                layer.effect: DropShadow { samples: 16; radius: 8; color: "#30000000"; horizontalOffset: 0; verticalOffset: 1 }
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
                background: Rectangle {
                    radius: 10
                    color: "#10FFFFFF"   // ~6% white
                    border.color: userField.activeFocus ? accentColor : "#33FFFFFF"
                    border.width: 1
                }
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
                background: Rectangle {
                    radius: 10
                    color: "#10FFFFFF"
                    border.color: passwordField.activeFocus ? accentColor : "#33FFFFFF"
                    border.width: 1
                }
            }

            Button {
                id: loginButton
                text: "Log In"
                Layout.fillWidth: true
                hoverEnabled: true
                contentItem: Text {
                    text: loginButton.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: fontFamily
                    font.pixelSize: fontSize
                    font.bold: true
                }
                background: Rectangle {
                    id: loginBg
                    radius: 10
                    color: accentColor
                }
                states: [
                    State { name: "hover"; when: loginButton.hovered; PropertyChanges { target: loginBg; color: Qt.darker(accentColor, 1.1) }},
                    State { name: "pressed"; when: loginButton.down; PropertyChanges { target: loginBg; color: Qt.darker(accentColor, 1.3) }}
                ]
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

            // Footer row: session selector + power options (optional)
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ComboBox {
                    id: sessionBox
                    Layout.fillWidth: true
                    visible: typeof sessionModel !== "undefined"
                    textRole: "name"
                    model: typeof sessionModel !== "undefined" ? sessionModel : []
                    displayText: currentIndex === -1 ? "Session" : currentText
                }

                Button {
                    text: "⏻"
                    ToolTip.visible: hovered
                    ToolTip.text: "Power Off"
                    contentItem: Text { text: "⏻"; color: textColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 10; color: "#10FFFFFF"; border.color: "#33FFFFFF" }
                    onClicked: if (typeof sddm !== "undefined" && sddm.powerOff) sddm.powerOff()
                }
                Button {
                    text: "↻"
                    ToolTip.visible: hovered
                    ToolTip.text: "Reboot"
                    contentItem: Text { text: "↻"; color: textColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 10; color: "#10FFFFFF"; border.color: "#33FFFFFF" }
                    onClicked: if (typeof sddm !== "undefined" && sddm.reboot) sddm.reboot()
                }
                Button {
                    text: "⏾"
                    ToolTip.visible: hovered
                    ToolTip.text: "Suspend"
                    contentItem: Text { text: "⏾"; color: textColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 10; color: "#10FFFFFF"; border.color: "#33FFFFFF" }
                    onClicked: if (typeof sddm !== "undefined" && sddm.suspend) sddm.suspend()
                }
            }
        }
    }

    function login() {
        if (typeof sddm !== "undefined" && sddm.login !== undefined) {
            var sess = (typeof sessionBox !== "undefined" && sessionBox.currentIndex >= 0) ? sessionBox.currentIndex : "";
            sddm.login(userField.text, passwordField.text, sess);
        }
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() { statusText.text = "Login failed. Try again."; passwordField.selectAll(); passwordField.forceActiveFocus() }
    }
}


