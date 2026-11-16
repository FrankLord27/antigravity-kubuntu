"""Genera el tema de GRUB «arcade»: fondo, marco neón, iconos de invaders, fuente y theme.txt.
Uso: grub.py   → crea $ARCADE_HOME/grub/arcade (lo instala theme/instalar_grub.sh)
ARCADE_FONT indica la fuente Press Start 2P si no está en la carpeta personal.
Necesita grub-mkfont (paquete grub-common) para convertir la fuente al formato de GRUB."""
import os
import random
import subprocess
import sys
from PIL import Image, ImageDraw

BASE = os.environ.get("ARCADE_HOME") or os.path.expanduser("~/.local/share/arcade-tokyo")
DEST = BASE + "/grub/arcade"
FONT = os.environ.get("ARCADE_FONT") or os.path.expanduser("~/.local/share/fonts/PressStart2P-Regular.ttf")
W, H = 1920, 1080
ITEM_H = 56  # alto de cada entrada del menú; la imagen de «seleccionado» mide lo mismo

BG, PANEL = (26, 27, 38), (22, 22, 30)
CYAN, PURPLE, PINK, GREEN, MUTE, FG = (125, 207, 255), (187, 154, 247), (247, 118, 142), (158, 206, 106), (86, 95, 137), (192, 202, 245)
GRID = (42, 46, 66)

SPR = {
    "squid": ("00011000", "00111100", "01111110", "11011011", "11111111", "00100100", "01011010", "10100101"),
    "crab": ("00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"),
    "octopus": ("000011110000", "011111111110", "111111111111", "111001100111", "111111111111", "000110011000", "001101101100", "110000000011"),
}
# clase de GRUB → (sprite, color). Las clases salen de /etc/grub.d (--class debian, os-prober, efi…)
ICONOS = {
    "debian": ("squid", PINK), "ubuntu": ("crab", (255, 158, 100)), "kubuntu": ("crab", (122, 162, 247)),
    "gnu-linux": ("crab", GREEN), "linux": ("crab", GREEN), "efi": ("octopus", PURPLE),
    "windows": ("squid", CYAN), "unknown": ("squid", CYAN),
}


