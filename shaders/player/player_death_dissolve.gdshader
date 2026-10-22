shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float noise_seed = 0.0;

float pixel_noise(vec2 pixel) {
	vec2 seeded_pixel = pixel + vec2(noise_seed, noise_seed * 0.73);
	return fract(sin(dot(seeded_pixel, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Use source texture pixels, including frames stored in an atlas.
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	float threshold = pixel_noise(pixel);
	if (dissolve_amount >= 1.0 ||
		(dissolve_amount > 0.0 && threshold < dissolve_amount)) {
		COLOR.a = 0.0;
	}
}
