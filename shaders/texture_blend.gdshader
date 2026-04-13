shader_type spatial;

uniform sampler2D tex_default : source_color;
uniform sampler2D tex_perfect : source_color;
uniform sampler2D tex_overcooked : source_color;

uniform float cook_amount;
uniform float max_cook_amount;
uniform float default_cook_amount;
uniform float perfect_cook_amount;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 default_tex = texture(tex_default, UV);
	vec4 perfect_tex = texture(tex_perfect, UV);
	vec4 overcooked_tex = texture(tex_overcooked, UV);
	float clamped_cook = clamp(cook_amount, default_cook_amount, max_cook_amount);

	if (clamped_cook < perfect_cook_amount) {
		// Blend between default and perfect textures based on cook_amount
		float denom = max(perfect_cook_amount - default_cook_amount, 0.0001);
		float blend_factor = clamp((clamped_cook - default_cook_amount) / denom, 0.0, 1.0);
		ALBEDO = mix(default_tex.rgb, perfect_tex.rgb, blend_factor);
	} else {
		// Blend between perfect and overcooked textures based on cook_amount
		float denom = max(max_cook_amount - perfect_cook_amount, 0.0001);
		float blend_factor = clamp((clamped_cook - perfect_cook_amount) / denom, 0.0, 1.0);
		ALBEDO = mix(perfect_tex.rgb, overcooked_tex.rgb, blend_factor);
	}

	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

}
