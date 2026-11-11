"""Fondo animado: guerra arcade Tokyo Night con profundidad (falso 3D).
Uso: guerra_arcade_3d.py salida.mp4 [dir_previews]"""
import math, random, subprocess, sys
from PIL import Image, ImageChops, ImageDraw

OUT = sys.argv[1]
PREV = sys.argv[2] if len(sys.argv) > 2 else None
W, H, FPS, DUR = 1920, 1080, 60, 30
TOTAL = FPS * DUR
BG = (26, 27, 38)
HOME = (960.0, 900.0)
T_BOSS, T_DEADLINE, T_CLEAN, T_HOME = 1080, 1540, 1620, 1690

# Proyección: el campo de juego es un plano inclinado; lo lejano (arriba) se ve más pequeño.
PA, PB, HOR, PD = 0.909, 0.000842, -890.0, 1854.6
FAR_Y, SIDE = -420.0, 900.0  # dónde nace algo para quedar fuera de pantalla


def P(x, y):
    s = 1.0 / (PA + PB * (H - y))
    return 960 + (x - 960) * s, HOR + PD * s, s


SPR = {
    "squid": (("00011000", "00111100", "01111110", "11011011", "11111111", "00100100", "01011010", "10100101"),
              ("00011000", "00111100", "01111110", "11011011", "11111111", "01011010", "10000001", "01000010")),
    "crab": (("00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"),
             ("00100000100", "10010001001", "10111111101", "11101110111", "11111111111", "01111111110", "00100000100", "01000000010")),
    "octopus": (("000011110000", "011111111110", "111111111111", "111001100111", "111111111111", "000110011000", "001101101100", "110000000011"),
                ("000011110000", "011111111110", "111111111111", "111001100111", "111111111111", "001110011100", "011001100110", "001100001100")),
    "ufo": (("0000011111100000", "0001111111111000", "0011111111111100", "0110110110110110", "1111111111111111", "0011100110011100", "0001000000001000"),),
    "ship": (("0000001000000", "0000011100000", "0000011100000", "0100111110010", "0101111111010", "1111101011111", "1111111111111", "1011011101101", "1010011100101"),),
}
FONT = {"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111", "4": "101101111001001",
        "5": "111100111001111", "6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111",
        "+": "000010111010000"}
C = {"pink": (247, 118, 142), "yellow": (224, 175, 104), "purple": (187, 154, 247), "green": (158, 206, 106),
     "orange": (255, 158, 100), "cyan": (125, 207, 255), "blue": (122, 162, 247), "white": (192, 202, 245),
     "hot": (255, 255, 255), "smoke": (86, 95, 137), "shadow": (15, 16, 24)}
NEON = [C[k] for k in ("pink", "yellow", "purple", "green", "orange", "cyan", "blue")]
GRID_FAR, GRID_NEAR = (34, 36, 58), (72, 62, 140)
rng = random.Random(7)

_cache = {}


