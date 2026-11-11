"""Genera el estilo de Plasma «ArcadeTokyo»: marcos rectos de doble línea neón para
menús, ventanas emergentes, paneles y tooltips. Uso: tema_plasma.py"""
import json, os

DEST = os.path.expanduser("~/.local/share/plasma/desktoptheme/ArcadeTokyo")
BG, CYAN, PURPLE = "#1a1b26", "#7dcfff", "#bb9af7"
EDGE = 32  # largo de los bordes y lado del centro


def frame(corner, lines, opacity):
    """SVG de 9 piezas. lines = [(distancia al borde exterior, grosor, color), ...]"""
    total = 2 * corner + EDGE
    pos = (0, corner, corner + EDGE)
    size = (corner, EDGE, corner)
    names = (("topleft", "top", "topright"), ("left", "center", "right"), ("bottomleft", "bottom", "bottomright"))
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{total}" height="{total}" shape-rendering="crispEdges">']
    for r in range(3):
        for c in range(3):
            ex, ey, ew, eh = pos[c], pos[r], size[c], size[r]
            out.append(f'<g id="{names[r][c]}"><rect x="{ex}" y="{ey}" width="{ew}" height="{eh}" fill="{BG}" fill-opacity="{opacity}"/>')
            for off, w, col in lines:
                inner = total - 2 * off
                ring = ((off, off, inner, w), (off, total - off - w, inner, w), (off, off, w, inner), (total - off - w, off, w, inner))
                for x, y, rw, rh in ring:  # se recorta el anillo a la pieza
                    x0, y0, x1, y1 = max(x, ex), max(y, ey), min(x + rw, ex + ew), min(y + rh, ey + eh)
                    if x1 > x0 and y1 > y0:
                        out.append(f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" fill="{col}"/>')
            out.append("</g>")
    out.append("</svg>")
    return "\n".join(out)


FILES = {
    "dialogs/background.svg": frame(8, [(0, 2, CYAN), (4, 2, PURPLE)], 0.97),
    "widgets/background.svg": frame(8, [(0, 2, CYAN), (4, 2, PURPLE)], 0.9),
    "widgets/panel-background.svg": frame(4, [(0, 2, PURPLE)], 0.92),
    "widgets/tooltip.svg": frame(6, [(0, 2, CYAN)], 0.97),
}
for rel, svg in FILES.items():
    path = os.path.join(DEST, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(svg)
json.dump({"KPlugin": {"Id": "ArcadeTokyo", "Name": "Arcade Tokyo", "Description": "Marcos pixel de doble línea neón", "Version": "1.0"},
           "X-Plasma-API": "5.0"}, open(os.path.join(DEST, "metadata.json"), "w"), indent=2)
print("OK", DEST)
