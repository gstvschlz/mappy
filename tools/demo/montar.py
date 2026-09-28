"""Codifica os clipes brutos de saida/ em site/media (mp4 + png) e .github/media (gif).

Cada corte é (clipe, início, fim, velocidade) em segundos do clipe bruto. O uiautomator deixa
trechos mortos (câmera abrindo, teclado subindo), então o roteiro está aqui, não no gravar.py.
Precisa do ffmpeg do mise com libx264, drawtext e palettegen.
"""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
BRUTO = Path(__file__).parent / "saida"
SITE = RAIZ / "site" / "media"
GIFS = RAIZ / ".github" / "media"
FONTE = "C\\:/Windows/Fonts/segoeuib.ttf"

# ffmpeg do mise: no Windows o shim quebra (falta Library/bin no PATH); `mise where` acha a raiz.
try:
    _r = subprocess.run(["mise", "where", "ffmpeg"], capture_output=True, text=True, check=True).stdout.strip()
    _bin = Path(_r) / "Library" / "bin"
    if _bin.exists():
        os.environ["PATH"] = f"{_bin}{os.pathsep}{os.environ['PATH']}"
except Exception:
    pass

# 1064x2384 = tela 1080x2400 sem a borda de foco de 8px que o Flutter desenha após `input text`.
LIMPA = "crop=1064:2384:8:8"

DEMO = [  # (arquivo de saída, legenda, cortes)
    ("01-mapa", "Mapa offline: topo, ruas ou satélite",
     [("mapa", 0.5, 3.5, 1), ("mapa", 6.2, 8.2, 1), ("mapa", 13.5, 16.5, 1)]),
    ("02-obs", "Fotos, tags e GPS em cada ponto",
     [("obs", 3.0, 11.0, 1)]),
    ("03-nova", "Nova observação em poucos toques",
     [("nova", 0.5, 4.5, 1), ("nova", 11.5, 15.0, 1), ("nova", 17.0, 20.5, 1),
      ("nova", 26.0, 28.0, 1), ("nova", 28.0, 33.0, 2), ("nova", 33.0, 38.0, 1.2), ("nova", 38.0, 39.6, 1)]),
    ("04-trilha", "Trajeto gravado em segundo plano",
     [("trilha", 5.5, 15.5, 1)]),
    ("05-regua", "Régua: distância e área",
     [("regua", 4.5, 12.9, 1)]),
    ("06-notas", "Busca nas anotações",
     [("notas", 0.5, 7.5, 1.4)]),
    ("07-projetos", "Projetos com feed de fotos",
     [("projetos", 1.0, 9.5, 1.2)]),
    ("08-export", "Tudo num ZIP: GeoJSON, CSV, fotos",
     [("export", 1.4, 3.8, 1)]),
]
HERO = [("mapa", 0.5, 3.0, 1), ("obs", 3.0, 9.5, 1)]
CLIPES_SITE = {  # arquivo do site -> cortes
    "nova": DEMO[2][2], "trilha": DEMO[3][2],
}


def ff(*a):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *a], check=True)


def render(dst, cortes, legenda=None, w=540, segura=0):
    """Concatena os cortes (com velocidade), limpa a borda, redimensiona e opcionalmente legenda."""
    clipes = sorted({c for c, *_ in cortes})
    entradas = []
    for c in clipes:
        entradas += ["-i", str(BRUTO / "clipes" / f"{c}.mp4")]
    partes, rot = [], []
    for i, (c, ss, to, vel) in enumerate(cortes):
        k = clipes.index(c)
        partes.append(f"[{k}:v]fps=30,trim=start={ss}:end={to},setpts=(PTS-STARTPTS)/{vel},{LIMPA},"
                      f"scale={w}:-2,fps=30[v{i}]")
        rot.append(f"[v{i}]")
    fc = ";".join(partes) + f";{''.join(rot)}concat=n={len(cortes)}:v=1:a=0{',tpad=stop_mode=clone:stop_duration=%s' % segura if segura else ''}[cat]"
    saida = "cat"
    tmp = None
    if legenda:
        fd, nome = tempfile.mkstemp(suffix=".txt")
        os.close(fd)
        tmp = Path(nome)
        tmp.write_text(legenda, encoding="utf-8")
        fc += (f";[cat]drawtext=fontfile='{FONTE}':textfile='{tmp.as_posix().replace(':', chr(92) + ':')}':fontsize={int(w * .044)}:"
               f"fontcolor=white:box=1:boxcolor=black@0.62:boxborderw={int(w * .026)}:"
               f"x=(w-text_w)/2:y=h-{int(w * .43)}[leg]")
        saida = "leg"
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    ff(*entradas, "-filter_complex", fc, "-map", f"[{saida}]", "-c:v", "libx264", "-preset", "slow",
       "-crf", "27", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", str(dst))
    if tmp:
        tmp.unlink()


def gif(src, dst, w=270, fps=12):
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    vf = f"fps={fps},scale={w}:-2:flags=lanczos"
    with tempfile.TemporaryDirectory() as t:
        pal = Path(t) / "p.png"
        ff("-i", str(src), "-vf", f"{vf},palettegen=max_colors=96:stats_mode=diff", str(pal))
        ff("-i", str(src), "-i", str(pal), "-lavfi", f"{vf}[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4", str(dst))


def png(src, dst, w=540):
    ff("-i", str(src), "-vf", f"{LIMPA},scale={w}:-2", str(dst))


def main():
    SITE.mkdir(parents=True, exist_ok=True)
    # ícone
    ff("-i", str(RAIZ / "assets" / "icon" / "icon.png"), "-vf", "scale=256:-2", str(SITE / "icon.png"))
    # capturas
    for origem, destino in [("mapa", "mapa"), ("observacao", "observacao"), ("projetos", "projetos"),
                            ("nova_pronta", "nova")]:
        png(BRUTO / f"{origem}.png", SITE / f"{destino}.png")
    # quadro da trilha com o aviso de gravação
    ff("-ss", "9", "-i", str(BRUTO / "clipes" / "trilha.mp4"), "-frames:v", "1", "-vf",
       f"{LIMPA},scale=540:-2", str(SITE / "trilha.png"))
    # hero e clipes soltos do site
    render(SITE / "hero.mp4", HERO)
    for nome, cortes in CLIPES_SITE.items():
        render(SITE / f"{nome}.mp4", cortes)
    # demo completa: cada trecho com legenda, depois concatenados sem reencodar
    with tempfile.TemporaryDirectory() as t:
        lista = []
        for nome, leg, cortes in DEMO:
            p = Path(t) / f"{nome}.mp4"
            render(p, cortes, legenda=leg, segura=2.5 if nome == "08-export" else 0)
            lista.append(f"file '{p.as_posix()}'")
        (Path(t) / "l.txt").write_text("\n".join(lista), encoding="utf-8")
        ff("-f", "concat", "-safe", "0", "-i", str(Path(t) / "l.txt"), "-c", "copy",
           "-movflags", "+faststart", str(SITE / "demo.mp4"))
    # gifs do README
    gif(SITE / "hero.mp4", GIFS / "mapa.gif")
    gif(SITE / "nova.mp4", GIFS / "nova.gif")
    for f in ("mapa", "observacao", "projetos", "nova"):
        shutil.copy(SITE / f"{f}.png", GIFS / f"{f}.png")
    for f in sorted(list(SITE.iterdir()) + list(GIFS.iterdir())):
        print(f"{f.stat().st_size / 1024:8.0f} KB  {f.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