def sprite(kind, frame, col, s):
    key = (kind, frame % len(SPR[kind]), col, s)
    if key not in _cache:
        mat = SPR[kind][key[1]]
        im = Image.new("RGBA", (len(mat[0]) * s, len(mat) * s), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        two_tone = kind == "ship" and col == C["white"]
        for r, row in enumerate(mat):
            for c, v in enumerate(row):
                if v == "1":
                    px = col
                    if two_tone and ((c in (1, 11) and r in (3, 4)) or (r >= 6 and c in (0, 2, 6, 10, 12))):
                        px = C["pink"]
                    d.rectangle((c * s, r * s, (c + 1) * s - 1, (r + 1) * s - 1), fill=px + (255,))
        _cache[key] = im
    return _cache[key]


def blit(img, im, cx, cy):
    img.paste(im, (int(cx - im.width / 2), int(cy - im.height / 2)), im)


def box(d, x, y, s, col):
    """Cuadrado en coordenadas de juego, proyectado."""
    px, py, sc = P(x, y)
    h = max(1.0, s * sc / 2)
    d.rectangle((int(px - h), int(py - h), int(px + h), int(py + h)), fill=col)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ---------- estado ----------
stars = [(rng.uniform(-0.85, 0.85), rng.random(), k, rng.choice((C["blue"], C["purple"], C["smoke"], C["white"])))
         for k in (1, 1, 2, 2, 3) for _ in range(36)]
enemies, lasers, bullets, missiles, parts, rings, popups = [], [], [], [], [], [], []
ship = {"x": HOME[0], "y": HOME[1], "vx": 0.0, "vy": 0.0, "cd": 0, "shield": 0, "muzzle": 0, "target": None, "tt": 0}
fx = {"shake": 0.0, "flash": 0.0}
state = {"last_wave": -999, "boss_done": False, "wave_n": 0}


def boom(x, y, col, n=22, power=7.0, ring=True):
    for _ in range(n):
        a, sp = rng.uniform(0, math.tau), rng.uniform(0.8, power)
        life = rng.randint(16, 46)
        parts.append([x, y, math.cos(a) * sp, math.sin(a) * sp, life, life, rng.choice((6, 8, 11, 14)),
                      rng.choice((col, col, C["hot"], C["yellow"], C["orange"]))])
    if ring:
        rings.append([x, y, 6.0, power * 0.9, 16, col])


def sparks(x, y, col, n=6):
    boom(x, y, col, n, 4.0, ring=False)


def popup(x, y, n, col):
    popups.append([x, y, "+" + str(n), 44, col])


def kill(e):
    if e["state"] == "boss":
        e["state"], e["timer"] = "dying", 80
        return
    e["dead"] = True
    big = e["kind"] == "ufo"
    boom(e["x"], e["y"], e["col"], 46 if big else 24, 10 if big else 7)
    popup(e["x"], e["y"] - 30, 500 if big else e["pts"], e["col"])
    fx["shake"] = min(26, fx["shake"] + (9 if big else 3.5))
    fx["flash"] = min(1, fx["flash"] + (0.35 if big else 0.1))


def damage(e, dmg):
    if e["dead"] or e["state"] == "dying":
        return
    e["hp"] -= dmg
    e["hit"] = 4
    sparks(e["x"], e["y"] + e["h"] / 3, C["hot"], 4)
    if e["hp"] <= 0:
        kill(e)


def mk(kind, col, s, hp, pts, st, x, y, **kw):
    m = SPR[kind][0]
    e = {"kind": kind, "col": col, "s": s, "hp": hp, "pts": pts, "state": st, "x": float(x), "y": float(y), "vx": 0.0,
         "w": len(m[0]) * s, "h": len(m) * s, "hit": 0, "dead": False, "e": 0.0, "sx0": float(x), "sy0": float(y),
         "delay": 0, "slotx": 0.0, "sloty": 0.0, "ph": rng.uniform(0, math.tau), "timer": 0}
    e.update(kw)
    enemies.append(e)
    return e


def spawn_wave(rows, cols, top=150):
    n = state["wave_n"]
    state["wave_n"] += 1
    kinds = ("octopus", "crab", "crab", "squid")
    i = 0
    for r in range(rows):
        col = rng.choice(NEON)
        for c in range(cols):
            if rng.random() < 0.12:
                continue
            kind = kinds[r % 4]
            side = (r + n) % 3
            sx, sy = ((-SIDE, rng.randint(300, 700)), (W + SIDE, rng.randint(300, 700)), (rng.randint(200, W - 200), FAR_Y))[side]
            mk(kind, col if rng.random() < 0.75 else rng.choice(NEON), 8, {"octopus": 3, "crab": 2, "squid": 1}[kind],
               {"octopus": 300, "crab": 200, "squid": 100}[kind], "enter", sx, sy,
               slotx=960 + (c - (cols - 1) / 2) * 112, sloty=top + r * 82, delay=i * 3)
            i += 1


def shoot_at(x, y, tx, ty, col, sp=6.5, spread=0.0):
    a = math.atan2(ty - y, tx - x) + spread
    bullets.append([x, y, math.cos(a) * sp, math.sin(a) * sp, col])


def targets():
    return [e for e in enemies if not e["dead"] and e["state"] != "dying"]


ff = subprocess.Popen(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-framerate", str(FPS),
     "-i", "-", "-c:v", "libx264", "-preset", "slow", "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart", OUT],
    stdin=subprocess.PIPE)

