# CLAUDE.md

## Project Overview

Grass Growing Simulator 2026 — GOTY Edition. A browser-based interactive 3D grass growing simulator built with Three.js and WebGL. Single-page application with no backend.

## Structure

```
index.html                       # Entry point (redirects to simulator)
grass_growing_simulator.html     # Complete app: HTML + CSS + JS in one file (~900 lines)
```

All code lives in `grass_growing_simulator.html` — a monolithic single-file app organized with comment section headers (`// --- SECTION ---`).

## Dependencies

- **Three.js r128** — loaded from CDN (no package manager)
- **Google Fonts** (Silkscreen, VT323) — loaded from CDN

No npm, no build step, no bundler. Just static HTML files.

## Running Locally

```bash
python3 -m http.server 8000
# Open http://localhost:8000/
```

## Testing

No automated tests. Manual browser testing only — open in any modern WebGL-capable browser.

## Linting / Formatting

No linting or formatting tools configured.

## Code Conventions

- JavaScript ES6+ with camelCase naming
- Functions prefixed with action verbs: `createGrass()`, `checkAchievements()`
- GLSL shaders embedded as template literal strings
- Sections delimited by ASCII comment headers: `// --- GLOBALS ---`, `// --- INIT ---`, etc.
- Humorous comments throughout — matches the project's satirical tone

## Architecture

- **Game loop pattern**: `init()` → `animate()` via `requestAnimationFrame`
- **Instanced rendering**: 80,000 grass blades via `THREE.InstancedMesh`
- **Custom shaders**: GLSL vertex/fragment shaders for sky, terrain, and grass
- **Procedural generation**: Perlin noise terrain, FBM for hills
- **Day/night cycle**: 120-second real-time full cycle at 1x speed
- **Particle system**: 8,000 rain particles, 25 cloud groups

## Key Systems

| System | Description |
|--------|-------------|
| Grass growth | Time + weather + daylight driven; 3x faster in rain |
| Scoring | Based on grown blade count and average height |
| Achievements | 11 milestones tracked by game/real time |
| Controls | WASD/arrows (move), mouse drag (look), scroll (zoom), touch support |
| Weather | Toggleable rain with wind effects |
| Time control | 0.5x, 1x, 3x, 10x speed multipliers |
