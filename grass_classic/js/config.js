// ============================================================
//  GRASS GROWING SIMULATOR 2026 — GOTY EDITION
//  Global state, settings, and constants
// ============================================================

// --- CORE THREE.JS OBJECTS ---
let scene, camera, renderer, clock, composer, bloomPass;
let skyDome, sunSphere, moonSphere;
let sunLight, moonLight, ambientLight, hemiLight, lightningLight;
let rainSystem = null, snowSystem = null;
let fogParticleSystem = null;
let tornadoSystem = null;
let sunFlare = null, moonFlare = null;

// --- CAMERA ---
let camTarget;
let camAngleH = 0, camAngleV = 0.4, camDist = 45;
let keys = {};

// --- TIME ---
let gameTime = 0.25; // fraction of day (0-1), starts at 6 AM
let timeSpeed = 1;
let realTime = 0;

// --- WEATHER ---
const WEATHER = { CLEAR: 0, RAIN: 1, THUNDERSTORM: 2, SNOW: 3, TORNADO: 4, HURRICANE: 5 };
const WEATHER_NAMES = ['Clear', 'Rain', 'Thunderstorm', 'Snow', 'Tornado', 'Hurricane'];
const WEATHER_ICONS = ['\u2600\uFE0F', '\uD83C\uDF27\uFE0F', '\u26C8\uFE0F', '\u2744\uFE0F', '\uD83C\uDF2A\uFE0F', '\uD83C\uDF00'];
let currentWeather = WEATHER.CLEAR;

// Smoothly interpolated weather values
let wVal = {
  rain: 0,       // 0-1+ rain intensity
  snow: 0,       // 0-1 snow intensity
  windTarget: 0.2,
  fogMult: 1.0,
  cloudDark: 0,
  overcast: 0,
};

// --- WIND ---
let windStrength = 0.2;
let windDirection = 0;
let windDirTarget = 0;

// --- GAME STATE ---
let totalGrassScore = 0;
let grassGrowthRate = 0;
let snowCover = 0;      // 0-1 snow accumulation
let timeSinceRain = 0;  // game-seconds since last rain for drought

// --- LIGHTING ---
let dayFactor = 1;
let sunDir = null;
let moonDir = null;

// --- LIGHTNING ---
let lightningTimer = 0;
let lightningFlashTime = 0;
let lightningBolts = [];

// --- TORNADO ---
let tornadoPos = null;
let tornadoAngle = 0;
let tornadoWanderTarget = null;

// --- CHUNKS ---
const CHUNK_SIZE = 200;
const CHUNK_RENDER_DIST = 3;
let chunks = new Map(); // key: "cx,cz" -> chunk object
let currentChunkX = 0, currentChunkZ = 0;

// --- FPS ---
let fpsFrames = 0, fpsTime = 0;

// --- SHARED OBJECTS ---
let dummy;

// --- CLOUD LAYERS ---
let cloudLayers = { high: [], mid: [], low: [] };

// --- GRAPHICS SETTINGS ---
const gfx = {
  grassCount: 200000,
  shadows: true,
  shadowRes: 2048,
  bloom: true,
  bloomStrength: 0.35,
  antialias: true,
  pixelRatio: Math.min(window.devicePixelRatio, 2),
  cloudCount: 20,
  rainCount: 8000,
  terrainSeg: 48,
  drawDist: 5000,
  fogDensity: 0.0006,
  showFps: false,
  fogParticles: true,
  fogParticleCount: 150,
};

const PRESETS = {
  low: {
    grassCount: 50000, shadows: false, shadowRes: 512, bloom: false,
    bloomStrength: 0.2, pixelRatio: 0.75, cloudCount: 8, rainCount: 2000,
    terrainSeg: 32, drawDist: 2000, fogDensity: 0.001,
    fogParticles: true, fogParticleCount: 50
  },
  medium: {
    grassCount: 120000, shadows: true, shadowRes: 1024, bloom: true,
    bloomStrength: 0.25, pixelRatio: 1.0, cloudCount: 14, rainCount: 5000,
    terrainSeg: 40, drawDist: 3500, fogDensity: 0.0008,
    fogParticles: true, fogParticleCount: 100
  },
  high: {
    grassCount: 200000, shadows: true, shadowRes: 2048, bloom: true,
    bloomStrength: 0.35, pixelRatio: Math.min(window.devicePixelRatio, 2),
    cloudCount: 20, rainCount: 8000, terrainSeg: 48, drawDist: 5000,
    fogDensity: 0.0006, fogParticles: true, fogParticleCount: 150
  },
  ultra: {
    grassCount: 200000, shadows: true, shadowRes: 2048, bloom: true,
    bloomStrength: 0.5, pixelRatio: 2.0, cloudCount: 28, rainCount: 12000,
    terrainSeg: 64, drawDist: 8000, fogDensity: 0.0004,
    fogParticles: true, fogParticleCount: 200
  },
};

// --- WEATHER PROPERTIES PER TYPE ---
const WEATHER_PROPS = {
  [WEATHER.CLEAR]:        { windRange: [0.1, 0.3], rain: 0,   snow: 0, fogMult: 1.0, cloudDark: 0,   overcast: 0 },
  [WEATHER.RAIN]:         { windRange: [0.4, 0.7], rain: 1,   snow: 0, fogMult: 1.5, cloudDark: 0.4, overcast: 0.7 },
  [WEATHER.THUNDERSTORM]: { windRange: [0.7, 1.0], rain: 2,   snow: 0, fogMult: 2.0, cloudDark: 0.8, overcast: 0.9 },
  [WEATHER.SNOW]:         { windRange: [0.1, 0.4], rain: 0,   snow: 1, fogMult: 1.8, cloudDark: 0.3, overcast: 0.5 },
  [WEATHER.TORNADO]:      { windRange: [1.0, 1.5], rain: 0.8, snow: 0, fogMult: 2.5, cloudDark: 0.7, overcast: 0.8 },
  [WEATHER.HURRICANE]:    { windRange: [1.5, 2.5], rain: 3,   snow: 0, fogMult: 4.0, cloudDark: 0.9, overcast: 0.95 },
};

// --- SHARED COLOR PALETTE (grass + terrain matching) ---
const PALETTE = {
  grass1: [0.22, 0.55, 0.12],
  grass2: [0.35, 0.65, 0.15],
  grass3: [0.18, 0.45, 0.08],
  grassTip: [0.42, 0.78, 0.18],
  dead: [0.35, 0.25, 0.08],
  yellow: [0.65, 0.6, 0.15],
};
