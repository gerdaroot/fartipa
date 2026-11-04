/* Pure game rules: figures, trace scoring, progress. No DOM, runs in Node tests too. */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.PDLogic = api;
})(globalThis, function () {
  const TRACE_TOLERANCE = 0.05;
  const SAMPLE_STEP = 0.02;
  const ACCURACY_SLACK = 1.5;
  const STAR_THRESHOLDS = [30, 55, 80];
  const VERDICTS = [
    'Обосрался',
    'Говновато, но с душой',
    'Крепкий стул',
    'Мастер кисти и кучи',
  ];

  const pt = (x, y) => ({ x, y });

  function ellipse(cx, cy, rx, ry, from = 0, to = Math.PI * 2, n = 48) {
    return Array.from({ length: n + 1 }, (_, i) => {
      const t = from + ((to - from) * i) / n;
      return pt(cx + rx * Math.cos(t), cy + ry * Math.sin(t));
    });
  }

  function heartPath() {
    return Array.from({ length: 73 }, (_, i) => {
      const t = (i / 72) * Math.PI * 2;
      const x = 16 * Math.sin(t) ** 3;
      const y = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t);
      return pt(0.5 + x / 38, 0.46 - y / 38);
    });
  }

  function starPath() {
    return Array.from({ length: 11 }, (_, i) => {
      const r = i % 2 === 0 ? 0.46 : 0.19;
      const t = -Math.PI / 2 + (i * Math.PI) / 5;
      return pt(0.5 + r * Math.cos(t), 0.53 + r * Math.sin(t));
    });
  }

  const FIGURES = [
    {
      id: 'smile',
      name: 'Улыбка',
      paths: [
        ellipse(0.5, 0.5, 0.44, 0.44),
        ellipse(0.5, 0.5, 0.27, 0.27, 0.2, Math.PI - 0.2, 24),
        ellipse(0.35, 0.37, 0.04, 0.04, 0, Math.PI * 2, 12),
        ellipse(0.65, 0.37, 0.04, 0.04, 0, Math.PI * 2, 12),
      ],
    },
    { id: 'heart', name: 'Сердечко', paths: [heartPath()] },
    {
      id: 'house',
      name: 'Домик',
      paths: [
        [pt(0.14, 0.92), pt(0.14, 0.44), pt(0.5, 0.08), pt(0.86, 0.44), pt(0.86, 0.92), pt(0.14, 0.92)],
        [pt(0.4, 0.92), pt(0.4, 0.62), pt(0.6, 0.62), pt(0.6, 0.92)],
      ],
    },
    { id: 'star', name: 'Звезда', paths: [starPath()] },
    {
      id: 'fish',
      name: 'Рыба',
      paths: [
        ellipse(0.42, 0.5, 0.36, 0.24),
        [pt(0.76, 0.42), pt(0.96, 0.26), pt(0.96, 0.74), pt(0.76, 0.58)],
        ellipse(0.24, 0.44, 0.035, 0.035, 0, Math.PI * 2, 12),
      ],
    },
    {
      id: 'pile',
      name: 'Сама куча',
      paths: [
        ellipse(0.5, 0.8, 0.42, 0.14),
        ellipse(0.5, 0.56, 0.3, 0.12),
        ellipse(0.5, 0.36, 0.18, 0.09),
        [pt(0.42, 0.3), pt(0.5, 0.07), pt(0.58, 0.3)],
      ],
    },
  ];

  const dist2 = (a, b) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;

  /** Resamples a polyline so neighbouring points are at most `step` apart. */
  function densify(points, step) {
    if (points.length < 2) return points.slice();
    return points.slice(1).reduce((out, b, i) => {
      const a = points[i];
      const n = Math.max(1, Math.ceil(Math.sqrt(dist2(a, b)) / step));
      const segment = Array.from({ length: n }, (_, k) =>
        pt(a.x + ((b.x - a.x) * (k + 1)) / n, a.y + ((b.y - a.y) * (k + 1)) / n));
      return out.concat(segment);
    }, [points[0]]);
  }

  function sampleFigure(figure, step = SAMPLE_STEP) {
    return figure.paths.flatMap((path) => densify(path, step));
  }

  const isNear = (p, points, tol2) => points.some((q) => dist2(p, q) <= tol2);

  /** Returns a new `covered` array with targets near any of `points` switched on. */
  function markCovered(targets, covered, points, tol) {
    const tol2 = tol * tol;
    return targets.map((t, i) => covered[i] || isNear(t, points, tol2));
  }

  function starsFor(score) {
    return STAR_THRESHOLDS.filter((limit) => score >= limit).length;
  }

  function scoreTrace(targets, strokes, tol) {
    const drawn = strokes.flatMap((s) => densify(s, SAMPLE_STEP));
    if (drawn.length === 0 || targets.length === 0) {
      return { coverage: 0, accuracy: 0, score: 0, stars: 0 };
    }
    const covered = markCovered(targets, targets.map(() => false), drawn, tol);
    const coverage = covered.filter(Boolean).length / targets.length;
    const slack2 = (tol * ACCURACY_SLACK) ** 2;
    const accuracy = drawn.filter((p) => isNear(p, targets, slack2)).length / drawn.length;
    const score = Math.round(coverage * accuracy * 100);
    return { coverage, accuracy, score, stars: starsFor(score) };
  }

  function mergeBest(progress, id, stars) {
    return { ...progress, [id]: Math.max(progress[id] || 0, stars) };
  }

  function isUnlocked(progress, index) {
    return index === 0 || (progress[FIGURES[index - 1].id] || 0) >= 1;
  }

  /** Reads saved progress, dropping anything that is not a known level with 0-3 stars. */
  function parseProgress(raw) {
    let data;
    try {
      data = JSON.parse(raw);
    } catch (error) {
      return {};
    }
    if (!data || typeof data !== 'object' || Array.isArray(data)) return {};
    const known = new Set(FIGURES.map((f) => f.id));
    return Object.fromEntries(Object.entries(data).filter(([id, stars]) =>
      known.has(id) && Number.isInteger(stars) && stars >= 0 && stars <= 3));
  }

  return {
    TRACE_TOLERANCE, FIGURES, VERDICTS,
    densify, sampleFigure, markCovered, scoreTrace, starsFor, mergeBest, isUnlocked, parseProgress,
  };
});
