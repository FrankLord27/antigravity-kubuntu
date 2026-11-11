import QtQuick
import "pal.js" as Pal

// Etiqueta + dato secundario, porcentaje grande + historial, barra segmentada
Item {
    id: meter
    property string label
    property string sub
    property real value: 0
    property color accent: Pal.cyan
    property var hist: []
    readonly property int segs: 16
    width: 168
    height: 46

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const h = meter.hist.slice(-21);
            h.push(meter.value);
            meter.hist = h;
        }
    }
    PixText { text: meter.label; color: meter.accent }
    PixText { text: meter.sub; color: Pal.mute; anchors.right: parent.right }
    PixText { y: 13; text: Math.round(meter.value) + "%"; font.pixelSize: 16; color: Pal.heat(meter.value) }
    Row {
        y: 13
        anchors.right: parent.right
        height: 16
        spacing: 1
        Repeater {
            model: meter.hist
            Rectangle {
                width: 3
                height: Math.max(2, Math.round(modelData / 100 * 16))
                anchors.bottom: parent.bottom
                color: Pal.heat(modelData)
                opacity: 0.35 + 0.65 * index / Math.max(1, meter.hist.length - 1)
            }
        }
    }
    Row {
        anchors.bottom: parent.bottom
        spacing: 2
        Repeater {
            model: meter.segs
            Rectangle {
                width: (meter.width - 2 * (meter.segs - 1)) / meter.segs
                height: 9
                color: index < Math.ceil(meter.value / 100 * meter.segs - 0.01)
                       ? (index < 10 ? Pal.green : (index < 13 ? Pal.yellow : Pal.pink)) : Pal.off
            }
        }
    }
}
