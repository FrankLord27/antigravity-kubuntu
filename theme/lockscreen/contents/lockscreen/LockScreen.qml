import QtQuick
import org.kde.plasma.private.sessions 2.0

// Pantalla de bloqueo «Arcade Tokyo»: mismo diseño que el login de SDDM (reloj, caja neón, foto).
// La autenticación la hace kscreenlocker (objeto «authenticator»); aquí solo se dibuja.
Item {
    id: root
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()

    // Propiedades y señales «mágicas» que busca kscreenlocker
    property bool viewVisible: false
    property bool suspendToRamSupported: false
    property bool suspendToDiskSupported: false
    signal suspendToDisk()
    signal suspendToRam()

    implicitWidth: 800
    implicitHeight: 600

    readonly property color bg: "#1a1b26"
    readonly property color cyan: "#7dcfff"
    readonly property color purple: "#bb9af7"
    readonly property color pink: "#f7768e"
    readonly property color green: "#9ece6a"
    readonly property color mute: "#565f89"
    readonly property real k: Math.min(width / 1920, height / 1080)
    readonly property string pixel: "Press Start 2P"

    property string error: ""
    onClearPassword: pass.text = ""

    SessionManagement {
        id: sessionManagement
    }
    Connections {
        target: sessionManagement
        function onAboutToSuspend() { root.clearPassword() }
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind !== 0) return
            root.error = "GAME OVER - CLAVE INCORRECTA"
            errorTimer.restart()
            retryTimer.restart()
            shake.start()
        }
        function onSucceeded() { Qt.quit() }
        function onPromptForSecretChanged() { pass.forceActiveFocus() }
    }
    Timer { id: errorTimer; interval: 3000; onTriggered: root.error = "" }
    Timer { id: retryTimer; interval: 1500; onTriggered: { root.clearPassword(); authenticator.startAuthenticating() } }

    Rectangle { anchors.fill: parent; color: root.bg }
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("fondo.png")
        fillMode: Image.PreserveAspectCrop
        smooth: false
    }
    Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.6 }

    opacity: 0
    NumberAnimation on opacity { to: 1; duration: 300; running: true }

    // ---------- reloj ----------
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 90 * root.k
        width: clockText.width
        height: clockText.height + dateText.height + 16 * root.k
        Text {
            id: clockText
            font.family: root.pixel; font.pixelSize: 84 * root.k
            color: root.cyan; renderType: Text.NativeRendering
            property date now: new Date()
            text: Qt.formatTime(now, "hh") + (now.getSeconds() % 2 ? ":" : " ") + Qt.formatTime(now, "mm")
            Timer { interval: 500; running: true; repeat: true; onTriggered: clockText.now = new Date() }
        }
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockText.bottom; anchors.topMargin: 16 * root.k
            font.family: root.pixel; font.pixelSize: 18 * root.k
            color: root.purple; renderType: Text.NativeRendering
            text: Qt.locale().toString(clockText.now, "ddd d MMM yyyy").toUpperCase()
        }
    }

    // ---------- caja ----------
    Item {
        id: box
        width: 620 * root.k; height: 330 * root.k
        x: (root.width - width) / 2
        y: (root.height - height) / 2 + 60 * root.k

        SequentialAnimation {
            id: shake
            NumberAnimation { target: box; property: "x"; to: (root.width - box.width) / 2 + 18 * root.k; duration: 50 }
            NumberAnimation { target: box; property: "x"; to: (root.width - box.width) / 2 - 18 * root.k; duration: 80 }
            NumberAnimation { target: box; property: "x"; to: (root.width - box.width) / 2; duration: 50 }
        }

        Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.88 }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 3; border.color: root.cyan }
        Rectangle { anchors.fill: parent; anchors.margins: 8 * root.k; color: "transparent"; border.width: 2; border.color: root.purple }

        Text {
            x: 32 * root.k; y: 26 * root.k
            font.family: root.pixel; font.pixelSize: 16 * root.k
            color: root.purple; text: "PLAYER 1"; renderType: Text.NativeRendering
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 32 * root.k; y: 26 * root.k
            font.family: root.pixel; font.pixelSize: 16 * root.k
            color: root.pink; text: "PANTALLA BLOQUEADA"; renderType: Text.NativeRendering
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600 }
                NumberAnimation { to: 1; duration: 600 }
            }
        }

        Item {
            x: 32 * root.k; y: 62 * root.k
            width: parent.width - 64 * root.k; height: 76 * root.k
            Rectangle {
                id: avatar
                width: 76 * root.k; height: 76 * root.k
                color: "#16161e"; border.width: 3; border.color: root.pink
                Image {
                    id: face
                    anchors.fill: parent; anchors.margins: 3
                    source: kscreenlocker_userImage !== "" ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: false
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    font.family: root.pixel; font.pixelSize: 22 * root.k
                    color: root.pink; text: "P1"; renderType: Text.NativeRendering
                }
            }
            Text {
                anchors.left: avatar.right; anchors.leftMargin: 18 * root.k
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.pixel; font.pixelSize: 20 * root.k
                fontSizeMode: Text.Fit; minimumPixelSize: 9
                wrapMode: Text.WordWrap; maximumLineCount: 2; lineHeight: 1.35
                elide: Text.ElideRight
                color: root.cyan; text: kscreenlocker_userName.toUpperCase()
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            x: 32 * root.k; y: 160 * root.k
            width: parent.width - 64 * root.k; height: 52 * root.k
            color: "#16161e"
            border.width: 2; border.color: pass.activeFocus ? root.cyan : root.mute
            TextInput {
                id: pass
                anchors.fill: parent; anchors.margins: 14 * root.k
                verticalAlignment: TextInput.AlignVCenter
                font.family: root.pixel; font.pixelSize: 18 * root.k
                color: root.green
                echoMode: TextInput.Password
                passwordCharacter: "■"
                focus: true
                clip: true
                enabled: !authenticator.graceLocked
                Keys.onReturnPressed: authenticator.respond(pass.text)
                Keys.onEnterPressed: authenticator.respond(pass.text)
                Keys.onEscapePressed: root.clearPassword()
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 14 * root.k
                anchors.verticalCenter: parent.verticalCenter
                visible: pass.text === ""
                font.family: root.pixel; font.pixelSize: 12 * root.k
                color: root.mute; text: "CONTRASEÑA"; renderType: Text.NativeRendering
            }
        }

        Rectangle {
            id: unlock
            x: 32 * root.k; y: 232 * root.k
            width: parent.width - 64 * root.k; height: 52 * root.k
            color: hover.containsMouse ? root.cyan : "transparent"
            border.width: 2; border.color: root.cyan
            Text {
                anchors.centerIn: parent
                font.family: root.pixel; font.pixelSize: 18 * root.k
                color: hover.containsMouse ? root.bg : root.cyan
                text: "DESBLOQUEAR"; renderType: Text.NativeRendering
            }
            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: authenticator.respond(pass.text) }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 296 * root.k
            font.family: root.pixel; font.pixelSize: 11 * root.k
            color: root.pink; text: root.error; renderType: Text.NativeRendering
        }
    }

    Component.onCompleted: {
        authenticator.startAuthenticating()
        pass.forceActiveFocus()
    }
}
