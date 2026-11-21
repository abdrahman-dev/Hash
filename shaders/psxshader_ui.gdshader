shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 pixel_size = vec2(420.0, 360.0);
uniform vec3 tint_color : source_color = vec3(0.92, 0.88, 0.82);
uniform float tint_strength = 0.02;
uniform float scanline_strength = 0.02;
uniform float scanline_count = 240.0;
uniform float grain_strength = 0.025;
uniform float color_depth = 64.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = floor(UV * pixel_size) / pixel_size;
	vec4 col = texture(screen_tex, uv);
	col.rgb = floor(col.rgb * color_depth) / color_depth;
	col.rgb = mix(col.rgb, col.rgb * tint_color, tint_strength);
	float scan = sin(UV.y * scanline_count * 3.14159) * 0.5 + 0.5;
	col.rgb *= mix(1.0, scan, scanline_strength);
	float noise = rand(UV * pixel_size + vec2(TIME * 60.0, TIME * 60.0));
	col.rgb += (noise - 0.5) * grain_strength;
	COLOR = col;
}