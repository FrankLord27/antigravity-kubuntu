// KWin no puede reproducir audio: pide a systemd (usuario) que lance pw-play con el sonido.
// Una sola acción suele disparar varios eventos seguidos (p. ej. restaurar una ventana
// maximizada emite «minimizada» y «maximizada»), así que solo suena el primero de cada ráfaga.
var lastPlay = 0;
function play(name) {
    var now = Date.now();
    if (now - lastPlay < 700)
        return;
    lastPlay = now;
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager",
             "StartUnit", "arcade-sound@" + name + ".service", "replace");
}
function watch(w) {
    if (!w.normalWindow)
        return;
    w.minimizedChanged.connect(function () { play(w.minimized ? "window-minimize" : "window-restore"); });
    w.maximizedAboutToChange.connect(function (mode) { play(mode === 0 ? "window-restore" : "window-maximize"); });
}
workspace.windowList().forEach(watch);
workspace.windowAdded.connect(function (w) {
    if (!w.normalWindow)
        return;
    watch(w);
    play("window-open");
});
workspace.windowRemoved.connect(function (w) {
    if (w.normalWindow)
        play("window-close");
});
