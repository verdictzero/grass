// ============================================================
//  Tornado funnel effect
// ============================================================

const TORNADO_PARTICLES = 800;

function createTornado() {
  if (tornadoSystem) {
    scene.remove(tornadoSystem);
    tornadoSystem.geometry.dispose();
    tornadoSystem.material.dispose();
  }

  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(TORNADO_PARTICLES * 3);
  const sizes = new Float32Array(TORNADO_PARTICLES);
  const offsets = new Float32Array(TORNADO_PARTICLES); // angle offset
  const heights = new Float32Array(TORNADO_PARTICLES); // normalized height 0-1

  for (let i = 0; i < TORNADO_PARTICLES; i++) {
    const h = Math.random();
    const angle = Math.random() * Math.PI * 2;
    heights[i] = h;
    offsets[i] = angle;
    sizes[i] = 0.5 + Math.random() * 2.0;

    // Initial position will be computed in update
    positions[i * 3] = 0;
    positions[i * 3 + 1] = h * 80;
    positions[i * 3 + 2] = 0;
  }

  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geo.setAttribute('size', new THREE.BufferAttribute(sizes, 1));

  const mat = new THREE.PointsMaterial({
    color: 0x555555,
    size: 2.0,
    transparent: true,
    opacity: 0.4,
    depthWrite: false,
    sizeAttenuation: true
  });

  tornadoSystem = new THREE.Points(geo, mat);
  tornadoSystem.userData = { offsets, heights };
  scene.add(tornadoSystem);
}

function updateTornado(dt) {
  if (currentWeather !== WEATHER.TORNADO || !tornadoPos || !tornadoSystem) return;

  // Wander slowly
  if (!tornadoWanderTarget ||
      tornadoPos.distanceTo(tornadoWanderTarget) < 5) {
    tornadoWanderTarget = new THREE.Vector3(
      camTarget.x + (Math.random() - 0.5) * 400,
      0,
      camTarget.z + (Math.random() - 0.5) * 400
    );
  }

  const wanderDir = tornadoWanderTarget.clone().sub(tornadoPos).normalize();
  const wanderSpeed = 15 * dt;
  tornadoPos.x += wanderDir.x * wanderSpeed;
  tornadoPos.z += wanderDir.z * wanderSpeed;
  tornadoPos.y = getTerrainHeight(tornadoPos.x, tornadoPos.z);

  // Rotate
  tornadoAngle += dt * 4;

  // Update particle positions
  const pos = tornadoSystem.geometry.attributes.position;
  const offsets = tornadoSystem.userData.offsets;
  const heights = tornadoSystem.userData.heights;

  for (let i = 0; i < TORNADO_PARTICLES; i++) {
    const h = heights[i];
    const angle = offsets[i] + tornadoAngle * (1 + h * 0.5);

    // Funnel shape: narrow at bottom, wider at top
    const radius = 3 + h * h * 35;
    // Add some noise to radius
    const noiseR = Math.sin(angle * 3 + realTime) * 2 * h;

    const px = tornadoPos.x + Math.cos(angle) * (radius + noiseR);
    const py = tornadoPos.y + h * 80;
    const pz = tornadoPos.z + Math.sin(angle) * (radius + noiseR);

    pos.setXYZ(i, px, py, pz);
  }
  pos.needsUpdate = true;

  // Darken tornado particles based on density
  tornadoSystem.material.opacity = 0.3 + Math.sin(realTime * 2) * 0.1;
}
