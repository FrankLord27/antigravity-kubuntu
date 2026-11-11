import QtQuick
import "pal.js" as Pal

// Red: bajada grande con historial y barra segmentada; subida como dato secundario.
// La escala se ajusta sola al mayor valor reciente (mínimo 1 MB/s).
Item {
    id: meter
    property string label: "RED"
    property real down: 0     // bytes/s
    property real up: 0       // bytes/s
    property color accent: Pal.blue
    property var hist: []
    readonly property int segs: 16
    readonly property real scaleMax: Math.max(1048576, Math.max.apply(null, hist.concat([down])))
    width: 168
    height: 46

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const h = meter.hist.slice(-20);
            h.push(meter.down);
            meter.hist = h;
        }
    }
    PixText { text: meter.label; color: meter.accent }
    PixText { text: "UP " + Pal.bps(meter.up); color: Pal.mute; anchors.right: parent.right }
    PixText { y: 15; text: Pal.bps(meter.down); font.pixelSize: 12; color: Pal.cyan }
    Row {
        y: 13
        anchors.right: parent.right
        height: 16
        spacing: 1
        Repeater {
            model: meter.hist
            Rectangle {
                width: 3
                height: Math.max(2, Math.round(modelData / meter.scaleMax * 16))
                anchors.bottom: parent.bottom
                color: Pal.cyan
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
                color: index < Math.ceil(meter.down / meter.scaleMax * meter.segs - 0.01) ? Pal.cyan : Pal.off
            }
        }
    }
}
