// ── everything you'd want to change lives here ───────────────────
const NAME = { her: "wawita", him: "bober", pet: "wiwi" };

const CRATE = [
  ["Trance to the Sun", "Spiders, Aether & Rain"],
  ["Trance to the Sun", "Urchin Tear Soda"],
  ["Melancholia", "Book of Ruination"],
  ["Blut aus Nord", "Triunity"],
  ["Blut aus Nord", "Memoria Vetusta II"],
  ["Deathspell Omega", "Si Monumentum Requires, Circumspice"],
  ["Deathspell Omega", "Fas – Ite, Maledicti, in Ignem Aeternum"],
  ["P.H.O.B.O.S.", "Triunity"],
  ["London After Midnight", "Selected Scenes From The End Of The World"],
  ["Glass Beams", "Mahal"],
  ["Trance to the Sun", "Bloom Flowers, Bloom!"],
  ["Melancholia", "Sunscathed"],
];

const PERFUME = {
  brief: "Cold green stem. Then smoke. Then something with a pulse underneath.",
  layers: [
    { label: "opening", options: ["galbanum", "bergamot", "tuberose", "cardamom"], answer: "galbanum" },
    { label: "heart", options: ["iris", "birch tar", "rose", "saffron"], answer: "birch tar" },
    { label: "drydown", options: ["vanilla", "amber", "castoreum", "oakmoss"], answer: "castoreum" },
  ],
};

const RIDDLE = {
  ask: "I am named in the song you have played more than any other. I build a house out of my own body and then I sit in it and wait. What am I?",
  answers: ["spider", "a spider", "the spider"],
  hint: "Spiders, aether and rain.",
};

const RECORD = { side: "333", cat: "MMXXII / 16 XI" };

const AUDIO = {
  src: "/audio/angel.wav",
  loopStart: 0,
  loopEnd: 0,
  volume: 0.75,
};

const LETTER = `Happy birthday, ${NAME.her}.

Replace all of this before she sees it. Write it badly first, then once more.

Say the specific things. Not "I miss you" — the particular hour you miss,
the thing she said about a record that you still think about, what you are
going to do in the first ten minutes after the plane lands.

The rite is a joke. This part isn't.

— ${NAME.him}`;
// ─────────────────────────────────────────────────────────────────

const FRAGMENTS = {
  crate: { mark: 3, name: "Sulphur" },
  cabinet: { mark: 3, name: "Mercury" },
  circle: { mark: 3, name: "Salt" },
};
const ORDER = ["crate", "cabinet", "circle"];

const $ = (id) => document.getElementById(id);
const say = $("say"), act = $("act"), mount = $("mount"), sigils = $("sigils");
const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
const KEY = "triunity-v1";

let state = load();

function load() {
  try {
    return Object.assign({ found: [], step: "intro" }, JSON.parse(localStorage.getItem(KEY) || "{}"));
  } catch (e) {
    return { found: [], step: "intro" };
  }
}
function save() {
  try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {}
}
function found(place) {
  if (!state.found.includes(place)) state.found.push(place);
  save();
}

function renderSigils() {
  sigils.innerHTML = "";
  if (!state.found.length) return;
  const label = document.createElement("span");
  label.textContent = `${state.found.length} of three recovered`;
  const digits = document.createElement("b");
  digits.textContent = ORDER.map((k) => (state.found.includes(k) ? FRAGMENTS[k].mark : "·")).join("");
  sigils.append(label, digits);
}

let typing = null;
let skipper = null;

function unskip() {
  if (skipper) document.removeEventListener("click", skipper);
  skipper = null;
}

function tell(text, then) {
  clearInterval(typing);
  unskip();
  say.textContent = "";
  act.innerHTML = "";
  mount.innerHTML = "";
  if (reduce) { say.textContent = text; return then && then(); }
  let i = 0, done = false;
  const finish = () => {
    if (done) return;
    done = true;
    clearInterval(typing);
    unskip();
    say.textContent = text;
    then && then();
  };
  typing = setInterval(() => {
    say.textContent = text.slice(0, ++i);
    if (i >= text.length) finish();
  }, text.length > 200 ? 10 : 15);
  skipper = finish;
  setTimeout(() => { if (!done && skipper) document.addEventListener("click", skipper, { once: true }); }, 300);
}

