.pragma library
var bg = "#1a1b26", fg = "#c0caf5", mute = "#565f89", off = "#2a2e42", lip = "#3b3f5c";
var cyan = "#7dcfff", purple = "#bb9af7", green = "#9ece6a", yellow = "#e0af68", pink = "#f7768e", orange = "#ff9e64", blue = "#7aa2f7";
var neon = [pink, yellow, purple, green, orange, cyan, blue];
function num(v) { var n = Number(v); return isNaN(n) ? 0 : n; }
function heat(p) { return p < 60 ? green : (p < 85 ? yellow : pink); }
var crab = ["00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"];
var crab2 = ["00100000100", "10010001001", "10111111101", "11101110111", "11111111111", "01111111110", "00100000100", "01000000010"];
var ship = ["0000001000000", "0000011100000", "0000011100000", "0100111110010", "0101111111010", "1111101011111", "1111111111111", "1011011101101", "1010011100101"];
var wx = {
    sun: ["00011000", "01000010", "00111100", "10111101", "10111101", "00111100", "01000010", "00011000"],
    moon: ["00111000", "01110000", "11100000", "11100000", "11100000", "11110001", "01111110", "00111100"],
    cloud: ["00000000", "00111000", "01111100", "01111110", "11111111", "11111111", "01111110", "00000000"],
    rain: ["00111000", "01111110", "11111111", "11111111", "00000000", "01001001", "10010010", "00000000"],
    storm: ["00111000", "01111110", "11111111", "11111111", "00011000", "00110000", "00011000", "00100000"],
    fog: ["00000000", "11111110", "00000000", "01111111", "00000000", "11111110", "00000000", "01111111"]
};
// código WMO de open-meteo -> [sprite, texto, color]
function weather(code, isDay) {
    if (code === 0) return isDay ? ["sun", "DESPEJADO", yellow] : ["moon", "DESPEJADO", fg];
    if (code <= 2) return isDay ? ["sun", "POCAS NUBES", yellow] : ["moon", "POCAS NUBES", fg];
    if (code === 3) return ["cloud", "NUBLADO", fg];
    if (code <= 48) return ["fog", "NIEBLA", mute];
    if (code <= 67) return ["rain", "LLUVIA", cyan];
    if (code <= 77) return ["cloud", "NIEVE", fg];
    if (code <= 82) return ["rain", "AGUACERO", cyan];
    return ["storm", "TORMENTA", pink];
}
// bytes por segundo -> texto corto para el HUD ("850K", "1.2M")
function bps(v) {
    var n = num(v);
    if (n < 1024) return Math.round(n) + "B";
    if (n < 1048576) return Math.round(n / 1024) + "K";
    return (n / 1048576).toFixed(1) + "M";
}
