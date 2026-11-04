const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../game/logic.js');

const TOL = L.TRACE_TOLERANCE;

test('densify places points no farther apart than step', () => {
  const out = L.densify([{ x: 0, y: 0 }, { x: 1, y: 0 }], 0.1);
  assert.ok(out.length >= 11);
  out.slice(1).forEach((p, i) => assert.ok(Math.hypot(p.x - out[i].x, p.y - out[i].y) <= 0.1 + 1e-9));
});

test('densify keeps a single tap as one point and does not mutate input', () => {
  const input = [{ x: 0.5, y: 0.5 }];
  assert.equal(L.densify(input, 0.1).length, 1);
  assert.equal(input.length, 1);
});

test('every figure stays inside the unit square', () => {
  assert.ok(L.FIGURES.length >= 6);
  L.FIGURES.forEach((f) => {
    L.sampleFigure(f).forEach((p) => {
      assert.ok(p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1, `${f.id} out of bounds: ${p.x},${p.y}`);
    });
  });
});

test('perfect trace earns three stars on every figure', () => {
  L.FIGURES.forEach((f) => {
    const r = L.scoreTrace(L.sampleFigure(f), f.paths, TOL);
    assert.equal(r.stars, 3, f.id);
    assert.equal(r.score, 100, f.id);
  });
});

test('no strokes earn nothing', () => {
  const r = L.scoreTrace(L.sampleFigure(L.FIGURES[0]), [], TOL);
  assert.deepEqual([r.score, r.stars], [0, 0]);
});

test('scribbling over the whole board does not beat the game', () => {
  const zigzag = [];
  for (let i = 0; i <= 20; i += 1) zigzag.push({ x: i % 2, y: i / 20 });
  const fig = L.FIGURES.find((f) => f.id === 'heart');
  const r = L.scoreTrace(L.sampleFigure(fig), [zigzag], TOL);
  assert.ok(r.stars <= 1, `scribble got ${r.stars} stars, score ${r.score}`);
});

test('tracing half of the figure cannot reach two stars', () => {
  const fig = L.FIGURES.find((f) => f.id === 'star');
  const half = fig.paths[0].slice(0, Math.ceil(fig.paths[0].length / 2));
  const r = L.scoreTrace(L.sampleFigure(fig), [half], TOL);
  assert.ok(r.stars <= 1, `half trace got ${r.stars}`);
});

test('markCovered returns a new array and only marks close targets', () => {
  const targets = [{ x: 0, y: 0 }, { x: 1, y: 1 }];
  const before = [false, false];
  const after = L.markCovered(targets, before, [{ x: 0.01, y: 0 }], TOL);
  assert.deepEqual(after, [true, false]);
  assert.deepEqual(before, [false, false]);
});

test('progress: best stars are kept, input is untouched', () => {
  const p = { heart: 2 };
  assert.deepEqual(L.mergeBest(p, 'heart', 1), { heart: 2 });
  assert.deepEqual(L.mergeBest(p, 'heart', 3), { heart: 3 });
  assert.deepEqual(p, { heart: 2 });
});

test('levels unlock in order after at least one star', () => {
  const [a, b] = L.FIGURES;
  assert.equal(L.isUnlocked({}, 0), true);
  assert.equal(L.isUnlocked({}, 1), false);
  assert.equal(L.isUnlocked({ [a.id]: 0 }, 1), false);
  assert.equal(L.isUnlocked({ [a.id]: 1 }, 1), true);
  assert.equal(L.isUnlocked({ [a.id]: 1 }, 2), false, b.id);
});

test('parseProgress survives garbage from storage', () => {
  assert.deepEqual(L.parseProgress(null), {});
  assert.deepEqual(L.parseProgress('not json'), {});
  assert.deepEqual(L.parseProgress('[1,2]'), {});
  assert.deepEqual(L.parseProgress('{"heart":2,"star":99,"fish":"x","nope":1}'), { heart: 2 });
});
