// ╔══════════════════════════════════════════════════════════════╗
// ║  Ambient Dashboard — Full Screen Bento                       ║
// ╚══════════════════════════════════════════════════════════════╝

import { React, css } from "uebersicht";

// Resolved at run time so the widget works wherever Übersicht is installed.
export const command = `bash "$HOME/Library/Application Support/Übersicht/widgets/ambient-dashboard/get-data.sh"`;
export const refreshFrequency = 8000;
const SLIDE_SEC = 20;

// ── Path → file:// URL (encodeURI preserves / but encodes 中文 & Ü etc.) ─────
const fileUrl = (path) => encodeURI("file://" + (path || ""));

// ── Icons ─────────────────────────────────────────────────────────────────────
const Ic = ({ d, size = 12 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth="1.6"
    strokeLinecap="round" strokeLinejoin="round"
    style={{ flexShrink: 0, display: "block" }}>
    <path d={d} />
  </svg>
);
const IC = {
  clock: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z",
  music: "M9 19V6l12-3v13M9 19c0 1.1-.9 2-2 2s-2-.9-2-2 .9-2 2-2 2 .9 2 2zm12-3c0 1.1-.9 2-2 2s-2-.9-2-2 .9-2 2-2 2 .9 2 2z",
  cpu:   "M9 3H5a2 2 0 00-2 2v4m6-6h10a2 2 0 012 2v4M9 3v18m0 0h10a2 2 0 002-2v-4M9 21H5a2 2 0 01-2-2v-4m0 0h18",
  mem:   "M20 7H4a2 2 0 00-2 2v6a2 2 0 002 2h16a2 2 0 002-2V9a2 2 0 00-2-2z",
  down:  "M19 9l-7 7-7-7",
  up:    "M5 15l7-7 7 7",
};

// ── Sparkline ─────────────────────────────────────────────────────────────────
const Spark = ({ data, color, w = 88, h = 28 }) => {
  const pts = (data || []).slice(-24);
  const gradId = "g" + color.replace(/[^a-z0-9]/gi, "");
  if (pts.length < 2) return (
    <svg width={w} height={h} style={{ display:"block" }}>
      <line x1="0" y1={h/2} x2={w} y2={h/2}
        stroke={color} strokeWidth="1.2"
        strokeDasharray="3 3" strokeOpacity="0.25" />
    </svg>
  );
  const max  = Math.max(...pts, 1);
  const step = w / (pts.length - 1);
  const coords = pts.map((v, i) => [
    i * step,
    h - 2 - (v / max) * (h - 6),
  ]);
  const line = coords.map(([x, y]) => `${x},${y}`).join(" ");
  const area = `0,${h} ${line} ${w},${h}`;
  const [lx, ly] = coords[coords.length - 1];
  return (
    <svg width={w} height={h} style={{ display:"block", overflow:"visible" }}>
      <defs>
        <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%"   stopColor={color} stopOpacity="0.25" />
          <stop offset="100%" stopColor={color} stopOpacity="0.01" />
        </linearGradient>
      </defs>
      <polygon points={area} fill={`url(#${gradId})`} />
      <polyline points={line} fill="none"
        stroke={color} strokeWidth="1.5"
        strokeLinejoin="round" strokeLinecap="round"
        style={{ filter:`drop-shadow(0 0 2px ${color}66)` }} />
      <circle cx={lx} cy={ly} r="2.2" fill={color} />
    </svg>
  );
};

// ── Arc gauge ─────────────────────────────────────────────────────────────────
const Arc = ({ value = 0, color = "#38bdf8", size = 48 }) => {
  const r    = (size - 7) / 2;
  const c    = size / 2;
  const circ = 2 * Math.PI * r;
  const fill = (Math.min(100, Math.max(0, Number(value) || 0)) / 100) * circ;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}
      style={{ display:"block", transform:"rotate(-90deg)", flexShrink:0 }}>
      <circle cx={c} cy={c} r={r}
        fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth="4" />
      <circle cx={c} cy={c} r={r}
        fill="none" stroke={color} strokeWidth="4"
        strokeLinecap="round"
        strokeDasharray={`${fill} ${circ}`}
        style={{ filter:`drop-shadow(0 0 3px ${color}99)` }} />
    </svg>
  );
};

