## Le dernier coup du boss final (moments.gd › on_boss_kill, boss marqué grand_finale) : tout
## l'affichage se distord, HUD compris. En temps réel (le jeu est presque à l'arrêt pendant ce temps) :
##   0 → 0,22 s : l'écran est aspiré vers le boss (le coup s'enfonce) ;
##   0,22 s : il éclate : gonflement, onde de choc qui réfracte l'image, torsion, aberration
##            chromatique ; une seconde onde à 0,9 s ;
##   jusqu'à DURATION : tout retombe.
## Dosé par Settings.shake_strength() (mouvement de l'image) ; rien avec « réduire les effets ».
extends CanvasLayer

const Shader_ = preload("res://shaders/distortion.gdshader")
const DURATION := 3.0
const SNAP := 0.22

var main
var target: Node2D
var at := Vector2.ZERO
var t := 0.0
var k := 1.0
var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = Shader_
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _mat
	add_child(_rect)
	_apply()


## Lance la distorsion sur « node » (suivi tant qu'il existe) ou sur le point « pos ».
func start(node: Node2D, pos: Vector2, strength: float) -> void:
	target = node
	at = pos
	k = strength
	t = 0.0


func _process(delta: float) -> void:
	t += clampf(delta / maxf(Engine.time_scale, 0.01), 0.0, 0.1)
	if t >= DURATION:
		queue_free()
		return
	_apply()


func _apply() -> void:
	if _mat == null:
		return
	if target != null and is_instance_valid(target):
		at = target.global_position + Vector2(0, -40.0)
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var screen: Vector2 = vp.get_canvas_transform() * at
	_mat.set_shader_parameter("center", Vector2(screen.x / size.x, screen.y / size.y))
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	var bulge := 0.0
	var wave_r := 0.0
	var wave_amp := 0.0
	var wave2_r := 0.0
	var wave2_amp := 0.0
	var twist := 0.0
	var chroma := 0.0
	if t < SNAP:
		# Aspiration : l'écran se creuse vers le point d'impact.
		var u := t / SNAP
		bulge = -0.55 * Anim.ease_in(u)
		twist = 0.5 * u
		chroma = 0.012 * u
	else:
		var u := t - SNAP
		var fall := exp(-u * 1.6)
		bulge = 0.7 * exp(-u * 3.5) * cos(u * 9.0)
		wave_r = u * 1.35
		wave_amp = 1.6 * fall
		twist = 0.5 * exp(-u * 2.2) * cos(u * 6.0)
		chroma = 0.045 * exp(-u * 1.2)
		if u > 0.68:
			var v := u - 0.68
			wave2_r = v * 1.1
			wave2_amp = 1.0 * exp(-v * 1.8)
	_mat.set_shader_parameter("bulge", bulge * k)
	_mat.set_shader_parameter("wave_r", wave_r)
	_mat.set_shader_parameter("wave_amp", wave_amp * k)
	_mat.set_shader_parameter("wave2_r", wave2_r)
	_mat.set_shader_parameter("wave2_amp", wave2_amp * k)
	_mat.set_shader_parameter("twist", twist * k)
	_mat.set_shader_parameter("chroma", chroma * k)
	_mat.set_shader_parameter("glow", 0.35 * Settings.flash_strength())
