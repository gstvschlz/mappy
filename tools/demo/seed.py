"""Enche um emulador Android com dados falsos do mappy (as imagens e vídeos do site/README).

APAGA o banco e as fotos do app no aparelho conectado. Só funciona em emulador com
`adb root` (imagem Google APIs), o que também protege o seu celular. Rodar com
`mise run demo-seed` depois de instalar a APK (`adb install`).
"""
import math
import random
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

PKG = "com.example.mappy"
DATA = f"/data/data/{PKG}"
DOCS = f"{DATA}/app_flutter"
HERE = Path(__file__).parent
FOTOS = HERE / "fotos"
random.seed(7)


def adb(*a, check=True):
    r = subprocess.run(["adb", *a], capture_output=True, text=True)
    if check and r.returncode:
        sys.exit(f"adb {' '.join(a)}: {r.stderr or r.stdout}")
    return r.stdout.strip()


def uid():
    return str(uuid.uuid4())


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def trilha(pontos, inicio, passo_s=5, vel=1.2):
    """Interpola waypoints (lat, lon, alt) em pontos de GPS com ruído; devolve lista com hora."""
    out, t = [], inicio
    for (a, b) in zip(pontos, pontos[1:]):
        dy, dx = (b[0] - a[0]) * 111_320, (b[1] - a[1]) * 111_320 * math.cos(math.radians(a[0]))
        n = max(1, int(math.hypot(dx, dy) / (vel * passo_s)))
        for i in range(n):
            f = i / n
            out.append((a[0] + (b[0] - a[0]) * f + random.gauss(0, 1.2e-5),
                        a[1] + (b[1] - a[1]) * f + random.gauss(0, 1.2e-5),
                        a[2] + (b[2] - a[2]) * f + random.gauss(0, 0.8),
                        random.uniform(3.5, 8), vel + random.gauss(0, 0.2), t))
            t += timedelta(seconds=passo_s)
    return out


now = datetime.now(timezone.utc).replace(microsecond=0)
dia1 = (now - timedelta(days=2)).replace(hour=12, minute=10, second=0)  # 09h10 em Brasília
dia0 = (now - timedelta(days=9)).replace(hour=13, minute=30, second=0)

# Itaimbezinho (Cambará do Sul, RS): da portaria do parque pela borda norte do cânion.
T1 = [(-29.1581, -50.0774, 1005), (-29.1591, -50.0802, 1000), (-29.1608, -50.0837, 996),
      (-29.1615, -50.0888, 990), (-29.1610, -50.0911, 992), (-29.1632, -50.0939, 985),
      (-29.1641, -50.0972, 980), (-29.1653, -50.0978, 978), (-29.1708, -50.0988, 972)]
# Vale do Rio Camisas, poucos km a oeste.
T2 = [(-29.1180, -50.1720, 905), (-29.1150, -50.1680, 890), (-29.1120, -50.1650, 880),
      (-29.1105, -50.1600, 872)]

# (foto(s), descrição, tags, fração da trilha, minutos após o início)
PROJETOS = [
    dict(nome="Rio Camisas — reconhecimento", icone="hammer", criado=dia0 - timedelta(days=3),
         trilha=T2, inicio=dia0, obs=[
        (["estrias"], "Pavimento rochoso polido, com estrias de direção ~N40E. Marca de gelo ou só desgaste do rio? Voltar com bússola.",
         ["estrutura", "amostra"], 0.10, 8),
        (["agata"], "Ágata em amígdala de basalto, bandamento concêntrico bem marcado. Coletei uma amostra de mão.",
         ["basalto", "amostra"], 0.45, 30),
        (["veio-quartzo"], "Veio de quartzo leitoso de ~10 cm, direção N70W, cortando o basalto. Sem sulfeto visível.",
         ["basalto", "quartzo", "estrutura"], 0.85, 52),
    ]),
    dict(nome="Serra Geral — Itaimbezinho", icone="mountain", criado=dia1 - timedelta(days=1),
         trilha=T1, inicio=dia1, obs=[
        (["basalto-amigdalas", "afloramento"], "Basalto da Fm. Serra Geral, textura afanítica, amígdalas preenchidas por calcedônia. Fratura conchoidal.",
         ["basalto", "amígdalas"], 0.05, 6),
        (["basalto-drusa", "quartzo-cristal"], "Geodo de quartzo hialino dentro do basalto, ~15 cm. Cristais euédricos, sem zonação visível.",
         ["basalto", "geodo", "quartzo", "amostra"], 0.20, 24),
        (["basalto-colunar"], "Disjunção colunar no derrame, colunas de 30–40 cm de diâmetro, sub-verticais.",
         ["basalto", "estrutura"], 0.34, 41),
        (["riolito"], "Riolito tipo Palmas, textura fluidal, cinza-rosado. Topo do derrame ácido, contato gradual.",
         ["riolito", "contato"], 0.52, 63),
        (["arenito-cruzada"], "Arenito eólico (Fm. Botucatu) com estratificação cruzada de grande porte. Mergulho ~28° para NE.",
         ["arenito", "estrutura"], 0.68, 85),
        (["arenito-br"], "Arenito fino, bem selecionado, avermelhado. Contato com o basalto ~2 m acima.",
         ["arenito", "contato"], 0.82, 101),
        (["conglomerado"], "Nível conglomerático na base do arenito, seixos de basalto arredondados.",
         ["arenito", "amostra"], 0.93, 118),
    ]),
]
LIXEIRA = (["afloramento"], "Ponto repetido, apagar.", [], 0.5, 70)


