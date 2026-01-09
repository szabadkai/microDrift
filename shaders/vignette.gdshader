shader_type canvas_item;

// Racing vignette effect - darkens edges of screen

uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv * vec2(1.0, 0.8)); // Slightly oval shape
	float vignette = smoothstep(softness, softness - 0.3, dist);
	float darkness = (1.0 - vignette) * intensity;
	COLOR = vec4(color.rgb, darkness);
}
