shader_type spatial;

// Red/White Kerb Stripe Shader
// Apply this to road edge collision meshes or overlay planes

uniform float stripe_width : hint_range(0.1, 2.0) = 0.5;
uniform float stripe_angle : hint_range(0.0, 90.0) = 45.0;
uniform vec3 red_color : source_color = vec3(0.9, 0.1, 0.1);
uniform vec3 white_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float speed : hint_range(0.0, 5.0) = 0.0; // Optional animation

void fragment() {
    // Calculate diagonal stripe pattern
    float angle_rad = radians(stripe_angle);
    float pattern = sin(angle_rad) * UV.x + cos(angle_rad) * UV.y;
    
    // Add time offset for optional animation
    pattern += TIME * speed;
    
    // Create alternating stripes
    float stripe = step(0.5, fract(pattern / stripe_width));
    
    // Mix between red and white
    vec3 color = mix(red_color, white_color, stripe);
    
    ALBEDO = color;
    ROUGHNESS = 0.7;
    METALLIC = 0.0;
}
