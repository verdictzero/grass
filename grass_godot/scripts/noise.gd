extends Node
## Noise functions & terrain height — direct port from js/noise.js

func hash_2d(x: float, y: float) -> float:
	var n := sin(x * 127.1 + y * 311.7) * 43758.5453
	return n - floor(n)

func smooth_noise(x: float, y: float) -> float:
	var ix := floor(x)
	var iy := floor(y)
	var fx := x - ix
	var fy := y - iy
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sy := fy * fy * (3.0 - 2.0 * fy)
	var a := hash_2d(ix, iy)
	var b := hash_2d(ix + 1.0, iy)
	var c := hash_2d(ix, iy + 1.0)
	var d := hash_2d(ix + 1.0, iy + 1.0)
	return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy

func fbm(x: float, y: float, octaves: int = 5) -> float:
	var v := 0.0
	var amp := 0.5
	var freq := 1.0
	for i in range(octaves):
		v += amp * smooth_noise(x * freq, y * freq)
		amp *= 0.5
		freq *= 2.0
	return v

func get_terrain_height(x: float, z: float) -> float:
	var h := fbm(x * 0.008 + 5.3, z * 0.008 + 2.7, 5) * 18.0
	h += fbm(x * 0.025, z * 0.025, 3) * 4.0
	h += sin(x * 0.01) * cos(z * 0.015) * 6.0
	return h

# GLSL noise code shared by shaders (included via #include or pasted)
const GLSL_NOISE := """
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
	float v = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) break;
		v += amp * noise2D(p * freq);
		amp *= 0.5;
		freq *= 2.0;
	}
	return v;
}
"""
