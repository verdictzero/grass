// ============================================================
//  Chunk-based grass with health/death system
// ============================================================

// Shared grass shaders
const GRASS_VERT = `
  uniform float uTime;
  uniform float uWindStr;
  uniform vec2 uWindDir;

  attribute float aHealth;
  varying float vY;
  varying vec3 vWorldPos;
  varying float vHealth;

  void main() {
    vHealth = aHealth;

    // Scale down dead grass (wilt) in local space before instance transform
    float wiltScale = 0.3 + 0.7 * smoothstep(0.0, 0.4, aHealth);
    vec3 localPos = position * vec3(1.0, wiltScale, 1.0);

    vec4 mvPos = instanceMatrix * vec4(localPos, 1.0);
    vWorldPos = (modelMatrix * mvPos).xyz;

    // Wind displacement
    float windPhase = dot(vWorldPos.xz, normalize(uWindDir) * 0.15) + uTime * 2.5;
    float windWave = sin(windPhase) * 0.5 + sin(windPhase * 2.3 + 1.5) * 0.25 + sin(windPhase * 0.7 + 3.0) * 0.25;
    float heightFactor = localPos.y;

    mvPos.x += windWave * uWindStr * heightFactor * 1.8;
    mvPos.z += windWave * uWindStr * heightFactor * 0.6 * sin(uTime * 0.5 + vWorldPos.x);

    vY = localPos.y;
    gl_Position = projectionMatrix * modelViewMatrix * mvPos;
  }
`;

const GRASS_FRAG = `
  uniform vec3 uSunDir;
  uniform float uDayFactor;
  uniform float uSnowCover;
  varying float vY;
  varying vec3 vWorldPos;
  varying float vHealth;

  ${GLSL_NOISE}

  void main() {
    // Healthy color gradient
    vec3 baseGreen = vec3(${PALETTE.grass1.join(',')});
    vec3 tipGreen = vec3(${PALETTE.grassTip.join(',')});
    vec3 healthyCol = mix(baseGreen, tipGreen, vY);

    // Dead/dying colors
    vec3 yellowCol = vec3(${PALETTE.yellow.join(',')});
    vec3 deadCol = vec3(${PALETTE.dead.join(',')});

    // Blend based on health
    vec3 col;
    if (vHealth > 0.5) {
      col = mix(yellowCol, healthyCol, (vHealth - 0.5) * 2.0);
    } else {
      col = mix(deadCol, yellowCol, vHealth * 2.0);
    }

    // Per-blade variation (matches terrain noise pattern)
    float n = noise2D(vWorldPos.xz * 0.05);
    float n2 = noise2D(floor(vWorldPos.xz * 2.0));
    col *= 0.85 + n * 0.2 + n2 * 0.1;

    // Sun lighting
    float sunFactor = max(uSunDir.y, 0.0) * 0.6 + 0.15;
    vec3 sunLit = col * sunFactor * vec3(1.0, 0.97, 0.9);

    // Moon lighting — stronger
    float moonFactor = max(-uSunDir.y, 0.0) * 0.5;
    vec3 moonLit = col * moonFactor * vec3(0.4, 0.5, 0.8);

    // Ambient
    vec3 ambLit = col * mix(0.12, 0.22, uDayFactor);

    vec3 finalCol = sunLit * uDayFactor + moonLit * (1.0 - uDayFactor) + ambLit;

    // Snow on tips
    float snowOnBlade = uSnowCover * vY * (0.7 + n * 0.3);
    float snowLight = max(sunFactor * uDayFactor, moonFactor * (1.0 - uDayFactor)) + 0.15;
    finalCol = mix(finalCol, vec3(0.88, 0.9, 0.95) * snowLight, snowOnBlade);

    gl_FragColor = vec4(finalCol, 1.0);
  }
`;

