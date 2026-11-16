const $ = (id) => document.getElementById(id);
let data = null;

const GREETINGS = [
  [0, ["still awake, {her}", "it's late and you know it", "a sleepless malice, as ever"]],
  [5, ["morning, {her}", "you're up early", "early, {her}"]],
  [9, ["morning, {her}", "hello you", "hi {her}"]],
  [12, ["afternoon, {her}", "hello you", "hi {her}"]],
  [17, ["evening, {her}", "hey {her}", "evening, you"]],
  [21, ["still up, {her}", "late, {her}", "a sleepless malice, as ever"]],
];

const NUMBERS = ["zero", "one", "two", "three", "four", "five", "six",
  "seven", "eight", "nine", "ten", "eleven", "twelve"];

function spell(n) {
  return Math.abs(n) <= 12 ? NUMBERS[Math.abs(n)] : String(Math.abs(n));
}

function greetingsFor(hour) {
  let out = GREETINGS[0][1];
  for (const [from, lines] of GREETINGS) if (hour >= from) out = lines;
  return out;
}

const ROMAN = [
  [1000, "m"], [900, "cm"], [500, "d"], [400, "cd"], [100, "c"], [90, "xc"],
  [50, "l"], [40, "xl"], [10, "x"], [9, "ix"], [5, "v"], [4, "iv"], [1, "i"],
];

function roman(n) {
  let out = "";
  for (const [v, s] of ROMAN) while (n >= v) { out += s; n -= v; }
  return out;
}

const THEMES = [
  ["sky", "follow the sky"],
  ["void", "void"],
  ["oval", "the oval"],
  ["sanguine", "sanguine"],
  ["ash", "ash"],
  ["vellum", "vellum"],
];

const SKY_THEME = { dawn: "dawn", day: "vellum", dusk: "dusk", night: "void" };

function themePref() {
  try {
    const saved = localStorage.getItem("theme");
    if (saved && THEMES.some(([id]) => id === saved)) return saved;
  } catch (e) {}
  return "sky";
}

function applyTheme(herHour) {
  const pref = themePref();
  const resolved = pref === "sky" ? SKY_THEME[skyFor(herHour)] : pref;
  document.documentElement.dataset.theme = resolved;
}

function renderThemeList() {
  const box = $("themesList");
  const pref = themePref();
  box.textContent = "";
  THEMES.forEach(([id, label]) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    if (id === pref) b.setAttribute("aria-current", "true");
    b.onclick = () => {
      try { localStorage.setItem("theme", id); } catch (e) {}
      closeThemes();
      renderClocks();
      renderThemeList();
    };
    box.appendChild(b);
  });
}

function closeThemes() {
  $("themesList").hidden = true;
  $("themes").dataset.open = "false";
  $("themesOpen").setAttribute("aria-expanded", "false");
}

$("themesOpen").addEventListener("click", (e) => {
  e.stopPropagation();
  const open = $("themesList").hidden;
  $("themesList").hidden = !open;
  $("themes").dataset.open = String(open);
  $("themesOpen").setAttribute("aria-expanded", String(open));
  if (open) renderThemeList();
});
document.addEventListener("click", closeThemes);
document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeThemes(); });
$("themesList").addEventListener("click", (e) => e.stopPropagation());

function zoneOffset(zone, date) {
  const f = new Intl.DateTimeFormat("en-US", {
    timeZone: zone, hour12: false, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  });
  const p = Object.fromEntries(f.formatToParts(date).map((x) => [x.type, x.value]));
  const asUTC = Date.UTC(p.year, p.month - 1, p.day, p.hour % 24, p.minute, p.second);
  return (asUTC - Math.floor(date.getTime() / 1000) * 1000) / 60000;
}

function skyFor(hour) {
  if (hour >= 5 && hour < 9) return "dawn";
  if (hour >= 9 && hour < 17) return "day";
  if (hour >= 17 && hour < 21) return "dusk";
  return "night";
}

