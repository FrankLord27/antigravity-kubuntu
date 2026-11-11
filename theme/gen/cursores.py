"""Genera el tema de cursores pixel art «ArcadePixel» en ~/.local/share/icons. Uso: cursores.py"""
import os, subprocess, tempfile
from PIL import Image

DEST = os.path.expanduser("~/.local/share/icons/ArcadePixel")
COL = {"X": (22, 22, 30, 255), "o": (192, 202, 245, 255), "c": (125, 207, 255, 255), "p": (247, 118, 142, 255)}

ARROW = """
X
XX
XcX
XccX
XcooX
XcoooX
XcooooX
XcoooooX
XcooooooX
XcoooooooX
XcooooooooX
XcoooooXXXXX
XcooXooX
XcoX.XooX
XcX..XooX
XX....XooX
X.....XooX
.......XX
"""
HAND = """
.....XX
....XppX
....XppX
....XooX
....XooX
....XooXXX
....XooXooXXX
....XooXooXooXX
....XooXooXooXoX
XXX.XooXooXooXoX
XooXXooooooooooX
XoooXooooooooooX
.XooXooooooooooX
..XooooooooooooX
..XooooooooooooX
...XoooooooooooX
...XooooooooooX
....XoooooooooX
....XoooooooooX
.....XXXXXXXXX
"""
TEXT = "\n".join(["XXX.XXX", "XccXccX", ".XXcXX."] + ["..XcX.."] * 12 + [".XXcXX.", "XccXccX", "XXX.XXX"])

# nombre: (dibujo, punto activo en píxeles del dibujo, alias)
CURSORS = {
    "default": (ARROW, (0, 0), ("left_ptr", "arrow", "top_left_arrow")),
    "pointer": (HAND, (5, 0), ("hand1", "hand2", "pointing_hand", "9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106")),
    "text": (TEXT, (3, 9), ("xterm", "ibeam")),
}


def render(art, scale):
    rows = art.strip("\n").split("\n")
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w * scale, len(rows) * scale), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in COL:
                im.paste(COL[ch], (x * scale, y * scale, (x + 1) * scale, (y + 1) * scale))
    return im


os.makedirs(DEST + "/cursors", exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
    for name, (art, (hx, hy), aliases) in CURSORS.items():
        lines = []
        for scale, nominal in ((1, 24), (2, 48), (3, 72), (4, 96)):  # la flecha mide 12x18 por unidad, como un cursor estándar de 24
            png = f"{tmp}/{name}{scale}.png"
            render(art, scale).save(png)
            lines.append(f"{nominal} {hx * scale + scale // 2} {hy * scale + scale // 2} {png}")
        cfg = f"{tmp}/{name}.cfg"
        open(cfg, "w").write("\n".join(lines) + "\n")
        subprocess.run(["xcursorgen", cfg, f"{DEST}/cursors/{name}"], check=True)
        for a in aliases:
            link = f"{DEST}/cursors/{a}"
            if os.path.lexists(link):
                os.remove(link)
            os.symlink(name, link)
open(DEST + "/index.theme", "w").write("[Icon Theme]\nName=Arcade Pixel\nComment=Cursores pixel art Tokyo Night\nInherits=breeze_cursors\n")
print("OK", DEST)