const pColor = v => Number(v) < 40 ? "#4ade80" : Number(v) < 70 ? "#facc15" : "#f87171";
const fmtNet = kb => {
  const n = Number(kb) || 0;
  if (n >= 1024*1024) return `${(n/1024/1024).toFixed(1)} GB/s`;
  if (n >= 1024)      return `${(n/1024).toFixed(1)} MB/s`;
  return `${n} KB/s`;
};

const Card  = ({ children, style }) => <div className={card} style={style}>{children}</div>;
const Chip  = ({ icon, label, color }) => (
  <div className={chip} style={color ? { color } : {}}>
    <Ic d={IC[icon]} size={10} /><span>{label}</span>
  </div>
);
const Divr  = () => <div style={{ height:1, background:"rgba(255,255,255,0.05)", margin:"0" }} />;

// ── StatRow ───────────────────────────────────────────────────────────────────
const StatRow = ({ icon, label, value, unit, color, spark, sub }) => (
  <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", gap:8, padding:"5px 0" }}>
    <div style={{ display:"flex", alignItems:"center", gap:8, flexShrink:0 }}>
      <div style={{ position:"relative", width:48, height:48,
        display:"flex", alignItems:"center", justifyContent:"center" }}>
        <Arc value={value} color={color} size={48} />
        <span style={{ position:"absolute",
          fontFamily:"'JetBrains Mono',monospace", fontSize:10, color, whiteSpace:"nowrap" }}>
          {value}{unit}
        </span>
      </div>
      <div style={{ display:"flex", flexDirection:"column", gap:3 }}>
        <Chip icon={icon} label={label} />
        {sub && <div className={subTxt}>{sub}</div>}
      </div>
    </div>
    <Spark data={spark} color={color} w={88} h={28} />
  </div>
);

// ── NetRow ────────────────────────────────────────────────────────────────────
const NetRow = ({ icon, label, value, color, spark }) => (
  <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", gap:8, padding:"5px 0" }}>
    <div style={{ display:"flex", flexDirection:"column", gap:3, flexShrink:0 }}>
      <Chip icon={icon} label={label} color={color} />
      <span style={{ fontFamily:"'JetBrains Mono',monospace", fontSize:12, color, lineHeight:1 }}>
        {fmtNet(value)}
      </span>
    </div>
    <Spark data={spark} color={color} w={88} h={28} />
  </div>
);

