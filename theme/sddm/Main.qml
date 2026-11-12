import QtQuick
import QtQuick.Controls
import SddmComponents 2.0

// Login «Arcade Tokyo»: mismo look que el escritorio (Tokyo Night, pixel, marco neón).
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#1a1b26"

    readonly property color bg: "#1a1b26"
    readonly property color cyan: "#7dcfff"
    readonly property color purple: "#bb9af7"
    readonly property color pink: "#f7768e"
    readonly property color green: "#9ece6a"
    readonly property color mute: "#565f89"
    readonly property color fg: "#c0caf5"
    // todo se diseña para 1080p y se escala a la pantalla real
    readonly property real k: Math.min(width / 1920, height / 1080)

    FontLoader { id: pixel; source: "assets/PressStart2P-Regular.ttf" }

    property string error: ""
    property bool busy: false
    property bool kb: false        // teclado en pantalla (solo si se pide con el botón)
    property bool shift: false
    property bool symbols: false

    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        smooth: false
    }
    Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.6 }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.error = "GAME OVER - CLAVE INCORRECTA"
            pass.text = ""
            pass.forceActiveFocus()
        }
        function onLoginSucceeded() { root.error = ""; root.busy = true }
    }

    // ---------- reloj ----------
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 90 * root.k
        width: clockText.width
        height: clockText.height + dateText.height + 16 * root.k
        Text {
            id: clockText
            font.family: pixel.name; font.pixelSize: 84 * root.k
            color: root.cyan
            renderType: Text.NativeRendering
            property date now: new Date()
            text: Qt.formatTime(now, "hh") + (now.getSeconds() % 2 ? ":" : " ") + Qt.formatTime(now, "mm")
            Timer { interval: 500; running: true; repeat: true; onTriggered: clockText.now = new Date() }
        }
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockText.bottom; anchors.topMargin: 16 * root.k
            font.family: pixel.name; font.pixelSize: 18 * root.k
            color: root.purple
            renderType: Text.NativeRendering
            text: Qt.formatDate(clockText.now, "ddd d MMM yyyy").toUpperCase()
        }
    }

    // ---------- usuarios ----------
    ListView {
        id: userList
        width: 1; height: 1; opacity: 0
        model: userModel
        currentIndex: userModel.lastIndex
        delegate: Item {
            width: 1; height: 1
            property string uname: model.name
            property string real: model.realName
            property string icon: model.icon
        }
    }
    readonly property string userName: userList.currentItem ? userList.currentItem.uname : ""
    readonly property string userReal: userList.currentItem && userList.currentItem.real !== "" ? userList.currentItem.real : userName

    function doLogin() {
        if (busy || userName === "") return
        error = ""
        sddm.login(userName, pass.text, sessionModel.lastIndex)
    }

    // ---------- caja de login ----------
    Item {
        id: box
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (root.kb ? -150 : 60) * root.k
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 150 } }
        width: 620 * root.k
        height: 330 * root.k

        Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.88 }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 3; border.color: root.cyan }
        Rectangle { anchors.fill: parent; anchors.margins: 8 * root.k; color: "transparent"; border.width: 2; border.color: root.purple }

        Text {
            x: 32 * root.k; y: 26 * root.k
            font.family: pixel.name; font.pixelSize: 16 * root.k
            color: root.purple; text: "PLAYER 1"
            renderType: Text.NativeRendering
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 32 * root.k; y: 26 * root.k
            font.family: pixel.name; font.pixelSize: 16 * root.k
            color: root.pink; text: "INSERT COIN"
            renderType: Text.NativeRendering
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600 }
                NumberAnimation { to: 1; duration: 600 }
            }
        }

        // usuario: foto + nombre (con flechas si hay varios)
        Item {
            x: 32 * root.k; y: 62 * root.k
            width: parent.width - 64 * root.k; height: 76 * root.k
            Rectangle {
                id: avatar
                width: 76 * root.k; height: 76 * root.k
                color: "#16161e"
                border.width: 3; border.color: root.pink
                Image {
                    id: face
                    anchors.fill: parent; anchors.margins: 3
                    source: userList.currentItem ? userList.currentItem.icon : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: false
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    font.family: pixel.name; font.pixelSize: 22 * root.k
                    color: root.pink; text: "P1"
                    renderType: Text.NativeRendering
                }
            }
            Text {
                anchors.left: avatar.right; anchors.leftMargin: 18 * root.k
                anchors.right: parent.right
                anchors.rightMargin: (userModel.count > 1 ? 56 : 0) * root.k
                anchors.verticalCenter: parent.verticalCenter
                font.family: pixel.name; font.pixelSize: 20 * root.k
                fontSizeMode: Text.Fit; minimumPixelSize: 9
                wrapMode: Text.WordWrap; maximumLineCount: 2; lineHeight: 1.35
                elide: Text.ElideRight
                color: root.cyan; text: root.userReal.toUpperCase()
                renderType: Text.NativeRendering
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                visible: userModel.count > 1
                spacing: 14 * root.k
                Text {
                    font.family: pixel.name; font.pixelSize: 20 * root.k; color: root.cyan; text: "<"
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: userList.decrementCurrentIndex() }
                }
                Text {
                    font.family: pixel.name; font.pixelSize: 20 * root.k; color: root.cyan; text: ">"
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: userList.incrementCurrentIndex() }
                }
            }
        }

        // contraseña: bloques en vez de puntos
        Rectangle {
            x: 32 * root.k; y: 160 * root.k
            width: parent.width - 64 * root.k; height: 52 * root.k
            color: "#16161e"
            border.width: 2; border.color: pass.activeFocus ? root.cyan : root.mute
            TextInput {
                id: pass
                anchors.fill: parent; anchors.margins: 14 * root.k
                verticalAlignment: TextInput.AlignVCenter
                font.family: pixel.name; font.pixelSize: 18 * root.k
                color: root.green
                echoMode: TextInput.Password
                passwordCharacter: "■"
                focus: true
                clip: true
                enabled: !root.busy
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 14 * root.k
                anchors.verticalCenter: parent.verticalCenter
                visible: pass.text === ""
                font.family: pixel.name; font.pixelSize: 12 * root.k
                color: root.mute; text: "CONTRASEÑA"
                renderType: Text.NativeRendering
            }
        }

        // botón START / mensajes
        Rectangle {
            id: start
            x: 32 * root.k; y: 232 * root.k
            width: parent.width - 64 * root.k; height: 52 * root.k
            color: hover.containsMouse ? root.cyan : "transparent"
            border.width: 2; border.color: root.cyan
            Text {
                anchors.centerIn: parent
                font.family: pixel.name; font.pixelSize: 18 * root.k
                color: hover.containsMouse ? root.bg : root.cyan
                text: root.busy ? "CARGANDO..." : "START"
                renderType: Text.NativeRendering
            }
            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: root.doLogin() }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 296 * root.k
            font.family: pixel.name; font.pixelSize: 11 * root.k
            color: root.pink; text: root.error
            renderType: Text.NativeRendering
        }
    }

    // ---------- apagar / reiniciar ----------
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 60 * root.k
        spacing: 36 * root.k
        Repeater {
            model: [
                { t: "TECLADO", c: root.cyan, a: 2 },
                { t: "REINICIAR", c: root.purple, a: 0 },
                { t: "APAGAR", c: root.pink, a: 1 }
            ]
            Rectangle {
                width: 200 * root.k; height: 46 * root.k
                color: (m.containsMouse || (modelData.a === 2 && root.kb)) ? modelData.c : root.bg
                opacity: 0.95
                border.width: 2; border.color: modelData.c
                Text {
                    anchors.centerIn: parent
                    font.family: pixel.name; font.pixelSize: 13 * root.k
                    color: (m.containsMouse || (modelData.a === 2 && root.kb)) ? root.bg : modelData.c
                    text: modelData.t
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: m; anchors.fill: parent; hoverEnabled: true
                    onClicked: modelData.a === 0 ? sddm.reboot() : (modelData.a === 1 ? sddm.powerOff() : (root.kb = !root.kb))
                }
            }
        }
    }


    // ---------- teclado en pantalla (solo aparece con el botón TECLADO) ----------
    Item {
        id: keyboard
        visible: root.kb
        anchors.horizontalCenter: parent.horizontalCenter
        y: 640 * root.k
        width: 760 * root.k
        height: 292 * root.k
        readonly property var abc: ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"]
        readonly property var sym: ["1234567890", "!@#$%^&*()", "-_=+[]{};:", "'\",.<>/?\\|"]
        function press(ch) {
            pass.insert(pass.cursorPosition, root.shift && !root.symbols ? ch.toUpperCase() : ch)
            if (root.shift) root.shift = false
            pass.forceActiveFocus()
        }
        function del() {
            if (pass.cursorPosition > 0) pass.remove(pass.cursorPosition - 1, pass.cursorPosition)
            pass.forceActiveFocus()
        }
        Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.92 }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: root.purple }
        Column {
            anchors.centerIn: parent
            spacing: 8 * root.k
            Repeater {
                model: root.symbols ? keyboard.sym : keyboard.abc
                Row {
                    id: keyRow
                    property string chars: modelData
                    property int rowIndex: index
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8 * root.k
                    Key {
                        k: root.k
                        visible: keyRow.rowIndex === 3 && !root.symbols
                        w: 90; label: "MAY"; on: root.shift; accent: root.green
                        onClicked: root.shift = !root.shift
                    }
                    Repeater {
                        model: keyRow.chars.length
                        Key {
                            k: root.k
                            property string ch: keyRow.chars.charAt(index)
                            label: root.shift && !root.symbols ? ch.toUpperCase() : ch
                            onClicked: keyboard.press(ch)
                        }
                    }
                    Key {
                        k: root.k
                        visible: keyRow.rowIndex === 3
                        w: 90; label: "DEL"; accent: root.pink
                        onClicked: keyboard.del()
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * root.k
                Key {
                    k: root.k; w: 100; label: root.symbols ? "ABC" : "#+="; accent: root.green; onClicked: { root.symbols = !root.symbols; root.shift = false } }
                Key {
                    k: root.k; w: 380; label: "ESPACIO"; onClicked: keyboard.press(" ") }
                Key {
                    k: root.k; w: 100; label: "OK"; accent: root.cyan; on: true; onClicked: root.doLogin() }
            }
        }
    }

    Component.onCompleted: pass.forceActiveFocus()
}
