"""Genera la pantalla de arranque (tema de Plymouth) «arcade»: imágenes y arcade.script.
Uso: arranque.py   → crea $ARCADE_HOME/plymouth/arcade (lo instala theme/instalar_arranque.sh)
ARCADE_FONT indica la fuente Press Start 2P si no está en la carpeta personal."""
import os
from PIL import Image, ImageDraw, ImageFont

BASE = os.environ.get("ARCADE_HOME") or os.path.expanduser("~/.local/share/arcade-tokyo")
DEST = BASE + "/plymouth/arcade"
FONT = os.environ.get("ARCADE_FONT") or os.path.expanduser("~/.local/share/fonts/PressStart2P-Regular.ttf")
S = 8  # tamaño de cada píxel de los sprites

SPR = {
    "squid": (("00011000", "00111100", "01111110", "11011011", "11111111", "00100100", "01011010", "10100101"),
              ("00011000", "00111100", "01111110", "11011011", "11111111", "01011010", "10000001", "01000010")),
    "crab": (("00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"),
             ("00100000100", "10010001001", "10111111101", "11101110111", "11111111111", "01111111110", "00100000100", "01000000010")),
    "octopus": (("000011110000", "011111111110", "111111111111", "111001100111", "111111111111", "000110011000", "001101101100", "110000000011"),
                ("000011110000", "011111111110", "111111111111", "111001100111", "111111111111", "001110011100", "011001100110", "001100001100")),
}
SHIP = ("0000001000000", "0000011100000", "0000011100000", "0100111110010", "0101111111010", "1111101011111", "1111111111111", "1011011101101", "1010011100101")
ROW = (("squid", (247, 118, 142)), ("crab", (224, 175, 104)), ("octopus", (187, 154, 247)), ("crab", (158, 206, 106)),
       ("squid", (125, 207, 255)), ("octopus", (255, 158, 100)), ("crab", (122, 162, 247)))
FG, PINK, OFF = (192, 202, 245), (247, 118, 142), (42, 46, 66)