let _bladeGeoTemplate = null;
function createGrassBlade() {
  if (!_bladeGeoTemplate) {
    _bladeGeoTemplate = new THREE.BufferGeometry();
    const verts = new Float32Array([
      -0.06, 0, 0,  0.06, 0, 0,  0.04, 0.5, 0,
      -0.06, 0, 0,  0.04, 0.5, 0, -0.04, 0.5, 0,
      -0.04, 0.5, 0, 0.04, 0.5, 0, 0.0, 1.0, 0,
    ]);
    const uvs = new Float32Array([
      0, 0, 1, 0, 1, 0.5,
      0, 0, 1, 0.5, 0, 0.5,
      0, 0.5, 1, 0.5, 0.5, 1.0,
    ]);
    _bladeGeoTemplate.setAttribute('position', new THREE.BufferAttribute(verts, 3));
    _bladeGeoTemplate.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
  }
  return _bladeGeoTemplate.clone();
}

function createGrassMaterial() {
  return new THREE.ShaderMaterial({
    side: THREE.DoubleSide,
    uniforms: {
      uTime: { value: 0 },
      uWindStr: { value: 0.3 },
      uWindDir: { value: new THREE.Vector2(1, 0.5) },
      uSunDir: { value: new THREE.Vector3(0, 1, 0) },
      uDayFactor: { value: 1.0 },
      uSnowCover: { value: 0 }
    },
    vertexShader: GRASS_VERT,
    fragmentShader: GRASS_FRAG
  });
}

function createChunkGrass(cx, cz, dist) {
  const count = getGrassCountForChunk(dist);
  if (count === 0) return { mesh: null, blades: [], healthAttr: null };

  const bladeGeo = createGrassBlade();
  const mat = createGrassMaterial();
  const mesh = new THREE.InstancedMesh(bladeGeo, mat, count);
  mesh.castShadow = gfx.shadows;

  const blades = [];
  const healthArray = new Float32Array(count);
  healthArray.fill(1.0);
  const healthAttr = new THREE.InstancedBufferAttribute(healthArray, 1);
  mesh.geometry.setAttribute('aHealth', healthAttr);

  const offsetX = cx * CHUNK_SIZE;
  const offsetZ = cz * CHUNK_SIZE;
  const halfChunk = CHUNK_SIZE / 2;

  for (let i = 0; i < count; i++) {
    const lx = (Math.random() - 0.5) * CHUNK_SIZE;
    const lz = (Math.random() - 0.5) * CHUNK_SIZE;
    const wx = lx + offsetX;
    const wz = lz + offsetZ;
    const y = getTerrainHeight(wx, wz);
    const rot = Math.random() * Math.PI * 2;
    const baseScale = 0.3 + Math.random() * 0.4;
    const maxScale = 2.0 + Math.random() * 4.0;
    const growSpeed = 0.005 + Math.random() * 0.02;

    blades.push({
      x: wx, y, z: wz, rot,
      scale: baseScale, maxScale, growSpeed,
      grown: false, health: 1.0
    });

    dummy.position.set(wx, y, wz);
    dummy.rotation.set(0, rot, 0);
    dummy.scale.set(1, baseScale, 1);
    dummy.updateMatrix();
    mesh.setMatrixAt(i, dummy.matrix);
  }

  mesh.instanceMatrix.needsUpdate = true;
  scene.add(mesh);

  return { mesh, blades, healthAttr };
}