function choices(...opts) {
  act.innerHTML = "";
  opts.forEach(([label, fn, quiet]) => {
    const b = document.createElement("button");
    b.textContent = label;
    if (quiet) b.className = "quiet";
    b.onclick = fn;
    act.appendChild(b);
  });
}

function go(step) {
  state.step = step;
  save();
  renderSigils();
  SCENES[step]();
}

function claim(place, text) {
  found(place);
  tell(text, () => choices(["take it", () => go("map")]));
}

const SCENES = {
  intro() {
    tell(
      `${NAME.him} tried to summon you a birthday present.\n\nIt is not clear where he got the instructions. It is very clear he did not read all of them.`,
      () => choices(["go on", () => go("intro2")])
    );
  },

  intro2() {
    tell(
      `The rite came apart into three and went to ground in three rooms.\n\nSulphur, mercury, salt. Three marks, and all three are the same mark. You already know which number he would pick.`,
      () => choices(["begin", () => go("map")])
    );
  },

  map() {
    const has = (k) => state.found.includes(k);
    const left = 3 - state.found.length;
    tell(
      left === 0
        ? "Three marks. The seal is downstairs and it has been waiting all night."
        : left === 3
        ? "Three rooms. Any order."
        : `${left} left. ${NAME.pet} is already in the next room, being unhelpful.`,
      () => {
        const opts = [];
        if (!has("crate")) opts.push(["the record shop", () => go("crate")]);
        if (!has("cabinet")) opts.push(["the perfumer's cabinet", () => go("cabinet")]);
        if (!has("circle")) opts.push(["the table upstairs", () => go("circle")]);
        if (!opts.length) opts.push(["go down to the seal", () => go("seal")]);
        else if (state.found.length) opts.push(["try the seal anyway", () => go("seal"), true]);
        choices(...opts);
      }
    );
  },

  crate() {
    tell(
      `The shop closed hours ago and the door was open anyway.\n\nTwelve sleeves in the front crate. One of them is a pressing that no label ever made. Flip them. The room will tell you when you are close.`,
      () => {
        const grid = document.createElement("div");
        grid.className = "crate";
        const target = Math.floor(Math.random() * 12);
        let flips = 0;
        CRATE.forEach(([artist, album], i) => {
          const b = document.createElement("button");
          b.className = "sleeve";
          b.setAttribute("aria-label", `sleeve ${i + 1}`);
          b.onclick = () => {
            if (b.dataset.flipped === "true") return;
            flips++;
            if (i === target) {
              b.dataset.found = "true";
              b.textContent = `— / ${RECORD.side}`;
              claim(
                "crate",
                `No artist. No title. A three scratched into the runout groove.\n\n${flips === 1 ? "First sleeve. That is either luck or something worse." : `Took you ${flips} sleeves.`}\n\nSulphur.`
              );
              return;
            }
            b.dataset.flipped = "true";
            const d = Math.abs((i % 3) - (target % 3)) + Math.abs(Math.floor(i / 3) - Math.floor(target / 3));
            b.dataset.heat = d <= 1 ? "hot" : "";
            b.textContent = `${artist} — ${album}`;
          };
          grid.appendChild(b);
        });
        mount.appendChild(grid);
      }
    );
  },

  cabinet() {
    tell(
      `The cabinet is open and something has already been half-composed on the bench.\n\nA card in his handwriting: "${PERFUME.brief}"\n\nBuild it. One from each row.`,
      () => {
        const wrap = document.createElement("div");
        wrap.className = "layers";
        const picked = {};
        PERFUME.layers.forEach((layer, li) => {
          const row = document.createElement("div");
          row.className = "layer";
          const label = document.createElement("span");
          label.textContent = layer.label;
          const opts = document.createElement("div");
          layer.options.forEach((name) => {
            const b = document.createElement("button");
            b.className = "note";
            b.textContent = name;
            b.onclick = () => {
              picked[li] = name;
              opts.querySelectorAll(".note").forEach((n) => (n.dataset.picked = "false"));
              b.dataset.picked = "true";
            };
            opts.appendChild(b);
          });
          row.append(label, opts);
          wrap.appendChild(row);
        });
        mount.appendChild(wrap);

        const wear = () => {
          if (Object.keys(picked).length < 3) {
            say.textContent = "Three rows. It needs all three.";
            return;
          }
          const right = PERFUME.layers.filter((l, i) => picked[i] === l.answer).length;
          if (right === 3) {
            claim(
              "cabinet",
              `It opens cold, turns, and then does the thing that makes you close your eyes.\n\nPressed into the wax under the bottle: a three.\n\nMercury.`
            );
          } else {
            say.textContent = `${right} of three layers are right. It smells like a mistake with promise.`;
          }
        };
        choices(["wear it", wear], ["leave it", () => go("map"), true]);
      }
    );
  },

  circle() {
    tell(
      `${NAME.pet} is sitting in the middle of the table where the planchette should be.\n\nFour marks around the edge. Something taps them in order. Tap them back. Four times, and it gets longer each time.`,
      () => {
        const circle = document.createElement("div");
        circle.className = "circle";
        const marks = ["🜁", "🜂", "🜃", "🜄"];
        const buttons = marks.map((m) => {
          const b = document.createElement("button");
          b.className = "glyph";
          b.textContent = m;
          circle.appendChild(b);
          return b;
        });
        mount.appendChild(circle);

        let seq = [], input = [], round = 0;
        const flash = (i, ms = 360) =>
          new Promise((res) => {
            buttons[i].dataset.lit = "true";
            setTimeout(() => { buttons[i].dataset.lit = "false"; setTimeout(res, 130); }, ms);
          });

        async function play() {
          buttons.forEach((b) => (b.disabled = true));
          say.textContent = `${round} of four — watch`;
          await new Promise((r) => setTimeout(r, 550));
          for (const i of seq) await flash(i);
          say.textContent = "now you";
          buttons.forEach((b) => (b.disabled = false));
        }

        function next() {
          round++;
          input = [];
          seq.push(Math.floor(Math.random() * 4));
          if (round > 4) {
            claim(
              "circle",
              `The table stops. ${NAME.pet} looks insufferable about it.\n\nThree taps, then nothing.\n\nSalt.`
            );
            return;
          }
          play();
        }

        buttons.forEach((b, i) => {
          b.onclick = async () => {
            await flash(i, 170);
            input.push(i);
            if (input[input.length - 1] !== seq[input.length - 1]) {
              say.textContent = "wrong mark. that round again";
              input = [];
              setTimeout(play, 700);
              return;
            }
            if (input.length === seq.length) next();
          };
        });
        next();
      }
    );
  },

  seal() {
    const full = ORDER.every((k) => state.found.includes(k));
    tell(
      full
        ? "Three marks, in the order you found them or any other. It only ever wanted the one number."
        : `The seal wants three and you are holding ${state.found.length}. It is not the negotiating kind.`,
      () => {
        if (!full) return choices(["keep looking", () => go("map")]);
        const input = document.createElement("input");
        input.type = "tel";
        input.className = "seal";
        input.maxLength = 3;
        input.placeholder = "···";
        mount.appendChild(input);
        const open = () => {
          if (input.value.trim() === ORDER.map((k) => FRAGMENTS[k].mark).join("")) go("question");
          else say.textContent = "Nothing moves. Somewhere a beaver is embarrassed.";
        };
        input.onkeydown = (e) => { if (e.key === "Enter") open(); };
        choices(["open it", open]);
        input.focus();
      }
    );
  },

  question() {
    tell(
      `Under the seal: one record, no sleeve, and a question scratched into the dead wax.\n\n"${RIDDLE.ask}"`,
      () => {
        const input = document.createElement("input");
        input.type = "text";
        input.autocapitalize = "none";
        input.placeholder = "answer";
        mount.appendChild(input);
        const check = () => {
          const v = input.value.toLowerCase().replace(/[^a-z ]/g, "").trim();
          if (RIDDLE.answers.includes(v)) go("play");
          else say.textContent = "The wax disagrees.";
        };
        input.onkeydown = (e) => { if (e.key === "Enter") check(); };
        choices(["say it", check], ["hint", () => { say.textContent = RIDDLE.hint; }, true]);
        input.focus();
      }
    );
  },

  play() {
    tell("It was always going to be the spider.\n\nThe record is warm. Put it on.", () => {
      mount.appendChild(turntable(false));
      choices(["drop the needle", () => {
        needle.start();
        mount.querySelector(".platter").dataset.spinning = "true";
        say.textContent = "";
        act.innerHTML = "";
        setTimeout(() => go("end"), 1400);
      }]);
    });
  },

  end() {
    say.textContent = "";
    act.innerHTML = "";
    mount.innerHTML = "";
    const liner = document.createElement("div");
    liner.className = "liner";
    liner.textContent = LETTER;
    mount.append(turntable(true), liner);
    motes();
    setTimeout(() => {
      const opts = [["from the top", () => { needle.stop(); state = { found: [], step: "intro" }; save(); go("intro"); }, true]];
      if (needle.playing()) opts.unshift(["lift the needle", () => { needle.stop(); go("end"); }, true]);
      choices(...opts);
    }, 1400);
  },
};

