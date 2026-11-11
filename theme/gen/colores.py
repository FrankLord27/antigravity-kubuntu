"""Escribe los esquemas de color Tokyo Night Arcade: el de Plasma y el de Konsole. Uso: colores.py"""
import os

HOME = os.path.expanduser("~")
bg, bgd, bgh, fg, mute = "26,27,38", "22,22,30", "41,46,66", "192,202,245", "86,95,137"
blue, cyan, mag, red, green, yellow = "122,162,247", "125,207,255", "187,154,247", "247,118,142", "158,206,106", "224,175,104"


def section(name, normal, alt, fgc=fg):
    return f"""[Colors:{name}]
BackgroundAlternate={alt}
BackgroundNormal={normal}
DecorationFocus={cyan}
DecorationHover={mag}
ForegroundActive={cyan}
ForegroundInactive={mute}
ForegroundLink={blue}
ForegroundNegative={red}
ForegroundNeutral={yellow}
ForegroundNormal={fgc}
ForegroundPositive={green}
ForegroundVisited={mag}
"""


plasma = "\n".join([
    section("Button", bgh, bg), section("Complementary", bgd, bg), section("Header", bgd, bg), section("Header][Inactive", bgd, bg),
    section("Selection", mag, blue, fgc=bgd), section("Tooltip", bgd, bg), section("View", bg, bgd), section("Window", bgd, bg),
    f"[General]\nColorScheme=TokyoNightArcade\nName=Tokyo Night Arcade\nshadeSortColumn=true\naccentColor={mag}\n",
    "[KDE]\ncontrast=4\n",
    f"[WM]\nactiveBackground={bgd}\nactiveBlend={mag}\nactiveForeground={fg}\ninactiveBackground={bgd}\ninactiveBlend={mute}\ninactiveForeground={mute}\n",
])
os.makedirs(HOME + "/.local/share/color-schemes", exist_ok=True)
open(HOME + "/.local/share/color-schemes/TokyoNightArcade.colors", "w").write(plasma)

ansi = {"Background": bg, "Foreground": fg, "Color0": "21,22,30", "Color1": red, "Color2": green, "Color3": yellow,
        "Color4": blue, "Color5": mag, "Color6": cyan, "Color7": "169,177,214"}
out = []
for key, value in ansi.items():
    for suffix in ("", "Intense", "Faint"):
        v = value
        if suffix == "Intense" and key == "Color0":
            v = "65,72,104"
        if suffix == "Intense" and key == "Color7":
            v = fg
        out.append(f"[{key}{suffix}]\nColor={v}\n")
out.append("[General]\nDescription=Tokyo Night Arcade\nOpacity=0.92\nBlur=true\nWallpaper=\n")
os.makedirs(HOME + "/.local/share/konsole", exist_ok=True)
open(HOME + "/.local/share/konsole/TokyoNightArcade.colorscheme", "w").write("\n".join(out))
print("OK esquemas de color")
