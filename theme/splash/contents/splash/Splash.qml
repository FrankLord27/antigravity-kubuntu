import QtQuick

// Carga al iniciar sesión: mismo estilo arcade del escritorio (Tokyo Night, pixel, marco neón).
// La fuente Press Start 2P la instala theme/aplicar.sh en ~/.local/share/fonts.
Rectangle {
    id: root
    color: "#1a1b26"
    property int stage: 0
    readonly property real k: Math.min(width / 1920, height / 1080)
    readonly property var crab: ["00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"]
    readonly property var crab2: ["00100000100", "10010001001", "10111111101", "11101110111", "11111111111", "01111111110", "00100000100", "01000000010"]


    property int tick: 0
    Timer { interval: 350; running: true; repeat: true; onTriggered: root.tick++ }

    Item {
        id: content
        anchors.centerIn: parent
        width: 560 * root.k; height: 260 * root.k
        opacity: 0
        NumberAnimation on opacity { to: 1; duration: 250; running: true }

        Rectangle { anchors.fill: parent; color: "#1a1b26" }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 3; border.color: "#7dcfff" }
        Rectangle { anchors.fill: parent; anchors.margins: 8 * root.k; color: "transparent"; border.width: 2; border.color: "#bb9af7" }

        // marciano que anima 2 cuadros
        Grid {
            id: sprite
            anchors.horizontalCenter: parent.horizontalCenter
            y: 36 * root.k
            columns: 11
            readonly property var m: root.tick % 2 ? root.crab2 : root.crab
            readonly property real px: 9 * root.k
            Repeater {
                model: 88
                Rectangle {
                    width: sprite.px; height: sprite.px
                    color: sprite.m[Math.floor(index / 11)].charAt(index % 11) === "1" ? "#bb9af7" : "transparent"
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 140 * root.k
            font.family: "Press Start 2P"; font.pixelSize: 18 * root.k
            color: "#7dcfff"; renderType: Text.NativeRendering
            text: "CARGANDO" + ".".repeat(root.tick % 4)
        }

        // barra segmentada: avanza con las etapas de Plasma y late mientras espera
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 190 * root.k
            spacing: 4 * root.k
            Repeater {
                model: 16
                Rectangle {
                    width: 20 * root.k; height: 18 * root.k
                    readonly property int filled: Math.min(16, Math.max(root.stage * 3, 1) + (root.tick % 3))
                    color: index < filled ? (index < 10 ? "#9ece6a" : (index < 13 ? "#e0af68" : "#f7768e")) : "#2a2e42"
                }
            }
        }
    }
}