function partsIn(zone) {
  const f = new Intl.DateTimeFormat("en-GB", {
    timeZone: zone, hour: "2-digit", minute: "2-digit", hour12: false,
    year: "numeric", month: "2-digit", day: "2-digit",
  });
  const p = Object.fromEntries(f.formatToParts(new Date()).map((x) => [x.type, x.value]));
  return { time: `${p.hour}:${p.minute}`, hour: Number(p.hour), day: `${p.year}-${p.month}-${p.day}` };
}

function stateFor(hour) {
  if (hour >= 1 && hour < 7) return "asleep";
  if (hour >= 7 && hour < 10) return "just up";
  if (hour >= 23 || hour < 1) return "up late";
  return "up";
}

function pickDaily(list, seed) {
  let h = 0;
  for (const ch of String(seed)) h = (h * 31 + ch.charCodeAt(0)) % 100000;
  return list[h % list.length];
}

function nextWindow(mine, gap) {
  const pad = (n) => String(((n % 24) + 24) % 24).padStart(2, "0");
  const asleep = mine.hour >= 23 || mine.hour < 7;
  const boundary = asleep ? 8 : 23;
  return `${asleep ? "wakes" : "turns in"} around ${pad(boundary - gap)}:00 your time`;
}

function renderClocks() {
  if (!data) return;
  const now = new Date();
  const her = partsIn(data.her_timezone);
  const mine = partsIn(data.my_timezone);
  const gap = Math.round(
    (zoneOffset(data.my_timezone, now) - zoneOffset(data.her_timezone, now)) / 60
  );
  applyTheme(her.hour);
  $("herTime").textContent = her.time;
  $("myTime").textContent = mine.time;
  $("myWho").textContent = data.my_name;

  const greeting = pickDaily(greetingsFor(her.hour), her.day + her.hour)
    .replace("{her}", data.her_name);
  const where = mine.day > her.day
    ? `it is already tomorrow for ${data.my_name}`
    : mine.day < her.day
    ? `${data.my_name} is still on yesterday`
    : `${data.my_name} is ${spell(gap)} hours ahead`;
  $("heroLine").textContent = `${greeting}. ${where}.`;
  $("heroSub").textContent = `he is ${stateFor(mine.hour)}, and ${nextWindow(mine, gap)}.`;
}

function renderMoon() {
  const m = data.moon;
  $("moon").textContent = m.glyph;
  const lit = m.illumination === 0 || m.illumination === 100 ? "" : ` ${m.illumination}%`;
  $("moonName").textContent = `${m.name}${lit}, day ${m.age}`;
  $("railMansion").textContent = `mansion ${roman(m.mansion)} · ${m.mansion_name}`;
  $("railDay").innerHTML = "";
  $("railDay").append(
    Object.assign(document.createElement("b"), { textContent: data.day_glyph }),
    `${data.day_ruler}'s day`
  );
  const full = m.until_full, dark = m.until_new;
  $("railNext").textContent =
    full === 0 ? "full tonight"
    : dark === 0 ? "no moon tonight"
    : full <= dark ? `full in ${full} ${full === 1 ? "day" : "days"}`
    : `dark in ${dark} ${dark === 1 ? "day" : "days"}`;
}

function renderVerse() {
  const v = data.verse;
  $("verse").hidden = !v.today;
  if (!v.today) return;
  $("versePast").innerHTML = "";
  v.revealed.slice(-4).forEach((line) => {
    const p = document.createElement("p");
    p.textContent = line;
    $("versePast").appendChild(p);
  });
  $("verseToday").textContent = v.today || "";
  if (v.today) {
    $("verseMeta").textContent = v.done
      ? `leaf ${roman(v.day)} — the last one`
      : `leaf ${roman(v.day)}`;
  }
}

function renderLinks() {
  const box = $("links");
  box.textContent = "";
  (data.links || []).forEach((l) => {
    if (!l || !l.url) return;
    const a = document.createElement("a");
    a.href = l.url;
    a.textContent = l.name || l.url;
    a.rel = "noreferrer";
    box.appendChild(a);
  });
}

