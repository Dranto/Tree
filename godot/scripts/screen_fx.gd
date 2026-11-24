## Effets d'écran : vignette rouge quand le Porte-Graine est touché, voiles de transition
## (ouverture de l'arbre, du journal ou de la carte, mort et renaissance, entrée de l'arène)
## et éclat de couleur. Animation seulement : rien ici ne change le jeu.
##
## Rythme de la charte : le choc est immédiat (anticipation nulle, c'est une réaction), puis
## un retour souple (Anim.ease_out). La couche est au-dessus de tout sauf du menu pause,
## et ne se redessine que tant qu'un effet est actif.
extends CanvasLayer

## Vitesse à laquelle la vignette de dégâts s'éteint (par seconde) : ~0,45 s pour un coup plein.
const HURT_DECAY := 2.2
## Épaisseur de la vignette, part de la plus petite dimension de l'écran.
const VIGNETTE_WIDTH := 0.2
const VIGNETTE_ALPHA := 0.45
## Durées types des transitions (secondes).
const FADE_PANEL := 0.18
const FADE_DEATH := 1.1
const FADE_ARENA := 0.5

var main
var _hurt := 0.0
## Voile en cours : couleur, opacité de départ et d'arrivée, durée, temps écoulé.
var _veil := {"color": Color.BLACK, "from": 0.0, "to": 0.0, "dur": 0.0, "t": 0.0}
## Éclat de couleur (bord de l'écran) : couleur et avancement.
var _glow := {"color": Color.WHITE, "t": 1.0, "dur": 1.0, "a": 0.0}
var _canvas: Control


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_fx)
	add_child(_canvas)


## Le Porte-Graine encaisse un coup : vignette rouge, d'autant plus forte que le coup est gros.
## amount : part de sa vie maximale perdue (0 à 1).
func hurt(amount := 0.1) -> void:
	_hurt = clampf(maxf(_hurt, 0.45 + amount * 2.0), 0.0, 1.0)
	_canvas.queue_redraw()


## Atténuation des éclats lumineux (Settings.flash_scale, divisée par deux si les effets sont
## réduits). Les voiles sombres de transition ne sont pas concernés.
static func flash_k() -> float:
	return Settings.flash_scale * (0.5 if Settings.reduce_effects else 1.0)


## Voile qui passe d'une opacité à l'autre (ex. noir 0,6 → 0 : un écran qui « s'ouvre »).
## Un voile clair est un éclat : il suit le réglage des éclats lumineux.
func fade(color: Color, from_alpha: float, to_alpha: float, dur: float) -> void:
	if color.get_luminance() > 0.5:
		from_alpha *= flash_k()
		to_alpha *= flash_k()
	_veil = {"color": color, "from": from_alpha, "to": to_alpha, "dur": maxf(dur, 0.01), "t": 0.0}
	_canvas.queue_redraw()


## Éclat sur le bord de l'écran (arène qui se referme, sanctuaire ravivé…).
func glow(color: Color, alpha: float, dur: float) -> void:
	alpha *= flash_k()
	_glow = {"color": color, "t": 0.0, "dur": maxf(dur, 0.01), "a": alpha}
	_canvas.queue_redraw()


func active() -> bool:
	return _hurt > 0.0 or _veil["t"] < _veil["dur"] or _glow["t"] < _glow["dur"]


func _process(delta: float) -> void:
	if not active():
		return
	# Temps réel : la micro-pause d'un coup ne doit pas figer la vignette qu'elle accompagne.
	var real := delta / maxf(Engine.time_scale, 0.01)
	_hurt = maxf(0.0, _hurt - HURT_DECAY * real)
	_veil["t"] = minf(_veil["t"] + real, _veil["dur"])
	_glow["t"] = minf(_glow["t"] + real, _glow["dur"])
	_canvas.queue_redraw()


## Opacité courante du voile (0 quand il est fini).
func veil_alpha() -> float:
	if _veil["t"] >= _veil["dur"]:
		return 0.0
	return lerpf(_veil["from"], _veil["to"], Anim.ease_out(_veil["t"] / _veil["dur"]))


func _draw_fx() -> void:
	var size := _canvas.size
	var va := veil_alpha()
	if va > 0.004:
		var col: Color = _veil["color"]
		col.a *= va
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), col)
	if _hurt > 0.0:
		var a: float = VIGNETTE_ALPHA * Anim.ease_out(_hurt)
		# La vignette porte une information (coup reçu) : jamais sous 40 %.
		a *= lerpf(0.4, 1.0, flash_k())
		_edge(size, Art.c("danger"), a)
	if _glow["t"] < _glow["dur"]:
		var k: float = 1.0 - Anim.ease_out(_glow["t"] / _glow["dur"])
		_edge(size, _glow["color"], _glow["a"] * k)


## Bande dégradée sur les quatre bords : opaque au bord, transparente vers le centre.
func _edge(size: Vector2, col: Color, alpha: float) -> void:
	if alpha <= 0.004:
		return
	var w := minf(size.x, size.y) * VIGNETTE_WIDTH
	var edge := Color(col.r, col.g, col.b, alpha)
	var none := Color(col.r, col.g, col.b, 0.0)
	var corners := [Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]
	var inner := [Vector2(w, w), Vector2(size.x - w, w), Vector2(size.x - w, size.y - w), Vector2(w, size.y - w)]
	for i in 4:
		var j := (i + 1) % 4
		_canvas.draw_polygon(PackedVector2Array([corners[i], corners[j], inner[j], inner[i]]),
			PackedColorArray([edge, edge, none, none]))