function updateGrass(dt) {
  const isRaining = wVal.rain > 0.3;
  const growMult = (isRaining ? 3 : 1) * (dayFactor * 0.7 + 0.3) * timeSpeed;

  let totalGrown = 0;
  let totalHeight = 0;
  let totalBlades = 0;

  for (const [, chunk] of chunks) {
    if (!chunk.grassMesh) continue;
    const blades = chunk.blades;
    const healthAttr = chunk.healthAttr;
    let matrixChanged = false;
    let healthChanged = false;

    for (let i = 0; i < blades.length; i++) {
      const b = blades[i];
      totalBlades++;

      // Health changes
      updateBladeHealth(b, dt);

      // Sync health attribute
      if (Math.abs(healthAttr.getX(i) - b.health) > 0.01) {
        healthAttr.setX(i, b.health);
        healthChanged = true;
      }

      // Growth (only if alive)
      if (b.health > 0.1 && b.scale < b.maxScale) {
        b.scale = Math.min(b.maxScale, b.scale + b.growSpeed * growMult * dt * b.health);
        if (i % 4 === Math.floor(realTime) % 4) {
          dummy.position.set(b.x, b.y, b.z);
          dummy.rotation.set(0, b.rot, 0);
          dummy.scale.set(1, b.scale, 1);
          dummy.updateMatrix();
          chunk.grassMesh.setMatrixAt(i, dummy.matrix);
          matrixChanged = true;
        }
      }

      if (b.scale >= b.maxScale && !b.grown) b.grown = true;
      if (b.grown && b.health > 0.5) totalGrown++;
      totalHeight += b.scale;
    }

    if (matrixChanged) chunk.grassMesh.instanceMatrix.needsUpdate = true;
    if (healthChanged) healthAttr.needsUpdate = true;

    // Update grass shader uniforms
    const gu = chunk.grassMesh.material.uniforms;
    gu.uTime.value = realTime;
    gu.uWindStr.value = windStrength;
    gu.uWindDir.value.set(Math.cos(windDirection), Math.sin(windDirection));
    gu.uSunDir.value.copy(sunDir);
    gu.uDayFactor.value = dayFactor;
    gu.uSnowCover.value = snowCover;
  }

  // Global score
  if (totalBlades > 0) {
    totalGrassScore = Math.floor(totalGrown * 0.5 + (totalHeight / totalBlades) * 100);
    grassGrowthRate = totalGrown;
  }
}

function updateBladeHealth(b, dt) {
  const tdt = dt * timeSpeed;
  let healthDelta = 0;

  // Rain heals
  if (wVal.rain > 0.3) {
    healthDelta += 0.05 * tdt;
  }

  // Drought kills slowly
  if (timeSinceRain > 300) { // 5 game-minutes without rain
    healthDelta -= 0.01 * tdt * Math.min(1, (timeSinceRain - 300) / 600);
  }

  // Snow causes dormancy (health drops to 0.3 min)
  if (wVal.snow > 0.3 && b.health > 0.3) {
    healthDelta -= 0.02 * tdt;
  }

  // Tornado destruction
  if (tornadoPos && currentWeather === WEATHER.TORNADO) {
    const dx = b.x - tornadoPos.x;
    const dz = b.z - tornadoPos.z;
    const dist = Math.sqrt(dx * dx + dz * dz);
    if (dist < 40) {
      healthDelta -= 0.5 * tdt * (1 - dist / 40);
    }
  }

  // Hurricane widespread damage
  if (currentWeather === WEATHER.HURRICANE) {
    healthDelta -= 0.03 * tdt;
  }

  // Clear weather slow recovery
  if (currentWeather === WEATHER.CLEAR && wVal.rain < 0.1) {
    healthDelta += 0.01 * tdt;
  }

  b.health = Math.max(0, Math.min(1, b.health + healthDelta));
}

// Damage grass in a radius (for lightning strikes)
function damageGrassInRadius(wx, wz, radius, damage) {
  for (const [, chunk] of chunks) {
    if (!chunk.grassMesh) continue;
    for (let i = 0; i < chunk.blades.length; i++) {
      const b = chunk.blades[i];
      const dx = b.x - wx;
      const dz = b.z - wz;
      const dist = Math.sqrt(dx * dx + dz * dz);
      if (dist < radius) {
        const falloff = 1 - dist / radius;
        b.health = Math.max(0, b.health - damage * falloff);
      }
    }
  }
}
