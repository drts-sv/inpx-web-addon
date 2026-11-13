#!/usr/bin/env bash
# Options arrive from the Supervisor as /data/options.json; parsed with jq, so
# the image needs no bashio and no Home Assistant base image.
set -euo pipefail

OPTIONS_FILE="/data/options.json"
PORT=12380

log()  { printf '[%s] %s\n'        "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n'   "$(date '+%H:%M:%S')" "$*" >&2; exit 1; }

opt() { jq -r --arg k "$1" 'if has($k) then .[$k] else "" end' "$OPTIONS_FILE"; }

[ -f "$OPTIONS_FILE" ] || die "Не найден ${OPTIONS_FILE} — add-on запущен вне Supervisor?"

LIB_DIR="$(opt lib_dir)"
INPX_FILE="$(opt inpx_file)"
DATA_DIR="$(opt data_dir)"
ACCESS_PASSWORD="$(opt access_password)"
OPDS_USER="$(opt opds_user)"
OPDS_PASSWORD="$(opt opds_password)"
LOW_MEMORY="$(opt low_memory)"

[ -n "$DATA_DIR" ] || DATA_DIR="/data/inpx-web"
[ -n "$LOW_MEMORY" ] || LOW_MEMORY="true"

log "inpx-web: library dir = ${LIB_DIR}"
[ -d "$LIB_DIR" ] || die "Каталог библиотеки не найден: ${LIB_DIR}. Проверьте, что диск смонтирован в /media и что add-on имеет доступ к media."

# --- pick the .inpx file -----------------------------------------------------
# inpx-web aborts with "Found more than one .inpx files" when it finds several
# on its own, so always hand it an explicit --inpx.
if [ -z "$INPX_FILE" ]; then
    mapfile -t FOUND < <(
        find "$LIB_DIR" -maxdepth 2 -type f -iname '*.inpx' -printf '%s\t%p\n' 2>/dev/null \
            | sort -rn | cut -f2-
    )
    [ "${#FOUND[@]}" -gt 0 ] || die "В ${LIB_DIR} нет ни одного .inpx файла"
    if [ "${#FOUND[@]}" -gt 1 ]; then
        warn "Найдено .inpx файлов: ${#FOUND[@]} — беру самый большой. Задайте 'inpx_file' вручную, если нужен другой:"
        printf '%s\n' "${FOUND[@]}" | while read -r line; do warn "  $line"; done
    fi
    INPX_FILE="${FOUND[0]}"
elif [ ! -f "$INPX_FILE" ]; then
    die "Файл .inpx не найден: ${INPX_FILE}"
fi

log "inpx-web: inpx file   = ${INPX_FILE}"
log "inpx-web: data dir    = ${DATA_DIR}"

# --- config.json -------------------------------------------------------------
# Add-on options are the source of truth for these fields; everything else in
# an existing config.json (cache sizes, filters, uiDefaults) is left untouched.
FIRST_RUN=false
[ -d "$DATA_DIR" ] || FIRST_RUN=true
mkdir -p "$DATA_DIR"

CONFIG_FILE="${DATA_DIR}/config.json"
if [ -f "$CONFIG_FILE" ]; then
    jq --arg pw "$ACCESS_PASSWORD" \
       --argjson low "$LOW_MEMORY" \
       --arg ou "$OPDS_USER" \
       --arg op "$OPDS_PASSWORD" \
       --argjson port "$PORT" \
       '.accessPassword = $pw
        | .lowMemoryMode = $low
        | .server = ((.server // {}) | .host = "0.0.0.0" | .port = $port)
        | .opds = ((.opds // {}) | .enabled = true | .user = $ou | .password = $op | .root = "/opds")' \
       "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    jq -n --arg pw "$ACCESS_PASSWORD" \
       --argjson low "$LOW_MEMORY" \
       --arg ou "$OPDS_USER" \
       --arg op "$OPDS_PASSWORD" \
       --argjson port "$PORT" \
       '{accessPassword: $pw, lowMemoryMode: $low,
         server: {host: "0.0.0.0", port: $port},
         opds: {enabled: true, user: $ou, password: $op, root: "/opds"}}' \
       > "$CONFIG_FILE"
fi

if [ "$FIRST_RUN" = "true" ]; then
    warn "Первый запуск: строится поисковая БД. Для большой коллекции это займёт от минут до десятков минут; веб-интерфейс поднимется после индексации."
fi

log "inpx-web: Web UI  -> http://<host>:${PORT}/"
log "inpx-web: OPDS    -> http://<host>:${PORT}/opds"

exec /opt/inpx-web/inpx-web \
    --data-dir "$DATA_DIR" \
    --lib-dir "$LIB_DIR" \
    --inpx "$INPX_FILE" \
    --port "$PORT" \
    --host 0.0.0.0
