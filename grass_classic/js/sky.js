// ============================================================
//  Sky dome, sun sphere, moon sphere
// ============================================================

function createSky() {
  const geo = new THREE.SphereGeometry(900, 32, 32);
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    uniforms: {
      uSunPos: { value: new THREE.Vector3(0, 1, 0) },
      uTime: { value: 0 },
      uOvercast: { value: 0 },
      uSnow: { value: 0 }
    },
    vertexShader: `
      varying vec3 vWorldPos;
      void main() {
        vWorldPos = (modelMatrix * vec4(position, 1.0)).xyz;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3 uSunPos;
      uniform float uTime;
      uniform float uOvercast;
      uniform float uSnow;
      varying vec3 vWorldPos;

      void main() {
        vec3 dir = normalize(vWorldPos);
        float y = dir.y * 0.5 + 0.5;
        float sunH = uSunPos.y;

        // Day
        vec3 dayTop = vec3(0.25, 0.55, 0.95);
        vec3 dayBot = vec3(0.6, 0.8, 1.0);
        vec3 dayCol = mix(dayBot, dayTop, pow(y, 0.8));

        // Sunset
        vec3 sunsetTop = vec3(0.15, 0.1, 0.35);
        vec3 sunsetBot = vec3(0.9, 0.4, 0.15);
        vec3 sunsetCol = mix(sunsetBot, sunsetTop, pow(y, 0.5));

        // Night
        vec3 nightTop = vec3(0.02, 0.02, 0.08);
        vec3 nightBot = vec3(0.05, 0.05, 0.15);
        vec3 nightCol = mix(nightBot, nightTop, pow(y, 0.6));

        // Blend day/night/sunset
        float dayF = smoothstep(-0.1, 0.3, sunH);
        float sunsetF = smoothstep(-0.2, 0.0, sunH) * (1.0 - smoothstep(0.0, 0.25, sunH));

        vec3 col = mix(nightCol, dayCol, dayF);
        col = mix(col, sunsetCol, sunsetF * 0.7);

        // Sun glow
        float sunDot = max(dot(dir, normalize(uSunPos)), 0.0);
        col += vec3(1.0, 0.8, 0.4) * pow(sunDot, 64.0) * 2.0 * max(sunH, 0.0);
        col += vec3(1.0, 0.6, 0.3) * pow(sunDot, 8.0) * 0.3 * max(sunH + 0.1, 0.0);

        // Moon glow
        vec3 moonPos = -normalize(uSunPos);
        float moonDot = max(dot(dir, moonPos), 0.0);
        float moonGlow = pow(moonDot, 128.0) * 1.5 + pow(moonDot, 16.0) * 0.15;
        col += vec3(0.6, 0.7, 1.0) * moonGlow * (1.0 - dayF);

        // Overcast (rain/storm)
        vec3 overcast = vec3(0.45, 0.48, 0.52);
        col = mix(col, overcast, uOvercast * 0.7);

        // Snow tint
        vec3 snowSky = vec3(0.65, 0.68, 0.72);
        col = mix(col, snowSky, uSnow * 0.5);

        // Stars
        float starHash = fract(sin(dot(floor(dir * 500.0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
        float star = step(0.998, starHash) * (1.0 - dayF) * (1.0 - uOvercast) * (1.0 - uSnow);
        col += vec3(star) * 0.8;

        gl_FragColor = vec4(col, 1.0);
      }
    `
  });
  skyDome = new THREE.Mesh(geo, mat);
  scene.add(skyDome);

  // Sun sphere
  const sunGeo = new THREE.SphereGeometry(18, 16, 16);
  const sunMat = new THREE.MeshBasicMaterial({ color: 0xffee88 });
  sunSphere = new THREE.Mesh(sunGeo, sunMat);
  scene.add(sunSphere);

  // Moon sphere — brighter, slightly emissive look
  const moonGeo = new THREE.SphereGeometry(12, 16, 16);
  const moonMat = new THREE.MeshBasicMaterial({ color: 0xeef4ff });
  moonSphere = new THREE.Mesh(moonGeo, moonMat);
  scene.add(moonSphere);
}

function updateSky(dt) {
  skyDome.material.uniforms.uSunPos.value.copy(sunDir);
  skyDome.material.uniforms.uTime.value = realTime;

  // Smooth overcast transition
  const targetOvercast = wVal.overcast;
  const curOvercast = skyDome.material.uniforms.uOvercast.value;
  skyDome.material.uniforms.uOvercast.value += (targetOvercast - curOvercast) * dt * 2;

  const targetSnow = wVal.snow;
  const curSnow = skyDome.material.uniforms.uSnow.value;
  skyDome.material.uniforms.uSnow.value += (targetSnow - curSnow) * dt * 2;

  // Sun/moon positions & visibility
  sunSphere.position.copy(sunDir).multiplyScalar(850);
  sunSphere.visible = sunDir.y > -0.05;
  moonSphere.position.copy(moonDir).multiplyScalar(850);
  moonSphere.visible = sunDir.y < 0.05;

  // Sky dome follows camera
  skyDome.position.copy(camTarget);
  sunSphere.position.add(camTarget);
  moonSphere.position.add(camTarget);
}