// ── Main render ───────────────────────────────────────────────────────────────
export const render = ({ output, error }) => {
  let d = {};
  if (!error) { try { d = JSON.parse(output || "{}"); } catch (_) {} }

  const {
    time="--:--", date="---", year="",
    track="", artist="", album="", artPath="", player="",
    cpu=0, memPressure=0, memUsed="?", memTotal="?",
    netInKB=0, netOutKB=0, history={}, images=[],
  } = d;

  const hist     = history || {};
  const hasTrack = Boolean(track);
  const artUrl   = artPath ? fileUrl(artPath) + `?_t=${Math.floor(Date.now()/16000)}` : "";
  const [hh, mm] = (time||"--:--").split(":");
  const slideIdx = images.length
    ? Math.floor(Date.now()/1000/SLIDE_SEC) % images.length : 0;
  const slideUrl = images.length ? fileUrl(images[slideIdx]) : null;

  return (
    <div className={root}>

      {/* Ambient bg: blurred slide */}
      <div style={{ position:"absolute", inset:0, zIndex:0, overflow:"hidden" }}>
        {slideUrl && (
          <img src={slideUrl} style={{
            position:"absolute", top:"-10%", left:"-10%",
            width:"120%", height:"120%", objectFit:"cover",
            filter:"blur(60px) brightness(0.18) saturate(2.4)",
            transform:"scale(1.05)",
          }} />
        )}
        <div style={{
          position:"absolute", inset:0,
          background:"linear-gradient(135deg,rgba(4,8,18,0.88) 0%,rgba(4,7,16,0.94) 100%)",
        }} />
      </div>

      {/* LEFT */}
      <div className={leftPanel}>

        <Card>
          <Chip icon="clock" label="LOCAL TIME" />
          <div style={{ display:"flex", alignItems:"baseline", marginTop:7, lineHeight:1 }}>
            <span className={cNum}>{hh}</span>
            <span className={cColon}>:</span>
            <span className={cNum}>{mm}</span>
          </div>
          <div className={dateTxt}>{date}</div>
          <div className={yearTxt}>{year}</div>
        </Card>

        <Card>
          <div style={{ display:"flex", alignItems:"center", gap:6, marginBottom:9 }}>
            <Chip icon="music" label={hasTrack ? player.toUpperCase() : "NOW PLAYING"} />
            {hasTrack && (
              <div style={{ display:"flex", alignItems:"flex-end", gap:2, marginLeft:"auto" }}>
                {[4,11,7,13,5].map((h,i) => (
                  <span key={i} className={pBar} style={{ height:h, animationDelay:`${i*.15}s` }} />
                ))}
              </div>
            )}
          </div>
          {hasTrack ? (
            <div style={{ display:"flex", gap:10, alignItems:"center" }}>
              <div style={{ width:52, height:52, borderRadius:9, overflow:"hidden", flexShrink:0,
                background:"rgba(255,255,255,0.05)", border:"1px solid rgba(255,255,255,0.07)" }}>
                {artUrl
                  ? <img src={artUrl} style={{ width:"100%",height:"100%",objectFit:"cover",display:"block" }} alt="" />
                  : <div style={{ width:"100%",height:"100%",display:"flex",alignItems:"center",
                      justifyContent:"center",color:"rgba(148,163,184,0.2)" }}>
                      <Ic d={IC.music} size={18} />
                    </div>
                }
              </div>
              <div style={{ flex:1, minWidth:0 }}>
                <div className={tName}>{track}</div>
                <div className={tArtist}>{artist}</div>
                <div className={tAlbum}>{album}</div>
              </div>
            </div>
          ) : (
            <div style={{ display:"flex", alignItems:"center", gap:7, padding:"3px 0",
              color:"rgba(100,116,139,0.28)", fontSize:10, letterSpacing:1 }}>
              <Ic d={IC.music} size={15} />
              <span>Nothing playing</span>
            </div>
          )}
        </Card>

        <Card>
          <StatRow icon="cpu" label="CPU" value={cpu} unit="%" color="#38bdf8" spark={hist.cpu} />
          <Divr />
          <StatRow icon="mem" label="MEM PRESSURE" value={memPressure} unit="%"
            color={pColor(memPressure)} spark={hist.mem}
            sub={`${memUsed} / ${memTotal} GB`} />
          <Divr />
          <NetRow icon="down" label="DOWN" value={netInKB}  color="#4ade80" spark={hist.ni} />
          <Divr />
          <NetRow icon="up"   label="UP"   value={netOutKB} color="#f472b6" spark={hist.no} />
        </Card>

      </div>

      {/* RIGHT */}
      <div className={rightPanel}>
        <div className={slideOuter}>
          {slideUrl
            ? <img key={slideUrl} src={slideUrl} className={slideImg} alt="" />
            : <div style={{ width:"100%",height:"100%",display:"flex",
                alignItems:"center",justifyContent:"center" }}>
                <div style={{ fontFamily:"monospace",fontSize:11,letterSpacing:"2px",
                  lineHeight:2.2,textAlign:"center",color:"rgba(148,163,184,0.28)" }}>
                  PUT IMAGES IN<br/>
                  <span style={{ color:"rgba(56,189,248,0.5)" }}>
                    ambient-dashboard/slideshow/
                  </span><br/>
                  <span style={{ fontSize:9,opacity:.5 }}>
                    jpg · jpeg · png · webp · gif · avif · heic · tiff · bmp
                  </span>
                </div>
              </div>
          }
          {images.length > 1 && (
            <div style={{ position:"absolute",bottom:12,left:"50%",transform:"translateX(-50%)",
              display:"flex",gap:5,zIndex:2 }}>
              {images.map((_, i) => (
                <span key={i} style={{
                  display:"block",width:4,height:4,borderRadius:"50%",
                  background: i===slideIdx ? "rgba(255,255,255,0.8)" : "rgba(255,255,255,0.18)",
                }}/>
              ))}
            </div>
          )}
        </div>
      </div>

    </div>
  );
};

