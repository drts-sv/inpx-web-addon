# inpx-web add-on для Home Assistant

Обёртка над [inpx-web](https://github.com/bookpauk/inpx-web) (форк
[drts-sv/inpx-web](https://github.com/drts-sv/inpx-web)): поиск по `.inpx`-коллекции
fb2, веб-интерфейс и OPDS-сервер для читалок.

## Установка репозитория

1. Home Assistant → **Настройки → Дополнения → Магазин дополнений**.
2. **⋮** (справа вверху) → **Репозитории**.
3. Добавить URL: `https://github.com/drts-sv/inpx-web-addon`
4. Закрыть, найти **inpx-web library** → **Установить** → **Запустить**.

## Состав

| Файл | Назначение |
|---|---|
| `repository.yaml` | делает репозиторий доступным как источник add-on'ов в HA |
| `inpx_web/config.yaml` | манифест: опции, порт 12380, монтирование `media:ro` и `share:rw` |
| `inpx_web/Dockerfile` | multi-stage `node:20-bookworm-slim`: сборка клиента из форка [inpx-web-glass](https://github.com/drts-sv/inpx-web-glass) + рантайм `node server` |
| `inpx_web/run.sh` | `/data/options.json` → `jq` → поиск `.inpx` → генерация `config.json` → запуск сервера |

## Опции

| Опция | По умолчанию | Смысл |
|---|---|---|
| `lib_dir` | `/media/disk/torrents/fb2.Flibusta.Net` | каталог с `.inpx` и zip-архивами (только чтение) |
| `inpx_file` | пусто = автопоиск | явный путь, если в каталоге несколько `.inpx` |
| `data_dir` | `/data/inpx-web` | поисковая БД, кэш, логи, `config.json` |
| `access_password` | пусто | пароль на веб-интерфейс |
| `opds_user` / `opds_password` | пусто | Basic-auth для OPDS |
| `low_memory` | `true` | `lowMemoryMode` — для хостов под swap |
| `db_cache_size` | `5` | `dbCacheSize`: кэш БД в памяти, 1–50 |

## Особенности реализации

- **Ingress не поддерживается** осознанно: фронтенд inpx-web грузит ассеты по
  абсолютному `publicPath` и строит ссылки на книги от `window.location.origin`,
  поэтому под `/api/hassio_ingress/<token>/` он ломается. Используется порт
  12380 + «Open Web UI».
- **Нет зависимости от базовых образов HA и bashio**: Supervisor 2026 не
  передал `build.args` (`${BUILD_FROM}` пришёл пустым), поэтому база
  фиксирована, а опции читаются через `jq`.
- `.inpx` выбирается скриптом явно: inpx-web падает с `Found more than one .inpx
  files`, если в каталоге их несколько.
- Первый старт строит поисковую БД (для крупной коллекции — десятки минут);
  `/data` переживает обновления add-on'а, повторные старты секундные.

## Проверено

- `bash -n inpx_web/run.sh`, разбор `config.yaml`, LF-переводы строк.
- ELF-зависимости бинарника: `libc.so.6`, `libm`, `libdl`, `libpthread`,
  `libgcc_s`, `libstdc++` — покрываются `debian:bookworm-slim` + `libstdc++6`.
- Релизные артефакты `inpx-web-1.5.8-linux.zip` / `-linux-arm64.zip` доступны.
