import './site.css';

const body = document.body;
const canvas = document.querySelector('#canvas');
const stage = document.querySelector('#stage');
const play = document.querySelector('#play');
const retry = document.querySelector('#retry');
const progress = document.querySelector('#progress');
const status = document.querySelector('#status');
const home = document.querySelector('#home');
const fullscreen = document.querySelector('#fullscreen');
const gameStatus = document.querySelector('#game-status');
const storage = document.querySelector('#storage');
const motionButton = document.querySelector('#motion');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let engine;
let booted = false;
let startup = null;
let loader = null;
let mode = 'arena';
let sceneMode = 'arena';
let focusListener = null;
let fullscreenListener = null;
let watchdog = null;
let lastProgressAt = 0;
let lastProgress = -1;
let diorama = null;
let sceneLoading = null;
let sceneRetired = false;
let sceneReady = false;
let sceneFailed = false;
let motionPreference = null;
try { motionPreference = localStorage.getItem('gloamthread.website.motion'); } catch { /* Website preferences are optional. */ }
let motion = motionPreference === null ? !reducedMotion.matches : motionPreference === 'on';

function setState(state) {
  body.dataset.gameState = state;
  body.classList.toggle('playing', state === 'playing');
  body.classList.toggle('loading', state === 'loading');
  home.disabled = !booted || state !== 'playing';
  body.style.setProperty('--storage-height', `${storage.hidden ? 0 : storage.offsetHeight}px`);
}

function resize() {
  if (!engine || !['loading', 'playing'].includes(body.dataset.gameState)) return;
  const unit = mode === 'story' ? [960, 360] : [640, 360];
  const ratio = window.devicePixelRatio || 1;
  const available = Math.min(stage.clientWidth * ratio / unit[0], stage.clientHeight * ratio / unit[1]);
  const factor = Math.max(1, Math.floor(available));
  const width = unit[0] * factor;
  const height = unit[1] * factor;
  if (canvas.width !== width) canvas.width = width;
  if (canvas.height !== height) canvas.height = height;
  // Whole physical pixels when they fit; undersized windows still show the complete view.
  const displayFactor = available < 1 ? available : factor;
  canvas.style.width = `${unit[0] * displayFactor / ratio}px`;
  canvas.style.height = `${unit[1] * displayFactor / ratio}px`;
}

function loseFocus() {
  if (focusListener && ['playing', 'loading'].includes(body.dataset.gameState)) focusListener();
}

function stopWatchdog() {
  clearInterval(watchdog);
  watchdog = null;
}

function startWatchdog() {
  stopWatchdog();
  lastProgress = -1;
  lastProgressAt = performance.now();
  watchdog = setInterval(() => {
    if (performance.now() - lastProgressAt < 30000) return;
    status.textContent = 'Loading is taking longer than usual. You can wait, or Retry loading.';
    retry.hidden = false;
  }, 1000);
}

function retireScene() {
  sceneRetired = true;
  diorama?.dispose();
  diorama = null;
  sceneReady = false;
  body.classList.remove('diorama-ready');
  body.classList.add('scene-static');
}

async function loadScene() {
  if (sceneRetired || sceneFailed || !motion || sceneLoading || diorama) return;
  sceneLoading = import('./diorama.js').then(({ createDiorama }) => {
    if (sceneRetired || !motion) return;
    const instance = createDiorama(document.querySelector('#diorama'), {
      motion,
      onReady() { sceneReady = true; if (!sceneRetired && motion) body.classList.add('diorama-ready'); },
      onError() { sceneReady = false; sceneFailed = true; body.classList.remove('diorama-ready'); body.classList.add('scene-static'); },
    });
    if (sceneRetired) instance?.dispose();
    else {
      diorama = instance;
      diorama?.setMode(sceneMode);
    }
  }).catch(() => {
    sceneFailed = true;
    body.classList.add('scene-static');
  }).finally(() => { sceneLoading = null; });
  await sceneLoading;
}

function updateMotion() {
  motionButton.setAttribute('aria-checked', String(motion));
  motionButton.querySelector('span').textContent = motion ? 'Motion on' : 'Motion off';
  body.classList.toggle('motion-off', !motion);
  diorama?.setMotion(motion);
  if (motion && !sceneRetired) loadScene();
  if (!motion) body.classList.remove('diorama-ready');
  else if (diorama && sceneReady && !sceneRetired) body.classList.add('diorama-ready');
}

function loadEngine() {
  if (loader) return loader;
  loader = new Promise((resolve, reject) => {
    if (typeof window.Engine !== 'undefined') return resolve();
    const script = document.createElement('script');
    script.src = window.GloamGameConfig.url;
    script.onload = () => typeof window.Engine === 'undefined'
      ? reject(new Error('The game loader did not initialize.')) : resolve();
    script.onerror = () => reject(new Error('The game loader could not download.'));
    document.head.append(script);
  });
  return loader;
}

