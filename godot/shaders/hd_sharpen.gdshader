shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float sharpen_amount : hint_range(0.0, 1.0) = 0.34;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.10;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 n = texture(screen_tex, SCREEN_UV + vec2(0.0, -px.y)).rgb;
	vec3 s = texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb;
	vec3 e = texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb;
	vec3 w = texture(screen_tex, SCREEN_UV + vec2(-px.x, 0.0)).rgb;

	float lc = luma(c);
	float lblur = (lc + luma(n) + luma(s) + luma(e) + luma(w)) * 0.2;
	float ldiff = clamp(lc - lblur, -0.14, 0.14) * sharpen_amount;
	vec3 sharpened = clamp(c + vec3(ldiff), vec3(0.0), vec3(1.0));

	vec2 uv_centered = SCREEN_UV - vec2(0.5);
	float dist = dot(uv_centered, uv_centered);
	float vig = 1.0 - smoothstep(0.18, 0.72, dist) * vignette_strength;
	vec3 warm_tint = mix(vec3(0.96, 0.90, 0.84), vec3(1.0), vig);

	COLOR = vec4(sharpened * vig * warm_tint, 1.0);
}
