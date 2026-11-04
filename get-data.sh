#!/bin/bash
# ─── Portable timeout shim ───────────────────────────────────────────────────
# macOS ships no `timeout`; some setups have coreutils' `gtimeout`. Fall back to
# running the command unwrapped so the widget still works on a stock Mac.
TO() {
  if command -v timeout  >/dev/null 2>&1; then timeout  "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else shift; "$@"
  fi
}

# ─── Per-user scratch dir (avoids /tmp collisions between widget instances) ──
UB_DIR="${TMPDIR:-/tmp}/uebersicht-ambient"
mkdir -p "$UB_DIR"
# Artwork path is derived per track further down (see "Now Playing"), so that a
# new track never shows the previous track's cover while this script is still
# extracting the fresh one.
UB_ART=""

# ─── Time & Date ─────────────────────────────────────────────────────────────
TIME=$(LC_ALL=C date "+%H:%M")
DATE=$(LC_ALL=C date "+%A, %B %-d")
YEAR=$(LC_ALL=C date "+%Y")

# ─── Now Playing ─────────────────────────────────────────────────────────────
TRACK="" ARTIST="" ALBUM="" ART_PATH="" PLAYER=""

NP_RESULT=$(TO 4 osascript 2>/dev/null <<'AS'
tell application "System Events"
  set musicRunning   to (name of processes) contains "Music"
  set spotifyRunning to (name of processes) contains "Spotify"
end tell
if musicRunning then
  tell application "Music"
    if player state is playing then
      return "Music|||" & (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track)
    end if
  end tell
end if
if spotifyRunning then
  tell application "Spotify"
    if player state is playing then
      return "Spotify|||" & (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track)
    end if
  end tell
end if
return "none"
AS
)

if [[ "$NP_RESULT" != "none" && -n "$NP_RESULT" ]]; then
  PLAYER=$( echo "$NP_RESULT" | awk -F'[|][|][|]' '{print $1}')
  TRACK=$(  echo "$NP_RESULT" | awk -F'[|][|][|]' '{print $2}')
  ARTIST=$( echo "$NP_RESULT" | awk -F'[|][|][|]' '{print $3}')
  ALBUM=$(  echo "$NP_RESULT" | awk -F'[|][|][|]' '{print $4}')
  if [[ "$PLAYER" == "Music" ]]; then
    # Cache the cover per track. Hitting the cache avoids both the 8s gap after
    # a track change and the stale-cover flash while osascript is still writing.
    ART_KEY=$(printf '%s|%s|%s' "$PLAYER" "$TRACK" "$ARTIST" | md5 -q)
    UB_ART="$UB_DIR/art_$ART_KEY.jpg"
    if [ -s "$UB_ART" ]; then
      ART_PATH="$UB_ART"
    else
      (TO 3 osascript - "$UB_ART" 2>/dev/null <<'AS'
on run argv
  set dst to item 1 of argv
  tell application "Music"
    try
      set artData to data of artwork 1 of current track
      set f to open for access POSIX file dst with write permission
      set eof of f to 0
      write artData to f
      close access f
    end try
  end tell
end run
AS
      ) &
    fi
  fi
fi


# ─── Memory pressure (官方指标，后台异步更新，本次读上次缓存) ─────────────────
MEM_PRESSURE_CACHE="$UB_DIR/ub_mem_pressure.txt"

# 启动后台更新（不阻塞主流程）
(
  FREE_PCT=$(memory_pressure 2>/dev/null \
    | grep -i "System-wide memory free percentage" \
    | grep -o '[0-9]*' | head -1)
  echo $(( 100 - ${FREE_PCT:-100} )) > "$MEM_PRESSURE_CACHE"
) &

# 读取上次缓存值（首次运行为 0，下次刷新即有真实值）
MEM_PRESSURE=$(cat "$MEM_PRESSURE_CACHE" 2>/dev/null || echo 0)
MEM_PRESSURE=${MEM_PRESSURE:-0}

# ─── CPU ─────────────────────────────────────────────────────────────────────
CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 1)
CPU=$(ps -A -o %cpu 2>/dev/null | awk -v c="$CORES" \
  '{s+=$1} END{v=int(s/c); print (v>100)?100:v}')
CPU=${CPU:-0}

# ─── Memory used (for subtitle) ───────────────────────────────────────────────
python3 - > $UB_DIR/ub_mem.txt 2>/dev/null <<'PYEOF'
import subprocess, re
out   = subprocess.check_output(["vm_stat"], text=True)
total = int(subprocess.check_output(["sysctl","-n","hw.memsize"], text=True).strip())
PAGE  = 4096
def p(pat):
    m = re.search(pat + r'[^0-9]*([0-9]+)', out)
    return int(m.group(1)) if m else 0
used = (p(r'Pages active') + p(r'Pages wired down') + p(r'occupied by compressor')) * PAGE
print(f'{used/1073741824:.1f}')
print(f'{total/1073741824:.0f}')
PYEOF
MEM_USED_GB=$( sed -n '1p' $UB_DIR/ub_mem.txt 2>/dev/null || echo '?')
MEM_TOTAL_GB=$(sed -n '2p' $UB_DIR/ub_mem.txt 2>/dev/null || echo '?')

