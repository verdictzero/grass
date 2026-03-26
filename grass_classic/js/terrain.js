// ============================================================
//  Chunk-based infinite terrain
// ============================================================

// Shared terrain shader code
const TERRAIN_VERT = `
  varying vec3 vNormal;
  varying vec3 vWorldPos;
  varying float vHeight;
  void main() {
    vNormal = normalize(normalMatrix * normal);
    vec4 wp = modelMatrix * vec4(position, 1.0);
    vWorldPos = wp.xyz;
    vHeight = position.y;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const TERRAIN_FRAG = `
  uniform vec3 uSunDir;
  uniform vec3 uMoonDir;
  uniform float uDayFactor;
  uniform float uSnowCover;
  varying vec3 vNormal;
  varying vec3 vWorldPos;
  varying float vHeight;

  ${GLSL_NOISE}

  void main() {
    float h = vHeight;
    // Base grass colors — matched with grass blade shader
    vec3 grass1 = vec3(${PALETTE.grass1.join(',')});
    vec3 grass2 = vec3(${PALETTE.grass2.join(',')});
    vec3 grass3 = vec3(${PALETTE.grass3.join(',')});

    float n = noise2D(vWorldPos.xz * 0.05);
    float n2 = noise2D(vWorldPos.xz * 0.15 + vec2(50.0));
    vec3 baseCol = mix(mix(grass1, grass2, n), grass3, smoothstep(5.0, 15.0, h));
    baseCol *= 0.85 + n2 * 0.3;

    // Sun lighting
    float sunDiff = max(dot(vNormal, normalize(uSunDir)), 0.0);
    vec3 sunCol = vec3(1.0, 0.95, 0.85) * sunDiff * 0.7 * uDayFactor;

    // Moon lighting — stronger blue tint
    float moonDiff = max(dot(vNormal, normalize(uMoonDir)), 0.0);
    vec3 moonCol = vec3(0.3, 0.35, 0.6) * moonDiff * 0.5 * (1.0 - uDayFactor);

    // Ambient
    float ambient = 0.2 + uDayFactor * 0.25;
    vec3 ambCol = mix(vec3(0.08, 0.1, 0.2), vec3(0.3, 0.3, 0.25), uDayFactor) * ambient;

    vec3 lit = baseCol * (sunCol + moonCol + ambCol);

    // Snow cover
    float snowNoise = noise2D(vWorldPos.xz * 0.03) * 0.3 + 0.7;
    float upFacing = max(dot(vNormal, vec3(0.0, 1.0, 0.0)), 0.0);
    float snow = uSnowCover * snowNoise * upFacing;
    lit = mix(lit, vec3(0.9, 0.92, 0.95) * (sunCol + moonCol + ambCol), snow);

    gl_FragColor = vec4(lit, 1.0);
  }
`;

function createChunkTerrain(cx, cz) {
  const seg = gfx.terrainSeg;
  const geo = new THREE.PlaneGeometry(CHUNK_SIZE, CHUNK_SIZE, seg, seg);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;

  const offsetX = cx * CHUNK_SIZE;
  const offsetZ = cz * CHUNK_SIZE;

  for (let i = 0; i < pos.count; i++) {
    const lx = pos.getX(i);
    const lz = pos.getZ(i);
    const wx = lx + offsetX;
    const wz = lz + offsetZ;
    pos.setX(i, wx);
    pos.setZ(i, wz);
    pos.setY(i, getTerrainHeight(wx, wz));
  }
  geo.computeVertexNormals();

  const mat = new THREE.ShaderMaterial({
    uniforms: {
      uSunDir: { value: new THREE.Vector3(0, 1, 0) },
      uMoonDir: { value: new THREE.Vector3(0, -1, 0) },
      uDayFactor: { value: 1.0 },
      uSnowCover: { value: 0.0 }
    },
    vertexShader: TERRAIN_VERT,
    fragmentShader: TERRAIN_FRAG
  });

  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = gfx.shadows;
  scene.add(mesh);
  return mesh;
}

function getGrassCountForChunk(dist) {
  const base = Math.floor(gfx.grassCount / 12);
  if (dist <= 0) return base;
  if (dist <= 1) return Math.floor(base * 0.6);
  if (dist <= 2) return Math.floor(base * 0.25);
  return Math.floor(base * 0.1);
}

function getChunkCoord(wx, wz) {
  return [Math.floor((wx + CHUNK_SIZE / 2) / CHUNK_SIZE), Math.floor((wz + CHUNK_SIZE / 2) / CHUNK_SIZE)];
}

function createChunk(cx, cz) {
  const key = cx + ',' + cz;
  if (chunks.has(key)) return;

  const dist = Math.max(Math.abs(cx - currentChunkX), Math.abs(cz - currentChunkZ));
  const terrain = createChunkTerrain(cx, cz);
  const grassData = createChunkGrass(cx, cz, dist);

  chunks.set(key, {
    cx, cz,
    terrain,
    grassMesh: grassData.mesh,
    blades: grassData.blades,
    healthAttr: grassData.healthAttr,
    lodDist: dist
  });
}

function disposeChunk(chunk) {
  scene.remove(chunk.terrain);
  chunk.terrain.geometry.dispose();
  chunk.terrain.material.dispose();
  if (chunk.grassMesh) {
    scene.remove(chunk.grassMesh);
    chunk.grassMesh.geometry.dispose();
    chunk.grassMesh.material.dispose();
  }
}

function updateChunks() {
  const [ccx, ccz] = getChunkCoord(camTarget.x, camTarget.z);

  if (ccx === currentChunkX && ccz === currentChunkZ) return;
  currentChunkX = ccx;
  currentChunkZ = ccz;

  // Create needed chunks
  for (let dx = -CHUNK_RENDER_DIST; dx <= CHUNK_RENDER_DIST; dx++) {
    for (let dz = -CHUNK_RENDER_DIST; dz <= CHUNK_RENDER_DIST; dz++) {
      const key = (ccx + dx) + ',' + (ccz + dz);
      if (!chunks.has(key)) {
        createChunk(ccx + dx, ccz + dz);
      }
    }
  }

  // Remove far chunks
  const removeKeys = [];
  for (const [key, chunk] of chunks) {
    if (Math.abs(chunk.cx - ccx) > CHUNK_RENDER_DIST + 1 ||
        Math.abs(chunk.cz - ccz) > CHUNK_RENDER_DIST + 1) {
      removeKeys.push(key);
    }
  }
  for (const key of removeKeys) {
    disposeChunk(chunks.get(key));
    chunks.delete(key);
  }
}

function updateTerrainUniforms() {
  for (const [, chunk] of chunks) {
    const tu = chunk.terrain.material.uniforms;
    tu.uSunDir.value.copy(sunDir);
    tu.uMoonDir.value.copy(moonDir);
    tu.uDayFactor.value = dayFactor;
    tu.uSnowCover.value = snowCover;
  }
}