function renderNote() {
  $("note").dataset.fallback = String(data.note.is_fallback);
  $("noteBody").textContent = data.note.body;
}

function renderRecord() {
  const r = data.record;
  if (!r) return;
  $("record").hidden = false;
  $("recordAlbum").textContent = r.album;
  $("recordArtist").textContent = r.artist;
  if (r.from_me) {
    $("recordMine").hidden = false;
    $("recordMine").textContent = r.from_me;
  }
}

function fmtDay(iso) {
  return new Date(iso + "T12:00:00").toLocaleDateString(undefined, {
    weekday: "long", day: "numeric", month: "long",
  });
}

async function renderArchive() {
  const body = $("archiveBody");
  body.textContent = "";
  const res = await fetch("/api/archive").then((r) => r.json());
  if (!res.notes.length) {
    const p = document.createElement("p");
    p.className = "archive-text";
    p.textContent = "Nothing behind you yet. There will be.";
    body.appendChild(p);
  }
  res.notes.forEach((n) => {
    const wrap = document.createElement("div");
    wrap.className = "archive-entry";
    const d = document.createElement("p");
    d.className = "archive-date";
    d.textContent = fmtDay(n.day);
    const t = document.createElement("p");
    t.className = "archive-text";
    t.textContent = n.body;
    wrap.append(d, t);
    body.appendChild(wrap);
  });
  const leaves = res.verse.revealed.concat(res.verse.today ? [res.verse.today] : []);
  if (leaves.length) {
    const v = document.createElement("div");
    v.className = "archive-leaves";
    leaves.forEach((line) => {
      const p = document.createElement("p");
      p.textContent = line;
      v.appendChild(p);
    });
    body.appendChild(v);
  }
}

function renderPoem() {
  const p = data.poem;
  if (!p) return;
  $("poem").hidden = false;
  $("poemText").textContent = p.text;
  $("poemMeta").textContent = `${roman(p.number)} of ${p.total}`;
}

$("poemToggle").addEventListener("click", async () => {
  const box = $("poemAll");
  const open = box.hidden;
  box.hidden = !open;
  $("poemToggle").setAttribute("aria-expanded", String(open));
  $("poemToggle").textContent = open ? "close the book" : "the whole book";
  if (open && !box.dataset.loaded) {
    box.dataset.loaded = "1";
    const res = await fetch("/api/poems").then((r) => r.json());
    res.poems.forEach((text, i) => {
      const el = document.createElement("p");
      el.dataset.n = roman(i + 1);
      el.textContent = text;
      box.appendChild(el);
    });
  }
});

$("archiveToggle").addEventListener("click", async () => {
  const body = $("archiveBody");
  const open = body.hidden;
  body.hidden = !open;
  $("archiveToggle").setAttribute("aria-expanded", String(open));
  if (open && !body.dataset.loaded) {
    body.dataset.loaded = "1";
    await renderArchive();
  }
});

const BANGS = {
  y: ["https://www.youtube.com/results?search_query=%s", "youtube"],
  w: ["https://en.wikipedia.org/w/index.php?search=%s", "wikipedia"],
  d: ["https://www.discogs.com/search/?q=%s", "discogs"],
  a: ["https://www.metal-archives.com/search?searchString=%s&type=band_name", "metal archives"],
  f: ["https://letterboxd.com/search/%s/", "letterboxd"],
  l: ["https://www.last.fm/search?q=%s", "last.fm"],
  p: ["https://www.fragrantica.com/search/?query=%s", "fragrantica"],
  m: ["https://www.openstreetmap.org/search?query=%s", "map"],
};

function resolveQuery(raw) {
  const q = raw.trim();
  if (/^https?:\/\/\S+$/.test(q)) return q;
  const bang = q.match(/^!([a-z])\s+(.+)$/i);
  if (bang && BANGS[bang[1].toLowerCase()]) {
    return BANGS[bang[1].toLowerCase()][0].replace("%s", encodeURIComponent(bang[2]));
  }
  const tpl = (data && data.search_url) || "https://duckduckgo.com/?q=%s";
  return tpl.replace("%s", encodeURIComponent(q));
}

