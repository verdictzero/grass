// ============================================================
//  Lighting: ambient, sun, moon, hemisphere, lightning
// ============================================================

function createLights() {
  // Ambient — base fill
  ambientLight = new THREE.AmbientLight(0x404060, 0.4);
  scene.add(ambientLight);

  // Hemisphere — sky/ground fill that's always present
  hemiLight = new THREE.HemisphereLight(0x334466, 0x1a1a2e, 0.2);
  scene.add(hemiLight);

  // Sun — directional with shadows
  sunLight = new THREE.DirectionalLight(0xffeedd, 1.0);
  sunLight.castShadow = true;
  sunLight.shadow.mapSize.set(gfx.shadowRes, gfx.shadowRes);
  sunLight.shadow.camera.left = -120;
  sunLight.shadow.camera.right = 120;
  sunLight.shadow.camera.top = 120;
  sunLight.shadow.camera.bottom = -120;
  sunLight.shadow.camera.far = 400;
  scene.add(sunLight);
  scene.add(sunLight.target);

  // Moon — directional, cooler
  moonLight = new THREE.DirectionalLight(0x8899cc, 0.15);
  scene.add(moonLight);

  // Lightning — point light, off by default
  lightningLight = new THREE.PointLight(0xeeeeff, 0, 600);
  lightningLight.position.set(0, 80, 0);
  scene.add(lightningLight);
}

function updateLights(dt) {
  // Sun
  sunLight.position.copy(sunDir).multiplyScalar(150);
  sunLight.position.add(camTarget);
  sunLight.target.position.copy(camTarget);
  sunLight.target.updateMatrixWorld();
  sunLight.intensity = dayFactor * 1.8;
  const sunHue = 0.1 + (1 - dayFactor) * 0.02;
  sunLight.color.setHSL(sunHue, 0.5, 0.6 + dayFactor * 0.4);

  // Moon — stronger at night
  moonLight.position.copy(moonDir).multiplyScalar(150);
  moonLight.position.add(camTarget);
  moonLight.intensity = (1 - dayFactor) * 0.7;
  moonLight.color.setHSL(0.6, 0.35, 0.75);

  // Ambient — warm day, cool night, never too dark
  const ambDay = new THREE.Color(0.35, 0.35, 0.3);
  const ambNight = new THREE.Color(0.1, 0.12, 0.25);
  ambientLight.color.copy(ambDay).lerp(ambNight, 1 - dayFactor);
  ambientLight.intensity = 0.35 + dayFactor * 0.4;

  // Hemisphere — boost at night for fill
  hemiLight.intensity = 0.15 + (1 - dayFactor) * 0.15;

  // Sunset golden hour
  const sunsetFactor = Math.max(0, 1 - Math.abs(sunDir.y) * 5) * 0.6;
  sunLight.color.lerp(new THREE.Color(1.0, 0.45, 0.15), sunsetFactor);
  ambientLight.color.lerp(new THREE.Color(0.4, 0.25, 0.15), sunsetFactor * 0.4);

  // Lightning flash decay
  if (lightningFlashTime > 0) {
    lightningFlashTime -= dt;
    const flash = Math.max(0, lightningFlashTime * 15);
    lightningLight.intensity = flash * 8;
    // Also flash ambient briefly
    ambientLight.intensity += flash * 2;
  } else {
    lightningLight.intensity = 0;
  }
}
