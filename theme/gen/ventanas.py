"""Genera la decoración de ventanas «ArcadeTokyo» (motor Aurorae): borde neón recto y
botones cuadrados con símbolos pixel art. Uso: ventanas.py"""
import os

DEST = os.path.expanduser("~/.local/share/aurorae/themes/ArcadeTokyo")
BAR, DARK, OFF, MUTE = "#16161e", "#16161e", "#2a2e42", "#565f89"
PURPLE, CYAN = "#bb9af7", "#7dcfff"
SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" shape-rendering="crispEdges">\n{body}\n</svg>\n'

GLYPHS = {
    "close": ("100001", "010010", "001100", "001100", "010010", "100001"),
    "maximize": ("111111", "111111", "100001", "100001", "100001", "111111"),
    "restore": ("001111", "001111", "111101", "111101", "100111", "111100"),
    "minimize": ("000000", "000000", "000000", "000000", "111111", "111111"),
}
# botón: (color normal, color al pasar el ratón, color al pulsar)
COLORS = {"close": ("#f7768e", "#ff9db0", "#c4576b"), "maximize": ("#9ece6a", "#c3e88d", "#73964a"),
          "restore": ("#9ece6a", "#c3e88d", "#73964a"), "minimize": ("#e0af68", "#f5cf94", "#a8824a")}


def button(name):
    normal, hover, pressed = COLORS[name]
    states = (("active", normal, DARK, None), ("hover", hover, DARK, CYAN), ("pressed", pressed, DARK, CYAN),
              ("inactive", OFF, MUTE, None), ("hover-inactive", hover, DARK, CYAN), ("pressed-inactive", pressed, DARK, CYAN),
              ("deactivated", OFF, MUTE, None), ("deactivated-inactive", OFF, MUTE, None))
    body = []
    for i, (state, bg, fg, ring) in enumerate(states):
        x0 = i * 30
        body.append(f'<g id="{state}-center"><rect x="{x0}" y="0" width="24" height="24" fill="{ring or bg}"/>')
        if ring:
            body.append(f'<rect x="{x0 + 2}" y="2" width="20" height="20" fill="{bg}"/>')
        for r, row in enumerate(GLYPHS[name]):
            for c, v in enumerate(row):
                if v == "1":
                    body.append(f'<rect x="{x0 + 3 + c * 3}" y="{3 + r * 3}" width="3" height="3" fill="{fg}"/>')
        body.append("</g>")
    return SVG.format(w=len(states) * 30, h=24, body="\n".join(body))


def decoration():
    t, mid = 2, 28  # grosor del borde y lado de la pieza central
    total = 2 * t + mid
    pos, size = (0, t, t + mid), (t, mid, t)
    names = (("topleft", "top", "topright"), ("left", "center", "right"), ("bottomleft", "bottom", "bottomright"))
    body = []
    for k, (prefix, line) in enumerate((("decoration", PURPLE), ("decoration-inactive", "#414868"))):
        ox = k * (total + 8)
        for r in range(3):
            for c in range(3):
                fill = BAR if names[r][c] == "center" else line
                body.append(f'<rect id="{prefix}-{names[r][c]}" x="{ox + pos[c]}" y="{pos[r]}" width="{size[c]}" height="{size[r]}" fill="{fill}"/>')
    return SVG.format(w=2 * total + 8, h=total, body="\n".join(body))


RC = """[General]
ActiveTextColor=192,202,245,255
InactiveTextColor=86,95,137,255
UseTextShadow=false
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=0

[Layout]
BorderLeft=2
BorderRight=2
BorderBottom=2
TitleEdgeTop=5
TitleEdgeBottom=5
TitleEdgeLeft=8
TitleEdgeRight=8
TitleEdgeTopMaximized=5
TitleEdgeBottomMaximized=5
TitleEdgeLeftMaximized=8
TitleEdgeRightMaximized=8
TitleBorderLeft=10
TitleBorderRight=10
TitleHeight=24
ButtonWidth=24
ButtonHeight=24
ButtonSpacing=6
ButtonMarginTop=0
ExplicitButtonSpacer=8
PaddingTop=0
PaddingBottom=0
PaddingLeft=0
PaddingRight=0
"""

os.makedirs(DEST, exist_ok=True)
for name in GLYPHS:
    open(f"{DEST}/{name}.svg", "w").write(button(name))
open(f"{DEST}/decoration.svg", "w").write(decoration())
open(f"{DEST}/ArcadeTokyorc", "w").write(RC)
open(f"{DEST}/metadata.desktop", "w").write(
    "[Desktop Entry]\nName=Arcade Tokyo\nComment=Borde neón y botones pixel art\nX-KDE-PluginInfo-Name=ArcadeTokyo\nX-KDE-PluginInfo-Version=1.0\n")
print("OK", DEST)