# ─── Network (cached, no sleep) ───────────────────────────────────────────────
NET_IN_KB=0; NET_OUT_KB=0
NET_CACHE="$UB_DIR/ub_net_cache.txt"
NET_IF=$(route get default 2>/dev/null | awk '/interface/{print $2}')
if [ -n "$NET_IF" ]; then
  NOW_TS=$(date +%s)
  read CUR_IN CUR_OUT <<< \
    $(netstat -I "$NET_IF" -b 2>/dev/null | awk 'NR==2{print $7+0,$10+0}')
  if [ -f "$NET_CACHE" ]; then
    read PREV_TS PREV_IN PREV_OUT < "$NET_CACHE"
    DELTA=$(( NOW_TS - ${PREV_TS:-$NOW_TS} ))
    if [ "${DELTA:-0}" -gt 0 ] 2>/dev/null; then
      NET_IN_KB=$(( (${CUR_IN:-0}  - ${PREV_IN:-0})  / 1024 / DELTA ))
      NET_OUT_KB=$(( (${CUR_OUT:-0} - ${PREV_OUT:-0}) / 1024 / DELTA ))
      [ "${NET_IN_KB:-0}"  -lt 0 ] && NET_IN_KB=0
      [ "${NET_OUT_KB:-0}" -lt 0 ] && NET_OUT_KB=0
    fi
  fi
  echo "$NOW_TS ${CUR_IN:-0} ${CUR_OUT:-0}" > "$NET_CACHE"
fi

# ─── History ─────────────────────────────────────────────────────────────────
HIST="$UB_DIR/ub_history.json"
python3 - > $UB_DIR/ub_hist_new.json 2>/dev/null <<PYEOF
import json
try:    h = json.load(open("$HIST"))
except: h = {"cpu":[],"mem":[],"ni":[],"no":[]}
def push(a, v, n=24): a.append(v); return a[-n:]
h["cpu"] = push(h.get("cpu",[]), $CPU)
h["mem"] = push(h.get("mem",[]), $MEM_PRESSURE)
h["ni"]  = push(h.get("ni", []), $NET_IN_KB)
h["no"]  = push(h.get("no", []), $NET_OUT_KB)
with open("$UB_DIR/ub_hist_new.json","w") as f: json.dump(h,f)
print(json.dumps(h))
PYEOF
mv $UB_DIR/ub_hist_new.json "$HIST" 2>/dev/null
HISTORY=$(cat "$HIST" 2>/dev/null || echo '{"cpu":[],"mem":[],"ni":[],"no":[]}')

# ─── Slideshow images ─────────────────────────────────────────────────────────
# Übersicht does not load widgets over file:// — it serves them from a local
# HTTP server (http://127.0.0.1:<port>) and mounts the widgets folder statically
# at the server root. So images must be addressed as /<widget-folder>/<file>,
# not as file:// URLs: a file:// <img> from an http page is blocked by WebKit and
# silently renders nothing. `images` keeps the absolute paths (useful for
# scripting); `imageUrls` is what the widget actually renders.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIDGET_NAME="$(basename "$SCRIPT_DIR")"
SLIDE_DIR="$SCRIPT_DIR/slideshow"
IMAGES="[]"
IMAGE_URLS="[]"
if [ -d "$SLIDE_DIR" ]; then
  SLIDE_FILES=$(find "$SLIDE_DIR" -maxdepth 1 \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
       -o -iname "*.webp" -o -iname "*.gif"  -o -iname "*.avif" \
       -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.tiff" \
       -o -iname "*.tif"  -o -iname "*.bmp" \) \
    | sort)
  if [ -n "$SLIDE_FILES" ]; then
    IMAGES=$(printf '%s\n' "$SLIDE_FILES" | python3 -c \
      "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" \
      2>/dev/null || echo "[]")
    IMAGE_URLS=$(printf '%s\n' "$SLIDE_FILES" | WIDGET_NAME="$WIDGET_NAME" python3 -c \
      "import sys,json,os,urllib.parse as u
name=u.quote(os.environ['WIDGET_NAME'])
print(json.dumps(['/'+name+'/slideshow/'+u.quote(os.path.basename(l.strip()))
                  for l in sys.stdin if l.strip()]))" \
      2>/dev/null || echo "[]")
  fi
fi

# ─── Artwork as a data: URL ───────────────────────────────────────────────────
# Same reason as the slideshow: the cover lives outside the widgets folder, where
# the local HTTP server cannot reach it. Inlining it sidesteps the whole
# file://-from-http problem. Covers are a few tens of KB, so the cost is small.
ART_DATA=""
if [ -n "$ART_PATH" ] && [ -s "$ART_PATH" ]; then
  ART_DATA="data:image/jpeg;base64,$(base64 < "$ART_PATH" | tr -d '\n')"
fi

# ─── JSON ─────────────────────────────────────────────────────────────────────
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
cat <<JSON
{
  "time":        "$(esc "$TIME")",
  "date":        "$(esc "$DATE")",
  "year":        "$(esc "$YEAR")",
  "track":       "$(esc "$TRACK")",
  "artist":      "$(esc "$ARTIST")",
  "album":       "$(esc "$ALBUM")",
  "artPath":     "$(esc "$ART_PATH")",
  "artData":     "$(esc "$ART_DATA")",
  "player":      "$(esc "$PLAYER")",
  "cpu":         $CPU,
  "memPressure": $MEM_PRESSURE,
  "memUsed":     "$(esc "$MEM_USED_GB")",
  "memTotal":    "$(esc "$MEM_TOTAL_GB")",
  "netInKB":     $NET_IN_KB,
  "netOutKB":    $NET_OUT_KB,
  "history":     $HISTORY,
  "images":      $IMAGES,
  "imageUrls":   $IMAGE_URLS
}
JSON
