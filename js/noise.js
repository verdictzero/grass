// ============================================================
//  Noise functions & terrain height
// ============================================================

function hash(x, y) {
  let n = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
  return n - Math.floor(n);
}

function smoothNoise(x, y) {
  const ix = Math.floor(x), iy = Math.floor(y);
  const fx = x - ix, fy = y - iy;
  const sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
  const a = hash(ix, iy), b = hash(ix + 1, iy);
  const c = hash(ix, iy + 1), d = hash(ix + 1, iy + 1);
  return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
}

function fbm(x, y, octaves = 5) {
  let v = 0, amp = 0.5, freq = 1;
  for (let i = 0; i < octaves; i++) {
    v += amp * smoothNoise(x * freq, y * freq);
    amp *= 0.5;
    freq *= 2;
  }
  return v;
}

function getTerrainHeight(x, z) {
  let h = fbm(x * 0.008 + 5.3, z * 0.008 + 2.7, 5) * 18;
  h += fbm(x * 0.025, z * 0.025, 3) * 4;
  h += Math.sin(x * 0.01) * Math.cos(z * 0.015) * 6;
  return h;
}

// GLSL noise functions shared by multiple shaders
const GLSL_NOISE = `
  float hash2D(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }
  float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2D(i);
    float b = hash2D(i + vec2(1.0, 0.0));
    float c = hash2D(i + vec2(0.0, 1.0));
    float d = hash2D(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
  }
  float fbmNoise(vec2 p, int octaves) {
    float v = 0.0, amp = 0.5, freq = 1.0;
    for (int i = 0; i < 6; i++) {
      if (i >= octaves) break;
      v += amp * noise2D(p * freq);
      amp *= 0.5;
      freq *= 2.0;
    }
    return v;
  }
`;
