// ============================================================
//  Sun & Moon lens flares (circular caustic + anamorphic)
// ============================================================

let flareTextures = {};

function createFlareTextures() {
  // Central glow
  flareTextures.glow = makeFlareCanvas(128, (ctx, size) => {
    const grad = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
    grad.addColorStop(0, 'rgba(255,255,255,1)');
    grad.addColorStop(0.2, 'rgba(255,240,200,0.6)');
    grad.addColorStop(0.5, 'rgba(255,200,100,0.15)');
    grad.addColorStop(1, 'rgba(255,150,50,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, size, size);
  });

  // Ring caustic
  flareTextures.ring = makeFlareCanvas(128, (ctx, size) => {
    const c = size / 2;
    ctx.lineWidth = 3;
    for (let r = 15; r < 55; r += 12) {
      const alpha = 0.3 - (r / 55) * 0.2;
      ctx.strokeStyle = `rgba(255,220,180,${alpha})`;
      ctx.beginPath();
      ctx.arc(c, c, r, 0, Math.PI * 2);
      ctx.stroke();
    }
    // Rainbow ring
    const hues = [0, 30, 60, 120, 200, 270];
    hues.forEach((hue, i) => {
      ctx.strokeStyle = `hsla(${hue},80%,70%,0.08)`;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(c, c, 30 + i * 3, 0, Math.PI * 2);
      ctx.stroke();
    });
  });

  // Hex bokeh
  flareTextures.hex = makeFlareCanvas(64, (ctx, size) => {
    const c = size / 2;
    ctx.fillStyle = 'rgba(255,230,180,0.15)';
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
      const a = i * Math.PI / 3;
      const x = c + Math.cos(a) * 20;
      const y = c + Math.sin(a) * 20;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,220,150,0.2)';
    ctx.lineWidth = 2;
    ctx.stroke();
  });

  // Anamorphic streak
  flareTextures.streak = makeFlareCanvas(256, (ctx, size) => {
    const grad = ctx.createLinearGradient(0, size / 2, size, size / 2);
    grad.addColorStop(0, 'rgba(255,200,100,0)');
    grad.addColorStop(0.3, 'rgba(255,220,150,0.15)');
    grad.addColorStop(0.5, 'rgba(255,240,200,0.3)');
    grad.addColorStop(0.7, 'rgba(255,220,150,0.15)');
    grad.addColorStop(1, 'rgba(255,200,100,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, size / 2 - 4, size, 8);

    // Secondary thinner streak
    const grad2 = ctx.createLinearGradient(0, size / 2, size, size / 2);
    grad2.addColorStop(0, 'rgba(200,180,255,0)');
    grad2.addColorStop(0.35, 'rgba(200,180,255,0.06)');
    grad2.addColorStop(0.5, 'rgba(200,180,255,0.12)');
    grad2.addColorStop(0.65, 'rgba(200,180,255,0.06)');
    grad2.addColorStop(1, 'rgba(200,180,255,0)');
    ctx.fillStyle = grad2;
    ctx.fillRect(0, size / 2 - 12, size, 24);
  });
}

function makeFlareCanvas(size, drawFn) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  drawFn(ctx, size);
  const tex = new THREE.CanvasTexture(canvas);
  tex.needsUpdate = true;
  return tex;
}

