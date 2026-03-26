// ============================================================
//  UI: HUD, settings drawer, weather selector
// ============================================================

function setupUI() {
  // Weather cycle button
  document.getElementById('weather-btn').addEventListener('click', cycleWeather);

  // Speed control
  document.querySelectorAll('#speed-ctrl button').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#speed-ctrl button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      timeSpeed = parseFloat(btn.dataset.speed);
    });
  });
}

function setupSettings() {
  const drawer = document.getElementById('settings-drawer');
  const overlay = document.getElementById('settings-overlay');
  const openBtn = document.getElementById('settings-btn');
  const closeBtn = drawer.querySelector('.settings-close');

  function toggleDrawer(open) {
    drawer.classList.toggle('open', open);
    overlay.classList.toggle('open', open);
  }
  openBtn.addEventListener('click', () => toggleDrawer(true));
  closeBtn.addEventListener('click', () => toggleDrawer(false));
  overlay.addEventListener('click', () => toggleDrawer(false));

  function syncUI() {
    document.getElementById('s-grass').value = gfx.grassCount;
    document.getElementById('sv-grass').textContent = (gfx.grassCount / 1000) + 'K';
    document.getElementById('s-pixelratio').value = gfx.pixelRatio;
    document.getElementById('sv-pixelratio').textContent = gfx.pixelRatio.toFixed(2);
    document.getElementById('s-drawdist').value = gfx.drawDist;
    document.getElementById('sv-drawdist').textContent = gfx.drawDist;
    document.getElementById('s-shadows').checked = gfx.shadows;
    document.querySelectorAll('[data-shadow]').forEach(b => {
      b.classList.toggle('active', parseInt(b.dataset.shadow) === gfx.shadowRes);
    });
    document.getElementById('s-bloom').checked = gfx.bloom;
    document.getElementById('s-bloomstr').value = gfx.bloomStrength;
    document.getElementById('sv-bloomstr').textContent = gfx.bloomStrength.toFixed(2);
    document.getElementById('s-antialias').checked = gfx.antialias;
    document.getElementById('s-clouds').value = gfx.cloudCount;
    document.getElementById('sv-clouds').textContent = gfx.cloudCount;
    document.getElementById('s-rain').value = gfx.rainCount;
    document.getElementById('sv-rain').textContent = (gfx.rainCount / 1000) + 'K';
    document.getElementById('s-fog').value = gfx.fogDensity;
    document.getElementById('sv-fog').textContent = gfx.fogDensity.toFixed(4);
    document.getElementById('s-fps').checked = gfx.showFps;
    document.getElementById('s-fogparticles').checked = gfx.fogParticles;
  }

  // Presets
  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const p = PRESETS[btn.dataset.preset];
      if (!p) return;
      Object.assign(gfx, p);
      document.querySelectorAll('.preset-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      syncUI();
      applyAllSettings();
    });
  });

  // Slider helper
  function bindSlider(id, valueId, key, fmt, apply) {
    const slider = document.getElementById(id);
    const val = document.getElementById(valueId);
    slider.addEventListener('input', () => {
      gfx[key] = parseFloat(slider.value);
      val.textContent = fmt(gfx[key]);
      clearActivePreset();
    });
    slider.addEventListener('change', () => { if (apply) apply(); });
  }

  bindSlider('s-grass', 'sv-grass', 'grassCount', v => (v / 1000) + 'K', rebuildAllChunks);
  bindSlider('s-pixelratio', 'sv-pixelratio', 'pixelRatio', v => v.toFixed(2), () => {
    renderer.setPixelRatio(gfx.pixelRatio);
    composer.setSize(window.innerWidth, window.innerHeight);
  });
  bindSlider('s-drawdist', 'sv-drawdist', 'drawDist', v => v, () => {
    camera.far = gfx.drawDist;
    camera.updateProjectionMatrix();
  });
  bindSlider('s-bloomstr', 'sv-bloomstr', 'bloomStrength', v => v.toFixed(2), () => {
    if (bloomPass) bloomPass.strength = gfx.bloomStrength;
  });
  bindSlider('s-clouds', 'sv-clouds', 'cloudCount', v => v, rebuildClouds);
  bindSlider('s-rain', 'sv-rain', 'rainCount', v => (v / 1000) + 'K', () => { rebuildRain(); rebuildSnow(); });
  bindSlider('s-fog', 'sv-fog', 'fogDensity', v => v.toFixed(4), () => {
    scene.fog.density = gfx.fogDensity;
  });

  // Toggles
  document.getElementById('s-shadows').addEventListener('change', e => {
    gfx.shadows = e.target.checked;
    renderer.shadowMap.enabled = gfx.shadows;
    for (const [, chunk] of chunks) {
      if (chunk.terrain) chunk.terrain.receiveShadow = gfx.shadows;
      if (chunk.grassMesh) chunk.grassMesh.castShadow = gfx.shadows;
    }
    clearActivePreset();
  });
  document.getElementById('s-bloom').addEventListener('change', e => {
    gfx.bloom = e.target.checked;
    if (bloomPass) bloomPass.enabled = gfx.bloom;
    clearActivePreset();
  });
  document.getElementById('s-antialias').addEventListener('change', () => clearActivePreset());
  document.getElementById('s-fps').addEventListener('change', e => {
    gfx.showFps = e.target.checked;
    document.getElementById('fps-counter').style.display = gfx.showFps ? 'block' : 'none';
  });
  document.getElementById('s-fogparticles').addEventListener('change', e => {
    gfx.fogParticles = e.target.checked;
    if (!gfx.fogParticles) {
      fogSprites.forEach(s => { scene.remove(s); s.material.dispose(); });
      fogSprites = [];
    } else {
      createFogParticles();
    }
  });

  // Shadow res
  document.querySelectorAll('[data-shadow]').forEach(btn => {
    btn.addEventListener('click', () => {
      gfx.shadowRes = parseInt(btn.dataset.shadow);
      document.querySelectorAll('[data-shadow]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      sunLight.shadow.mapSize.set(gfx.shadowRes, gfx.shadowRes);
      if (sunLight.shadow.map) { sunLight.shadow.map.dispose(); sunLight.shadow.map = null; }
      clearActivePreset();
    });
  });

  function clearActivePreset() {
    document.querySelectorAll('.preset-btn').forEach(b => b.classList.remove('active'));
  }

  // Mobile auto-detect
  if (/Android|iPhone|iPod|iPad/.test(navigator.userAgent) || window.innerWidth < 600) {
    const lowBtn = document.querySelector('[data-preset="low"]');
    if (lowBtn) lowBtn.click();
  }

  syncUI();
}

