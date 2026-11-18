## Planche des régions (tâche F du jalon 7) : une bande par région du monde, lue dans data/regions/<id>.json
## et dans enemies.json, donc une région ajoutée par ses fichiers y apparaît d'elle-même (il faut alors
## refaire les références : tools/visual-tests.sh --update).
## Chaque bande montre : le sol (terre morte, apaisée, vivante) ; les ennemis de la région (apparitions
## et vagues du Cœur), normaux puis à l'attaque annoncée ; le boss endormi puis ce qui pousse à sa place.
## Ce sont les vrais dessins du jeu (enemy.gd, scripts de boss), figés à un instant précis.
## Capturée par le banc visuel (scénario « regions », capture « galerie_regions »).
extends Node2D

const EnemyScript = preload("res://scripts/enemy.gd")
const Regions = preload("res://scripts/regions.gd")
const RegionUi = preload("res://scripts/region_ui.gd")

var view := Vector2(1600, 900)
## Une bande : {id, y, h}.
var _bands: Array = []
var _labels: Array = []
var _tiles: Array = []


class PlayerStub:
	var position := Vector2(4000, 300)
	var radius := 14.0


class MainStub:
	var player := PlayerStub.new()
	var enemies: Array = []

	func enemies_near(_center: Vector2, _radius: float, _touch_body := true) -> Array:
		return []


## Faux « arène » : juste ce que lisent draw_sleeper et draw_victory, dessinés dans son propre _draw.
class ArenaStub extends Node2D:
	var boss_script
	var victory := false
	var center := Vector2.ZERO
	var state := "ouverte"
	var t := 1.3
	var alive := true
	var region := ""

	func _draw() -> void:
		if boss_script == null:
			return
		if victory:
			boss_script.draw_victory(self)
		else:
			boss_script.draw_sleeper(self)


func _ready() -> void:
	var stub := MainStub.new()
	var ids: Array = Regions.ids()
	if ids.is_empty():
		return
	var band_h := minf(300.0, (view.y - 50.0) / ids.size())
	var k := band_h / 300.0
	for i in ids.size():
		var id: String = ids[i]
		var y0 := 50.0 + i * band_h
		_bands.append({"id": id, "y": y0, "h": band_h})
		_labels.append([Vector2(24, y0 + 26), "%s · décor : %s" % [RegionUi.full_name(id), Regions.section(id, "decor").get("kind", "monde")], 18])
		_ground_tiles(id, y0, k)
		_enemies(stub, id, y0, k)
		_boss(id, y0, k)


## Les trois états du sol, avec le point de la région (baies, spores…).
func _ground_tiles(id: String, y0: float, k: float) -> void:
	var g := Regions.section(id, "ground")
	var named := Regions.named_colors(g)
	var states := [["morte", "dead_dark", "dead_light"], ["apaisée", "purified_dark", "purified_light"], ["vivante", "alive_dark", "alive_light"]]
	for j in states.size():
		var rect := Rect2(Vector2(30 + j * 82, y0 + 52 * k), Vector2(76, 150 * k))
		_tiles.append([rect, Regions.color(g.get(states[j][1], "#000000"), named), Regions.color(g.get(states[j][2], "#000000"), named), Regions.color(g.get("dot", "#ffffff"), named)])
		_labels.append([rect.position + Vector2(2, rect.size.y + 18), states[j][0], 13])


## Les ennemis de la région : sortes d'apparition et de vagues du Cœur, chacun normal puis à l'attaque annoncée.
func _enemies(stub: MainStub, id: String, y0: float, k: float) -> void:
	var kinds: Array = []
	var spawn := Regions.section(id, "spawn")
	for kd in spawn.get("kinds", {}):
		kinds.append(str(kd))
	var heart := Regions.section(id, "heart")
	var hw: Dictionary = heart.get("waves", {})
	for kd in hw.get("kinds", []) + [hw.get("big", ""), heart.get("idle", {}).get("kind", "")]:
		if str(kd) != "" and not str(kd) in kinds:
			kinds.append(str(kd))
	var x := 330.0
	var step := minf(112.0, 900.0 / maxf(1.0, kinds.size()))
	for kd in kinds:
		if EnemyScript.kind_index(kd) < 0:
			continue
		for s in 2:
			var e = EnemyScript.new()
			e.main = stub
			e.setup(kd, 1.0)
			e.t = 0.0
			e.attack_dir = Vector2.RIGHT
			if s == 1 and e.data.has("windup"):
				e.state = "windup"
				e.state_t = float(e.data["windup"]) * 0.35
			var sc := minf(1.0, 40.0 / maxf(14.0, float(e.data["radius"]))) * k * 1.25
			e.scale = Vector2(sc, sc)
			e.position = Vector2(x, y0 + (96 + s * 100) * k)
			add_child(e)
			e.set_process(false)
			e.set_physics_process(false)
		_labels.append([Vector2(x - step * 0.45, y0 + 262 * k), str(EnemyScript.KINDS[EnemyScript.kind_index(kd)]["name"]), 12])
		x += step


## Le boss endormi, puis ce qui pousse à sa place une fois vaincu (dessinés par son script, comme dans l'arène).
func _boss(id: String, y0: float, k: float) -> void:
	var b := Regions.section(id, "boss")
	var path := str(b.get("script", ""))
	if not ResourceLoader.exists(path):
		return
	var script = load(path)
	for j in 2:
		var a := ArenaStub.new()
		a.boss_script = script
		a.victory = j == 1
		a.region = id
		a.position = Vector2(1330 + j * 130, y0 + 150 * k)
		a.scale = Vector2(0.62, 0.62) * k
		add_child(a)
		a.queue_redraw()
	_labels.append([Vector2(1290, y0 + 262 * k), "%s : endormi, puis vaincu" % str(b.get("name", "Boss")), 12])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.1, 0.12, 0.1))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24, 30), "Régions du monde : sol, ennemis (normal, attaque annoncée) et boss", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	for b in _bands:
		draw_rect(Rect2(14, b["y"] + 4, view.x - 28, b["h"] - 8), Color(RegionUi.tint(b["id"]), 0.1))
		draw_rect(Rect2(14, b["y"] + 4, view.x - 28, b["h"] - 8), Color(RegionUi.tint(b["id"]), 0.5), false, 1.5)
	for t in _tiles:
		var r: Rect2 = t[0]
		draw_rect(r, t[1])
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5)), t[2])
		for d in 5:
			draw_circle(r.position + Vector2(14 + d * 12, 18 + (d % 2) * 70), 3.0, t[3])
	for l in _labels:
		draw_string(font, l[0], l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, l[2], Color(0.92, 0.9, 0.82))
