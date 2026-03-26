// ============================================================
//  Procedural fog particle system
// ============================================================

let fogTexture = null;
let fogSprites = [];

function createFogTexture() {
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  const imgData = ctx.createImageData(size, size);
  const data = imgData.data;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const idx = (y * size + x) * 4;
      const nx = x / size;
      const ny = y / size;

      // FBM noise for cloudy shape
      let val = 0;
      let amp = 0.5, freq = 1;
      for (let o = 0; o < 5; o++) {
        val += amp * smoothNoise(nx * freq * 4 + o * 7.3, ny * freq * 4 + o * 3.1);
        amp *= 0.5;
        freq *= 2;
      }

      // Radial falloff for soft edges
      const cx = nx - 0.5, cy = ny - 0.5;
      const r = Math.sqrt(cx * cx + cy * cy) * 2;
      const radial = Math.max(0, 1 - r * r);

      const alpha = Math.max(0, Math.min(255, val * radial * 255));

      data[idx] = 255;
      data[idx + 1] = 255;
      data[idx + 2] = 255;
      data[idx + 3] = alpha;
    }
  }

  ctx.putImageData(imgData, 0, 0);
  fogTexture = new THREE.CanvasTexture(canvas);
  fogTexture.needsUpdate = true;
  return fogTexture;
}

function createFogParticles() {
  // Clean up old
  fogSprites.forEach(s => { scene.remove(s); s.material.dispose(); });
  fogSprites = [];

  if (!gfx.fogParticles) return;
  if (!fogTexture) createFogTexture();

  const count = gfx.fogParticleCount;

  for (let i = 0; i < count; i++) {
    const mat = new THREE.SpriteMaterial({
      map: fogTexture,
      transparent: true,
      opacity: 0.06 + Math.random() * 0.06,
      depthWrite: false,
      fog: true,
      color: 0xffffff
    });

    const sprite = new THREE.Sprite(mat);
    const size = 15 + Math.random() * 35;
    sprite.scale.set(size, size * (0.3 + Math.random() * 0.4), 1);

    // Distribute around origin, will re-center to camera
    sprite.position.set(
      (Math.random() - 0.5) * 500,
      2 + Math.random() * 20,
      (Math.random() - 0.5) * 500
    );

    sprite.userData = {
      baseY: sprite.position.y,
      speed: 0.5 + Math.random() * 2.0,
      phase: Math.random() * Math.PI * 2,
      driftX: (Math.random() - 0.5) * 0.5,
      baseOpacity: mat.opacity
    };

    scene.add(sprite);
    fogSprites.push(sprite);
  }
}

function updateFogParticles(dt) {
  if (!gfx.fogParticles || fogSprites.length === 0) return;

  // Weather-based fog intensity
  const fogIntensity = wVal.fogMult;
  const isSnowy = wVal.snow > 0.3;

  fogSprites.forEach(s => {
    const ud = s.userData;

    // Move with wind
    s.position.x += (Math.cos(windDirection) * windStrength * ud.speed + ud.driftX) * dt * 3;
    s.position.z += (Math.sin(windDirection) * windStrength * ud.speed) * dt * 3;

    // Gentle vertical bob
    s.position.y = ud.baseY + Math.sin(realTime * 0.3 + ud.phase) * 2;

    // Re-center around camera when too far
    const dx = s.position.x - camTarget.x;
    const dz = s.position.z - camTarget.z;
    if (Math.abs(dx) > 250 || Math.abs(dz) > 250) {
      s.position.x = camTarget.x + (Math.random() - 0.5) * 400;
      s.position.z = camTarget.z + (Math.random() - 0.5) * 400;
      s.position.y = 2 + Math.random() * 20;
      ud.baseY = s.position.y;
    }

    // Opacity based on weather
    const targetOp = ud.baseOpacity * fogIntensity * (isSnowy ? 1.5 : 1.0);
    s.material.opacity += (targetOp - s.material.opacity) * dt * 2;

    // Snow-tinted fog
    if (isSnowy) {
      s.material.color.lerp(new THREE.Color(0.9, 0.92, 0.95), dt);
    } else {
      s.material.color.lerp(new THREE.Color(1, 1, 1), dt);
    }
  });
}
