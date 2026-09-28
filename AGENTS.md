# mappy

App de campo offline e local-only para mapeamento geológico: ponto + foto + descrição + GPS + tracks, em projetos. Sem conta, sem nuvem, sem sync; tudo fica no aparelho até exportar. Um único usuário (o autor), APK assinada com debug-key, sem Play Store.

## Commands
Tudo via `mise` (Flutter e JDK pinados em `mise.toml`).
- `mise run setup` — `flutter pub get` + codegen
- `mise run codegen` — `dart run build_runner build --delete-conflicting-outputs`
- `mise run analyze` — `flutter analyze`
- `mise run test` — `flutter test`
- `mise run build` — APK release
- `mise run demo-avd` / `demo-emulator` — cria e liga o emulador `mappy_demo`
- `mise run demo-seed` — instala a APK release e semeia dados falsos (APAGA o app: só em emulador)
- `mise run demo-gravar` / `demo-montar` — grava telas e clipes; gera `site/media` e `.github/media`

## Layout
- `lib/app/` tema e shell de navegação
- `lib/core/` db (Drift), location, permissions, notifications, files, exif
- `lib/features/<feature>/` map, observations, projects, tracks, export. Código novo entra na feature dona; `core/` só recebe o que mais de uma feature usa.
- `test/` espelha `lib/` (db, export, map)
- `site/` landing page estática (GitHub Pages via `pages.yml`); `.github/media/` mídia do README
- `tools/demo/` seed, gravação e montagem da demo (fotos PD/CC0 em `fotos/`); `tools/` scripts avulsos

## Conventions
- Riverpod para estado, Navigator para navegação, Drift para persistência.
- `*.g.dart` e `*.freezed.dart` são gerados e ficam no `.gitignore`.
- UI em inglês; README, site e docs em PT-BR.
- Push na `main` dispara build da APK e release (`release.yml`).

## Domain glossary
- **observação**: ponto com N fotos, descrição, tags e GPS capturado no save; EXIF (lat/lon, bearing, altitude) escrito nos JPEGs.
- **projeto**: agrupa observações e tracks; tem ícone próprio e estado de gravação independente.
- **track**: trajeto gravado em foreground service.
- **região offline**: retângulo de tiles pré-baixados via FMTC.

## Never do
- Adicionar rede, nuvem, conta, sync ou telemetria (única rede permitida: tiles de mapa).
- Trocar o User-Agent dos tiles ou o package name.
- Editar `*.g.dart` à mão.
- Rodar `demo-seed` ou dados falsos num aparelho real.
- Co-autorar commits ou PRs: sem `Co-Authored-By` e sem rodapé "Generated with Claude Code".

## Definition of done
`mise run analyze` e `mise run test` verdes; mudança visual conferida rodando o app num emulador.
