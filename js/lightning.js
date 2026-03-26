// ============================================================
//  Lightning bolt system
// ============================================================

function updateLightning(dt) {
  // Only during thunderstorm
  if (currentWeather !== WEATHER.THUNDERSTORM) {
    clearLightningBolts();
    return;
  }

  lightningTimer -= dt;
  if (lightningTimer <= 0) {
    strikeLightning();
    lightningTimer = 3 + Math.random() * 10;
  }

  // Fade out existing bolts
  for (let i = lightningBolts.length - 1; i >= 0; i--) {
    const bolt = lightningBolts[i];
    bolt.life -= dt;
    if (bolt.life <= 0) {
      scene.remove(bolt.mesh);
      bolt.mesh.geometry.dispose();
      bolt.mesh.material.dispose();
      if (bolt.glow) {
        scene.remove(bolt.glow);
        bolt.glow.geometry.dispose();
        bolt.glow.material.dispose();
      }
      lightningBolts.splice(i, 1);
    } else {
      const alpha = Math.min(1, bolt.life * 5);
      bolt.mesh.material.opacity = alpha;
      if (bolt.glow) bolt.glow.material.opacity = alpha * 0.3;
    }
  }
}

function strikeLightning() {
  // Strike position near camera
  const sx = camTarget.x + (Math.random() - 0.5) * 300;
  const sz = camTarget.z + (Math.random() - 0.5) * 300;
  const groundY = getTerrainHeight(sx, sz);
  const startY = 70 + Math.random() * 30;

  // Generate jagged bolt path
  const points = [];
  const segments = 12 + Math.floor(Math.random() * 8);
  let cx = sx, cy = startY, cz = sz;

  points.push(new THREE.Vector3(cx, cy, cz));

  for (let i = 1; i <= segments; i++) {
    const t = i / segments;
    cy = startY + (groundY - startY) * t;
    cx = sx + (Math.random() - 0.5) * 20 * (1 - t * 0.5);
    cz = sz + (Math.random() - 0.5) * 20 * (1 - t * 0.5);
    points.push(new THREE.Vector3(cx, cy, cz));
  }

  // Ensure last point is on ground
  points[points.length - 1].y = groundY;

  // Main bolt line
  const geo = new THREE.BufferGeometry().setFromPoints(points);
  const mat = new THREE.LineBasicMaterial({
    color: 0xeeeeff,
    linewidth: 2,
    transparent: true,
    opacity: 1
  });
  const mesh = new THREE.Line(geo, mat);
  scene.add(mesh);

  // Glow tube (thicker, semi-transparent)
  const glowGeo = new THREE.BufferGeometry().setFromPoints(points);
  const glowMat = new THREE.LineBasicMaterial({
    color: 0xaabbff,
    linewidth: 4,
    transparent: true,
    opacity: 0.3
  });
  const glow = new THREE.Line(glowGeo, glowMat);
  scene.add(glow);

  // Add branch bolts
  for (let i = 2; i < points.length - 2; i++) {
    if (Math.random() > 0.4) continue;
    const branchPoints = [points[i].clone()];
    let bx = points[i].x, by = points[i].y, bz = points[i].z;
    const branchLen = 3 + Math.floor(Math.random() * 4);
    for (let j = 0; j < branchLen; j++) {
      bx += (Math.random() - 0.5) * 12;
      by -= 3 + Math.random() * 5;
      bz += (Math.random() - 0.5) * 12;
      branchPoints.push(new THREE.Vector3(bx, by, bz));
    }
    const branchGeo = new THREE.BufferGeometry().setFromPoints(branchPoints);
    const branchMat = new THREE.LineBasicMaterial({
      color: 0xccddff,
      transparent: true,
      opacity: 0.6
    });
    const branchMesh = new THREE.Line(branchGeo, branchMat);
    scene.add(branchMesh);
    lightningBolts.push({ mesh: branchMesh, glow: null, life: 0.3 + Math.random() * 0.2 });
  }

  lightningBolts.push({ mesh, glow, life: 0.4 + Math.random() * 0.2 });

  // Flash effect
  lightningFlashTime = 0.15;
  lightningLight.position.set(sx, startY * 0.5, sz);

  // Bloom spike
  if (bloomPass) {
    const origStrength = bloomPass.strength;
    bloomPass.strength = Math.min(2.0, origStrength + 1.0);
    setTimeout(() => { if (bloomPass) bloomPass.strength = origStrength; }, 150);
  }

  // Destroy grass at strike point
  damageGrassInRadius(sx, sz, 15, 1.0);
}

function clearLightningBolts() {
  for (const bolt of lightningBolts) {
    scene.remove(bolt.mesh);
    bolt.mesh.geometry.dispose();
    bolt.mesh.material.dispose();
    if (bolt.glow) {
      scene.remove(bolt.glow);
      bolt.glow.geometry.dispose();
      bolt.glow.material.dispose();
    }
  }
  lightningBolts.length = 0;
}
