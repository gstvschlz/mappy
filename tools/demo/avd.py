"""Cria o emulador `mappy_demo` (Pixel 7, Android 16) já ajustado para gravar a demo.

- câmera traseira "virtual scene" com uma foto de rocha no lugar do pôster da sala;
- GPU do host, 4 GB de RAM e teclado virtual (sem teclado físico, senão o Flutter
  desenha um contorno de foco nas telas).
O pôster mora no SDK do emulador (compartilhado): guarda-se o original em Toren1BD.posters.orig.
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

NOME = sys.argv[1] if len(sys.argv) > 1 else "mappy_demo"
IMAGEM = "system-images;android-36;google_apis;x86_64"
SDK = Path(os.environ["ANDROID_HOME"])
AQUI = Path(__file__).parent

subprocess.run(f'sdkmanager "{IMAGEM}"', shell=True, input="y\n" * 10, text=True, check=True)
# avdmanager reclama de devices.xml da imagem mas cria o AVD; o retorno não é confiável.
subprocess.run(f'avdmanager create avd -n {NOME} -k "{IMAGEM}" -d pixel_7 --force', shell=True, input="no\n", text=True)

cfg = Path.home() / ".android" / "avd" / f"{NOME}.avd" / "config.ini"
texto = cfg.read_text(encoding="utf-8")
for chave, valor in {"hw.camera.back": "virtualscene", "hw.ramSize": "4096", "hw.keyboard": "no",
                     "hw.gpu.enabled": "yes", "hw.gpu.mode": "host"}.items():
    texto = re.sub(rf"^{re.escape(chave)}=.*$", f"{chave}={valor}", texto, flags=re.M) \
        if re.search(rf"^{re.escape(chave)}=", texto, re.M) else texto + f"\n{chave}={valor}\n"
cfg.write_text(texto, encoding="utf-8")

res = SDK / "emulator" / "resources"
if not (res / "Toren1BD.posters.orig").exists():
    shutil.copy(res / "Toren1BD.posters", res / "Toren1BD.posters.orig")
shutil.copy(AQUI / "poster.jpg", res / "rocha.jpg")
# o pôster de parede fica na frente da câmera, no lugar da TV de xadrez
(res / "Toren1BD.posters").write_text(
    "poster wall\nsize 3 3\nposition 0 0 -1.6\nrotation 0 0 0\ndefault rocha.jpg\n\n"
    "poster table\nsize 1 1\nposition -2.205 -0.077 3.949\nrotation -90 0 120\ndefault poster.png\n",
    encoding="utf-8")
print(f"AVD {NOME} pronto. Ligue com: mise run demo-emulator")
