"""Gera as capturas e os clipes do site/README a partir do emulador semeado (seed.py).

    python tools/demo/gravar.py telas        # PNGs em tools/demo/saida/
    python tools/demo/gravar.py clipes       # MP4s brutos em tools/demo/saida/clipes/
Depois `python tools/demo/montar.py` codifica tudo para site/media e .github/media.
"""
import sys
import time
from pathlib import Path

import drive as d

PKG = "com.example.mappy"
SAIDA = Path(__file__).parent / "saida"
TAB = {"map": (135, 2200), "notes": (405, 2200), "projects": (675, 2200), "export": (945, 2200)}
CENTRO = (-29.1615, -50.0888)


def abrir():
    d.status_bar()
    d.sh("am", "force-stop", PKG)
    d.geo(*CENTRO)
    d.sh("monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    for _ in range(8):  # o GPS do emulador só "pega" depois de repetir a posição
        time.sleep(2)
        d.geo(*CENTRO)
    d.tap(975, 1895)  # seguir o GPS
    time.sleep(5)


def aba(nome):
    d.tap(*TAB[nome])
    time.sleep(1.5)


def zoom_in():
    d.sh("input tap 540 1000; input tap 540 1000")  # duplo toque
    time.sleep(2.5)


def telas():
    abrir()
    d.shot(SAIDA / "mapa.png")
    d.tap(724, 1172)  # pino do geodo
    time.sleep(3)
    d.shot(SAIDA / "observacao.png")
    d.back()
    time.sleep(1.5)
    aba("projects")
    d.shot(SAIDA / "projetos.png")
    aba("notes")
    d.shot(SAIDA / "notas.png")
    aba("export")
    d.shot(SAIDA / "exportar.png")
    aba("map")
    d.tap_text("New observation")
    time.sleep(2)
    d.shot(SAIDA / "nova.png")
    d.back()


CLIPES = SAIDA / "clipes"


def clipe_mapa():
    abrir()
    d.tap_text("Tile source")
    d.tap_text("OpenTopoMap", wait=4)
    with d.Rec(CLIPES / "mapa.mp4"):
        time.sleep(2.5)
        d.tap_text("Tile source")
        d.tap_text("Esri", wait=4.5)
        d.tap_text("Tile source")
        d.tap_text("OpenTopoMap", wait=3)


def clipe_obs():
    abrir()
    with d.Rec(CLIPES / "obs.mp4"):
        time.sleep(2)
        d.tap(724, 1172)  # geodo
        time.sleep(3)
        d.swipe(540, 1900, 540, 1100, 700)
        time.sleep(2)
        d.swipe(540, 1100, 540, 1900, 700)
        time.sleep(1.5)
        d.back()
        time.sleep(1.5)
        d.tap(450, 1215)  # riolito
        time.sleep(3)


def clipe_nova():
    abrir()
    with d.Rec(CLIPES / "nova.mp4"):
        time.sleep(1.5)
        d.tap(810, 2055)  # New observation
        time.sleep(2.5)
        d.tap(540, 608)  # Take photos
        time.sleep(6)
        d.tap(540, 2260)
        time.sleep(5)
        d.tap(540, 2260)
        time.sleep(5)
        d.shot(SAIDA / "nova_fotos.png")
        d.tap(995, 208)  # Done
        time.sleep(2)
        d.tap(540, 1116)  # descrição (com fotos o layout desce)
        time.sleep(1)
        d.text("Basalto vesicular com geodo de quartzo")
        time.sleep(1.5)
        d.tap(288, 1474)  # campo de tag (o teclado segue aberto)
        time.sleep(1)
        d.text("bas")
        time.sleep(1.8)
        d.tap(160, 2338)  # recolhe o teclado (a sugestão fica atrás dele)
        time.sleep(1)
        d.tap(144, 1620)  # sugestão "basalto"
        time.sleep(1.5)
        d.shot(SAIDA / "nova_pronta.png")
        d.tap(995, 208)  # Save
        time.sleep(4)


def clipe_regua():
    abrir()
    with d.Rec(CLIPES / "regua.mp4"):
        time.sleep(1.5)
        d.tap_text("Measure", wait=1.5)
        for x, y in [(250, 700), (820, 700), (700, 1000), (250, 1000)]:
            d.tap(x, y)
            time.sleep(1.4)
        time.sleep(2.5)
        d.shot(SAIDA / "regua.png")


def clipe_trilha():
    abrir()
    with d.Rec(CLIPES / "trilha.mp4"):
        time.sleep(1.5)
        d.tap_text("Start track", wait=2)
        d.shot(SAIDA / "trilha.png")
        time.sleep(3)
        d.tap_text("Stop track", wait=2)


def clipe_notas():
    abrir()
    aba("notes")
    with d.Rec(CLIPES / "notas.mp4"):
        time.sleep(2)
        d.tap(540, 370)
        d.text("basalto")
        time.sleep(3)


def clipe_projetos():
    abrir()
    with d.Rec(CLIPES / "projetos.mp4"):
        aba("projects")
        time.sleep(2)
        d.tap(500, 390)
        time.sleep(3)
        d.shot(SAIDA / "projeto.png")
        d.swipe(540, 1800, 540, 900, 700)
        time.sleep(2)


def clipe_export():
    abrir()
    aba("export")
    with d.Rec(CLIPES / "export.mp4"):
        time.sleep(1.5)
        d.tap(540, 715)
        time.sleep(9)
        d.shot(SAIDA / "export_ok.png")


def executar(nome):
    globals()[nome if nome == "telas" else "clipe_" + nome]()


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        if arg == "tudo":
            for n in ("telas", "mapa", "obs", "nova", "regua", "trilha", "notas", "projetos", "export"):
                executar(n)
        else:
            executar(arg)