$("seekInput").addEventListener("input", () => {
  const bang = $("seekInput").value.match(/^!([a-z])(\s|$)/i);
  const hit = bang && BANGS[bang[1].toLowerCase()];
  $("seekHint").textContent = hit ? hit[1] : "!y !w !d !a !f !l !p";
});

$("seek").addEventListener("submit", (e) => {
  e.preventDefault();
  const q = $("seekInput").value.trim();
  if (!q) return;
  location.href = resolveQuery(q);
});

let wallCurrent = "";
let wallSlot = 0;

function unitPref() {
  try {
    const saved = localStorage.getItem("unit");
    if (saved === "c" || saved === "f") return saved;
  } catch (e) {}
  return (data && data.weather_unit) === "f" ? "f" : "c";
}

function renderUnitSwitch() {
  const el = $("unit");
  el.innerHTML = "";
  const now = unitPref();
  ["c", "f"].forEach((u, i) => {
    if (i) {
      const dot = document.createElement("span");
      dot.className = "unit-dot";
      dot.textContent = "·";
      el.appendChild(dot);
    }
    const span = document.createElement("span");
    span.textContent = u.toUpperCase();
    if (u === now) span.className = "on";
    el.appendChild(span);
  });
}

function showTemp(c) {
  if (c === null || c === undefined) return "";
  return unitPref() === "f" ? `${Math.round(c * 9 / 5 + 32)}°` : `${Math.round(c)}°`;
}

let lastLive = null;

$("unit").addEventListener("click", () => {
  const next = unitPref() === "c" ? "f" : "c";
  try { localStorage.setItem("unit", next); } catch (e) {}
  if (lastLive) renderLive(lastLive);
});

function renderLive(live) {
  lastLive = live;
  const w = live.weather;
  if (w && w.temp !== null && w.temp !== undefined) {
    $("weather").hidden = false;
    $("weatherPlace").textContent = w.place || "outside";
    $("temp").textContent = showTemp(w.temp);
    renderUnitSwitch();
    $("weatherWords").textContent = w.words || "";
    $("daylight").textContent = w.daylight
      ? `${w.daylight} of light` + (w.daylight_change ? `, ${w.daylight_change}` : "")
      : "";
    $("sun").textContent = w.sunrise && w.sunset ? `${w.sunrise} — ${w.sunset}` : "";
  }

  const t = live.weather_mine;
  if (t && t.temp !== null && t.temp !== undefined) {
    $("weatherThere").hidden = false;
    $("therePlace").textContent = t.place || "there";
    $("thereTemp").textContent = showTemp(t.temp) + unitPref().toUpperCase();
    $("thereWords").textContent = t.words || "";
  }

  const a = live.aurora;
  if (a && a.worth_saying) {
    $("aurora").hidden = false;
    $("aurora").innerHTML = "";
    const head = document.createElement("b");
    head.textContent = `aurora · Kp ${a.kp}`;
    const tail = document.createElement("span");
    tail.textContent = a.words + (a.peak && a.peak_at ? `, peaking ${a.peak} around ${a.peak_at}` : "");
    $("aurora").append(head, tail);
  } else {
    $("aurora").hidden = true;
  }

  const mine = live.playing_mine;
  if (mine && mine.track) {
    $("playingThere").hidden = false;
    $("playingThere").dataset.live = String(!!mine.now);
    $("thereWho").textContent = mine.now ? `${data.my_name} is playing` : `${data.my_name} played`;
    $("thereTrack").textContent = [mine.track, mine.artist].filter(Boolean).join(" — ");
  }

  const both = live.overlap;
  if (both && both.length) {
    $("playingBoth").hidden = false;
    $("playingBoth").innerHTML = "";
    $("playingBoth").append("both of you this week · ");
    both.forEach((name, i) => {
      if (i) $("playingBoth").append(" · ");
      const b = document.createElement("b");
      b.textContent = name;
      $("playingBoth").append(b);
    });
  } else {
    $("playingBoth").hidden = true;
  }

  const k = live.sky;
  if (k) {
    $("sky").hidden = false;
    if (k.hour) {
      $("hourGlyph").textContent = k.hour.glyph;
      $("hourRuler").textContent = k.hour.ruler;
      $("hourWhen").textContent =
        `${k.hour.night ? "night" : "day"} hour ${k.hour.index} of 12, until ${k.hour.ends}`;
    }
    $("skySigns").textContent =
      `☉ ${k.sun.sign} ${k.sun.degree}°   ☾ ${k.moon.sign} ${k.moon.degree}°`;
    $("retro").hidden = !k.mercury_retrograde;
  }

  const p = live.playing;
  if (p && p.track) {
    $("playing").hidden = false;
    $("playing").dataset.live = String(!!p.now);
    $("playingCap").textContent = p.now ? "playing now" : "last played";
    $("playingTrack").textContent = p.track;
    $("playingArtist").textContent = [p.artist, p.album].filter(Boolean).join(" — ");
    if (p.art) {
      $("playingArt").hidden = false;
      $("playingArt").src = p.art;
      setWallpaper(p.art);
    }
  }
}

