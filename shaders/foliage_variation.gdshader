shader_type spatial;

// Foliage variation shader - gives each tree instance a unique shade of green
// Apply this to tree meshes in the MeshLibrary

uniform vec3 base_color : source_color = vec3(0.2, 0.5, 0.15);
uniform float hue_variation : hint_range(0.0, 0.2) = 0.08;
uniform float saturation_variation : hint_range(0.0, 0.5) = 0.2;
uniform float brightness_variation : hint_range(0.0, 0.3) = 0.15;

// Convert RGB to HSV
vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV to RGB
vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Simple hash function for position-based randomness
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Use world position to generate unique variation per tree instance
	vec2 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	float random = hash(floor(world_pos * 0.1));
	
	// Convert base color to HSV
	vec3 hsv = rgb_to_hsv(base_color);
	
	// Apply variations
	hsv.x += (random - 0.5) * hue_variation * 2.0;  // Hue shift
	hsv.y += (random - 0.5) * saturation_variation * 2.0;  // Saturation
	hsv.z += (random - 0.5) * brightness_variation * 2.0;  // Brightness
	
	// Clamp values
	hsv.x = fract(hsv.x);  // Wrap hue
	hsv.y = clamp(hsv.y, 0.0, 1.0);
	hsv.z = clamp(hsv.z, 0.0, 1.0);
	
	// Convert back to RGB
	vec3 varied_color = hsv_to_rgb(hsv);
	
	ALBEDO = varied_color;
	ROUGHNESS = 0.8;
}
