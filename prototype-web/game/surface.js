/* The poop itself: a height field lit per pixel. Fingers carve real grooves into it.
   Large typed arrays are updated in place on purpose: copying them per stroke would stall the frame. */
(function (root) {
  const MAX_PIXELS = 1200000;
  const LIGHT = normalize3(-0.5, -0.62, 0.6);
  const HALF = normalize3(LIGHT[0], LIGHT[1], LIGHT[2] + 1);
  const DARK = [66, 39, 18];
  const LIGHT_BROWN = [139, 92, 47];
  const CORN = [214, 170, 66];
  const GOLD = [240, 190, 72];
  const RIM_REACH = 1.7;

  function normalize3(x, y, z) {
    const l = Math.hypot(x, y, z);
    return [x / l, y / l, z / l];
  }

  function mulberry32(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function makeNoise(rnd) {
    const grid = Float32Array.from({ length: 65536 }, () => rnd());
    return (x, y) => {
      const xi = Math.floor(x);
      const yi = Math.floor(y);
      const u = x - xi;
      const v = y - yi;
      const su = u * u * (3 - 2 * u);
      const sv = v * v * (3 - 2 * v);
      const x0 = xi & 255;
      const x1 = (xi + 1) & 255;
      const y0 = (yi & 255) << 8;
      const y1 = ((yi + 1) & 255) << 8;
      const top = grid[x0 | y0] + (grid[x1 | y0] - grid[x0 | y0]) * su;
      const bottom = grid[x0 | y1] + (grid[x1 | y1] - grid[x0 | y1]) * su;
      return top + (bottom - top) * sv;
    };
  }

  const smooth01 = (t) => (t <= 0 ? 0 : t >= 1 ? 1 : t * t * (3 - 2 * t));
  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

  function boxPass(input, along, across, stepA, stepB, radius) {
    const out = new Float32Array(input.length);
    const norm = 1 / (2 * radius + 1);
    for (let b = 0; b < across; b += 1) {
      const at = (a) => input[clamp(a, 0, along - 1) * stepA + b * stepB];
      let sum = 0;
      for (let a = -radius; a <= radius; a += 1) sum += at(a);
      for (let a = 0; a < along; a += 1) {
        out[a * stepA + b * stepB] = sum * norm;
        sum += at(a + radius + 1) - at(a - radius);
      }
    }
    return out;
  }

  function createSurface(canvas, cssWidth, cssHeight, firstSeed) {
    const dpr = root.devicePixelRatio || 1;
    const scale = Math.min(dpr, Math.sqrt(MAX_PIXELS / (cssWidth * cssHeight)));
    const w = Math.max(2, Math.round(cssWidth * scale));
    const h = Math.max(2, Math.round(cssHeight * scale));
    canvas.width = w;
    canvas.height = h;
    canvas.style.width = `${cssWidth}px`;
    canvas.style.height = `${cssHeight}px`;
    const ctx = canvas.getContext('2d', { alpha: false });
    const image = ctx.createImageData(w, h);
    const px = image.data;
    const height = new Float32Array(w * h);
    const base = new Float32Array(w * h);
    const mottle = new Float32Array(w * h);
    const corn = new Uint8Array(w * h);
    const gild = new Float32Array(w * h);
    let dirtyBoxes = [];

    function markDirty(x0, y0, x1, y1) {
      dirtyBoxes.push([Math.max(0, Math.floor(x0)), Math.max(0, Math.floor(y0)),
        Math.min(w, Math.ceil(x1)), Math.min(h, Math.ceil(y1))]);
    }

    function addKernel(cx, cy, angle, r) {
      const cos = Math.cos(angle);
      const sin = Math.sin(angle);
      const reach = Math.ceil(r * 1.6);
      for (let y = Math.max(0, Math.floor(cy - reach)); y < Math.min(h, cy + reach); y += 1) {
        for (let x = Math.max(0, Math.floor(cx - reach)); x < Math.min(w, cx + reach); x += 1) {
          const u = ((x - cx) * cos + (y - cy) * sin) / (r * 1.5);
          const v = (-(x - cx) * sin + (y - cy) * cos) / r;
          const d = u * u + v * v;
          if (d < 1) {
            const i = x + y * w;
            base[i] += (1 - d) * 2.4;
            corn[i] = 1;
          }
        }
      }
    }

    function generate(seed) {
      const rnd = mulberry32(seed);
      const noise = makeNoise(rnd);
      for (let y = 0; y < h; y += 1) {
        for (let x = 0; x < w; x += 1) {
          const sx = x / scale;
          const sy = y / scale;
          const warp = noise(sx / 70, sy / 70) * 1.6;
          const warp2 = noise(sx / 31 + 40, sy / 31) * 0.8;
          const lumps = noise(sx / 120 + warp, sy / 120) * 26 + noise(sx / 48 - warp, sy / 48 + warp) * 13;
          const ridge = 1 - Math.abs(2 * noise(sx / 38 + warp2, sy / 38 - warp2) - 1);
          const crack = smooth01((ridge - 0.94) / 0.06) * 4.5;
          const grain = noise(sx / 7, sy / 7) * 2.6 + noise(sx / 2.6, sy / 2.6) * 0.9;
          const i = x + y * w;
          base[i] = lumps + grain - crack;
          mottle[i] = smooth01(noise(sx / 55 + 9, sy / 55) * 0.75 + noise(sx / 11, sy / 11) * 0.45 - 0.1);
        }
      }
      corn.fill(0);
      const kernels = Math.round((cssWidth * cssHeight) / 26000);
      for (let n = 0; n < kernels; n += 1) {
        addKernel(rnd() * w, rnd() * h, rnd() * Math.PI, (3 + rnd() * 2) * scale);
      }
      height.set(base);
      markDirty(0, 0, w, h);
    }

    function shadePixel(x, y) {
      const i = x + y * w;
      const left = height[x > 0 ? i - 1 : i];
      const right = height[x < w - 1 ? i + 1 : i];
      const up = height[y > 0 ? i - w : i];
      const down = height[y < h - 1 ? i + w : i];
      const sx = (left - right) * scale * 0.5;
      const sy = (up - down) * scale * 0.5;
      const invLen = 1 / Math.sqrt(sx * sx + sy * sy + 1);
      const nx = sx * invLen;
      const ny = sy * invLen;
      const diffuse = Math.max(0, nx * LIGHT[0] + ny * LIGHT[1] + invLen * LIGHT[2]);
      const facing = Math.max(0, nx * HALF[0] + ny * HALF[1] + invLen * HALF[2]);
      const dug = base[i] - height[i];
      const gilded = gild[i];
      const occlusion = 1 - smooth01(dug / 9) * 0.5 * (1 - gilded);
      const m = mottle[i];
      const wet = 0.2 + smooth01(dug / 5) * 0.28 + (1 - m) * 0.12;
      const shine = facing ** 34 * wet * 255;
      const light = (0.34 + diffuse * 1.02) * occlusion;
      const isCorn = corn[i] === 1;
      const j = i * 4;
      for (let c = 0; c < 3; c += 1) {
        const albedo = isCorn ? CORN[c] : DARK[c] + (LIGHT_BROWN[c] - DARK[c]) * m;
        px[j + c] = (albedo + (GOLD[c] - albedo) * gilded) * light + shine;
      }
      px[j + 3] = 255;
    }

    /** Applies pending changes to the canvas; call once per animation frame. */
    function flush() {
      const boxes = dirtyBoxes;
      dirtyBoxes = [];
      boxes.forEach(([x0, y0, x1, y1]) => {
        if (x1 <= x0 || y1 <= y0) return;
        for (let y = y0; y < y1; y += 1) {
          for (let x = x0; x < x1; x += 1) shadePixel(x, y);
        }
        ctx.putImageData(image, 0, 0, x0, y0, x1 - x0, y1 - y0);
      });
    }

    function carveSegment(ax, ay, bx, by, radius) {
      const r = radius * scale;
      const x0 = ax * scale;
      const y0 = ay * scale;
      const dx = bx * scale - x0;
      const dy = by * scale - y0;
      const len2 = dx * dx + dy * dy;
      const len = Math.sqrt(len2) || 1;
      const reach = r * RIM_REACH;
      const depth = radius * 0.8;
      const rimHeight = radius * 0.3;
      const left = Math.max(0, Math.floor(Math.min(x0, x0 + dx) - reach));
      const right = Math.min(w, Math.ceil(Math.max(x0, x0 + dx) + reach));
      const top = Math.max(0, Math.floor(Math.min(y0, y0 + dy) - reach));
      const bottom = Math.min(h, Math.ceil(Math.max(y0, y0 + dy) + reach));
      for (let y = top; y < bottom; y += 1) {
        for (let x = left; x < right; x += 1) {
          const t = len2 ? clamp(((x - x0) * dx + (y - y0) * dy) / len2, 0, 1) : 0;
          const d = Math.hypot(x - (x0 + t * dx), y - (y0 + t * dy));
          if (d < reach) {
            const i = x + y * w;
            if (d < r) {
              const across = ((x - x0) * dy - (y - y0) * dx) / len / scale;
              const fingerprint = len2 ? Math.sin(across * 1.5) * 0.35 : 0;
              height[i] = Math.min(height[i], base[i] - depth * (1 - (d / r) ** 2) - fingerprint);
            } else if (height[i] >= base[i] - 0.3) {
              const bump = Math.sin((Math.PI * (d - r)) / (reach - r)) * rimHeight * (0.45 + mottle[i]);
              height[i] = Math.max(height[i], base[i] + bump);
            }
          }
        }
      }
      markDirty(left - 1, top - 1, right + 1, bottom + 1);
    }

    function smoothAt(cx, cy, radius) {
      const r = radius * scale;
      const x0 = cx * scale;
      const y0 = cy * scale;
      const left = Math.max(0, Math.floor(x0 - r));
      const right = Math.min(w, Math.ceil(x0 + r));
      const top = Math.max(0, Math.floor(y0 - r));
      const bottom = Math.min(h, Math.ceil(y0 + r));
      for (let y = top; y < bottom; y += 1) {
        for (let x = left; x < right; x += 1) {
          const d = Math.hypot(x - x0, y - y0) / r;
          if (d < 1) {
            const i = x + y * w;
            height[i] += (base[i] - height[i]) * 0.45 * (1 - d);
          }
        }
      }
      markDirty(left - 1, top - 1, right + 1, bottom + 1);
    }

    const blurred = (source, radius) =>
      boxPass(boxPass(source, w, h, 1, w, radius), h, w, w, 1, radius);

    /** Presses the given lines of text into the surface: the title screen is part of the poop. */
    function carveText(lines, centerY) {
      const mask = document.createElement('canvas');
      mask.width = w;
      mask.height = h;
      const m = mask.getContext('2d', { willReadFrequently: true });
      const longest = lines.reduce((a, b) => (a.length > b.length ? a : b), '');
      const family = 'ui-rounded, "SF Pro Rounded", "Arial Black", Impact, sans-serif';
      m.font = `900 100px ${family}`;
      const size = Math.min(100 * ((w * 0.88) / m.measureText(longest).width), 74 * scale);
      m.font = `900 ${size}px ${family}`;
      m.textAlign = 'center';
      m.textBaseline = 'middle';
      m.fillStyle = '#fff';
      const lineGap = size * 1.08;
      const startY = centerY * scale - ((lines.length - 1) * lineGap) / 2;
      lines.forEach((line, n) => m.fillText(line, w / 2, startY + n * lineGap));
      const data = m.getImageData(0, 0, w, h).data;
      const alpha = Float32Array.from({ length: w * h }, (_, i) => data[i * 4 + 3] / 255);
      const press = blurred(alpha, Math.max(1, Math.round(1.1 * scale)));
      const halo = blurred(alpha, Math.max(2, Math.round(5 * scale)));
      for (let i = 0; i < height.length; i += 1) {
        height[i] = base[i] - press[i] * 10 + Math.max(0, halo[i] - press[i]) * 7;
        gild[i] = press[i];
      }
      markDirty(0, 0, w, h);
    }

    function resetCarving() {
      height.set(base);
      gild.fill(0);
      markDirty(0, 0, w, h);
    }

    generate(firstSeed);
    flush();

    return {
      cssWidth,
      cssHeight,
      regenerate: generate,
      carveSegment,
      smoothAt,
      carveText,
      resetCarving,
      flush,
      toDataURL: () => {
        flush();
        return canvas.toDataURL('image/jpeg', 0.92);
      },
    };
  }

  root.PDSurface = { createSurface };
})(globalThis);