// ── Styles ────────────────────────────────────────────────────────────────────
const root = css`
  @import url('https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=JetBrains+Mono:wght@300;400&family=Inter:wght@300;400;500&display=swap');
  position: fixed; inset: 0;
  display: flex; flex-direction: row; align-items: flex-start;
  gap: 12px; padding: 14px; box-sizing: border-box;
  font-family: 'Inter', sans-serif;
  color: rgba(226,232,240,0.9);
  overflow: hidden;
`;

const card = css`
  background: rgba(8,13,24,0.62);
  backdrop-filter: blur(28px) saturate(160%);
  -webkit-backdrop-filter: blur(28px) saturate(160%);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 16px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.055);
  padding: 14px; box-sizing: border-box;
  position: relative; overflow: hidden;
  &::before {
    content:''; position:absolute; inset:0; border-radius:16px;
    background:linear-gradient(140deg,rgba(255,255,255,0.035) 0%,transparent 55%);
    pointer-events:none;
  }
`;

const leftPanel = css`
  position: relative; z-index: 1;
  width: 265px; flex-shrink: 0;
  display: flex; flex-direction: column; gap: 10px;
`;

const rightPanel = css`
  position: relative; z-index: 1;
  flex: 1; min-width: 0;
  height: calc(100vh - 28px);
`;

const slideOuter = css`
  position: absolute; inset: 0;
  border-radius: 16px; overflow: hidden;
  border: 1px solid rgba(255,255,255,0.08);
  box-shadow: 0 4px 24px rgba(0,0,0,0.5);
  background: rgba(8,13,24,0.62);
  backdrop-filter: blur(28px);
  -webkit-backdrop-filter: blur(28px);
`;

const slideImg = css`
  position: absolute; inset: 0;
  width: 100%; height: 100%;
  object-fit: cover; display: block;
`;

const cNum = css`
  font-family: 'DM Serif Display', serif;
  font-size: 72px; line-height: 1;
  color: rgba(241,245,249,0.95); letter-spacing: -2px;
`;

const cColon = css`
  font-family: 'DM Serif Display', serif;
  font-size: 72px; line-height: 1; letter-spacing: -2px;
  color: rgba(241,245,249,0.18); margin: 0 1px;
  animation: blink 1s step-end infinite;
  @keyframes blink { 0%,100%{opacity:1} 50%{opacity:0.08} }
`;

const dateTxt = css`
  font-family:'Inter',sans-serif; font-weight:300;
  font-size:10px; letter-spacing:3px; text-transform:uppercase;
  color:rgba(148,163,184,0.42); margin-top:8px;
`;

const yearTxt = css`
  font-family:'JetBrains Mono',monospace;
  font-size:9px; letter-spacing:2px;
  color:rgba(100,116,139,0.28); margin-top:2px;
`;

const chip = css`
  display:inline-flex; align-items:center; gap:5px;
  color:rgba(100,116,139,0.52);
  font-family:'JetBrains Mono',monospace;
  font-size:8.5px; letter-spacing:2.5px; text-transform:uppercase;
`;

const pBar = css`
  display:block; width:2px; background:#38bdf8; border-radius:2px;
  animation:pulse 1.1s ease-in-out infinite;
  @keyframes pulse{0%,100%{transform:scaleY(.25);opacity:.35}50%{transform:scaleY(1);opacity:.9}}
`;

const tName   = css`font-size:12px;font-weight:500;color:rgba(241,245,249,0.9);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;`;
const tArtist = css`font-size:10px;color:rgba(148,163,184,0.68);margin-top:2px;`;
const tAlbum  = css`font-size:9.5px;color:rgba(100,116,139,0.52);font-style:italic;margin-top:1px;`;
const subTxt  = css`font-family:'JetBrains Mono',monospace;font-size:8px;color:rgba(100,116,139,0.42);`;