function turntable(spinning) {
  const deck = document.createElement("div");
  deck.className = "deck";
  const platter = document.createElement("div");
  platter.className = "platter";
  if (spinning) platter.dataset.spinning = "true";
  const label = document.createElement("div");
  label.className = "label";
  label.textContent = `${RECORD.side} · ${RECORD.cat}`;
  platter.appendChild(label);
  deck.appendChild(platter);
  return deck;
}

const needle = (() => {
  let el = null;
  return {
    start() {
      if (el || !AUDIO.src) return;
      el = new Audio(AUDIO.src);
      el.volume = 0;
      el.preload = "auto";
      const trimmed = !AUDIO.loopEnd;
      const seek = () => {
        if (AUDIO.loopStart) el.currentTime = AUDIO.loopStart;
        el.play().then(fade).catch(() => { el = null; });
      };
      if (trimmed) {
        el.loop = true;
      } else {
        el.addEventListener("timeupdate", () => {
          if (el && el.currentTime >= AUDIO.loopEnd) el.currentTime = AUDIO.loopStart;
        });
      }
      el.addEventListener("error", () => { el = null; });
      if (el.readyState >= 1) seek();
      else el.addEventListener("loadedmetadata", seek, { once: true });
    },
    fadeOut() {
      if (!el) return;
      const node = el;
      el = null;
      const step = setInterval(() => {
        node.volume = Math.max(0, node.volume - 0.05);
        if (node.volume <= 0.001) { clearInterval(step); node.pause(); }
      }, 60);
    },
    stop() { this.fadeOut(); },
    playing() { return !!el; },
  };
  function fade() {
    if (!el) return;
    const node = el;
    const step = setInterval(() => {
      node.volume = Math.min(AUDIO.volume, node.volume + 0.03);
      if (node.volume >= AUDIO.volume - 0.001) clearInterval(step);
    }, 80);
  }
})();

function motes() {
  if (reduce) return;
  const colors = ["#c99a4a", "#8d8794", "#b8323f", "#e9e3d6"];
  for (let i = 0; i < 40; i++) {
    const m = document.createElement("div");
    m.className = "mote";
    m.style.left = Math.random() * 100 + "vw";
    m.style.background = colors[i % colors.length];
    m.style.opacity = 0.15 + Math.random() * 0.4;
    m.style.animation = `drift ${9 + Math.random() * 9}s linear ${Math.random() * 5}s forwards`;
    document.body.appendChild(m);
    setTimeout(() => m.remove(), 26000);
  }
}

go(state.step in SCENES ? state.step : "intro");
