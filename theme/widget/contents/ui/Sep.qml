import QtQuick
import "pal.js" as Pal

Item {
    width: 2
    height: 46
    Column {
        anchors.centerIn: parent
        spacing: 4
        Repeater {
            model: 6
            Rectangle { width: 2; height: 4; color: Pal.mute }
        }
    }
}