def sprite(mat, col, s):
    im = Image.new("RGBA", (len(mat[0]) * s, len(mat) * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for r, row in enumerate(mat):
        for c, v in enumerate(row):
            if v == "1":
                d.rectangle((c * s, r * s, (c + 1) * s - 1, (r + 1) * s - 1), fill=col + (255,))
    return im


def fondo():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)  # estrellas siempre iguales
    for _ in range(140):
        x, y = rnd.randrange(W), rnd.randrange(int(H * 0.72))
        d.rectangle((x, y, x + 2, y + 2), fill=rnd.choice([MUTE, GRID, GRID, PURPLE]))
    # rejilla en perspectiva abajo, como en el login
    hz = int(H * 0.80)
    for i in range(-14, 15):
        d.line((W // 2 + i * 40, hz, W // 2 + i * 300, H), fill=GRID, width=2)
    for k in range(1, 9):
        d.line((0, hz + int((H - hz) * (k / 8) ** 2), W, hz + int((H - hz) * (k / 8) ** 2)), fill=GRID, width=2)
    # fila de invaders encima del título, con los mismos colores del arranque
    fila = [("squid", PINK), ("crab", (224, 175, 104)), ("octopus", PURPLE), ("crab", GREEN), ("squid", CYAN), ("octopus", (255, 158, 100)), ("crab", (122, 162, 247))]
    x = (W - 7 * 100) // 2
    for nombre, col in fila:
        sp = sprite(SPR[nombre], col, 5)
        im.paste(sp, (x + (100 - sp.width) // 2, int(H * 0.115)), sp)
        x += 100
    # oscurece un poco para que el texto se lea
    return Image.blend(im, Image.new("RGB", (W, H), BG), 0.25)


def marco():
    """Marco neón doble (cian por fuera, morado por dentro) cortado en las 9 piezas que pide GRUB."""
    n = 36
    im = Image.new("RGBA", (n, n), PANEL + (225,))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, n - 1, n - 1), outline=CYAN + (255,), width=3)
    d.rectangle((6, 6, n - 7, n - 7), outline=PURPLE + (255,), width=2)
    m = 12
    pieza = {"nw": (0, 0, m, m), "n": (m, 0, m + 1, m), "ne": (n - m, 0, n, m),
             "w": (0, m, m, m + 1), "c": (m, m, m + 1, m + 1), "e": (n - m, m, n, m + 1),
             "sw": (0, n - m, m, n), "s": (m, n - m, m + 1, n), "se": (n - m, n - m, n, n)}
    for nombre, caja in pieza.items():
        im.crop(caja).save(f"{DEST}/menu_{nombre}.png")


def seleccion():
    """Entrada elegida: relleno oscuro y borde rosa. Tres piezas (izquierda, centro, derecha)."""
    im = Image.new("RGBA", (40, ITEM_H), (42, 46, 66, 255))
    ImageDraw.Draw(im).rectangle((0, 0, 39, ITEM_H - 1), outline=PINK + (255,), width=3)
    im.crop((0, 0, 8, ITEM_H)).save(f"{DEST}/select_w.png")
    im.crop((16, 0, 17, ITEM_H)).save(f"{DEST}/select_c.png")
    im.crop((32, 0, 40, ITEM_H)).save(f"{DEST}/select_e.png")


def iconos():
    os.makedirs(DEST + "/icons", exist_ok=True)
    for clase, (nombre, col) in ICONOS.items():
        sp = sprite(SPR[nombre], col, 4)
        lienzo = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        lienzo.paste(sp, ((48 - sp.width) // 2, (48 - sp.height) // 2), sp)
        lienzo.save(f"{DEST}/icons/{clase}.png")


def fuente():
    for size in (12, 16, 32):
        subprocess.run(["grub-mkfont", "-s", str(size), "-o", f"{DEST}/pressstart{size}.pf2", FONT], check=True)


TEMA = f"""# Tema de GRUB «Arcade Tokyo» — lo genera theme/gen/grub.py
desktop-image: "background.png"
desktop-color: "#1a1b26"
title-text: ""
terminal-font: "Press Start 2P Regular 16"
terminal-box: "menu_*.png"
terminal-left: "10%"
terminal-top: "10%"
terminal-width: "80%"
terminal-height: "80%"

+ label {{
    left = 0
    top = 5%
    width = 100%
    align = "center"
    text = "ARCADE TOKYO"
    font = "Press Start 2P Regular 32"
    color = "#7dcfff"
}}

+ label {{
    left = 0
    top = 23%
    width = 100%
    align = "center"
    text = "PLAYER 1 - ELIGE TU JUEGO"
    font = "Press Start 2P Regular 16"
    color = "#bb9af7"
}}

+ boot_menu {{
    left = 20%
    top = 30%
    width = 60%
    height = 42%
    item_font = "Press Start 2P Regular 16"
    selected_item_font = "Press Start 2P Regular 16"
    item_color = "#c0caf5"
    selected_item_color = "#7dcfff"
    icon_width = 48
    icon_height = 48
    item_icon_space = 24
    item_height = {ITEM_H}
    item_padding = 12
    item_spacing = 10
    menu_pixmap_style = "menu_*.png"
    selected_item_pixmap_style = "select_*.png"
    scrollbar = false
}}

+ progress_bar {{
    id = "__timeout__"
    left = 30%
    top = 77%
    width = 40%
    height = 28
    show_text = true
    text = "@TIMEOUT_NOTIFICATION_SHORT@"
    font = "Press Start 2P Regular 12"
    text_color = "#c0caf5"
    fg_color = "#9ece6a"
    bg_color = "#16161e"
    border_color = "#565f89"
}}

+ label {{
    left = 0
    top = 86%
    width = 100%
    align = "center"
    text = "FLECHAS: ELEGIR   ENTER: JUGAR   E: EDITAR   C: CONSOLA"
    font = "Press Start 2P Regular 12"
    color = "#565f89"
}}
"""


def main():
    if not os.path.isfile(FONT):
        sys.exit(f"No encuentro la fuente {FONT}")
    os.makedirs(DEST, exist_ok=True)
    fondo().save(f"{DEST}/background.png")
    marco()
    seleccion()
    iconos()
    fuente()
    with open(f"{DEST}/theme.txt", "w", encoding="utf-8") as f:
        f.write(TEMA)
    print("OK", DEST, sorted(os.listdir(DEST)))


main()