def sprite(mat, col, s=S, two_tone=False):
    im = Image.new("RGBA", (len(mat[0]) * s, len(mat) * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for r, row in enumerate(mat):
        for c, v in enumerate(row):
            if v == "1":
                px = PINK if two_tone and ((c in (1, 11) and r in (3, 4)) or (r >= 6 and c in (0, 2, 6, 10, 12))) else col
                d.rectangle((c * s, r * s, (c + 1) * s - 1, (r + 1) * s - 1), fill=px + (255,))
    return im


def block(col):
    return Image.new("RGBA", (20, 20), col + (255,))


os.makedirs(DEST, exist_ok=True)
for i, (kind, col) in enumerate(ROW):
    sprite(SPR[kind][0], col).save(f"{DEST}/inv{i}a.png")
    sprite(SPR[kind][1], col).save(f"{DEST}/inv{i}b.png")
sprite(SHIP, FG, two_tone=True).save(f"{DEST}/ship.png")
Image.new("RGBA", (6, 28), (125, 207, 255, 255)).save(f"{DEST}/laser.png")
block(OFF).save(f"{DEST}/block_off.png")
block((158, 206, 106)).save(f"{DEST}/block_green.png")
block((224, 175, 104)).save(f"{DEST}/block_yellow.png")
block(PINK).save(f"{DEST}/block_pink.png")
font = ImageFont.truetype(FONT, 24)
text = "CARGANDO SISTEMA"
box = font.getbbox(text)
title = Image.new("RGBA", (box[2] + 4, box[3] + 4), (0, 0, 0, 0))
ImageDraw.Draw(title).text((2, 2), text, font=font, fill=(125, 207, 255, 255))
title.save(f"{DEST}/title.png")

open(f"{DEST}/arcade.plymouth", "w").write("""[Plymouth Theme]
Name=Arcade Tokyo
Description=Marcianos de 8 bits con barra de carga
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/arcade
ScriptFile=/usr/share/plymouth/themes/arcade/arcade.script
""")

open(f"{DEST}/arcade.script", "w").write("""# Pantalla de arranque arcade: marcianos que se balancean, nave que dispara y barra de carga.
Window.SetBackgroundTopColor (0.102, 0.106, 0.149);
Window.SetBackgroundBottomColor (0.102, 0.106, 0.149);

sw = Window.GetWidth ();
sh = Window.GetHeight ();
cx = Window.GetX () + sw / 2;
cy = Window.GetY () + sh / 2;

NUM = 7;
STEP = 140;
for (i = 0; i < NUM; i++) {
    inv[i].a = Image ("inv" + i + "a.png");
    inv[i].b = Image ("inv" + i + "b.png");
    inv[i].sprite = Sprite (inv[i].a);
    inv[i].base = cx - (NUM * STEP) / 2 + i * STEP + (STEP - inv[i].a.GetWidth ()) / 2;
    inv[i].sprite.SetY (cy - 190);
    inv[i].sprite.SetX (inv[i].base);
}

ship.image = Image ("ship.png");
ship.sprite = Sprite (ship.image);
ship.sprite.SetY (cy + 20);

laser.image = Image ("laser.png");
laser.sprite = Sprite (laser.image);
laser.x = 0;
laser.y = 0;

title.image = Image ("title.png");
title.sprite = Sprite (title.image);
title.sprite.SetX (cx - title.image.GetWidth () / 2);
title.sprite.SetY (cy + 140);

BLOCKS = 20;
GAP = 26;
block_off = Image ("block_off.png");
block_green = Image ("block_green.png");
block_yellow = Image ("block_yellow.png");
block_pink = Image ("block_pink.png");
for (i = 0; i < BLOCKS; i++) {
    bar[i] = Sprite (block_off);
    bar[i].SetX (cx - (BLOCKS * GAP) / 2 + i * GAP);
    bar[i].SetY (cy + 200);
}

tick = 0;
fun refresh_cb () {
    tick++;
    sway = Math.Sin (tick / 40) * 60;
    frame = Math.Int (tick / 20) % 2;
    for (i = 0; i < NUM; i++) {
        if (frame == 0) inv[i].sprite.SetImage (inv[i].a);
        else inv[i].sprite.SetImage (inv[i].b);
        inv[i].sprite.SetX (inv[i].base + sway);
    }
    shipx = cx + Math.Sin (tick / 23) * 300 - ship.image.GetWidth () / 2;
    ship.sprite.SetX (shipx);
    if (laser.y < cy - 110) {
        laser.y = cy + 10;
        laser.x = shipx + ship.image.GetWidth () / 2 - 3;
    }
    laser.y -= 14;
    laser.sprite.SetPosition (laser.x, laser.y, 1);
}
Plymouth.SetRefreshFunction (refresh_cb);

fun progress_cb (duration, progress) {
    lit = Math.Int (progress * BLOCKS + 0.5);
    for (i = 0; i < BLOCKS; i++) {
        if (i >= lit) bar[i].SetImage (block_off);
        else if (i < 12) bar[i].SetImage (block_green);
        else if (i < 17) bar[i].SetImage (block_yellow);
        else bar[i].SetImage (block_pink);
    }
}
Plymouth.SetBootProgressFunction (progress_cb);

# Mensajes y petición de contraseña (por si algún día se cifra el disco)
msg.sprite = Sprite ();
msg.sprite.SetPosition (cx - 300, cy + 250, 2);
fun message_cb (text) {
    msg.sprite.SetImage (Image.Text (text, 0.75, 0.79, 0.96));
}
Plymouth.SetMessageFunction (message_cb);

ask.prompt = Sprite ();
ask.bullets = Sprite ();
fun password_cb (prompt, bullets) {
    ask.prompt.SetImage (Image.Text (prompt, 0.75, 0.79, 0.96));
    ask.prompt.SetPosition (cx - 300, cy + 280, 2);
    stars = "";
    for (i = 0; i < bullets; i++) stars += "*";
    ask.bullets.SetImage (Image.Text (stars, 0.49, 0.81, 1));
    ask.bullets.SetPosition (cx - 300, cy + 310, 2);
    ask.prompt.SetOpacity (1);
    ask.bullets.SetOpacity (1);
}
Plymouth.SetDisplayPasswordFunction (password_cb);
fun normal_cb () {
    ask.prompt.SetOpacity (0);
    ask.bullets.SetOpacity (0);
}
Plymouth.SetDisplayNormalFunction (normal_cb);
""")

print("OK", DEST, sorted(os.listdir(DEST)))
