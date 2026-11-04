/* Flies crawl over the pile and scatter when a finger comes close. */
(function (root) {
  const SCARE_DISTANCE = 56;

  const spawn = (w, h) => ({
    x: Math.random() * w,
    y: Math.random() * h,
    heading: Math.random() * Math.PI * 2,
    airborne: 0,
    pause: Math.random() * 2,
  });

  function step(fly, dt, w, h) {
    const airborne = Math.max(0, fly.airborne - dt);
    const pause = fly.airborne > 0 ? fly.pause : fly.pause - dt;
    const resting = airborne === 0 && pause > 0;
    const speed = airborne > 0 ? 340 : 34;
    const heading = fly.heading + (Math.random() - 0.5) * (airborne > 0 ? 9 : 3.5) * dt;
    return {
      ...fly,
      airborne,
      heading,
      pause: pause <= -1.4 - Math.random() * 3 ? 0.4 + Math.random() * 2.4 : pause,
      x: resting ? fly.x : (fly.x + Math.cos(heading) * speed * dt + w) % w,
      y: resting ? fly.y : (fly.y + Math.sin(heading) * speed * dt + h) % h,
    };
  }

  function scatter(fly, x, y) {
    if (Math.hypot(fly.x - x, fly.y - y) > SCARE_DISTANCE) return fly;
    return { ...fly, airborne: 0.5 + Math.random() * 0.7, heading: Math.atan2(fly.y - y, fly.x - x), pause: 0 };
  }

  function drawFly(ctx, fly, time) {
    const lift = fly.airborne > 0 ? 9 : 1.5;
    ctx.save();
    ctx.translate(fly.x + lift, fly.y + lift);
    ctx.fillStyle = 'rgba(15,8,2,0.4)';
    ctx.beginPath();
    ctx.ellipse(0, 0, 4.5, 3, fly.heading, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    ctx.save();
    ctx.translate(fly.x, fly.y);
    ctx.rotate(fly.heading);
    const flutter = fly.airborne > 0 ? Math.sin(time * 0.09) * 0.5 : 0;
    ctx.fillStyle = 'rgba(218,226,232,0.5)';
    [-1, 1].forEach((side) => {
      ctx.beginPath();
      ctx.ellipse(-3.5, side * 3.2, 5, 2.3, side * (0.45 + flutter), 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.fillStyle = '#17120f';
    ctx.beginPath();
    ctx.ellipse(0, 0, 4.6, 2.7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#6d1f16';
    ctx.beginPath();
    ctx.arc(3.8, 0, 1.9, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function createFlies(count, w, h) {
    let flies = Array.from({ length: count }, () => spawn(w, h));
    return {
      update(dt) { flies = flies.map((f) => step(f, dt, w, h)); },
      scare(x, y) { flies = flies.map((f) => scatter(f, x, y)); },
      draw(ctx, time) { flies.forEach((f) => drawFly(ctx, f, time)); },
    };
  }

  root.PDFlies = { createFlies };
})(globalThis);
