/* Screens, input and the bridge to the iOS shell. Rules live in logic.js, rendering in surface.js. */
(function (root) {
  const { PDLogic: L, PDSurface, PDAudio, PDFlies } = root;
  const STORAGE_PROGRESS = 'pd.progress';
  const STORAGE_MUTED = 'pd.muted';
  const TITLE_LINES = ['РИСУЙ', 'НА ГОВНЕ'];
  const TRACE_RADIUS = 9;
  const SMOOTH_RADIUS = 30;
  const FLY_COUNT = 4;
  const HAPTIC_EVERY_PX = 38;
  const HUD_TOP_SPACE = 80;
  const HUD_BOTTOM_SPACE = 100;
  const RESIZE_REBUILD_PX = 120;
  const SQUELCH_HOLD_MS = 70;

  const $ = (id) => document.getElementById(id);
  const nativeBridge = root.webkit && root.webkit.messageHandlers && root.webkit.messageHandlers.native;

  function readStorage(key) {
    try {
      return root.localStorage.getItem(key);
    } catch (error) {
      return null;
    }
  }

  function writeStorage(key, value) {
    try {
      root.localStorage.setItem(key, value);
    } catch (error) {
      /* Private mode: progress simply lasts until the page closes. */
    }
  }

  const state = {
    mode: 'menu',
    radius: 12,
    smoothing: false,
    progress: L.parseProgress(readStorage(STORAGE_PROGRESS)),
    level: 0,
    targets: [],
    covered: [],
    strokes: [],
    activeStrokes: new Map(),
    pointers: new Map(),
    box: { x: 0, y: 0, side: 1 },
    hapticDistance: 0,
    lastMoveAt: 0,
    squelching: false,
  };

  const audio = PDAudio.createAudio(readStorage(STORAGE_MUTED) === '1');
  const surfaceCanvas = $('surface');
  const overlay = $('overlay');
  const overlayCtx = overlay.getContext('2d');
  let surface = null;
  let flies = null;

  const newSeed = () => Math.floor(Math.random() * 2 ** 31);

  function haptic() {
    if (nativeBridge) nativeBridge.postMessage({ type: 'haptic' });
  }

  /* ---------- layout ---------- */

  function buildBoard() {
    const width = root.innerWidth;
    const height = root.innerHeight;
    surface = PDSurface.createSurface(surfaceCanvas, width, height, newSeed());
    const dpr = root.devicePixelRatio || 1;
    overlay.width = Math.round(width * dpr);
    overlay.height = Math.round(height * dpr);
    overlay.style.width = `${width}px`;
    overlay.style.height = `${height}px`;
    overlayCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    flies = PDFlies.createFlies(FLY_COUNT, width, height);
    const usable = height - HUD_TOP_SPACE - HUD_BOTTOM_SPACE;
    const side = Math.min(width * 0.88, usable * 0.94);
    state.box = { x: (width - side) / 2, y: HUD_TOP_SPACE + (usable - side) / 2, side };
  }

  function refreshBoardForMode() {
    if (state.mode === 'menu' || state.mode === 'levels') {
      surface.carveText(TITLE_LINES, root.innerHeight * 0.3);
    }
  }

  function handleResize() {
    if (!surface) return;
    const widthChanged = root.innerWidth !== surface.cssWidth;
    const grewALot = root.innerHeight - surface.cssHeight > RESIZE_REBUILD_PX;
    const shrankALot = surface.cssHeight - root.innerHeight > RESIZE_REBUILD_PX;
    if (!widthChanged && !grewALot && !shrankALot) return;
    buildBoard();
    refreshBoardForMode();
    if (state.mode === 'trace') startLevel(state.level);
  }

  /* ---------- screens ---------- */

  function show(mode) {
    state.mode = mode;
    $('menu').hidden = mode !== 'menu';
    $('levels').hidden = mode !== 'levels';
    $('hud-top').hidden = mode !== 'free' && mode !== 'trace';
    $('hud-free').hidden = mode !== 'free';
    $('hud-trace').hidden = mode !== 'trace';
    $('trace-status').hidden = mode !== 'trace';
    $('result').hidden = mode !== 'result';
  }

  function goMenu() {
    surface.resetCarving();
    surface.carveText(TITLE_LINES, root.innerHeight * 0.3);
    state.targets = [];
    show('menu');
  }

  function goFree() {
    surface.resetCarving();
    state.targets = [];
    show('free');
  }

  function renderLevels() {
    const buttons = L.FIGURES.map((figure, index) => {
      const unlocked = L.isUnlocked(state.progress, index);
      const best = state.progress[figure.id] || 0;
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'lump level';
      button.disabled = !unlocked;
      const name = document.createElement('span');
      name.textContent = unlocked ? figure.name : 'Закрыто';
      const stars = document.createElement('small');
      stars.textContent = '★'.repeat(best) + '☆'.repeat(3 - best);
      button.append(name, stars);
      button.addEventListener('click', () => startLevel(index));
      return button;
    });
    $('level-grid').replaceChildren(...buttons);
  }

  function goLevels() {
    renderLevels();
    show('levels');
  }

  function startLevel(index) {
    state.level = index;
    state.targets = L.sampleFigure(L.FIGURES[index]);
    state.covered = state.targets.map(() => false);
    state.strokes = [];
    state.activeStrokes = new Map();
    surface.resetCarving();
    $('trace-name').textContent = L.FIGURES[index].name;
    updatePercent();
    show('trace');
  }

  function updatePercent() {
    const done = state.covered.filter(Boolean).length;
    const percent = state.targets.length ? Math.round((done / state.targets.length) * 100) : 0;
    $('trace-percent').textContent = `${percent}%`;
  }

  function finishLevel() {
    const figure = L.FIGURES[state.level];
    const strokes = [...state.strokes, ...state.activeStrokes.values()];
    const result = L.scoreTrace(state.targets, strokes, L.TRACE_TOLERANCE);
    state.progress = L.mergeBest(state.progress, figure.id, result.stars);
    writeStorage(STORAGE_PROGRESS, JSON.stringify(state.progress));

    const stars = Array.from({ length: 3 }, (_, i) => {
      const star = document.createElement('span');
      star.textContent = '★';
      star.className = i < result.stars ? '' : 'off';
      return star;
    });
    $('result-stars').replaceChildren(...stars);
    $('result-verdict').textContent = L.VERDICTS[result.stars];
    $('result-score').textContent =
      `${result.score} очков: обведено ${Math.round(result.coverage * 100)}%, точность ${Math.round(result.accuracy * 100)}%`;
    const nextIndex = state.level + 1;
    const next = $('btn-result-next');
    next.hidden = nextIndex >= L.FIGURES.length;
    next.disabled = !L.isUnlocked(state.progress, nextIndex);
    show('result');
    if (result.stars === 0) audio.fart();
    if (result.stars === 3) audio.fanfare();
    haptic();
  }

  function saveDrawing() {
    const picture = surface.toDataURL();
    if (nativeBridge) {
      nativeBridge.postMessage({ type: 'share', image: picture });
      return;
    }
    $('saved-image').src = picture;
    $('saved').hidden = false;
  }

  /* ---------- finger input ---------- */

  function toUnit(x, y) {
    const { box } = state;
    return { x: (x - box.x) / box.side, y: (y - box.y) / box.side };
  }

  function applyMove(from, to, pointerId) {
    if (state.mode === 'free' && state.smoothing) {
      const steps = Math.ceil(Math.hypot(to.x - from.x, to.y - from.y) / (SMOOTH_RADIUS / 3)) || 1;
      for (let k = 1; k <= steps; k += 1) {
        const t = k / steps;
        surface.smoothAt(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t, SMOOTH_RADIUS);
      }
    } else {
      const radius = state.mode === 'trace' ? TRACE_RADIUS : state.radius;
      surface.carveSegment(from.x, from.y, to.x, to.y, radius);
    }
    if (state.mode === 'trace') {
      const unit = toUnit(to.x, to.y);
      const stroke = state.activeStrokes.get(pointerId) || [];
      state.activeStrokes.set(pointerId, [...stroke, unit]);
      const prev = toUnit(from.x, from.y);
      const samples = L.densify([prev, unit], 0.02);
      state.covered = L.markCovered(state.targets, state.covered, samples, L.TRACE_TOLERANCE);
      updatePercent();
    }
    flies.scare(to.x, to.y);
  }

  function isDrawable() {
    return state.mode === 'free' || state.mode === 'trace';
  }

  function pointFrom(event) {
    const rect = surfaceCanvas.getBoundingClientRect();
    return { x: event.clientX - rect.left, y: event.clientY - rect.top };
  }

  function onPointerDown(event) {
    audio.unlock();
    if (!isDrawable()) return;
    event.preventDefault();
    surfaceCanvas.setPointerCapture(event.pointerId);
    const point = pointFrom(event);
    state.pointers.set(event.pointerId, { ...point, time: event.timeStamp });
    applyMove(point, point, event.pointerId);
    audio.plop();
    haptic();
  }

  function onPointerMove(event) {
    const last = state.pointers.get(event.pointerId);
    if (!last || !isDrawable()) return;
    event.preventDefault();
    const series = event.getCoalescedEvents ? event.getCoalescedEvents() : [];
    const tail = (series.length ? series : [event]).reduce((from, sample) => {
      const to = pointFrom(sample);
      applyMove(from, to, event.pointerId);
      return to;
    }, last);
    const moved = Math.hypot(tail.x - last.x, tail.y - last.y);
    const elapsed = Math.max(1, event.timeStamp - last.time);
    audio.squelch(moved / elapsed);
    state.lastMoveAt = event.timeStamp;
    state.squelching = true;
    state.hapticDistance += moved;
    if (state.hapticDistance >= HAPTIC_EVERY_PX) {
      state.hapticDistance = 0;
      haptic();
    }
    state.pointers.set(event.pointerId, { ...tail, time: event.timeStamp });
  }

  function onPointerEnd(event) {
    if (!state.pointers.has(event.pointerId)) return;
    state.pointers.delete(event.pointerId);
    const stroke = state.activeStrokes.get(event.pointerId);
    if (stroke) {
      state.strokes = [...state.strokes, stroke];
      state.activeStrokes.delete(event.pointerId);
    }
    if (state.pointers.size === 0) audio.squelch(0);
  }

  /* ---------- per-frame drawing ---------- */

  function drawGuide() {
    const { box, targets, covered } = state;
    targets.forEach((target, i) => {
      overlayCtx.fillStyle = covered[i] ? 'rgba(229,177,62,0.92)' : 'rgba(246,227,180,0.62)';
      overlayCtx.beginPath();
      overlayCtx.arc(box.x + target.x * box.side, box.y + target.y * box.side, covered[i] ? 2.6 : 2, 0, Math.PI * 2);
      overlayCtx.fill();
    });
  }

  const motionAllowed = !root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let lastFrame = 0;

  function frame(time) {
    const dt = Math.min(0.05, (time - lastFrame) / 1000);
    lastFrame = time;
    surface.flush();
    if (state.squelching && time - state.lastMoveAt > SQUELCH_HOLD_MS) {
      state.squelching = false;
      audio.squelch(0);
    }
    overlayCtx.clearRect(0, 0, surface.cssWidth, surface.cssHeight);
    if (state.mode === 'trace') drawGuide();
    if (motionAllowed) {
      flies.update(dt);
      flies.draw(overlayCtx, time);
    }
    root.requestAnimationFrame(frame);
  }

  /* ---------- wiring ---------- */

  function setRadius(radius) {
    state.radius = radius;
    state.smoothing = false;
    document.querySelectorAll('.size').forEach((button) => {
      button.classList.toggle('is-active', Number(button.dataset.size) === radius);
    });
    $('btn-smooth').setAttribute('aria-pressed', 'false');
  }

  function toggleSmoothing() {
    state.smoothing = !state.smoothing;
    $('btn-smooth').setAttribute('aria-pressed', String(state.smoothing));
    document.querySelectorAll('.size').forEach((button) => {
      button.classList.toggle('is-active', !state.smoothing && Number(button.dataset.size) === state.radius);
    });
  }

  function syncSoundButton() {
    const muted = audio.isMuted();
    $('btn-sound').textContent = muted ? 'Без звука' : 'Звук';
    $('btn-sound').setAttribute('aria-pressed', String(!muted));
  }

  function toggleSound() {
    audio.setMuted(!audio.isMuted());
    writeStorage(STORAGE_MUTED, audio.isMuted() ? '1' : '0');
    syncSoundButton();
  }

  const clicks = {
    'btn-free': goFree,
    'btn-levels': goLevels,
    'btn-levels-back': goMenu,
    'btn-back': goMenu,
    'btn-sound': toggleSound,
    'btn-smooth': toggleSmoothing,
    'btn-new': () => surface.regenerate(newSeed()),
    'btn-fart': () => { audio.fart(); haptic(); },
    'btn-save': saveDrawing,
    'btn-retry': () => startLevel(state.level),
    'btn-done': finishLevel,
    'btn-result-again': () => startLevel(state.level),
    'btn-result-next': () => startLevel(state.level + 1),
    'btn-result-save': saveDrawing,
    'btn-saved-close': () => { $('saved').hidden = true; },
  };

  function wire() {
    Object.entries(clicks).forEach(([id, handler]) => {
      $(id).addEventListener('click', () => {
        audio.unlock();
        handler();
      });
    });
    document.querySelectorAll('.size').forEach((button) => {
      button.addEventListener('click', () => setRadius(Number(button.dataset.size)));
    });
    surfaceCanvas.addEventListener('pointerdown', onPointerDown);
    surfaceCanvas.addEventListener('pointermove', onPointerMove);
    surfaceCanvas.addEventListener('pointerup', onPointerEnd);
    surfaceCanvas.addEventListener('pointercancel', onPointerEnd);
    root.addEventListener('resize', handleResize);
    document.addEventListener('gesturestart', (event) => event.preventDefault());
  }

  buildBoard();
  wire();
  setRadius(12);
  syncSoundButton();
  goMenu();
  root.requestAnimationFrame(frame);
})(globalThis);
