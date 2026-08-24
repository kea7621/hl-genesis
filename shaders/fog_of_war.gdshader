shader_type canvas_item;

// Driven by WorldDimmer.gd via set_shader_parameter — not meant to be
// tweaked by hand in the Inspector, though you can preview values there.
uniform float gray_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dim_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(tex.rgb, vec3(luminance), gray_amount);
	desaturated *= (1.0 - dim_amount);
	COLOR = vec4(desaturated, tex.a);
}
