"""Sintetiza sonidos chiptune (onda cuadrada y ruido) y crea el tema de sonidos «arcade».
Uso: sonidos.py"""
import math, os, random, struct, subprocess, wave

DEST = os.path.expanduser("~/.local/share/sounds/arcade")
RATE, VOL = 44100, 0.07
rng = random.Random(3)

C5, D5, E5, G5, A5, B5 = 523, 587, 659, 784, 880, 988
C6, D6, E6, G6 = 1047, 1175, 1319, 1568


def tone(f0, f1, dur, kind="sq", decay=False):
    """Segmento: barrido de f0 a f1 Hz. f0=0 es silencio. kind: sq (cuadrada) o noise."""
    n = int(RATE * dur)
    out, phase, held = [], 0.0, 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        env = (1 - t) ** 1.5 if decay else min(1.0, (n - i) / 200, (i + 1) / 60)  # evita chasquidos
        if f0 == 0:
            s = 0.0
        elif kind == "noise":
            if i % max(1, int(RATE / max(f, 1) / 2)) == 0:  # ruido «retenido», como en consolas de 8 bits
                held = rng.uniform(-1, 1)
            s = held
        else:
            phase += f / RATE
            s = 1.0 if phase % 1 < 0.5 else -1.0
        out.append(s * env * VOL)
    return out


def seq(*notes, dur=0.06, last=None):
    out = []
    for i, f in enumerate(notes):
        is_last = i == len(notes) - 1
        out += tone(f, f, last if is_last and last else dur, decay=is_last and bool(last))
    return out


def mix(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)]


SOUNDS = {
    # ventanas y dock (los reproduce el script de KWin y el dock)
    "window-open": seq(C5, E5, G5, dur=0.04, last=0.09),
    "window-close": seq(G5, E5, C5, dur=0.04, last=0.09),
    "window-minimize": tone(880, 330, 0.10),
    "window-maximize": tone(330, 880, 0.10),
    "window-restore": tone(700, 440, 0.08),  # un solo barrido: dos notas se oían como dos sonidos
    "pew": tone(1500, 260, 0.11),
    # eventos estándar de Plasma
    "message-new-instant": seq(B5, E6, dur=0.07, last=0.32),  # «moneda»
    "dialog-information": seq(B5, E6, dur=0.07, last=0.32),
    "dialog-question": seq(E5, G5, E5, B5, dur=0.06, last=0.16),
    "dialog-warning": tone(330, 330, 0.10) + tone(0, 0, 0.05) + tone(330, 330, 0.16),
    "dialog-error": mix(tone(220, 90, 0.30, decay=True), tone(400, 120, 0.30, "noise", decay=True)),
    "dialog-error-serious": mix(tone(180, 60, 0.45, decay=True), tone(300, 80, 0.45, "noise", decay=True)),
    "bell-window-system": tone(A5, A5, 0.07),
    "audio-volume-change": tone(E5, E5, 0.04),
    "button-pressed": tone(C6, C6, 0.03),
    "button-pressed-modifier": tone(G5, G5, 0.03),
    "device-added": seq(C5, G5, dur=0.06, last=0.14),
    "device-removed": seq(G5, C5, dur=0.06, last=0.14),
    "power-plug": seq(392, C5, G5, dur=0.05, last=0.14),
    "power-unplug": seq(G5, C5, 392, dur=0.05, last=0.14),
    "battery-low": (tone(440, 440, 0.12) + tone(0, 0, 0.06)) * 2 + tone(330, 330, 0.22, decay=True),
    "battery-caution": (tone(440, 440, 0.10) + tone(0, 0, 0.05)) * 3,
    "desktop-login": seq(C5, E5, G5, C6, E6, G6, dur=0.09, last=0.45),
    "desktop-logout": seq(G6, E6, C6, G5, E5, C5, dur=0.09, last=0.45),
    "service-login": seq(G5, C6, dur=0.07, last=0.2),
    "service-logout": seq(C6, G5, dur=0.07, last=0.2),
    "trash-empty": mix(tone(900, 60, 0.40, "noise", decay=True), tone(160, 40, 0.40, decay=True)),  # explosión
    "outcome-success": seq(E5, G5, E6, C6, D6, G6, dur=0.07, last=0.25),  # «vida extra»
    "completion-success": seq(E5, G5, E6, C6, D6, G6, dur=0.07, last=0.25),
    "outcome-failure": seq(392, 311, 262, dur=0.11, last=0.35),
    "completion-fail": seq(392, 311, 262, dur=0.11, last=0.35),
    "completion-partial": seq(G5, E5, dur=0.06, last=0.12),
    "completion-rotation": tone(D5, D5, 0.05),
    "alarm-clock-elapsed": (seq(C6, G6, dur=0.08) + tone(0, 0, 0.1)) * 4,
    "phone-incoming-call": (seq(E6, G6, E6, G6, E6, G6, dur=0.05) + tone(0, 0, 0.35)) * 2,
}
ALIASES = {"bell": "bell-window-system", "dialog-error-critical": "dialog-error-serious", "message-attention": "message-new-instant",
           "battery-full": "outcome-success", "theme-demo": "desktop-login", "message-sent-instant": "service-login"}

os.makedirs(DEST + "/wav", exist_ok=True)
os.makedirs(DEST + "/stereo", exist_ok=True)
for name, samples in SOUNDS.items():
    wav = f"{DEST}/wav/{name}.wav"
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<hh", v, v) for v in (int(max(-1, min(1, s)) * 32767) for s in samples)))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", f"{DEST}/stereo/{name}.oga"], check=True)
for alias, target in ALIASES.items():
    link = f"{DEST}/stereo/{alias}.oga"
    if os.path.lexists(link):
        os.remove(link)
    os.symlink(target + ".oga", link)
open(DEST + "/index.theme", "w").write(
    "[Sound Theme]\nName=Arcade\nComment=Sonidos chiptune de 8 bits\nInherits=ocean\nDirectories=stereo\n\n[stereo]\nOutputProfile=stereo\n")
print(f"OK: {len(SOUNDS)} sonidos en {DEST}")
