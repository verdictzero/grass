// ============================================================
//  Main: init, animate loop, start
// ============================================================

function init() {
  scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0x88bbee, gfx.fogDensity);
  clock = new THREE.Clock();

  camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.5, gfx.drawDist);
  camera.position.set(0, 20, 45);

  renderer = new THREE.WebGLRenderer({ antialias: gfx.antialias });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(gfx.pixelRatio);
  renderer.shadowMap.enabled = gfx.shadows;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.1;
  document.body.appendChild(renderer.domElement);

  // Post-processing
  composer = new THREE.EffectComposer(renderer);
  composer.addPass(new THREE.RenderPass(scene, camera));
  bloomPass = new THREE.UnrealBloomPass(
    new THREE.Vector2(window.innerWidth, window.innerHeight),
    gfx.bloomStrength, 0.6, 0.85
  );
  bloomPass.enabled = gfx.bloom;
  composer.addPass(bloomPass);

  // Shared dummy for matrix calculations
  dummy = new THREE.Object3D();
  camTarget = new THREE.Vector3(0, 8, 0);
  sunDir = new THREE.Vector3(0, 1, 0);
  moonDir = new THREE.Vector3(0, -1, 0);

  // Create all systems
  createSky();
  createLights();
  createClouds();
  createRain();
  createSnow();
  createFogParticles();
  createFlares();
  setupControls();

  // Initial chunks
  currentChunkX = -999;
  updateChunks();

  animate();
}

function animate() {
  requestAnimationFrame(animate);
  const dt = Math.min(clock.getDelta(), 0.05);
  realTime += dt;

  // --- TIME ---
  gameTime += (dt * timeSpeed) / 120;
  gameTime = gameTime % 1;

  // --- SUN/MOON POSITION ---
  const sunAngle = gameTime * Math.PI * 2 - Math.PI / 2;
  const sunX = Math.cos(sunAngle) * 200;
  const sunY = Math.sin(sunAngle) * 200;
  sunDir = new THREE.Vector3(sunX, sunY, 50).normalize();
  moonDir = sunDir.clone().negate();

  // --- DAY FACTOR ---
  dayFactor = Math.max(0, Math.min(1, (sunDir.y + 0.1) / 0.4));

  // --- WEATHER ---
  updateWeather(dt);

  // --- LIGHTING ---
  updateLights(dt);

  // --- SKY ---
  updateSky(dt);

  // --- FOG ---
  const rainVal = wVal.overcast;
  const snowVal = wVal.snow;
  const baseFogR = 0.55 * dayFactor + 0.05;
  const baseFogG = 0.7 * dayFactor + 0.05;
  const baseFogB = 0.85 * dayFactor + 0.1;
  let fogR = baseFogR * (1 - rainVal * 0.3);
  let fogG = baseFogG * (1 - rainVal * 0.3);
  let fogB = baseFogB * (1 - rainVal * 0.2);
  // Snow whitens fog
  fogR = fogR * (1 - snowVal * 0.3) + snowVal * 0.3 * 0.8;
  fogG = fogG * (1 - snowVal * 0.3) + snowVal * 0.3 * 0.82;
  fogB = fogB * (1 - snowVal * 0.3) + snowVal * 0.3 * 0.85;
  scene.fog.color.setRGB(fogR, fogG, fogB);
  renderer.setClearColor(scene.fog.color);

  // Dynamic fog density
  scene.fog.density = gfx.fogDensity * wVal.fogMult;

  // Exposure
  const rainDamp = rainVal;
  renderer.toneMappingExposure = (0.4 + dayFactor * 0.8) * (1 - rainDamp * 0.25);

  // --- WIND ---
  // (handled in updateWeather)

  // --- CHUNKS ---
  updateChunks();

  // --- GRASS ---
  updateGrass(dt);

  // --- TERRAIN UNIFORMS ---
  updateTerrainUniforms();

  // --- CLOUDS ---
  updateClouds(dt);

  // --- RAIN ---
  updateRain(dt);

  // --- SNOW ---
  updateSnow(dt);

  // --- FOG PARTICLES ---
  updateFogParticles(dt);

  // --- LIGHTNING ---
  updateLightning(dt);

  // --- TORNADO ---
  updateTornado(dt);

  // --- LENS FLARES ---
  updateFlares(dt);

  // --- CAMERA ---
  updateCamera(dt);

  // --- HUD ---
  updateHUD();

  // --- FPS ---
  fpsFrames++;
  fpsTime += dt;
  if (fpsTime >= 0.5) {
    const fps = Math.round(fpsFrames / fpsTime);
    document.getElementById('fps-counter').textContent = fps + ' FPS';
    fpsFrames = 0;
    fpsTime = 0;
  }

  // --- RENDER ---
  composer.render();
}

// --- START ---
document.getElementById('start-btn').addEventListener('click', () => {
  document.getElementById('title-screen').classList.add('hidden');
  document.getElementById('hud').style.display = 'flex';
  document.getElementById('controls-hint').style.display = 'block';
  document.getElementById('weather-btn').style.display = 'block';
  document.getElementById('speed-ctrl').style.display = 'flex';
  document.getElementById('settings-btn').style.display = 'flex';
  init();
  setupUI();
  setupSettings();
});
