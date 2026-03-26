// ============================================================
//  Weather state machine + rain/snow particle systems
// ============================================================

function cycleWeather() {
  currentWeather = (currentWeather + 1) % WEATHER_NAMES.length;
  onWeatherChange();
}

function setWeather(type) {
  currentWeather = type;
  onWeatherChange();
}

function onWeatherChange() {
  // Tornado init
  if (currentWeather === WEATHER.TORNADO && !tornadoPos) {
    tornadoPos = new THREE.Vector3(
      camTarget.x + (Math.random() - 0.5) * 200,
      0,
      camTarget.z + (Math.random() - 0.5) * 200
    );
    tornadoPos.y = getTerrainHeight(tornadoPos.x, tornadoPos.z);
    tornadoWanderTarget = tornadoPos.clone();
    createTornado();
  }
  if (currentWeather !== WEATHER.TORNADO) {
    tornadoPos = null;
    if (tornadoSystem) {
      scene.remove(tornadoSystem);
      tornadoSystem.geometry.dispose();
      tornadoSystem.material.dispose();
      tornadoSystem = null;
    }
  }

  // Hurricane wind rotation
  if (currentWeather === WEATHER.HURRICANE) {
    windDirTarget = windDirection;
  }
}

function updateWeather(dt) {
  const props = WEATHER_PROPS[currentWeather];
  const tdt = dt * 3; // transition speed

  // Smooth interpolation of weather values
  wVal.rain += (props.rain - wVal.rain) * tdt;
  wVal.snow += (props.snow - wVal.snow) * tdt;
  wVal.fogMult += (props.fogMult - wVal.fogMult) * tdt;
  wVal.cloudDark += (props.cloudDark - wVal.cloudDark) * tdt;
  wVal.overcast += (props.overcast - wVal.overcast) * tdt;

  // Wind
  const [windMin, windMax] = props.windRange;
  const windTarget = windMin + Math.sin(realTime * 0.1) * (windMax - windMin) * 0.5 + (windMax - windMin) * 0.5;
  windStrength += (windTarget - windStrength) * dt * 2;

  // Wind direction
  if (currentWeather === WEATHER.HURRICANE) {
    // Rotating wind
    windDirTarget += dt * 0.5;
  } else if (currentWeather === WEATHER.TORNADO && tornadoPos) {
    // Pull toward tornado
    const toTornado = Math.atan2(tornadoPos.z - camTarget.z, tornadoPos.x - camTarget.x);
    windDirTarget += (toTornado - windDirTarget) * dt * 2;
  } else {
    windDirTarget += (Math.random() - 0.5) * 0.02;
  }
  windDirection += (windDirTarget - windDirection) * dt * 3;

  // Track rain time for drought
  if (wVal.rain > 0.3) {
    timeSinceRain = 0;
  } else {
    timeSinceRain += dt * timeSpeed;
  }

  // Snow cover accumulation
  if (wVal.snow > 0.3) {
    snowCover = Math.min(1, snowCover + dt * 0.05 * timeSpeed);
  } else {
    snowCover = Math.max(0, snowCover - dt * 0.03 * timeSpeed);
  }
}

// --- RAIN SYSTEM ---
function createRain() {
  if (rainSystem) {
    scene.remove(rainSystem);
    rainSystem.geometry.dispose();
    rainSystem.material.dispose();
    rainSystem = null;
  }

  const count = gfx.rainCount;
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  const velocities = new Float32Array(count);

  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 400;
    positions[i * 3 + 1] = Math.random() * 120;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 400;
    velocities[i] = 30 + Math.random() * 25;
  }
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));

  const mat = new THREE.PointsMaterial({
    color: 0xaaccff,
    size: 0.4,
    transparent: true,
    opacity: 0,
    depthWrite: false
  });

  rainSystem = new THREE.Points(geo, mat);
  rainSystem.userData.velocities = velocities;
  scene.add(rainSystem);
}

