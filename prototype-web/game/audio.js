/* All sound is synthesised, so the app ships no audio files. Stays silent where Web Audio is missing. */
(function (root) {
  function createAudio(initialMuted) {
    let ctx = null;
    let squelchGain = null;
    let squelchFilter = null;
    let muted = initialMuted;

    function noiseBuffer(seconds) {
      const buffer = ctx.createBuffer(1, Math.floor(ctx.sampleRate * seconds), ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < data.length; i += 1) data[i] = Math.random() * 2 - 1;
      return buffer;
    }

    /** Must first run inside a user gesture, or iOS keeps the context suspended. */
    function unlock() {
      const Ctor = root.AudioContext || root.webkitAudioContext;
      if (!Ctor) return;
      if (!ctx) {
        ctx = new Ctor();
        const source = ctx.createBufferSource();
        source.buffer = noiseBuffer(2);
        source.loop = true;
        squelchFilter = ctx.createBiquadFilter();
        squelchFilter.type = 'bandpass';
        squelchFilter.Q.value = 2.2;
        squelchFilter.frequency.value = 420;
        squelchGain = ctx.createGain();
        squelchGain.gain.value = 0;
        source.connect(squelchFilter).connect(squelchGain).connect(ctx.destination);
        source.start();
      }
      if (ctx.state !== 'running') ctx.resume().catch(() => {});
    }

    /** speed is finger speed in CSS px per ms; 0 silences the squelch. */
    function squelch(speed) {
      if (!ctx || muted) return;
      const now = ctx.currentTime;
      const amount = Math.min(1, speed / 1.6);
      squelchGain.gain.setTargetAtTime(amount * 0.34, now, 0.03);
      squelchFilter.frequency.setTargetAtTime(280 + amount * 720 + Math.random() * 120, now, 0.05);
    }

    function tone(type, from, to, start, length, volume) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(from, start);
      osc.frequency.exponentialRampToValueAtTime(to, start + length);
      gain.gain.setValueAtTime(volume, start);
      gain.gain.exponentialRampToValueAtTime(0.001, start + length);
      osc.connect(gain).connect(ctx.destination);
      osc.start(start);
      osc.stop(start + length + 0.02);
      return osc;
    }

    function plop() {
      if (!ctx || muted) return;
      tone('sine', 340, 70, ctx.currentTime, 0.13, 0.32);
    }

    function fart() {
      if (!ctx || muted) return;
      const now = ctx.currentTime;
      const length = 0.55 + Math.random() * 0.5;
      const pitch = 62 + Math.random() * 38;
      const osc = tone('sawtooth', pitch * 1.25, pitch * 0.62, now, length, 0.5);
      const wobble = ctx.createOscillator();
      const depth = ctx.createGain();
      wobble.frequency.value = 17 + Math.random() * 16;
      depth.gain.value = pitch * 0.45;
      wobble.connect(depth).connect(osc.frequency);
      wobble.start(now);
      wobble.stop(now + length);
    }

    function fanfare() {
      if (!ctx || muted) return;
      [392, 523, 659, 784].forEach((f, i) => tone('triangle', f, f, ctx.currentTime + i * 0.11, 0.26, 0.2));
    }

    function setMuted(value) {
      muted = value;
      if (ctx && muted) squelchGain.gain.setTargetAtTime(0, ctx.currentTime, 0.02);
    }

    return { unlock, squelch, plop, fart, fanfare, setMuted, isMuted: () => muted };
  }

  root.PDAudio = { createAudio };
})(globalThis);