function createFlareGroup(isSun) {
  const group = {
    sprites: [],
    streakSprite: null
  };

  const color = isSun ? 0xffdd88 : 0xaabbee;
  const streakColor = isSun ? 0xffcc66 : 0x8899cc;

  // Central glow
  const glowMat = new THREE.SpriteMaterial({
    map: flareTextures.glow,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: false,
    color
  });
  const glowSprite = new THREE.Sprite(glowMat);
  glowSprite.scale.set(isSun ? 60 : 30, isSun ? 60 : 30, 1);
  glowSprite.renderOrder = 999;
  scene.add(glowSprite);
  group.sprites.push({ sprite: glowSprite, offset: 0, size: isSun ? 60 : 30 });

  // Ring caustics
  for (let i = 0; i < 3; i++) {
    const ringMat = new THREE.SpriteMaterial({
      map: flareTextures.ring,
      transparent: true,
      opacity: 0,
      depthWrite: false,
      depthTest: false,
      color
    });
    const ringSprite = new THREE.Sprite(ringMat);
    const s = (isSun ? 25 : 12) + i * (isSun ? 15 : 8);
    ringSprite.scale.set(s, s, 1);
    ringSprite.renderOrder = 999;
    scene.add(ringSprite);
    group.sprites.push({ sprite: ringSprite, offset: 0.3 + i * 0.25, size: s });
  }

  // Small hex bokeh dots
  for (let i = 0; i < 4; i++) {
    const hexMat = new THREE.SpriteMaterial({
      map: flareTextures.hex,
      transparent: true,
      opacity: 0,
      depthWrite: false,
      depthTest: false,
      color
    });
    const hexSprite = new THREE.Sprite(hexMat);
    const s = (isSun ? 8 : 4) + Math.random() * (isSun ? 10 : 5);
    hexSprite.scale.set(s, s, 1);
    hexSprite.renderOrder = 999;
    scene.add(hexSprite);
    group.sprites.push({ sprite: hexSprite, offset: 0.15 + i * 0.2 + Math.random() * 0.1, size: s });
  }

  // Anamorphic streak
  const streakMat = new THREE.SpriteMaterial({
    map: flareTextures.streak,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    depthTest: false,
    color: streakColor
  });
  const streakSprite = new THREE.Sprite(streakMat);
  streakSprite.scale.set(isSun ? 200 : 80, isSun ? 8 : 4, 1);
  streakSprite.renderOrder = 999;
  scene.add(streakSprite);
  group.streakSprite = streakSprite;

  return group;
}

function createFlares() {
  createFlareTextures();
  sunFlare = createFlareGroup(true);
  moonFlare = createFlareGroup(false);
}

function updateFlares(dt) {
  updateFlareGroup(sunFlare, sunSphere, sunDir, true);
  updateFlareGroup(moonFlare, moonSphere, moonDir, false);
}

function updateFlareGroup(flare, sphere, dir, isSun) {
  if (!flare || !sphere) return;

  // Check visibility
  const visible = sphere.visible;
  const camFwd = new THREE.Vector3();
  camera.getWorldDirection(camFwd);
  const dotView = camFwd.dot(dir.clone().normalize());

  // Intensity based on view angle and visibility
  const overcast = wVal.overcast;
  let intensity = visible ? Math.max(0, dotView) : 0;
  intensity *= (1 - overcast * 0.9); // clouds dim flare
  if (!isSun) intensity *= (1 - dayFactor); // moon only at night

  // Project to screen
  const screenPos = sphere.position.clone().project(camera);
  const onScreen = screenPos.z < 1 && Math.abs(screenPos.x) < 1.2 && Math.abs(screenPos.y) < 1.2;

  if (!onScreen) intensity = 0;

  const fadeSpeed = 4;

  // Flare elements along line from center to source
  flare.sprites.forEach(item => {
    const targetOp = intensity * (isSun ? 0.3 : 0.15) * (1 - item.offset * 0.5);
    item.sprite.material.opacity += (targetOp - item.sprite.material.opacity) * dt * fadeSpeed;

    // Position along line from center to source
    const t = item.offset;
    const px = screenPos.x * (1 - t * 2);
    const py = screenPos.y * (1 - t * 2);

    // Convert NDC to world position near camera
    const pos = new THREE.Vector3(px, py, 0.99).unproject(camera);
    item.sprite.position.copy(pos);
  });

  // Anamorphic streak
  if (flare.streakSprite) {
    const targetOp = intensity * (isSun ? 0.2 : 0.08);
    flare.streakSprite.material.opacity += (targetOp - flare.streakSprite.material.opacity) * dt * fadeSpeed;

    // Position at source
    const pos = new THREE.Vector3(screenPos.x, screenPos.y, 0.99).unproject(camera);
    flare.streakSprite.position.copy(pos);

    // Scale width with intensity
    const baseW = isSun ? 200 : 80;
    flare.streakSprite.scale.x = baseW * (0.5 + intensity * 0.5);
  }
}
