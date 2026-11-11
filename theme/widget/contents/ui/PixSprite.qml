import QtQuick

// Dibuja un sprite a partir de filas de "0"/"1"
Item {
    id: sprite
    property var rows: []
    property int px: 2
    property color color: "white"
    readonly property int cols: rows.length ? rows[0].length : 0
    width: cols * px
    height: rows.length * px
    Repeater {
        model: sprite.rows.length * sprite.cols
        Rectangle {
            visible: sprite.rows[Math.floor(index / sprite.cols)][index % sprite.cols] === "1"
            x: (index % sprite.cols) * sprite.px
            y: Math.floor(index / sprite.cols) * sprite.px
            width: sprite.px
            height: sprite.px
            color: sprite.color
        }
    }
}