function resume() {
  setState('playing');
  resize();
  canvas.focus();
}

async function beginGame() {
  if (booted) return resume();
  if (startup || body.dataset.gameState === 'error') return;
  play.disabled = true;
  progress.hidden = false;
  progress.removeAttribute('value');
  retry.hidden = true;
  status.textContent = 'Loading the world…';
  setState('loading');
  retireScene();
  startWatchdog();
  startup = (async () => {
    try {
      await loadEngine();
      if (!window.WebAssembly || !window.Engine.isWebGLAvailable(2)) {
        throw new Error('This browser needs WebAssembly and WebGL 2. Try a current Chrome, Edge or Firefox browser.');
      }
      engine = new window.Engine(window.GloamGameConfig.config);
      resize();
      await engine.startGame({
        canvas, canvasResizePolicy: 0, focusCanvas: true,
        onProgress(current, total) {
          const changed = current !== lastProgress;
          if (changed) {
            lastProgress = current;
            lastProgressAt = performance.now();
            retry.hidden = true;
          }
          if (total) progress.value = current / total * 100;
          if (changed) status.textContent = total ? `Loading the world… ${Math.round(progress.value)}%` : 'Loading the world…';
        },
        onPrintError(message) { console.error(message); },
      });
      booted = true;
      stopWatchdog();
      progress.hidden = true;
      retry.hidden = true;
      play.disabled = false;
      document.querySelectorAll('[data-guide]').forEach(link => { link.target = '_blank'; link.rel = 'noopener'; });
      resume();
    } catch (error) {
      stopWatchdog();
      setState('error');
      progress.hidden = true;
      retry.hidden = false;
      status.textContent = `${error?.message || String(error)} Press Retry loading to try again.`;
      // Partial engine startup is recovered by one explicit reload, never a second instance.
      play.disabled = true;
      retry.focus();
    }
  })();
  await startup;
}

window.GloamWeb = {
  setMode(value) { mode = value === 'story' ? 'story' : 'arena'; body.dataset.mode = mode; resize(); },
  onFocusLoss(callback) { focusListener = callback; },
  onFullscreenChange(callback) { fullscreenListener = callback; },
  storageWarning(message) {
    storage.textContent = message;
    storage.hidden = !message;
    body.style.setProperty('--storage-height', `${storage.hidden ? 0 : storage.offsetHeight}px`);
    resize();
  },
  home() {
    if (!booted) return;
    loseFocus();
    setState('home');
    status.textContent = 'Your game is still open. Press Resume to return.';
    play.innerHTML = 'Resume game <span aria-hidden="true">→</span>';
    play.disabled = false;
    play.focus();
  },
  async fullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
      gameStatus.textContent = 'Esc · pause / saves stay in this browser';
      canvas.focus();
    } catch {
      gameStatus.textContent = 'Fullscreen is unavailable. You can keep playing in the browser.';
    }
  },
};

play.addEventListener('click', beginGame);
retry.addEventListener('click', () => location.reload());
home.addEventListener('click', () => window.GloamWeb.home());
fullscreen.addEventListener('click', () => window.GloamWeb.fullscreen());
window.addEventListener('resize', () => {
  body.style.setProperty('--storage-height', `${storage.hidden ? 0 : storage.offsetHeight}px`);
  resize();
});
window.addEventListener('blur', loseFocus);
document.addEventListener('visibilitychange', () => { if (document.hidden) loseFocus(); });
document.addEventListener('fullscreenchange', () => {
  fullscreen.textContent = document.fullscreenElement ? 'Exit fullscreen' : 'Fullscreen';
  resize();
  if (fullscreenListener) fullscreenListener();
});
canvas.addEventListener('keydown', event => {
  if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.code)) event.preventDefault();
});
motionButton.addEventListener('click', () => {
  motion = !motion;
  motionPreference = motion ? 'on' : 'off';
  try { localStorage.setItem('gloamthread.website.motion', motionPreference); } catch { /* Play does not require storage. */ }
  updateMotion();
});
reducedMotion.addEventListener('change', () => {
  if (motionPreference !== null) return;
  motion = !reducedMotion.matches;
  updateMotion();
});
const tabs = [...document.querySelectorAll('[data-scene]')];
function selectScene(tab) {
  sceneMode = tab.dataset.scene;
  tabs.forEach(item => {
    const active = item === tab;
    item.setAttribute('aria-selected', String(active));
    item.tabIndex = active ? 0 : -1;
  });
  document.querySelector('#scene-status').textContent = `${sceneMode === 'arena' ? 'Arena' : 'Story'} scene`;
  diorama?.setMode(sceneMode);
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectScene(tab));
  tab.addEventListener('keydown', event => {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
    event.preventDefault();
    const next = event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : (index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
    selectScene(tabs[next]);
    tabs[next].focus();
  });
});
updateMotion();
// A guide Play link focuses the real button; audio starts from a deliberate click.
if (location.hash === '#play') play.focus();
