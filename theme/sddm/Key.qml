import QtQuick

// Tecla del teclado en pantalla (pixel art).
Rectangle {
    id: key
    property string label
    property real w: 64
    property color accent: "#7dcfff"
    property bool on: false
    signal clicked()
    property real k: 1
    FontLoader { id: pf; source: "assets/PressStart2P-Regular.ttf" }
    width: w * k; height: 48 * k
    color: (ma.pressed || on) ? accent : "#16161e"
    border.width: 2; border.color: accent
    Text {
        anchors.centerIn: parent
        font.family: pf.name; font.pixelSize: 16 * key.k
        color: (ma.pressed || key.on) ? "#1a1b26" : key.accent
        text: key.label
        renderType: Text.NativeRendering
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: key.clicked() }
}