def semear(db, docs_tmp):
    c = db.cursor()
    for tab in ("observation_tags", "tags", "photos", "track_points", "observations", "projects"):
        c.execute(f"DELETE FROM {tab}")
    for p in PROJETOS:
        pid = uid()
        c.execute("INSERT INTO projects VALUES (?,?,?,?)", (pid, p["nome"], iso(p["criado"]), p["icone"]))
        pts = trilha(p["trilha"], p["inicio"])
        tid = uid()
        c.executemany("INSERT INTO track_points (project_id,track_id,lat,lon,altitude,accuracy,speed,recorded_at) VALUES (?,?,?,?,?,?,?,?)",
                      [(pid, tid, la, lo, al, ac, sp, iso(t)) for la, lo, al, ac, sp, t in pts])
        tags = {}
        todas = list(p["obs"]) + ([LIXEIRA] if p["nome"].startswith("Serra") else [])
        for i, o in enumerate(todas):
            fotos, desc, tgs, frac, minutos = o
            lixo = o is LIXEIRA
            la, lo, al, ac, _, _ = pts[min(len(pts) - 1, int(frac * len(pts)))]
            t = p["inicio"] + timedelta(minutes=minutos)
            oid = uid()
            c.execute("INSERT INTO observations VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                      (oid, pid, desc, la + 4e-5, lo - 3e-5, al, ac, 0, iso(t), iso(t), iso(t + timedelta(hours=5)) if lixo else None))
            for k, f in enumerate(fotos):
                fid = uid()
                dst = f"{DOCS}/photos/{oid}/{fid}.jpg"
                (docs_tmp / oid).mkdir(exist_ok=True)
                (docs_tmp / oid / f"{fid}.jpg").write_bytes((FOTOS / f"{f}.jpg").read_bytes())
                c.execute("INSERT INTO photos VALUES (?,?,?,?,?,?,?)",
                          (fid, oid, dst, random.uniform(0, 360), al, iso(t + timedelta(seconds=20 * k)), k))
            for nome in tgs:
                if nome not in tags:
                    tags[nome] = uid()
                    c.execute("INSERT INTO tags VALUES (?,?,?,?)", (tags[nome], pid, nome, iso(t)))
                c.execute("INSERT INTO observation_tags VALUES (?,?)", (oid, tags[nome]))
    db.commit()


def main():
    if "emulator-" not in adb("devices"):
        sys.exit("Nenhum emulador conectado. Este script apaga os dados do app: use só em emulador.")
    adb("root")
    adb("wait-for-device")
    time.sleep(2)
    if adb("shell", "pm", "path", PKG, check=False) == "":
        sys.exit(f"{PKG} não está instalado: adb install -r build/app/outputs/flutter-apk/app-release.apk")
    for perm in ("CAMERA", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "POST_NOTIFICATIONS", "ACCESS_BACKGROUND_LOCATION"):
        adb("shell", "pm", "grant", PKG, f"android.permission.{perm}", check=False)
    # Deixa o próprio app criar o banco, para o esquema ser o real.
    adb("shell", "am", "force-stop", PKG)
    if "mappy.sqlite" not in adb("shell", "ls", DOCS, check=False):
        adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
        time.sleep(8)
        adb("shell", "am", "force-stop", PKG)
    uid_app = adb("shell", "stat", "-c", "%u", DATA)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for ext in ("", "-wal", "-shm"):
            adb("pull", f"{DOCS}/mappy.sqlite{ext}", str(tmp / f"mappy.sqlite{ext}"), check=False)
        db = sqlite3.connect(tmp / "mappy.sqlite")
        docs_tmp = tmp / "photos"
        docs_tmp.mkdir()
        semear(db, docs_tmp)
        db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        db.close()
        adb("shell", "rm", "-rf", f"{DOCS}/photos", f"{DOCS}/mappy.sqlite-wal", f"{DOCS}/mappy.sqlite-shm",
            f"{DATA}/shared_prefs/FlutterSharedPreferences.xml")
        adb("push", str(tmp / "mappy.sqlite"), f"{DOCS}/mappy.sqlite")
        adb("shell", "mkdir", "-p", f"{DOCS}/photos")
        adb("push", f"{docs_tmp}/.", f"{DOCS}/photos")
    adb("shell", "chown", "-R", f"{uid_app}:{uid_app}", DATA)
    adb("shell", "restorecon", "-R", DATA, check=False)
    print("Semeado: 2 projetos, 10 observações (+1 na lixeira), 2 trilhas.")


if __name__ == "__main__":
    main()
