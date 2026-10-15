(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const root = document.documentElement;
  const defaults = { tint: 'tide', frost: 64, depth: 55, light: 315, theme: 'dark', backdrop: 'signal', pointer: true, reduced: false };
  const presets = {
    tide: { name: 'Tide', rgb: '87 214 209', ink: '#0b322f', muted: '#28524b' },
    kelp: { name: 'Kelp', rgb: '145 194 122', ink: '#263c23', muted: '#3c5236' },
    amber: { name: 'Amber', rgb: '240 184 99', ink: '#49351b', muted: '#654d2d' },
    violet: { name: 'Violet', rgb: '176 150 214', ink: '#322b4b', muted: '#51486e' },
    frost: { name: 'Frost', rgb: '209 227 224', ink: '#263c3f', muted: '#425b5e' }
  };
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let state = { ...defaults };
  const effectiveLight = () => reducedMotion.matches ? defaults.light : state.light;
  let activated = false;
  let copyTimer;
  const ranges = ['frost', 'depth', 'light'];

  function render() {
    const tint = presets[state.tint];
    const blur = 4 + state.frost * .25;
    const alpha = .27 + state.frost * .0024;
    const edge = 8 + state.depth * .24;
    const rim = .25 + state.depth * .0045;
    root.style.setProperty('--tint', tint.rgb);
    root.style.setProperty('--glass-ink', tint.ink);
    root.style.setProperty('--glass-muted', tint.muted);
    root.style.setProperty('--blur', `${blur.toFixed(2)}px`);
    root.style.setProperty('--body-alpha', alpha.toFixed(3));
    root.style.setProperty('--rim-alpha', rim.toFixed(3));
    root.style.setProperty('--edge-shadow', `${edge.toFixed(2)}px`);
    root.style.setProperty('--contact-y', `${(10 + state.depth * .16).toFixed(2)}px`);
    root.style.setProperty('--light', effectiveLight());
    document.body.dataset.theme = state.theme;
    document.body.dataset.reduced = String(state.reduced);
    document.querySelector('.sample-name').textContent = tint.name.toUpperCase();
    $('tint-label').textContent = tint.name;
    document.querySelector('.context-label').textContent = state.theme === 'dark' ? 'DARK INSTRUMENT ENVIRONMENT' : 'PALE MINERAL ENVIRONMENT';
    document.querySelectorAll('[data-tint]').forEach((button) => {
      const selected = button.dataset.tint === state.tint;
      button.classList.toggle('is-active', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    document.querySelectorAll('[data-theme]').forEach((button) => {
      const selected = button.dataset.theme === state.theme;
      button.classList.toggle('is-active', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    ranges.forEach((name) => {
      const input = $(name);
      const value = name === 'light' ? effectiveLight() : state[name];
      input.value = value;
      input.disabled = (name === 'frost' && state.reduced) || (name === 'light' && reducedMotion.matches);
      input.style.setProperty('--range-progress', `${value / Number(input.max) * 100}%`);
      $(name + '-value').innerHTML = name === 'light' ? `${value}<span>°</span>` : `${value}<span>/ 100</span>`;
      input.setAttribute('aria-valuetext', name === 'light' ? `${value} degrees clockwise from up${reducedMotion.matches ? ', fixed resting rim with Reduce Motion' : ''}` : `${value} of 100, artistic index${name === 'frost' && state.reduced ? ', retained recipe value; disabled in opaque mode' : ''}`);
    });
    $('specimen-stage').dataset.backdrop = state.backdrop;
    $('backdrop').value = state.backdrop;
    $('pointer-light').checked = state.pointer && !reducedMotion.matches;
    $('pointer-light').disabled = reducedMotion.matches;
    $('reduce-transparency').checked = state.reduced;
    $('surface-mode').textContent = state.reduced ? 'OPAQUE FALLBACK' : 'SURFACE APPROXIMATION';
    $('recipe-summary').textContent = `${state.tint} · frost ${state.frost} · depth ${state.depth} · light ${effectiveLight()}°${state.reduced ? ' · opaque' : ''}${reducedMotion.matches ? ' · resting rim' : ''}`;
    document.querySelector('.stage-annotation span:last-child').textContent = state.reduced ? 'Solid color. Crisp, anchored ink.' : 'Soft transmission. Crisp, anchored ink.';
    $('recipe-note').textContent = reducedMotion.matches ? 'Reduce Motion fixes the rim at 315° and turns pointer steering off. Frost and depth remain artistic indices.' : state.reduced ? 'Frost is retained in the recipe, but inactive in opaque mode. Depth and light still shape the rim.' : 'Frost and depth are artistic indices, not physical measurements. This study approximates a surface.';
  }

  document.querySelectorAll('[data-tint]').forEach((button) => button.addEventListener('click', () => { state.tint = button.dataset.tint; render(); }));
  document.querySelectorAll('[data-theme]').forEach((button) => button.addEventListener('click', () => { state.theme = button.dataset.theme; render(); }));
  ranges.forEach((name) => $(name).addEventListener('input', (event) => { state[name] = Number(event.target.value); render(); }));
  $('backdrop').addEventListener('change', (event) => { state.backdrop = event.target.value; render(); });
  $('pointer-light').addEventListener('change', (event) => { state.pointer = event.target.checked; });
  $('reduce-transparency').addEventListener('change', (event) => { state.reduced = event.target.checked; render(); });
  $('reset').addEventListener('click', () => { state = { ...defaults }; render(); });
  $('specimen-stage').addEventListener('pointermove', (event) => {
    if (!state.pointer || reducedMotion.matches || event.pointerType === 'touch') return;
    const rect = event.currentTarget.getBoundingClientRect();
    const x = event.clientX - rect.left - rect.width / 2;
    const y = event.clientY - rect.top - rect.height / 2;
    if (Math.hypot(x, y) < 12) return;
    state.light = (Math.round(Math.atan2(y, x) * 180 / Math.PI) + 450) % 360;
    render();
  });
  $('activate').addEventListener('click', () => {
    activated = !activated;
    $('activate').setAttribute('aria-pressed', String(activated));
    $('activate-label').textContent = activated ? 'Surface active' : 'Activate surface';
    document.querySelector('.play-icon').textContent = activated ? '■' : '▶';
    $('action-status').textContent = activated ? 'Active · accepted state, with steady geometry.' : 'Ready · press to see the accepted state.';
  });
  const intents = { Surface: 'a calm, tactile plane.', Control: 'a focused action with a clear state.', Lens: 'an isolated optical layer over decorative ink.' };
  document.querySelectorAll('[data-intent]').forEach((button) => button.addEventListener('click', () => {
    document.querySelectorAll('[data-intent]').forEach((item) => {
      item.classList.toggle('is-active', item === button);
      item.setAttribute('aria-pressed', String(item === button));
    });
    $('intent-status').textContent = `${button.dataset.intent} · ${intents[button.dataset.intent]}`;
  }));

  function recipeText() {
    const tint = presets[state.tint];
    return `/* Metro Station Sea Glass — ${tint.name}\n * Artistic surface approximation; frost/depth are normalized indices.\n * Anchored ink and control frames must remain outside optical layers.\n * Apply with study.css .glass-body / .glass-grain / .glass-rim.\n */\n:root {\n  --sea-glass-tint-name: ${state.tint};\n  --sea-glass-frost-index: ${state.frost};\n  --sea-glass-depth-index: ${state.depth};\n  --sea-glass-light-angle: ${effectiveLight()}deg;\n  --tint: ${tint.rgb};\n  --glass-ink: ${tint.ink};\n  --glass-muted: ${tint.muted};\n  --blur: ${(4 + state.frost * .25).toFixed(2)}px;\n  --body-alpha: ${(.27 + state.frost * .0024).toFixed(3)};\n  --rim-alpha: ${(.25 + state.depth * .0045).toFixed(3)};\n  --edge-shadow: ${(8 + state.depth * .24).toFixed(2)}px;\n  --contact-y: ${(10 + state.depth * .16).toFixed(2)}px;\n  --light: ${effectiveLight()};\n}\n/* Appearance: ${state.theme}; backdrop: ${state.backdrop}; reduce transparency: ${state.reduced} */`;
  }
  $('copy-tokens').addEventListener('click', async () => {
    const text = recipeText();
    let copied = false;
    try {
      if (navigator.clipboard && window.isSecureContext) { await navigator.clipboard.writeText(text); copied = true; }
    } catch (_) { /* The selection fallback supports local file previews. */ }
    if (!copied) {
      const area = document.createElement('textarea');
      area.value = text;
      area.style.position = 'fixed';
      area.style.left = '-9999px';
      document.body.appendChild(area);
      area.select();
      try { copied = document.execCommand('copy'); } catch (_) { copied = false; }
      area.remove();
      $('copy-tokens').focus();
    }
    clearTimeout(copyTimer);
    $('copy-status').textContent = copied ? 'Recipe copied' : 'Copy unavailable in this browser';
    copyTimer = setTimeout(() => { $('copy-status').textContent = ''; }, 4000);
  });
  reducedMotion.addEventListener('change', render);
  render();
})();
