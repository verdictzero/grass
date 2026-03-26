// ============================================================
//  Camera controls: WASD, orbit, zoom, ground collider
// ============================================================

function setupControls() {
  // Keyboard
  document.addEventListener('keydown', e => keys[e.key.toLowerCase()] = true);
  document.addEventListener('keyup', e => keys[e.key.toLowerCase()] = false);

  // Mouse orbit
  let dragging = false, lastX = 0, lastY = 0;
  renderer.domElement.addEventListener('mousedown', e => {
    dragging = true; lastX = e.clientX; lastY = e.clientY;
  });
  document.addEventListener('mouseup', () => dragging = false);
  document.addEventListener('mousemove', e => {
    if (!dragging) return;
    camAngleH -= (e.clientX - lastX) * 0.005;
    camAngleV = Math.max(-0.1, Math.min(1.2, camAngleV + (e.clientY - lastY) * 0.005));
    lastX = e.clientX; lastY = e.clientY;
  });

  // Mouse zoom
  renderer.domElement.addEventListener('wheel', e => {
    camDist = Math.max(8, Math.min(200, camDist + e.deltaY * 0.05));
  });

  // Touch controls
  let pinching = false, lastPinchDist = 0;
  function getTouchDist(t) {
    const dx = t[0].clientX - t[1].clientX, dy = t[0].clientY - t[1].clientY;
    return Math.sqrt(dx * dx + dy * dy);
  }
  renderer.domElement.addEventListener('touchstart', e => {
    if (e.touches.length === 2) {
      pinching = true; dragging = false;
      lastPinchDist = getTouchDist(e.touches);
    } else if (e.touches.length === 1 && !pinching) {
      dragging = true; lastX = e.touches[0].clientX; lastY = e.touches[0].clientY;
    }
  });
  renderer.domElement.addEventListener('touchmove', e => {
    e.preventDefault();
    if (e.touches.length === 2 && pinching) {
      const dist = getTouchDist(e.touches);
      const delta = lastPinchDist - dist;
      camDist = Math.max(8, Math.min(200, camDist + delta * 0.15));
      lastPinchDist = dist;
    } else if (e.touches.length === 1 && dragging && !pinching) {
      camAngleH -= (e.touches[0].clientX - lastX) * 0.005;
      camAngleV = Math.max(-0.1, Math.min(1.2, camAngleV + (e.touches[0].clientY - lastY) * 0.005));
      lastX = e.touches[0].clientX; lastY = e.touches[0].clientY;
    }
  }, { passive: false });
  renderer.domElement.addEventListener('touchend', e => {
    if (e.touches.length < 2) pinching = false;
    if (e.touches.length === 0) dragging = false;
  });

  // Resize
  window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
    if (composer) composer.setSize(window.innerWidth, window.innerHeight);
  });
}

function updateCamera(dt) {
  // WASD movement
  const moveSpeed = 25 * dt;
  const forward = new THREE.Vector3(-Math.sin(camAngleH), 0, -Math.cos(camAngleH));
  const right = new THREE.Vector3(forward.z, 0, -forward.x);
  if (keys['w'] || keys['arrowup']) camTarget.addScaledVector(forward, moveSpeed);
  if (keys['s'] || keys['arrowdown']) camTarget.addScaledVector(forward, -moveSpeed);
  if (keys['a'] || keys['arrowleft']) camTarget.addScaledVector(right, -moveSpeed);
  if (keys['d'] || keys['arrowright']) camTarget.addScaledVector(right, moveSpeed);

  // Ground collider — target always above terrain
  const terrainY = getTerrainHeight(camTarget.x, camTarget.z);
  camTarget.y = terrainY + 2;

  // Position camera on orbit
  const cx = camTarget.x + Math.sin(camAngleH) * camDist * Math.cos(camAngleV);
  const cy = camTarget.y + camDist * Math.sin(camAngleV);
  const cz = camTarget.z + Math.cos(camAngleH) * camDist * Math.cos(camAngleV);

  // Camera ground collider — never below terrain + 1
  const camTerrainY = getTerrainHeight(cx, cz);
  const finalCy = Math.max(cy, camTerrainY + 1);

  camera.position.lerp(new THREE.Vector3(cx, finalCy, cz), 0.08);
  camera.lookAt(camTarget);
}
