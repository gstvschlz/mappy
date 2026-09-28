"""Opera o emulador por texto/descrição da tela (uiautomator) e grava vídeo. Usado por gravar.py.

O Flutter expõe tooltips e labels como content-desc/text, então dá para tocar pelo nome
em vez de por coordenada.
"""
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

W, H = 1080, 2400


def adb(*a, out=False):
    r = subprocess.run(["adb", *a], capture_output=True)
    return r.stdout if out else None


def sh(*a):
    adb("shell", *a)


def nodes():
    sh("uiautomator", "dump", "/sdcard/ui.xml")
    xml = adb("exec-out", "cat", "/sdcard/ui.xml", out=True).decode("utf-8", "ignore")
    xml = xml[xml.find("<?xml"):]
    return list(ET.fromstring(xml).iter("node"))


def center(n):
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds")))
    return (x1 + x2) // 2, (y1 + y2) // 2


def find(txt, exact=False):
    for n in nodes():
        for f in (n.get("text"), n.get("content-desc")):
            if f and (f == txt if exact else txt.lower() in f.lower()):
                return n
    return None


def tap(x, y):
    sh("input", "tap", str(x), str(y))


def tap_text(txt, wait=1.2, exact=False, tries=6):
    for _ in range(tries):
        n = find(txt, exact)
        if n is not None:
            tap(*center(n))
            time.sleep(wait)
            return True
        time.sleep(0.8)
    raise RuntimeError(f"não achei na tela: {txt!r}")


def swipe(x1, y1, x2, y2, ms=400):
    sh("input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def hold(x, y, ms=900):
    swipe(x, y, x, y, ms)


def back():
    sh("input", "keyevent", "KEYCODE_BACK")


def text(s):
    sh("input", "text", s.replace(" ", "%s"))


def shot(path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(adb("exec-out", "screencap", "-p", out=True))


class Rec:
    """screenrecord no aparelho; `with Rec('x.mp4'):` grava e puxa ao sair."""

    def __init__(self, dest, limit=170):
        self.dest, self.limit = Path(dest), limit

    def __enter__(self):
        self.p = subprocess.Popen(["adb", "shell", "screenrecord", "--bit-rate", "12000000",
                                   "--time-limit", str(self.limit), "/sdcard/rec.mp4"])
        time.sleep(1.5)
        return self

    def __exit__(self, *e):
        time.sleep(1.0)
        sh("pkill", "-INT", "screenrecord")
        self.p.wait()
        time.sleep(1.0)
        self.dest.parent.mkdir(parents=True, exist_ok=True)
        adb("pull", "/sdcard/rec.mp4", str(self.dest))


def geo(lat, lon):
    """Posição do GPS do emulador."""
    subprocess.run(["adb", "emu", "geo", "fix", str(lon), str(lat)], capture_output=True)


def status_bar(hhmm="0941"):
    """Barra de status limpa: relógio fixo, bateria cheia, sem notificações."""
    sh("settings", "put", "global", "sysui_demo_allowed", "1")
    cmds = [("enter", {}), ("clock", {"hhmm": hhmm}), ("battery", {"level": "100", "plugged": "false"}),
            ("network", {"wifi": "show", "level": "4", "fully": "true"}),
            ("network", {"mobile": "hide"}),
            ("notifications", {"visible": "false"})]
    for cmd, extras in cmds:
        args = ["am", "broadcast", "-a", "com.android.systemui.demo", "-e", "command", cmd]
        for k, v in extras.items():
            args += ["-e", k, v]
        sh(*args)