function setWallpaper(url) {
  if (url === wallCurrent) return;
  const next = new Image();
  next.onload = () => {
    const showing = wallSlot ? $("wallB") : $("wallA");
    const hiding = wallSlot ? $("wallA") : $("wallB");
    showing.style.backgroundImage = `url("${url}")`;
    showing.dataset.on = "true";
    hiding.dataset.on = "false";
    wallSlot = wallSlot ? 0 : 1;
    wallCurrent = url;
  };
  next.src = url;
}

const MINUTE = 60000;

function ago(iso) {
  if (!iso) return "";
  const then = new Date(iso.endsWith("Z") || iso.includes("+") ? iso : iso + "Z");
  const mins = Math.round((Date.now() - then.getTime()) / MINUTE);
  if (mins < 2) return "just now";
  if (mins < 60) return `${mins} minutes ago`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `${hours} ${hours === 1 ? "hour" : "hours"} ago`;
  const days = Math.round(hours / 24);
  if (days === 1) return "yesterday";
  if (days < 7) return `${days} days ago`;
  return then.toLocaleDateString(undefined, { day: "numeric", month: "long" });
}

let showAllSaid = false;
let saidCount = 0;

const ICON_PLAIN = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 180">' +
  '<rect width="180" height="180" rx="40" fill="#241f36"/>' +
  '<circle cx="90" cy="86" r="46" fill="none" stroke="#ff9dae" stroke-width="7"/>' +
  '<circle cx="112" cy="70" r="40" fill="#241f36"/>' +
  '<circle cx="90" cy="140" r="6" fill="#ffc46b"/></svg>';
const ICON_WAITING = ICON_PLAIN.replace("</svg>",
  '<circle cx="142" cy="38" r="30" fill="#b8323f"/></svg>');

function seenUpTo() {
  try { return Number(localStorage.getItem("lastSeenMsg") || 0); } catch (e) { return 0; }
}

function markThreadSeen() {
  const top = Math.max(0, ...(lastThread || []).map((m) => m.id || 0));
  try { localStorage.setItem("lastSeenMsg", String(top)); } catch (e) {}
  showWaiting(0);
}

function showWaiting(n) {
  document.title = n ? `(${n}) ·` : "·";
  const icon = $("favicon");
  if (icon) {
    icon.href = "data:image/svg+xml," + encodeURIComponent(n ? ICON_WAITING : ICON_PLAIN);
  }
}

let lastThread = [];

