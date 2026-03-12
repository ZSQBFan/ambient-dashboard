#!/bin/bash

# ─── Time & Date ─────────────────────────────────────────────────────────────
TIME=$(LC_ALL=C date "+%H:%M")
DATE=$(LC_ALL=C date "+%A, %B %-d")
YEAR=$(LC_ALL=C date "+%Y")

# ─── Now Playing ─────────────────────────────────────────────────────────────
TRACK="" ARTIST="" ALBUM="" ART_PATH="" PLAYER=""

NP_RESULT=$(timeout 4 osascript 2>/dev/null <<'AS'
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
    (timeout 3 osascript 2>/dev/null <<'AS'
tell application "Music"
  try
    set artData to data of artwork 1 of current track
    set f to open for access POSIX file "/tmp/ub_art.jpg" with write permission
    set eof of f to 0
    write artData to f
    close access f
  end try
end tell
AS
    ) &
  fi
  [ -f /tmp/ub_art.jpg ] && ART_PATH="/tmp/ub_art.jpg"
fi

# ─── Memory pressure (官方指标，后台异步更新，本次读上次缓存) ─────────────────
MEM_PRESSURE_CACHE="/tmp/ub_mem_pressure.txt"

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
python3 - > /tmp/ub_mem.txt 2>/dev/null <<'PYEOF'
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
MEM_USED_GB=$( sed -n '1p' /tmp/ub_mem.txt 2>/dev/null || echo '?')
MEM_TOTAL_GB=$(sed -n '2p' /tmp/ub_mem.txt 2>/dev/null || echo '?')

# ─── Network (cached, no sleep) ───────────────────────────────────────────────
NET_IN_KB=0; NET_OUT_KB=0
NET_CACHE="/tmp/ub_net_cache.txt"
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
HIST="/tmp/ub_history.json"
python3 - > /tmp/ub_hist_new.json 2>/dev/null <<PYEOF
import json
try:    h = json.load(open("$HIST"))
except: h = {"cpu":[],"mem":[],"ni":[],"no":[]}
def push(a, v, n=24): a.append(v); return a[-n:]
h["cpu"] = push(h.get("cpu",[]), $CPU)
h["mem"] = push(h.get("mem",[]), $MEM_PRESSURE)
h["ni"]  = push(h.get("ni", []), $NET_IN_KB)
h["no"]  = push(h.get("no", []), $NET_OUT_KB)
with open("/tmp/ub_hist_new.json","w") as f: json.dump(h,f)
print(json.dumps(h))
PYEOF
mv /tmp/ub_hist_new.json "$HIST" 2>/dev/null
HISTORY=$(cat "$HIST" 2>/dev/null || echo '{"cpu":[],"mem":[],"ni":[],"no":[]}')

# ─── Slideshow images ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIDE_DIR="$SCRIPT_DIR/slideshow"
IMAGES="[]"
if [ -d "$SLIDE_DIR" ]; then
  IMAGES=$(find "$SLIDE_DIR" -maxdepth 1 \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
       -o -iname "*.webp" -o -iname "*.gif"  -o -iname "*.avif" \
       -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.tiff" \
       -o -iname "*.tif"  -o -iname "*.bmp" \) \
    | sort | python3 -c \
    "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" \
    2>/dev/null || echo "[]")
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
  "player":      "$(esc "$PLAYER")",
  "cpu":         $CPU,
  "memPressure": $MEM_PRESSURE,
  "memUsed":     "$(esc "$MEM_USED_GB")",
  "memTotal":    "$(esc "$MEM_TOTAL_GB")",
  "netInKB":     $NET_IN_KB,
  "netOutKB":    $NET_OUT_KB,
  "history":     $HISTORY,
  "images":      $IMAGES
}
JSON