function updateRain(dt) {
  if (!rainSystem) return;

  const targetOp = Math.min(0.6, wVal.rain * 0.3);
  rainSystem.material.opacity += (targetOp - rainSystem.material.opacity) * dt * 3;

  if (rainSystem.material.opacity > 0.01) {
    const pos = rainSystem.geometry.attributes.position;
    const vel = rainSystem.userData.velocities;
    const windPush = windStrength * dt * (currentWeather === WEATHER.HURRICANE ? 25 : 8);

    for (let i = 0; i < pos.count; i++) {
      let py = pos.getY(i) - vel[i] * dt * (1 + wVal.rain * 0.3);
      if (py < -5) py = 80 + Math.random() * 40;
      pos.setY(i, py);
      pos.setX(i, pos.getX(i) + Math.cos(windDirection) * windPush);
      pos.setZ(i, pos.getZ(i) + Math.sin(windDirection) * windPush);

      // Re-center around camera
      if (Math.abs(pos.getX(i) - camTarget.x) > 200) pos.setX(i, camTarget.x + (Math.random() - 0.5) * 400);
      if (Math.abs(pos.getZ(i) - camTarget.z) > 200) pos.setZ(i, camTarget.z + (Math.random() - 0.5) * 400);
    }
    pos.needsUpdate = true;
  }
  rainSystem.position.set(0, 0, 0);
}

// --- SNOW SYSTEM ---
function createSnow() {
  if (snowSystem) {
    scene.remove(snowSystem);
    snowSystem.geometry.dispose();
    snowSystem.material.dispose();
    snowSystem = null;
  }

  const count = Math.floor(gfx.rainCount * 0.6);
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  const velocities = new Float32Array(count);
  const phases = new Float32Array(count); // for lateral drift

  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 400;
    positions[i * 3 + 1] = Math.random() * 100;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 400;
    velocities[i] = 5 + Math.random() * 10;
    phases[i] = Math.random() * Math.PI * 2;
  }
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));

  const mat = new THREE.PointsMaterial({
    color: 0xeef4ff,
    size: 1.2,
    transparent: true,
    opacity: 0,
    depthWrite: false
  });

  snowSystem = new THREE.Points(geo, mat);
  snowSystem.userData.velocities = velocities;
  snowSystem.userData.phases = phases;
  scene.add(snowSystem);
}

function updateSnow(dt) {
  if (!snowSystem) return;

  const targetOp = wVal.snow > 0.3 ? 0.6 : 0;
  snowSystem.material.opacity += (targetOp - snowSystem.material.opacity) * dt * 3;

  if (snowSystem.material.opacity > 0.01) {
    const pos = snowSystem.geometry.attributes.position;
    const vel = snowSystem.userData.velocities;
    const phases = snowSystem.userData.phases;

    for (let i = 0; i < pos.count; i++) {
      let py = pos.getY(i) - vel[i] * dt;
      if (py < -2) py = 80 + Math.random() * 30;
      pos.setY(i, py);

      // Gentle sine drift
      const drift = Math.sin(realTime * 0.8 + phases[i]) * 0.5;
      pos.setX(i, pos.getX(i) + (drift + Math.cos(windDirection) * windStrength * 2) * dt);
      pos.setZ(i, pos.getZ(i) + (Math.cos(realTime * 0.6 + phases[i]) * 0.3 + Math.sin(windDirection) * windStrength * 2) * dt);

      // Re-center
      if (Math.abs(pos.getX(i) - camTarget.x) > 200) pos.setX(i, camTarget.x + (Math.random() - 0.5) * 400);
      if (Math.abs(pos.getZ(i) - camTarget.z) > 200) pos.setZ(i, camTarget.z + (Math.random() - 0.5) * 400);
    }
    pos.needsUpdate = true;
  }
}

function rebuildRain() { createRain(); }
function rebuildSnow() { createSnow(); }
