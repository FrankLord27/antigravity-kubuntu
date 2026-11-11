"""Genera tamaños grandes del tema Pixelitos ampliando los PNG de 16 px sin suavizado,
para que los iconos se vean con píxeles nítidos en vez de borrosos. Uso: iconos_nitidos.py"""
import os, shutil
from PIL import Image

THEME = os.path.expanduser("~/.local/share/icons/pixelitos-dark")
SIZES = (32, 48, 64, 128, 256)
CONTEXTS = {"actions": "Actions", "apps": "Applications", "categories": "Categories", "devices": "Devices", "emblems": "Emblems",
            "mimetypes": "MimeTypes", "places": "Places", "status": "Status", "distributor-logo": "Applications", "symbolic": "Actions"}

n = 0
for size in SIZES:
    dest = f"{THEME}/{size}"
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    shutil.copytree(f"{THEME}/16", dest, symlinks=True)  # los enlaces entre iconos se conservan
    for root, _, files in os.walk(dest):
        for name in files:
            path = os.path.join(root, name)
            if os.path.islink(path) or not name.endswith(".png"):
                continue
            Image.open(path).convert("RGBA").resize((size, size), Image.NEAREST).save(path)
            n += 1

dirs = [f"{s}/{c}" for s in (16,) + SIZES for c in CONTEXTS]
sizes = ",".join(str(s) for s in (16,) + SIZES)
out = ["[Icon Theme]", "Name=Pixelitos Dark", "Comment=Pixel Art Style icons", "Inherits=breeze-dark,hicolor", "", "Example=folder", ""]
for group, default in (("Desktop", 48), ("Toolbar", 16), ("MainToolbar", 32), ("Small", 16), ("Panel", 48), ("Dialog", 32)):
    out += [f"{group}Default={default}", f"{group}Sizes={sizes}"]
out += ["", "Directories=" + ",".join(dirs), ""]
for d in dirs:
    size, ctx = d.split("/")
    out += [f"[{d}]", f"Context={CONTEXTS[ctx]}", f"Size={size}", "Type=Fixed", ""]
open(f"{THEME}/index.theme", "w").write("\n".join(out))
print(f"OK: {n} iconos generados en tamaños {SIZES}")
