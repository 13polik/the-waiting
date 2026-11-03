extends CanvasLayer
## A soft vignette and a whisper of grain over the world (below the UI).
## One full-screen quad with a tiny shader: cheap enough for older iPhones.

const SHADER := """
shader_type canvas_item;
uniform float strength = 0.62;
uniform float grain = 0.035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.32, 0.86, length(uv * vec2(1.0, 1.25)));
	// Grain changes only eight times a second: alive, never flickering.
	float n = hash(floor(FRAGCOORD.xy / 2.0) + floor(TIME * 8.0) * 17.0) - 0.5;
	COLOR = vec4(vec3(0.0), clamp(v * strength + n * grain, 0.0, 1.0));
}
"""


func _ready() -> void:
	layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
