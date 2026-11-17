shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float top = (1.0 - smoothstep(0.0, 0.23, UV.y)) * 0.62;
	float bottom = smoothstep(0.72, 1.0, UV.y) * 0.57;
	float sides = smoothstep(0.27, 0.53, abs(UV.x - 0.5)) * 0.59;
	COLOR = vec4(0.018, 0.037, 0.071, max(max(top, bottom), sides));
}