function rebuildAllChunks() {
  for (const [key, chunk] of chunks) {
    disposeChunk(chunk);
  }
  chunks.clear();
  currentChunkX = -999; // Force re-creation
  updateChunks();
}

function applyAllSettings() {
  renderer.setPixelRatio(gfx.pixelRatio);
  composer.setSize(window.innerWidth, window.innerHeight);
  camera.far = gfx.drawDist;
  camera.updateProjectionMatrix();
  scene.fog.density = gfx.fogDensity;
  renderer.shadowMap.enabled = gfx.shadows;
  sunLight.shadow.mapSize.set(gfx.shadowRes, gfx.shadowRes);
  if (sunLight.shadow.map) { sunLight.shadow.map.dispose(); sunLight.shadow.map = null; }
  if (bloomPass) { bloomPass.enabled = gfx.bloom; bloomPass.strength = gfx.bloomStrength; }
  document.getElementById('fps-counter').style.display = gfx.showFps ? 'block' : 'none';
  rebuildAllChunks();
  rebuildClouds();
  rebuildRain();
  rebuildSnow();
  createFogParticles();
}

function updateHUD() {
  // Time display
  const hours = Math.floor(gameTime * 24);
  const mins = Math.floor((gameTime * 24 - hours) * 60);
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const h12 = hours % 12 || 12;
  document.getElementById('time-display').textContent = `${h12}:${mins.toString().padStart(2, '0')} ${ampm}`;

  // Stats
  let totalBlades = 0, grownCount = 0;
  for (const [, chunk] of chunks) {
    if (!chunk.blades) continue;
    chunk.blades.forEach(b => {
      totalBlades++;
      if (b.grown && b.health > 0.5) grownCount++;
    });
  }
  document.getElementById('blade-count').textContent = grownCount.toLocaleString();
  document.getElementById('avg-height').textContent = totalBlades > 0 ?
    (totalGrassScore / Math.max(1, grownCount) * 0.2).toFixed(1) + ' cm' : '0.0 cm';
  document.getElementById('grass-score').textContent = totalGrassScore.toLocaleString();

  // Weather
  document.getElementById('weather-display').textContent =
    WEATHER_ICONS[currentWeather] + ' ' + WEATHER_NAMES[currentWeather];
  document.getElementById('weather-btn').textContent =
    WEATHER_ICONS[currentWeather] + ' ' + WEATHER_NAMES[currentWeather].toUpperCase();

  // Wind
  const windNames = ['Calm', 'Breeze', 'Windy', 'Gusty', 'INTENSE', 'EXTREME'];
  const wi = Math.min(5, Math.floor(windStrength * 4));
  document.getElementById('wind-display').textContent = windNames[wi];

  // FPS
  fpsFrames++;
  fpsTime += clock.getDelta ? 0 : 0; // handled in main loop
}
