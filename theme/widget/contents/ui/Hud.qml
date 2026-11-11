import QtQuick
import org.kde.ksysguard.sensors as Sensors
import "pal.js" as Pal

// HUD de escritorio: medidores, visualizador de audio, clima y reloj.
// Se dibuja a 1x y se amplía x2 sin suavizado para que todo quede pixelado.
Item {
    id: hud
    readonly property real zoom: 1.6
    property string city: "La Vega"
    property real latitude: 19.2221
    property real longitude: -70.5296
    implicitWidth: panel.width * zoom
    implicitHeight: panel.height * zoom

    Sensors.Sensor { id: sCpu; sensorId: "cpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: sCpuT; sensorId: "cpu/all/averageTemperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: sGpu; sensorId: "gpu/gpu0/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: sGpuT; sensorId: "gpu/gpu0/temperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: sVram; sensorId: "gpu/gpu0/usedVram"; updateRateLimit: 2000 }
    Sensors.Sensor { id: sRam; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: sRamU; sensorId: "memory/physical/used"; updateRateLimit: 2000 }

    Item {
        id: panel
        width: 592
        height: 150
        x: Math.round((hud.width - width * hud.zoom) / 2)
        y: Math.round((hud.height - height * hud.zoom) / 2)
        scale: hud.zoom
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: false

        Rectangle { anchors.fill: parent; color: Pal.bg; opacity: 0.86 }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Pal.cyan }
        Rectangle { anchors.fill: parent; anchors.margins: 4; color: "transparent"; border.width: 1; border.color: Pal.purple }

        // cabecera
        PixSprite {
            x: 14; y: 14
            rows: clock.now.getSeconds() % 2 ? Pal.crab : Pal.crab2
            px: 1
            color: Pal.purple
        }
        PixText { x: 32; y: 14; text: "SYSTEM HUD"; color: Pal.cyan }
        PixText {
            anchors.right: parent.right; anchors.rightMargin: 14; y: 14
            text: "PLAYER 1 READY"
            color: Pal.pink
            opacity: clock.now.getSeconds() % 2 ? 1 : 0.3
        }

        Row {
            x: 14; y: 32
            height: 46
            spacing: 14
            Meter {
                label: "CPU"; accent: Pal.cyan
                value: Pal.num(sCpu.value)
                sub: sCpuT.value !== undefined ? Math.round(Pal.num(sCpuT.value)) + "°C" : ""
            }
            Sep {}
            Meter {
                label: "GPU"; accent: Pal.purple
                value: Pal.num(sGpu.value)
                sub: (sGpuT.value !== undefined ? Math.round(Pal.num(sGpuT.value)) + "°C " : "") + (sVram.formattedValue || "")
            }
            Sep {}
            Meter {
                label: "RAM"; accent: Pal.orange
                value: Pal.num(sRam.value)
                sub: sRamU.formattedValue || ""
            }
        }

        Row {
            x: 14; y: 90
            height: 46
            spacing: 14

            // ---------- visualizador de audio (datos de cava por HTTP local) ----------
            Item {
                id: viz
                property var bars: []
                property bool busy: false
                property bool quiet: true
                width: 210; height: 46
                function poll() {
                    if (busy)
                        return;
                    busy = true;
                    const x = new XMLHttpRequest();
                    x.timeout = 1000;
                    x.onreadystatechange = function () {
                        if (x.readyState !== XMLHttpRequest.DONE)
                            return;
                        viz.busy = false;
                        if (x.status !== 200) {
                            viz.quiet = true;
                            return;
                        }
                        const a = x.responseText.split(";").map(Number);
                        viz.quiet = !a.some(v => v > 0);
                        viz.bars = a;
                    };
                    x.open("GET", "http://127.0.0.1:47821/");
                    x.send();
                }
                // en silencio se consulta poco para no gastar CPU
                Timer { interval: viz.quiet ? 500 : 50; running: true; repeat: true; onTriggered: viz.poll() }
                PixText { text: "AUDIO"; color: Pal.green }
                Repeater {
                    model: 35
                    Rectangle {
                        readonly property int lv: Math.max(0, Math.min(15, viz.bars[index] || 0))
                        x: index * 6
                        width: 5
                        height: 2 + lv * 2
                        anchors.bottom: parent.bottom
                        color: lv > 12 ? Pal.pink : (lv > 8 ? Pal.yellow : (lv > 0 ? Pal.green : Pal.off))
                    }
                }
            }
            Sep {}

            // ---------- clima (open-meteo) ----------
            Item {
                id: wx
                property real temp: NaN
                property int code: -1
                property bool isDay: true
                readonly property var info: code < 0 ? ["cloud", "SIN DATOS", Pal.mute] : Pal.weather(code, isDay)
                width: 150; height: 46
                function refresh() {
                    const x = new XMLHttpRequest();
                    x.timeout = 10000;
                    x.onreadystatechange = function () {
                        if (x.readyState !== XMLHttpRequest.DONE || x.status !== 200)
                            return;
                        try {
                            const c = JSON.parse(x.responseText).current;
                            wx.temp = c.temperature_2m;
                            wx.code = c.weather_code;
                            wx.isDay = c.is_day === 1;
                        } catch (e) {
                            console.warn("arcadedeck: clima ilegible", e);
                        }
                    };
                    x.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + hud.latitude + "&longitude=" + hud.longitude
                           + "&current=temperature_2m,weather_code,is_day&timezone=auto");
                    x.send();
                }
                Timer { interval: 15 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: wx.refresh() }
                PixText { text: hud.city.toUpperCase(); color: Pal.orange }
                PixSprite { y: 16; rows: Pal.wx[wx.info[0]]; px: 3; color: wx.info[2] }
                PixText { x: 34; y: 14; font.pixelSize: 16; text: isNaN(wx.temp) ? "--" : Math.round(wx.temp) + "°C" }
                PixText { x: 34; y: 38; text: wx.info[1]; color: Pal.mute }
            }
            Sep {}

            // ---------- reloj arcade ----------
            Item {
                id: clock
                property date now: new Date()
                readonly property string t: Qt.formatTime(now, "hh:mm AP")
                width: 144; height: 46
                Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clock.now = new Date() }
                Row {
                    PixText { text: clock.t.substring(0, 2); font.pixelSize: 24; color: Pal.cyan }
                    PixText { text: ":"; font.pixelSize: 24; color: Pal.pink; opacity: clock.now.getSeconds() % 2 ? 0.25 : 1 }
                    PixText { text: clock.t.substring(3, 5); font.pixelSize: 24; color: Pal.cyan }
                }
                PixText { anchors.right: parent.right; y: 30; text: clock.t.substring(6); color: Pal.yellow }
                PixText {
                    anchors.bottom: parent.bottom
                    text: clock.now.toLocaleDateString(Qt.locale("es_ES"), "ddd dd MMM").toUpperCase()
                    color: Pal.mute
                }
            }
        }
    }
}
