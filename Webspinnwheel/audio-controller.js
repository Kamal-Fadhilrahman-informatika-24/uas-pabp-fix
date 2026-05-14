// ============================================================
// audio-controller.js — GLOBAL AUDIO SYSTEM v2
// SpinDecide — Mute/Unmute + Spin SFX + Multiplayer Backsound
//
// Semua suara dibuat via Web Audio API (synthesized) sehingga
// tidak butuh file audio eksternal.
//
// API global:
//   AudioController.play(src, opts)      — putar file audio
//   AudioController.playSpinSound()      — SFX spin mulai
//   AudioController.stopSpinSound()      — SFX spin berhenti
//   AudioController.startBacksound()     — musik multiplayer
//   AudioController.stopBacksound()      — hentikan musik
//   AudioController.mute() / .unmute() / .toggle()
//   AudioController.getMuted()
// ============================================================

(function AudioController() {
  'use strict';

  const STORAGE_KEY = 'spindecide_muted';

  // ── State ─────────────────────────────────────────────────
  let isMuted       = false;
  let activeAudios  = [];
  let spinSoundNode = null;
  let backsoundGain = null;
  let isBacksoundRunning = false;

  let audioCtx   = null;
  let masterGain = null;
  let bsOscillators = [];
  let backsoundScheduler = null;
  let bsChordIndex  = 0;
  let bsNextBeatTime = 0;

  // ── Web Audio Context ─────────────────────────────────────
  function ensureAudioCtx() {
    if (audioCtx) return;
    try {
      audioCtx   = new (window.AudioContext || window.webkitAudioContext)();
      masterGain = audioCtx.createGain();
      masterGain.connect(audioCtx.destination);
      masterGain.gain.value = isMuted ? 0 : 1;
    } catch (e) {
      console.warn('[AudioController] Web Audio API tidak tersedia:', e);
    }
  }

  function resumeCtx() {
    if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume().catch(() => {});
  }

  function loadMuteState() {
    try { return localStorage.getItem(STORAGE_KEY) === 'true'; } catch (e) { return false; }
  }
  function saveMuteState(v) {
    try { localStorage.setItem(STORAGE_KEY, String(v)); } catch (e) {}
  }

  function applyMuteToAll(muted) {
    activeAudios = activeAudios.filter(a => !a.paused || a.loop);
    activeAudios.forEach(a => { a.muted = muted; });
    document.querySelectorAll('audio, video').forEach(el => { el.muted = muted; });
    if (masterGain && audioCtx) {
      masterGain.gain.setTargetAtTime(muted ? 0 : 1, audioCtx.currentTime, 0.05);
    }
    if (muted) {
      if (spinSoundNode) { _doStopSpin(); }
      if (isBacksoundRunning) _fadeOutBacksound();
    } else if (isBacksoundRunning && backsoundGain && audioCtx) {
      backsoundGain.gain.setTargetAtTime(0.18, audioCtx.currentTime, 0.3);
    }
  }

  // ── Play file audio ───────────────────────────────────────
  function play(src, options = {}) {
    const { loop = false, volume = 1.0, onEnd = null } = options;
    const audio = new Audio(src);
    audio.loop   = loop;
    audio.volume = volume;
    audio.muted  = isMuted;
    activeAudios.push(audio);
    audio.addEventListener('ended', () => {
      activeAudios = activeAudios.filter(a => a !== audio);
      if (onEnd) onEnd();
    });
    audio.play().catch(e => console.warn('[AudioController] Autoplay blocked:', e.message));
    return audio;
  }

  // ════════════════════════════════════════════════════════════
  // SPIN SOUND EFFECT
  // ════════════════════════════════════════════════════════════

  function makeDistortionCurve(amount) {
    const n = 256, curve = new Float32Array(n), deg = Math.PI / 180;
    for (let i = 0; i < n; i++) {
      const x = (i * 2) / n - 1;
      curve[i] = ((3 + amount) * x * 20 * deg) / (Math.PI + amount * Math.abs(x));
    }
    return curve;
  }

  function playSpinSound() {
    if (isMuted) return;
    ensureAudioCtx();
    resumeCtx();
    if (!audioCtx) return;
    _doStopSpin();

    const now = audioCtx.currentTime;
    const spinGain = audioCtx.createGain();
    spinGain.gain.setValueAtTime(0.0, now);
    spinGain.gain.linearRampToValueAtTime(0.32, now + 0.08);
    spinGain.connect(masterGain);

    // Ratchet oscillator
    const osc = audioCtx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(300, now);
    osc.frequency.exponentialRampToValueAtTime(90, now + 3.5);
    osc.frequency.exponentialRampToValueAtTime(50, now + 5.0);

    const dist = audioCtx.createWaveShaper();
    dist.curve = makeDistortionCurve(180);
    dist.oversample = '2x';

    const bpf = audioCtx.createBiquadFilter();
    bpf.type = 'bandpass';
    bpf.frequency.value = 900;
    bpf.Q.value = 4;

    osc.connect(dist);
    dist.connect(bpf);
    bpf.connect(spinGain);

    // Whoosh noise layer
    const bufSize = Math.min(audioCtx.sampleRate * 0.5, 22050);
    const noiseBuffer = audioCtx.createBuffer(1, bufSize, audioCtx.sampleRate);
    const data = noiseBuffer.getChannelData(0);
    for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;

    const ns = audioCtx.createBufferSource();
    ns.buffer = noiseBuffer;
    ns.loop   = true;

    const lpf = audioCtx.createBiquadFilter();
    lpf.type = 'lowpass';
    lpf.frequency.setValueAtTime(3000, now);
    lpf.frequency.exponentialRampToValueAtTime(500, now + 5.0);

    const ng = audioCtx.createGain();
    ng.gain.setValueAtTime(0.07, now);
    ng.gain.linearRampToValueAtTime(0.0, now + 5.0);

    ns.connect(lpf);
    lpf.connect(ng);
    ng.connect(masterGain);

    osc.start(now);
    ns.start(now);

    spinSoundNode = { osc, ns, spinGain, ng };
  }

  function _doStopSpin() {
    if (!spinSoundNode || !audioCtx) return;
    const { osc, ns, spinGain, ng } = spinSoundNode;
    const now = audioCtx.currentTime;
    spinGain.gain.setTargetAtTime(0, now, 0.06);
    ng.gain.setTargetAtTime(0, now, 0.06);
    setTimeout(() => {
      try { osc.stop(); } catch (_) {}
      try { ns.stop(); }  catch (_) {}
    }, 250);
    spinSoundNode = null;
  }

  function stopSpinSound() {
    _doStopSpin();
    if (!isMuted) _playResultDing();
  }

  function _playResultDing() {
    if (!audioCtx || isMuted) return;
    resumeCtx();
    const now = audioCtx.currentTime;
    [523.25, 659.25, 783.99, 1046.50].forEach((freq, i) => {
      const osc  = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      const t    = now + i * 0.11;
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0, t);
      gain.gain.linearRampToValueAtTime(0.20, t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.42);
      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.48);
    });
  }

  // ════════════════════════════════════════════════════════════
  // MULTIPLAYER BACKSOUND — Synthesized chord loop
  // Am – F – C – G  @ 128BPM (arcade vibe)
  // ════════════════════════════════════════════════════════════

  const CHORD_NOTES = [
    [220.00, 261.63, 329.63],  // Am
    [174.61, 220.00, 261.63],  // F
    [261.63, 329.63, 392.00],  // C
    [196.00, 246.94, 293.66],  // G
  ];
  const BEAT_PERIOD = 60 / 128;

  function startBacksound() {
    if (isBacksoundRunning) return;
    if (isMuted) return;
    ensureAudioCtx();
    resumeCtx();
    if (!audioCtx) return;

    isBacksoundRunning = true;
    bsChordIndex   = 0;
    bsOscillators  = [];

    backsoundGain = audioCtx.createGain();
    backsoundGain.gain.setValueAtTime(0, audioCtx.currentTime);
    backsoundGain.connect(masterGain);
    backsoundGain.gain.linearRampToValueAtTime(0.18, audioCtx.currentTime + 1.5);

    bsNextBeatTime = audioCtx.currentTime + 0.1;

    // Bass drone
    const bassOsc  = audioCtx.createOscillator();
    const bassGain = audioCtx.createGain();
    bassOsc.type = 'sine';
    bassOsc.frequency.value = 55;
    bassGain.gain.value = 0.28;
    bassOsc.connect(bassGain);
    bassGain.connect(backsoundGain);
    bassOsc.start();
    bsOscillators.push(bassOsc);

    backsoundScheduler = setInterval(_scheduleBeat, 25);
  }

  function stopBacksound() {
    if (!isBacksoundRunning) return;
    isBacksoundRunning = false;
    if (backsoundScheduler) { clearInterval(backsoundScheduler); backsoundScheduler = null; }
    _fadeOutBacksound();
  }

  function _fadeOutBacksound() {
    if (!backsoundGain || !audioCtx) return;
    const now = audioCtx.currentTime;
    backsoundGain.gain.setTargetAtTime(0, now, 0.35);
    setTimeout(() => {
      bsOscillators.forEach(o => { try { o.stop(); } catch (_) {} });
      bsOscillators = [];
      try { if (backsoundGain) backsoundGain.disconnect(); } catch (_) {}
      backsoundGain = null;
    }, 2000);
  }

  function _scheduleBeat() {
    if (!audioCtx || !backsoundGain) return;
    resumeCtx();
    const lookahead = 0.1;
    while (bsNextBeatTime < audioCtx.currentTime + lookahead) {
      _scheduleChord(bsNextBeatTime);
      bsChordIndex    = (bsChordIndex + 1) % CHORD_NOTES.length;
      bsNextBeatTime += BEAT_PERIOD * 4;
    }
  }

  function _scheduleChord(time) {
    if (!backsoundGain) return;
    const dur = BEAT_PERIOD * 3.8;
    CHORD_NOTES[bsChordIndex].forEach((freq, i) => {
      const osc  = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = i === 0 ? 'triangle' : 'sine';
      osc.frequency.value = freq;
      const vol = i === 0 ? 0.65 : 0.42;
      gain.gain.setValueAtTime(0, time);
      gain.gain.linearRampToValueAtTime(vol, time + 0.025);
      gain.gain.setValueAtTime(vol, time + dur - 0.1);
      gain.gain.linearRampToValueAtTime(0, time + dur);
      osc.connect(gain);
      gain.connect(backsoundGain);
      osc.start(time);
      osc.stop(time + dur + 0.05);
      bsOscillators.push(osc);
    });
    // Cleanup setelah chord selesai
    const ms = Math.max(0, (time - audioCtx.currentTime + dur + 0.5)) * 1000;
    setTimeout(() => {
      bsOscillators = bsOscillators.filter(o => {
        try { return o.context && o.context.state !== 'closed'; } catch (_) { return false; }
      });
    }, ms);
  }

  // ── Mute / Unmute ─────────────────────────────────────────
  function mute() {
    isMuted = true;
    saveMuteState(true);
    applyMuteToAll(true);
    updateToggleButton(true);
  }

  function unmute() {
    isMuted = false;
    saveMuteState(false);
    applyMuteToAll(false);
    updateToggleButton(false);
  }

  function toggle() { if (isMuted) unmute(); else mute(); }
  function getMuted() { return isMuted; }

  // ── Toggle button ─────────────────────────────────────────
  function updateToggleButton(muted) {
    const btn = document.getElementById('muteToggleBtn');
    if (!btn) return;
    if (muted) {
      btn.innerHTML = '🔇';
      btn.setAttribute('title', 'Aktifkan Suara');
      btn.setAttribute('aria-label', 'Aktifkan suara');
      btn.classList.add('muted');
    } else {
      btn.innerHTML = '🔊';
      btn.setAttribute('title', 'Matikan Suara');
      btn.setAttribute('aria-label', 'Matikan suara');
      btn.classList.remove('muted');
    }
  }

  function injectToggleButton() {
    if (document.getElementById('muteToggleBtn')) return;
    const btn = document.createElement('button');
    btn.id        = 'muteToggleBtn';
    btn.className = 'btn-mute-toggle';
    btn.onclick   = toggle;

    const navUser = document.querySelector('.nav-user');
    if (navUser) {
      navUser.insertBefore(btn, navUser.firstChild);
    } else {
      btn.classList.add('btn-mute-toggle--floating');
      document.body.appendChild(btn);
    }
    updateToggleButton(isMuted);
  }

  function observeNewMediaElements() {
    const observer = new MutationObserver(mutations => {
      mutations.forEach(m => {
        m.addedNodes.forEach(node => {
          if (node.nodeName === 'AUDIO' || node.nodeName === 'VIDEO') node.muted = isMuted;
          if (node.querySelectorAll) node.querySelectorAll('audio, video').forEach(el => { el.muted = isMuted; });
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  // ── Init ─────────────────────────────────────────────────
  isMuted = loadMuteState();
  ensureAudioCtx();

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      injectToggleButton();
      applyMuteToAll(isMuted);
      observeNewMediaElements();
    });
  } else {
    injectToggleButton();
    applyMuteToAll(isMuted);
    observeNewMediaElements();
  }

  ['click', 'touchstart', 'keydown'].forEach(evt => {
    document.addEventListener(evt, resumeCtx, { passive: true });
  });

  // ── Expose API ────────────────────────────────────────────
  window.AudioController = {
    play, mute, unmute, toggle, getMuted,
    getAudioContext: () => ({ ctx: audioCtx, gain: masterGain }),
    playSpinSound,
    stopSpinSound,
    startBacksound,
    stopBacksound,
    isBacksoundRunning: () => isBacksoundRunning,
  };

})();
