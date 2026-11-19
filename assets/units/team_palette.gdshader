shader_type canvas_item;

uniform bool enemy_team = false;
varying vec4 instance_color;

void vertex() {
	instance_color = COLOR;
}

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	if (enemy_team) {
		float blue = smoothstep(0.035, 0.24, paint.b - max(paint.r, paint.g));
		float lightness = dot(paint.rgb, vec3(0.24, 0.46, 0.30));
		vec3 crimson = vec3(lightness * 1.85, lightness * 0.48, lightness * 0.36);
		paint.rgb = mix(paint.rgb, crimson, blue);
	}
	COLOR = vec4(paint.rgb * instance_color.rgb, paint.a * instance_color.a);
}
