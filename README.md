# mappy

O mappy surgiu de uma necessidade **minha** — de campo mesmo, no sentido literal.
Eu precisava mapear uma região, marcar pontos, tirar fotos amarradas ao GPS,
gravar tracks, anotar o que estava vendo, e voltar pra casa com tudo isso
organizado num projeto. Procurei aplicativo, baixei uns dez, nenhum fazia
exatamente o que eu queria sem me obrigar a criar conta, sincronizar com
nuvem ou pagar assinatura. Aí decidi que era mais rápido fazer eu mesmo.

É um app offline, local-only, sem cadastro, sem sync, sem nada disso. Tudo
fica no celular até você exportar. Foi pensado pra geologia de campo, mas
serve pra qualquer atividade que precise de "ponto + foto + descrição + GPS"
em lugares onde não tem sinal.

> Status honesto: está em desenvolvimento ativo, sou o único usuário, então
> coisas quebram. A APK assinada com debug-key, distribuição é instalação
> direta. Se você caiu aqui e quer experimentar, beleza — só não espere
> Play Store.

---

## O que ele faz hoje

- **Mapa offline-friendly** com três fontes de tile: OpenStreetMap,
  OpenTopoMap (topográfico, com curvas de nível — o default) e Esri World
  Imagery (satélite). Troca pelo ícone de camadas no topo.
- **Pré-download de região** — desenha um retângulo no mapa, escolhe o range
  de zoom, e o app baixa todos os tiles pra usar depois sem internet. Cache
  via FMTC.
- **Nova observação** — abre a câmera in-app, tira N fotos da mesma parada,
  escreve uma descrição, e o GPS é capturado automaticamente no save. EXIF
  com lat/lon, bearing da bússola e altitude vai dentro de cada JPEG.
- **Long-press no mapa** pra criar um ponto manualmente onde você quiser
  (útil pra coisas que você viu mas não chegou perto o suficiente).
- **Projetos** — separe trabalhos diferentes. Cada projeto tem ícone
  próprio (vulcão, montanha, martelo, cristal, etc), e a aba mostra um
  feed visual com todas as fotos do projeto.
- **Tags por observação** com autocomplete — você digita uma tag e ele
  sugere as que já usou nesse projeto. Pode adicionar na hora de tirar a
  foto ou editar depois.
- **Gravação de trajeto** rodando em foreground service. Cada projeto tem
  seu próprio estado de gravação independente — dá pra estar gravando dois
  projetos ao mesmo tempo. Sobrevive a fechar e reabrir o app.
- **Banner persistente na tela de bloqueio** enquanto está rastreando, pra
  você não esquecer que o GPS tá ligado e queimar bateria à toa.
- **Régua** — toca em pontos pra medir distância. A partir de 3 pontos vira
  área.
- **Lista de observações** com busca por descrição.
- **Lixeira** — soft-delete, dá pra restaurar.
- **Export tudo** num ZIP em `Downloads/mappy/`:
  - `observations.geojson` (FeatureCollection com pontos e tracks)
  - `observations.csv`
  - `tracks.csv` (uma linha por ponto GPS gravado)
  - `photos/<id>/*.jpg` com EXIF preservado

---

## Como rodar (se você quiser brincar)

Vai precisar do Flutter (canal stable, 3.27+) e do Android SDK (API 26+).
Depois, do raiz do repo:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Pra gerar a APK de release:

```powershell
flutter build apk --release
# Sai em: build/app/outputs/flutter-apk/app-release.apk
```

Copia pro celular, libera "Instalar de fontes desconhecidas" pro seu
gerenciador de arquivos, abre o `.apk` e instala.

### CI

Tem um workflow do GitHub Actions (`.github/workflows/release.yml`) que roda
a cada push na `main`, builda a APK e publica como release com tag
`vX.Y.Z-build.N`. Se o repo for público, a APK é baixável direto da página
de releases sem login.

---

## Stack

Tudo Flutter/Dart. Nada de backend.

- **Riverpod** pra state.
- **go_router** pra navegação (legado — boa parte do app ainda usa Navigator
  direto).
- **Drift** (SQLite) pro banco local, com codegen via `build_runner`.
- **flutter_map** + **FMTC** (Flutter Map Tile Caching, com backend ObjectBox)
  pro mapa e cache offline. **Importante:** o mapa "ao vivo" usa
  `NetworkTileProvider` direto, sem FMTC, porque o backend dele tem dado
  problema em release build (provavelmente R8 minificando demais). O FMTC
  só entra quando você usa o pre-download explícito.
- **geolocator** pro GPS (foreground e streaming).
- **camera** + **flutter_image_compress** + **native_exif** pra fotos.
- **flutter_local_notifications** pro banner de tracking na lock screen.
- Ícone do app gerado por um script Dart (`tools/gen_icon.dart`) que desenha
  um pin de mapa estilizado com bandas estratigráficas e um martelo de
  geólogo. Placeholder até eu fazer um decente.

---

## Layout do código

```
lib/
├─ main.dart
├─ app/                        # Tema, shell de navegação
├─ core/
│  ├─ db/                      # Tabelas Drift + DAOs (com codegen)
│  ├─ location/                # Wrappers de geolocator e bússola
│  ├─ permissions/             # Tela de primeira execução
│  ├─ notifications/           # Banner persistente de tracking
│  ├─ files/                   # Pastas de app-docs e Downloads
│  └─ exif/                    # Escrita de EXIF GPS+bearing+altitude
└─ features/
   ├─ map/                     # flutter_map, fontes de tile, régua, pre-download
   ├─ observations/            # Fluxo de captura, câmera, lista, detalhe, lixeira
   ├─ projects/                # CRUD + ícones por projeto + projeto ativo
   ├─ tracks/                  # Recorder multi-projeto + camada de polilinha
   └─ export/                  # GeoJSON / CSV / ZIP
```

---


## Atribuição

Tiles de mapa:
- © OpenStreetMap contributors (ODbL)
- OpenTopoMap (CC-BY-SA), © OpenStreetMap contributors
- Esri World Imagery — Source: Esri, Maxar, Earthstar Geographics, and the
  GIS User Community

Os requests de tile mandam um User-Agent identificável (`mappy/0.1
(geological field mapping; com.scholze.mappy)`) — se você for forkar isso,
troca o package name pra um seu antes de bater nos servidores deles. OSM e
OpenTopoMap rate-limitam quem se faz passar pelos outros.

