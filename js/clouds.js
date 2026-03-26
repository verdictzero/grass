// ============================================================
//  Multi-layer cloud system
// ============================================================

const CLOUD_VERT = `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const CLOUD_FRAG = `
  uniform float uTime;
  uniform float uOvercast;
  uniform float uSeed;
  uniform float uDayFactor;
  uniform float uLayerDark;
  varying vec2 vUv;

  ${GLSL_NOISE}

  void main() {
    vec2 uv = vUv;
    vec2 p = uv * 3.0 + vec2(uTime * 0.02, uTime * 0.005) + uSeed * 10.0;

    float n1 = fbmNoise(p * 1.0, 6);
    float n2 = fbmNoise(p * 2.5 + vec2(5.3, 1.7), 4);
    float n3 = fbmNoise(p * 6.0 + vec2(9.1, 4.3), 3);

    float cloud = n1 * 0.6 + n2 * 0.3 + n3 * 0.1;

    // Coverage increases with overcast
    float coverage = mix(0.42, 0.25, uOvercast);
    cloud = smoothstep(coverage, coverage + 0.25, cloud);

    // Edge fade
    float edgeFade = smoothstep(0.0, 0.15, uv.x) * smoothstep(1.0, 0.85, uv.x)
                   * smoothstep(0.0, 0.15, uv.y) * smoothstep(1.0, 0.85, uv.y);
    cloud *= edgeFade;

    // Colors
    vec3 dayCloud = vec3(1.0, 0.99, 0.96);
    vec3 stormCloud = vec3(0.35, 0.37, 0.42);
    vec3 nightCloud = vec3(0.12, 0.14, 0.22);

    vec3 col = mix(nightCloud, dayCloud, uDayFactor);
    col = mix(col, stormCloud, uOvercast * 0.8 + uLayerDark * 0.3);

    // Bloom edge highlight
    col += vec3(0.15, 0.12, 0.08) * pow(cloud, 3.0) * uDayFactor;

    float alpha = cloud * mix(0.6, 0.95, uOvercast);
    gl_FragColor = vec4(col, alpha);
  }
`;

function createCloudPlane(seed, y, sizeMin, sizeMax, spreadX, spreadZ) {
  const size = sizeMin + Math.random() * (sizeMax - sizeMin);
  const geo = new THREE.PlaneGeometry(size, size * (0.4 + Math.random() * 0.5));
  const mat = new THREE.ShaderMaterial({
    vertexShader: CLOUD_VERT,
    fragmentShader: CLOUD_FRAG,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
    uniforms: {
      uTime: { value: 0 },
      uOvercast: { value: 0 },
      uSeed: { value: seed },
      uDayFactor: { value: 1.0 },
      uLayerDark: { value: 0 }
    }
  });

  const plane = new THREE.Mesh(geo, mat);
  plane.rotation.x = -Math.PI / 2;
  plane.rotation.z = Math.random() * Math.PI * 2;
  plane.position.set(
    (Math.random() - 0.5) * spreadX,
    y + Math.random() * 20,
    (Math.random() - 0.5) * spreadZ
  );
  plane.userData = {
    speed: 1.0 + Math.random() * 3.0,
    baseY: plane.position.y,
    spreadX
  };
  return plane;
}

function createClouds() {
  // Clear existing
  for (const layer of Object.values(cloudLayers)) {
    layer.forEach(c => { scene.remove(c); c.geometry.dispose(); c.material.dispose(); });
    layer.length = 0;
  }

  const count = gfx.cloudCount;

  // High cirrus (thin, fast, always present)
  const highCount = Math.floor(count * 0.25);
  for (let i = 0; i < highCount; i++) {
    const c = createCloudPlane(Math.random() * 100, 130 + Math.random() * 40, 200, 400, 1200, 1200);
    c.userData.speed = 3 + Math.random() * 5;
    scene.add(c);
    cloudLayers.high.push(c);
  }

  // Mid cumulus (standard clouds)
  const midCount = Math.floor(count * 0.5);
  for (let i = 0; i < midCount; i++) {
    const c = createCloudPlane(Math.random() * 100, 65 + Math.random() * 35, 120, 250, 1000, 1000);
    scene.add(c);
    cloudLayers.mid.push(c);
  }

  // Low stratus (storm clouds, appear during bad weather)
  const lowCount = Math.floor(count * 0.25);
  for (let i = 0; i < lowCount; i++) {
    const c = createCloudPlane(Math.random() * 100, 35 + Math.random() * 20, 150, 300, 800, 800);
    c.userData.speed = 0.5 + Math.random() * 1.5;
    scene.add(c);
    cloudLayers.low.push(c);
  }
}

function updateClouds(dt) {
  const overcast = skyDome.material.uniforms.uOvercast.value;

  function updateLayer(layer, layerDark, visOvercast) {
    layer.forEach(c => {
      // Move with wind
      c.position.x += c.userData.speed * dt * (1 + windStrength);
      const half = c.userData.spreadX / 2;
      if (c.position.x > camTarget.x + half) c.position.x = camTarget.x - half;
      if (c.position.x < camTarget.x - half) c.position.x = camTarget.x + half;

      // Follow camera Z loosely
      c.position.z += (camTarget.z - c.position.z) * 0.001;

      // Gentle bobbing
      c.position.y = c.userData.baseY + Math.sin(realTime * 0.2 + c.position.z * 0.008) * 3;

      // Uniforms
      c.material.uniforms.uTime.value = realTime;
      c.material.uniforms.uOvercast.value = overcast;
      c.material.uniforms.uDayFactor.value = dayFactor;
      c.material.uniforms.uLayerDark.value = layerDark;

      // Low clouds only visible during storms
      if (visOvercast !== undefined) {
        c.visible = overcast > visOvercast;
        c.material.opacity = Math.max(0, (overcast - visOvercast) * 3);
      }
    });
  }

  updateLayer(cloudLayers.high, 0, undefined);
  updateLayer(cloudLayers.mid, wVal.cloudDark * 0.5, undefined);
  updateLayer(cloudLayers.low, wVal.cloudDark, 0.3);
}

function rebuildClouds() {
  createClouds();
}
