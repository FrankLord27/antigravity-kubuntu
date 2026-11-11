"""Ejecuta cava y sirve el último cuadro de barras en http://127.0.0.1:47821/ para el HUD."""
import os, subprocess, tempfile, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BARS, PORT = 35, 47821
CONF = f"""[general]
bars = {BARS}
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 15
bar_delimiter = 59
frame_delimiter = 10
channels = mono
"""
latest = ";".join(["0"] * BARS)


def read_cava():
    global latest
    with tempfile.NamedTemporaryFile("w", suffix=".conf", delete=False) as f:
        f.write(CONF)
    try:
        proc = subprocess.Popen(["cava", "-p", f.name], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for line in proc.stdout:
            latest = line.strip().rstrip(";")
    finally:
        os.unlink(f.name)
    os._exit(1)  # cava terminó: salir para que systemd reinicie el servicio


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        body = latest.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


threading.Thread(target=read_cava, daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