for f in range(TOTAL):
    live = targets()
    boss = next((e for e in enemies if e["state"] in ("boss", "dying")), None)

    # ----- oleadas / jefe / ovni -----
    can_wave = f < T_BOSS - 120 or (state["boss_done"] and f < 1420)
    if can_wave and len(live) < 14 and f - state["last_wave"] > 70:
        spawn_wave(rng.choice((3, 4, 4)), rng.choice((8, 9, 10)))
        state["last_wave"] = f
    if f in (400, 860):
        left = f == 400
        mk("ufo", C["pink"], 9, 4, 500, "ufo", -SIDE if left else W + SIDE, 95, vx=9.0 if left else -9.0)
    if f == T_BOSS:
        mk("ufo", C["purple"], 19, 110, 5000, "boss", 960, -640, hpmax=110)
        spawn_wave(2, 8, top=420)
        fx["shake"] = 14

    # ----- enemigos -----
    sway = math.sin(f * math.tau / 360) * 150
    breathe = math.sin(f * math.tau / 120) * 10
    divers = sum(1 for e in live if e["state"] == "dive")
    for e in live:
        st = e["state"]
        if st == "enter":
            if e["delay"] > 0:
                e["delay"] -= 1
                continue
            e["e"] = min(1.0, e["e"] + 1 / 95)
            k = e["e"] * e["e"] * (3 - 2 * e["e"])
            tx, ty = e["slotx"] + sway, e["sloty"] + breathe
            nx = e["sx0"] + (tx - e["sx0"]) * k + math.sin(e["e"] * math.tau) * 190 * (1 - k)
            ny = e["sy0"] + (ty - e["sy0"]) * k + math.sin(e["e"] * math.pi) * 170 * (1 - k)
            e["vx"], e["x"], e["y"] = nx - e["x"], nx, ny
            if e["e"] >= 1:
                e["state"] = "form"
        elif st == "form":
            nx = e["slotx"] + sway
            e["vx"], e["x"], e["y"] = nx - e["x"], nx, e["sloty"] + breathe + math.sin(f / 9 + e["ph"]) * 4
            if f < T_DEADLINE:
                if rng.random() < 0.0035:
                    shoot_at(e["x"], e["y"] + e["h"] / 2, ship["x"], ship["y"], C["orange"])
                if divers < 5 and rng.random() < 0.004:
                    e["state"], e["vx"] = "dive", rng.choice((-3.0, 3.0))
                    divers += 1
                    for sp in (-0.15, 0.15):
                        shoot_at(e["x"], e["y"], ship["x"], ship["y"], C["pink"], 7.0, sp)
        elif st == "dive":
            e["vx"] += max(-0.3, min(0.3, (ship["x"] - e["x"]) * 0.004))
            e["vx"] = max(-7.0, min(7.0, e["vx"]))
            e["x"] += e["vx"] + math.sin(f / 7 + e["ph"]) * 3
            e["y"] += 6.0
            if f % 3 == 0:
                parts.append([e["x"], e["y"] - e["h"] / 2, 0, -1.5, 12, 12, 7, e["col"]])
            if rng.random() < 0.012:
                shoot_at(e["x"], e["y"], ship["x"], ship["y"], C["pink"], 7.5)
            if abs(e["x"] - ship["x"]) < 60 and abs(e["y"] - ship["y"]) < 50:
                ship["shield"] = 14
                kill(e)
            elif e["y"] > H + 140:
                e.update(state="enter", e=0.0, sx0=e["x"], sy0=FAR_Y, x=e["x"], y=FAR_Y, delay=0)
        elif st == "ufo":
            e["x"] += e["vx"]
            if f % 28 == 0 and 0 < e["x"] < W:
                shoot_at(e["x"], e["y"] + 20, ship["x"], ship["y"], C["yellow"], 7.0)
            if e["x"] < -SIDE - 50 or e["x"] > W + SIDE + 50:
                e["dead"] = True
        elif st == "boss":
            t = f - T_BOSS
            ty = 230 + math.sin(t * math.tau / 200) * 70
            nx = 960 + math.sin(t * math.tau / 300) * 560
            e["vx"], e["x"] = nx - e["x"], nx
            e["y"] += (ty - e["y"]) * 0.05
            if f < T_DEADLINE:
                if t % 42 == 20:
                    for sp in (-0.36, -0.18, 0, 0.18, 0.36):
                        shoot_at(e["x"], e["y"] + 50, ship["x"], ship["y"], C["pink"], 7.0, sp)
                if t % 130 == 90:
                    for i in range(18):
                        a = i * math.tau / 18 + t
                        bullets.append([e["x"], e["y"], math.cos(a) * 5.5, math.sin(a) * 5.5, C["yellow"]])
                    fx["shake"] = max(fx["shake"], 6)
            else:
                e["hp"] = 0
                kill(e)
        if e["hit"] > 0:
            e["hit"] -= 1

    if boss and boss["state"] == "dying":
        boss["timer"] -= 1
        boss["hit"] = 2 if boss["timer"] % 4 < 2 else 0
        if boss["timer"] % 4 == 0:
            boom(boss["x"] + rng.uniform(-120, 120), boss["y"] + rng.uniform(-60, 60), rng.choice(NEON), 18, 8)
            fx["shake"] = max(fx["shake"], 10)
        if boss["timer"] <= 0:
            boss["dead"] = True
            state["boss_done"] = True
            for _ in range(6):
                boom(boss["x"] + rng.uniform(-90, 90), boss["y"] + rng.uniform(-50, 50), rng.choice(NEON), 60, 17)
            popup(boss["x"], boss["y"], 5000, C["yellow"])
            fx["shake"], fx["flash"] = 34, 1.0
            for b in bullets:
                sparks(b[0], b[1], b[4], 3)
            bullets.clear()
            for e in targets():
                kill(e)

    if f >= T_CLEAN:  # limpieza para que el bucle cierre sin saltos
        for e in targets()[:3]:
            kill(e)
        for b in bullets:
            sparks(b[0], b[1], b[4], 3)
        bullets.clear()

    # ----- nave: persigue, esquiva, dispara -----
    live = targets()
    tg = ship["target"]
    ship["tt"] -= 1
    if tg is None or tg["dead"] or tg["state"] == "dying" or ship["tt"] <= 0:
        above = [e for e in live if e["y"] < ship["y"] + 60 and e["delay"] <= 0 and -40 < e["x"] < W + 40 and e["y"] > -60]
        div = [e for e in above if e["state"] == "dive"]
        pool = div or above
        tg = min(pool, key=lambda e: abs(e["x"] - ship["x"]) - e["y"] * 0.6) if pool else None
        ship["target"], ship["tt"] = tg, 45
    if tg and f < T_HOME:
        dx = tg["x"] + tg["vx"] * 9
        gap = 210 if tg["state"] == "dive" else (360 if tg["state"] == "boss" else 290)
        dy = max(430.0, min(960.0, tg["y"] + gap))
    else:
        dx, dy = HOME
    for b in bullets:
        ddy, ddx = ship["y"] - b[1], ship["x"] - b[0]
        if -20 < ddy < 230 and abs(ddx + b[2] * ddy / max(1.0, b[3])) < 75 and b[3] > 0:
            dx += 190 if ddx >= 0 else -190
            dy += 40
    dx, dy = max(70.0, min(W - 70.0, dx)), max(400.0, min(980.0, dy))
    k = 0.016 if f < T_HOME else 0.03
    ship["vx"] = max(-17.0, min(17.0, (ship["vx"] + (dx - ship["x"]) * k) * 0.87))
    ship["vy"] = max(-12.0, min(12.0, (ship["vy"] + (dy - ship["y"]) * k) * 0.87))
    ship["x"] += ship["vx"]
    ship["y"] += ship["vy"]
    if f >= TOTAL - 50:
        s = (f - (TOTAL - 50)) / 49
        s = s * s * (3 - 2 * s)
        ship["x"] += (HOME[0] - ship["x"]) * s
        ship["y"] += (HOME[1] - ship["y"]) * s

    ship["cd"] -= 1
    if ship["cd"] <= 0 and any(abs(e["x"] - ship["x"]) < e["w"] / 2 + 30 and -60 < e["y"] < ship["y"] for e in live):
        lasers.append([ship["x"] - 40, ship["y"] - 20])
        lasers.append([ship["x"] + 40, ship["y"] - 20])
        ship["cd"], ship["muzzle"] = 5, 2
    onscreen = [e for e in live if -60 < e["y"] and -40 < e["x"] < W + 40]
    if onscreen and f % 55 == 30 and f < T_CLEAN:
        for sd in (-1, 1):
            missiles.append([ship["x"] + sd * 44, ship["y"], sd * 9.0, -3.0, rng.choice(onscreen), 170])

    # ----- proyectiles -----
    for l in lasers[:]:
        l[1] -= 28
        hit = next((e for e in live if not e["dead"] and e["state"] != "dying" and abs(l[0] - e["x"]) < e["w"] / 2 + 5 and abs(l[1] - e["y"]) < e["h"] / 2 + 14), None)
        if hit:
            damage(hit, 1)
            lasers.remove(l)
        elif l[1] < FAR_Y:
            lasers.remove(l)
    for m in missiles[:]:
        t = m[4]
        if t["dead"] or t["state"] == "dying":
            pool = targets()
            if not pool:
                sparks(m[0], m[1], C["yellow"], 8)
                missiles.remove(m)
                continue
            t = m[4] = rng.choice(pool)
        ax, ay = t["x"] - m[0], t["y"] - m[1]
        dist = math.hypot(ax, ay) or 1.0
        m[2] = m[2] * 0.9 + ax / dist * 1.9
        m[3] = m[3] * 0.9 + ay / dist * 1.9
        m[0] += m[2]
        m[1] += m[3]
        m[5] -= 1
        parts.append([m[0], m[1], rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 16, 16, 9, C["smoke"]])
        if abs(ax) < t["w"] / 2 + 14 and abs(ay) < t["h"] / 2 + 14:
            boom(m[0], m[1], C["yellow"], 12, 5)
            damage(t, 3)
            missiles.remove(m)
        elif m[5] <= 0:
            sparks(m[0], m[1], C["yellow"], 8)
            missiles.remove(m)
    for b in bullets[:]:
        b[0] += b[2]
        b[1] += b[3]
        if abs(b[0] - ship["x"]) < 36 and abs(b[1] - ship["y"]) < 32:
            ship["shield"] = 14
            sparks(b[0], b[1], C["cyan"], 10)
            fx["shake"] = max(fx["shake"], 6)
            bullets.remove(b)
        elif not (-SIDE < b[0] < W + SIDE and FAR_Y < b[1] < H + 160):
            bullets.remove(b)
    enemies[:] = [e for e in enemies if not e["dead"]]

    # ---------- dibujo ----------
    fl = fx["flash"]
    bg = mix(BG, (70, 74, 110), fl)
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)

    # estrellas que vienen hacia la cámara desde el punto de fuga
    for ang, ph, k, col in stars:
        t = (ph + k * f / TOTAL * 2) % 1.0
        r = 880 + (t ** 1.6) * 1500
        x, y = 960 + math.sin(ang) * r, HOR + math.cos(ang) * r
        ln = 2 + t * 16 * k / 2
        ux, uy = math.sin(ang), math.cos(ang)
        d.line((x, y, x + ux * ln, y + uy * ln), fill=mix(bg, col, 0.35 + 0.65 * t), width=2 + int(t * 2))

    # rejilla en perspectiva que avanza
    off = (f * 4) % 160
    for gx in range(-1760, 3700, 160):
        x0, y0, _ = P(gx, -500)
        x1, y1, _ = P(gx, 1200)
        d.line((x0, y0, x1, y1), fill=mix(bg, GRID_NEAR, 0.45), width=2)
    for gy in range(-640, 1280, 160):
        _, py, sc = P(0, gy + off)
        if -4 < py < H + 4:
            d.line((0, py, W, py), fill=mix(GRID_FAR, GRID_NEAR, min(1.0, max(0.0, (sc - 0.5) / 0.6))) if fl < 0.05 else mix(bg, GRID_NEAR, 0.6),
                   width=2 if sc < 0.8 else 3)

    for p in parts:
        if p[7] == C["smoke"]:
            box(d, p[0], p[1], max(2, p[6] * p[4] / p[5]), p[7])

    for e in sorted(enemies, key=lambda e: e["y"]):
        if e["delay"] > 0:
            continue
        px, py, sc = P(e["x"], e["y"])
        size = max(2, round(e["s"] * sc))
        fr = f // 18 + int(e["ph"] * 3)
        lift = 26 if e["state"] in ("boss", "dying") else 14
        blit(img, sprite(e["kind"], fr, C["shadow"], size), px + lift * sc, py + lift * 1.5 * sc)
        blit(img, sprite(e["kind"], fr, C["hot"] if e["hit"] else e["col"], size), px, py)
        if e["state"] == "boss":
            n, bw = 20, 14 * sc
            fill = math.ceil(n * max(0, e["hp"]) / e["hpmax"])
            top = py - e["h"] / 2 * sc - 22 * sc
            for i in range(n):
                x0 = px - n * bw / 2 + i * bw
                d.rectangle((x0, top, x0 + bw * 0.72, top + 10 * sc), fill=(C["green"] if fill > 7 else C["pink"]) if i < fill else C["smoke"])

    for b in bullets:
        box(d, b[0], b[1], 15, b[4])
        box(d, b[0], b[1], 6, C["hot"])
    for l in lasers:
        px, py, sc = P(l[0], l[1])
        d.rectangle((px - 4 * sc, py - 18 * sc, px + 4 * sc, py + 18 * sc), fill=C["cyan"])
        d.rectangle((px - 1.5 * sc, py - 18 * sc, px + 1.5 * sc, py + 8 * sc), fill=C["hot"])
    for m in missiles:
        box(d, m[0], m[1], 13, C["yellow"])
        box(d, m[0] - m[2] * 0.8, m[1] - m[3] * 0.8, 9, C["orange"])

    sx, sy, sc = P(ship["x"], ship["y"])
    u = max(3, round(8 * sc))
    blit(img, sprite("ship", 0, C["shadow"], u), sx + 16 * sc, sy + 26 * sc)
    for i in range((3, 5, 4, 6)[f % 4]):  # llama del motor
        wd = 3 - min(2, i // 2)
        d.rectangle((sx - wd * u / 2, sy + 4.5 * u + i * u, sx + wd * u / 2, sy + 5.5 * u + i * u - 1),
                    fill=(C["yellow"], C["orange"], C["pink"])[min(2, i // 2)])
    blit(img, sprite("ship", 0, C["white"], u), sx, sy)
    if ship["muzzle"] > 0:
        ship["muzzle"] -= 1
        box(d, ship["x"] - 40, ship["y"] - 34, 18, C["hot"])
        box(d, ship["x"] + 40, ship["y"] - 34, 18, C["hot"])
    if ship["shield"] > 0:
        ship["shield"] -= 1
        for i in range(20):
            a = i * math.tau / 20 + f * 0.2
            box(d, ship["x"] + math.cos(a) * 74, ship["y"] + math.sin(a) * 64, 9, C["cyan"] if i % 2 else C["hot"])

    for r in rings:
        for i in range(22):
            a = i * math.tau / 22
            box(d, r[0] + math.cos(a) * r[2], r[1] + math.sin(a) * r[2], max(3, r[4] * 0.6), r[5])
        r[2] += r[3]
        r[4] -= 1
    rings[:] = [r for r in rings if r[4] > 0]
    for p in parts:
        if p[7] != C["smoke"]:
            box(d, p[0], p[1], max(2, p[6] * p[4] / p[5]), p[7])
        p[0] += p[2]
        p[1] += p[3]
        p[2] *= 0.95
        p[3] *= 0.95
        p[4] -= 1
    parts[:] = [p for p in parts if p[4] > 0]
    for pp in popups:
        if pp[3] % 6 < 4:
            px0, py0, sc = P(pp[0], pp[1])
            g = max(3, round(5 * sc))
            x0 = px0 - len(pp[2]) * g * 2
            for ci, ch in enumerate(pp[2]):
                for i, v in enumerate(FONT[ch]):
                    if v == "1":
                        qx, qy = x0 + ci * g * 4 + (i % 3) * g, py0 + (i // 3) * g
                        d.rectangle((qx, qy, qx + g - 1, qy + g - 1), fill=pp[4])
        pp[1] -= 1.2
        pp[3] -= 1
    popups[:] = [pp for pp in popups if pp[3] > 0]

    if fx["shake"] > 0.6:
        img = ImageChops.offset(img, int(rng.uniform(-1, 1) * fx["shake"]), int(rng.uniform(-1, 1) * fx["shake"]))
    fx["shake"] *= 0.86
    fx["flash"] = fx["flash"] * 0.8 if fx["flash"] > 0.02 else 0.0

    if PREV and f in (0, 150, 330, 700, 1250, 1500, 1622, TOTAL - 1):
        img.save(f"{PREV}/f{f:04d}.png")
    ff.stdin.write(img.tobytes())

ff.stdin.close()
if ff.wait() != 0:
    sys.exit("ffmpeg falló")
left = dict(enemies=len(enemies), lasers=len(lasers), bullets=len(bullets), missiles=len(missiles), parts=len(parts),
            rings=len(rings), popups=len(popups), ship=(round(ship["x"], 1), round(ship["y"], 1)), shake=round(fx["shake"], 2))
print("OK", OUT, "| estado final:", left)
