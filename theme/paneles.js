// Script de Plasma: fondo animado, barra superior y dock en cada pantalla conectada, y un HUD.
// aplicar.sh sustituye las marcas @...@ antes de ejecutarlo.
//
// Se puede repetir sin duplicar nada:
//   • Cuenta las pantallas conectadas ahora mismo (una en un portátil solo, dos con monitor externo).
//   • Cada pantalla recibe una sola barra y un solo dock; la que ya tiene paneles no se toca.
//   • El HUD existe una sola vez, en la primera pantalla.
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

function addPanels(screen) {
    var top = new Panel;
    top.screen = screen;
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
    deck.screen = screen;
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

// Escritorios de las pantallas conectadas. Plasma recuerda también los de monitores que ya no
// están (pantalla -1) y puede tener varios por pantalla (actividades): se toma uno por pantalla.
var ds = desktops();
var screens = {};
var hudExists = false;
for (var i = 0; i < ds.length; i++) {
    // fondo animado en todos (se puede repetir sin efecto)
    ds[i].wallpaperPlugin = VIDEO_PLUGIN;
    cfg(ds[i], ["Wallpaper", VIDEO_PLUGIN, "General"], {
        VideoUrls: JSON.stringify([{filename: VIDEO, enabled: true, loop: true}]),
        FillMode: 2,
        BackgroundColor: "#1a1b26"
    });
    if (ds[i].widgets(DECK).length > 0)
        hudExists = true;
    if (ds[i].screen >= 0 && screens[ds[i].screen] === undefined)
        screens[ds[i].screen] = ds[i];
}

var old = panels();
var panelsOn = {};      // pantalla -> cuántos paneles tiene
var themed = false;     // ¿hay ya algún dock arcade?
for (var i = 0; i < old.length; i++) {
    panelsOn[old[i].screen] = (panelsOn[old[i].screen] || 0) + 1;
    if (old[i].widgets(DECK).length > 0)
        themed = true;
}

var created = 0;
var count = 0;
var first = null;
for (var s in screens) {
    var n = Number(s);
    count++;
    if (first === null || n < first)
        first = n;
    // Primera vez: se crean en todas. Después: solo en una pantalla nueva que no tenga ningún panel.
    if (!themed || !panelsOn[n]) {
        addPanels(n);
        created++;
    }
}

if (!hudExists && first !== null) {
    // aplicar.sh lo coloca a la derecha con el id y el ancho que se imprimen aquí
    var hud = screens[first].addWidget(DECK, 0, 0, 758, 192);
    cfg(hud, ["General"], {city: CITY, latitude: LAT, longitude: LON});
    print("HUD=" + hud.id + " ANCHO=" + screenGeometry(first).width + "\n");
}

// Los paneles que había antes del tema se quitan solo en la primera instalación, y al final:
// si algo falla antes, el escritorio no se queda sin ninguno.
if (!themed && REPLACE)
    for (var i = 0; i < old.length; i++)
        old[i].remove();

print("PANELES=" + (created > 0 ? "creados" : "ya-instalados") + " PANTALLAS=" + count + " NUEVAS=" + created + "\n");
