// Script de Plasma: fondo animado, barra superior y dock en cada pantalla, y HUD en la principal.
// aplicar.sh sustituye las marcas @...@ antes de ejecutarlo. Si el dock arcade ya existe, no toca los paneles.
var HOME = "@HOME@";
var VIDEO = "file://@VIDEO@";
var REPLACE = @REPLACE@;
var CITY = "@CITY@";
var LAT = @LAT@;
var LON = @LON@;
var DECK = "com.frankf.arcadedeck";
var VIDEO_PLUGIN = "luisbocanegra.smart.video.wallpaper.reborn";
var LAUNCHERS = ["applications:systemsettings.desktop", "applications:org.kde.discover.desktop",
                 "preferred://filemanager", "preferred://browser", "applications:org.kde.konsole.desktop"];

function cfg(w, group, kv) {
    w.currentConfigGroup = group;
    for (var k in kv)
        w.writeConfig(k, kv[k]);
}

// fondo animado en todos los escritorios (se puede repetir sin efecto)
var ds = desktops();
for (var i = 0; i < ds.length; i++) {
    ds[i].wallpaperPlugin = VIDEO_PLUGIN;
    cfg(ds[i], ["Wallpaper", VIDEO_PLUGIN, "General"], {
        VideoUrls: JSON.stringify([{filename: VIDEO, enabled: true, loop: true}]),
        FillMode: 2,
        BackgroundColor: "#1a1b26"
    });
}

var ps = panels();
var installed = false;
for (var i = 0; i < ps.length; i++)
    if (ps[i].widgets(DECK).length > 0)
        installed = true;

if (installed) {
    print("PANELES=ya-instalados\n");
} else {
    var screens = {};
    for (var i = 0; i < ds.length; i++)
        if (ds[i].screen >= 0)
            screens[ds[i].screen] = ds[i];

    for (var s in screens) {
        var top = new Panel;
        top.screen = Number(s);
        top.location = "top";
        top.height = 30;
        top.floating = false;
        top.lengthMode = "fill";
        top.addWidget("org.kde.plasma.pager");
        top.addWidget("org.kde.plasma.appmenu");
        top.addWidget("org.kde.plasma.panelspacer");
        var clock = top.addWidget("org.kde.plasma.digitalclock");
        cfg(clock, ["Appearance"], {autoFontAndSize: false, fontFamily: "Press Start 2P", fontSize: 9,
                                    showDate: true, dateDisplayFormat: "BesideTime", dateFormat: "shortDate"});
        top.addWidget("org.kde.plasma.panelspacer");
        top.addWidget("org.kde.plasma.systemtray");

        var deck = new Panel;
        deck.screen = Number(s);
        deck.location = "bottom";
        deck.height = 104;
        deck.floating = true;
        deck.lengthMode = "fit";
        deck.alignment = "center";
        deck.hiding = "dodgewindows";
        var menu = deck.addWidget("org.kde.plasma.kickoff");
        cfg(menu, ["General"], {icon: HOME + "/.local/share/icons/arcade/invader.svg"});
        var dock = deck.addWidget(DECK);
        cfg(dock, ["General"], {launchers: LAUNCHERS});
        deck.addWidget("org.kde.plasma.lock_logout");
    }

    // HUD en la primera pantalla; aplicar.sh lo coloca a la derecha con el id y el ancho que se imprimen
    var first = null;
    for (var s in screens)
        if (first === null || Number(s) < first)
            first = Number(s);
    if (first !== null) {
        var hud = screens[first].addWidget(DECK, 0, 0, 960, 240);
        cfg(hud, ["General"], {city: CITY, latitude: LAT, longitude: LON});
        print("HUD=" + hud.id + " ANCHO=" + screenGeometry(first).width + "\n");
    }
    // Los paneles anteriores se quitan al final: si algo falla antes, el escritorio no se queda sin ninguno.
    if (REPLACE)
        for (var i = 0; i < ps.length; i++)
            ps[i].remove();
    print("PANELES=creados\n");
}