function renderThread(payload) {
  const box = $("sayThread");
  const all = payload.messages || [];
  lastThread = all;
  saidCount = all.length;
  const floor = seenUpTo();
  showWaiting(all.filter((m) => m.who === "him" && (m.id || 0) > floor).length);
  const shown = showAllSaid ? all : all.slice(-6);
  box.textContent = "";
  shown.forEach((m) => {
    const line = document.createElement("div");
    line.className = "say-line";
    line.dataset.who = m.who;
    const when = document.createElement("p");
    when.className = "say-when";
    when.textContent =
      (m.who === "her" ? "you" : data.my_name) +
      " · " + ago(m.at) +
      (m.who === "her" && !m.read_at ? " · unread" : "");
    const body = document.createElement("p");
    body.className = "say-body";
    body.textContent = m.body;
    line.append(when, body);
    box.appendChild(line);
  });
  $("sayMore").hidden = all.length <= 6;
  $("sayMore").textContent = showAllSaid ? "just the recent ones" : `everything we've said (${all.length})`;

  const him = (payload.seen || {}).him;
  $("saySeen").textContent = him ? `${data.my_name} was here ${ago(him)}` : "";
}

$("say").addEventListener("click", markThreadSeen);
$("say").addEventListener("focusin", markThreadSeen);

$("sayMore").addEventListener("click", async () => {
  showAllSaid = !showAllSaid;
  renderThread(await fetch("/api/thread").then((r) => r.json()));
});

const sayInput = $("sayInput");

function growInput() {
  sayInput.style.height = "auto";
  sayInput.style.height = Math.min(sayInput.scrollHeight, 320) + "px";
}

sayInput.addEventListener("input", growInput);
sayInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
    e.preventDefault();
    $("sayForm").requestSubmit();
  }
});

$("sayForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const body = sayInput.value.trim();
  if (!body) return;
  $("saySend").disabled = true;
  $("sayStatus").textContent = "";
  try {
    const res = await fetch("/api/message", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ body }),
    }).then((r) => r.json());
    if (res.ok) {
      sayInput.value = "";
      growInput();
      $("sayStatus").textContent = "sent";
      setTimeout(() => { $("sayStatus").textContent = ""; }, 4000);
      renderThread(res);
    } else {
      $("sayStatus").textContent = res.error || "that didn't send";
    }
  } catch (err) {
    $("sayStatus").textContent = "no signal — it wasn't sent, try again in a minute";
  }
  $("saySend").disabled = false;
});

async function pollThread() {
  try {
    renderThread(await fetch("/api/thread").then((r) => r.json()));
  } catch (e) {
    /* leave what is on screen */
  }
}

async function pollLive() {
  try {
    renderLive(await fetch("/api/live").then((r) => r.json()));
  } catch (e) {
    /* the page is still the page without them */
  }
}

$("candle").addEventListener("click", async () => {
  const btn = $("candle");
  if (btn.dataset.lit === "true") return;
  btn.dataset.lit = "true";
  $("candleLabel").textContent = "lit";
  try {
    await fetch("/api/heart", { method: "POST", headers: { "Content-Type": "application/json" } });
  } catch (e) {
    $("candleLabel").textContent = "lit — it'll reach him when the signal does";
  }
});

async function boot() {
  try {
    data = await fetch("/api/today").then((r) => r.json());
  } catch (e) {
    $("loading").textContent = "This page can't reach home right now. Try again in a minute.";
    return;
  }
  $("loading").hidden = true;
  $("page").hidden = false;
  renderMoon();
  renderClocks();
  renderVerse();
  renderNote();
  renderRecord();
  renderPoem();
  renderLinks();
  if (data.game_unlocked) $("door").hidden = false;
  if (data.birthday) $("door").textContent = `happy birthday, ${data.her_name}`;
  pollLive();
  pollThread();
  setInterval(pollLive, 45000);
  setInterval(pollThread, 60000);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) { pollLive(); pollThread(); }
  });
  document.querySelectorAll(".rail, .seek, .hero, .note, .panes, .links").forEach((el, i) => {
    el.classList.add("rise");
    el.style.animationDelay = `${0.1 * i}s`;
  });
  setInterval(renderClocks, 20000);
}

boot();
