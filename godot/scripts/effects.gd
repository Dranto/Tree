## Moteur d'effets : transforme les effets des nœuds appris (lus dans res://data/) en
## statistiques, compétences et réactions aux évènements du jeu.
##
## Quatre familles d'effets :
##   {"stat": "damage", "op": "inc", "value": 0.05}        modifie une statistique
##   {"skill": "nova"}                                      donne une compétence active
##   {"on": "kill", "do": "reduce_cooldown", ...}           réagit à un évènement
##   {"skill_mod": "nova", "param": "radius", "op": "more", "value": 1.5, "text": "…"}
##                                                          transforme un réglage d'une compétence
##   {"attack_form": "fouet"}                              change la forme de l'attaque de base
##   {"attack_mod": "fourche", "value": 1}                 ajoute un modificateur à l'attaque de base
##                                                          (voir attack.gd et data/attack.json)
## Un effet peut porter une condition : "if": {"state": "immobile", "min": 0.5}.
##
## Valeur d'une statistique :
##   (base + somme des add) × (1 + somme des inc) × produit des more + somme des flat
## puis bornes « min » / « max » et arrondi éventuel, définis dans stats.json.
extends RefCounted

const Content = preload("res://scripts/content.gd")
const Actions = preload("res://scripts/effect_actions.gd")
const AttackScript = preload("res://scripts/attack.gd")

var stats: Dictionary = {}
var skills: Dictionary = {}
var states: Dictionary = {}
var _mods: Array = []
var _triggers: Dictionary = {}   # évènement -> [{"uid", "effect"}]
var _cooldowns: Dictionary = {}  # uid -> secondes restantes
var _signature := ""
var _skill_mods: Dictionary = {}   # compétence -> [effets skill_mod]
var _skill_cache: Dictionary = {}
## Attaque de base : formes proposées ({"form", "priority", "ring", "order"}) et modificateurs.
var _attack_forms: Array = []
var _attack_mods: Array = []
var _attack_cache: Dictionary = {}


## Reconstruit la liste des effets actifs à partir des nœuds appris.
func rebuild(nodes: Array) -> void:
	_mods = []
	_triggers = {}
	_skill_mods = {}
	_skill_cache = {}
	_attack_forms = []
	_attack_mods = []
	_attack_cache = {}
	skills = {}
	for n in nodes:
		var list: Array = n["effects"]
		for i in list.size():
			var e: Dictionary = list[i]
			if e.has("attack_form"):
				_attack_forms.append({"form": e["attack_form"], "priority": e.get("priority"),
					"ring": float(n.get("ring", 0)), "order": _attack_forms.size()})
			elif e.has("attack_mod"):
				_attack_mods.append(e)
			elif e.has("stat"):
				_mods.append(e)
			elif e.has("skill"):
				skills[e["skill"]] = true
			elif e.has("skill_mod"):
				if not _skill_mods.has(e["skill_mod"]):
					_skill_mods[e["skill_mod"]] = []
				_skill_mods[e["skill_mod"]].append(e)
			elif e.has("on"):
				if not _triggers.has(e["on"]):
					_triggers[e["on"]] = []
				_triggers[e["on"]].append({"uid": "%s:%d" % [str(n["id"]), i], "effect": e})
	compute()


## Recalcule les statistiques avec les effets et les états courants.
func compute() -> Dictionary:
	var defs := Content.stats()
	var acc := {}
	for name in defs:
		acc[name] = {"add": 0.0, "inc": 0.0, "more": 1.0, "flat": 0.0}
	for e in _mods:
		if not acc.has(e["stat"]) or not _passes(e, {}):
			continue
		var a: Dictionary = acc[e["stat"]]
		match e["op"]:
			"add": a["add"] += e["value"]
			"inc": a["inc"] += e["value"]
			"more": a["more"] *= e["value"]
			"flat": a["flat"] += e["value"]
	stats = {}
	for name in defs:
		_resolve(name, defs, acc)
	_signature = _condition_signature()
	return stats


## Réglages d'une compétence (skills.json) une fois les mutations appliquées. Pour chaque réglage :
## « set » remplace la valeur, puis (valeur + somme des add) × (1 + somme des inc) × produit des more.
func skill_settings(id: String) -> Dictionary:
	if _skill_cache.has(id):
		return _skill_cache[id]
	var out: Dictionary = Content.skills().get(id, {}).duplicate(true)
	var acc := {}
	for e in _skill_mods.get(id, []):
		var param: String = e["param"]
		if not acc.has(param):
			acc[param] = {"add": 0.0, "inc": 0.0, "more": 1.0}
		match e["op"]:
			"set": out[param] = e["value"]
			"add": acc[param]["add"] += e["value"]
			"inc": acc[param]["inc"] += e["value"]
			"more": acc[param]["more"] *= e["value"]
	for param in acc:
		var v = out.get(param, 0.0)
		if v is float or v is int:
			out[param] = (float(v) + acc[param]["add"]) * (1.0 + acc[param]["inc"]) * acc[param]["more"]
	_skill_cache[id] = out
	return out


## État de l'attaque de base (forme et modificateurs, voir attack.gd), mis en cache jusqu'au
## prochain rebuild.
func attack_state() -> Dictionary:
	if _attack_cache.is_empty():
		_attack_cache = AttackScript.resolve(_attack_forms, _attack_mods)
	return _attack_cache


func _resolve(name: String, defs: Dictionary, acc: Dictionary):
	if stats.has(name):
		return stats[name]
	var def: Dictionary = defs[name]
	var a: Dictionary = acc[name]
	var inc: float = a["inc"]
	if def.has("inc_min"):
		inc = maxf(inc, def["inc_min"])
	var v: float = (def.get("base", 0.0) + a["add"]) * (1.0 + inc) * a["more"] + a["flat"]
	for bound in ["min", "max"]:
		if def.has(bound):
			var limit = def[bound]
			stats[name] = v  # garde-fou contre une référence circulaire entre plafonds
			var lv: float = _resolve(limit, defs, acc) if limit is String else limit
			v = maxf(v, lv) if bound == "min" else minf(v, lv)
	if def.get("round", "") == "floor":
		stats[name] = int(floor(v))
	else:
		stats[name] = v
	return stats[name]


## Met à jour un état (par exemple « immobile » et sa durée). Renvoie true si un effet
## conditionnel vient de s'activer ou de s'éteindre : les statistiques ont alors été recalculées.
func set_state(name: String, value: float) -> bool:
	states[name] = value
	if _condition_signature() == _signature:
		return false
	compute()
	return true


func _condition_signature() -> String:
	var sig := ""
	for e in _mods:
		if e.has("if"):
			sig += "1" if _passes(e, {}) else "0"
	return sig


func _passes(e: Dictionary, ctx: Dictionary) -> bool:
	if not e.has("if"):
		return true
	var cond: Dictionary = e["if"]
	var v: float = float(ctx.get(cond["state"], states.get(cond["state"], 0.0)))
	return v > 0.0 and v >= float(cond.get("min", 0.0))


## Signale un évènement du jeu. « ctx » transporte ce dont les actions ont besoin (main, enemy…)
## et peut porter des états propres à l'évènement. Renvoie true si une action l'a pris en charge
## (par exemple un coup mortel évité).
func fire(event: String, ctx: Dictionary = {}) -> bool:
	if not _triggers.has(event):
		return false
	ctx["stats"] = stats
	var handled := false
	for t in _triggers[event]:
		var e: Dictionary = t["effect"]
		if float(_cooldowns.get(t["uid"], 0.0)) > 0.0 or not _passes(e, ctx):
			continue
		if e.has("cooldown"):
			_cooldowns[t["uid"]] = float(e["cooldown"])
		if Actions.run(e["do"], e, ctx):
			handled = true
	return handled


func tick(delta: float) -> void:
	for uid in _cooldowns:
		_cooldowns[uid] = maxf(0.0, _cooldowns[uid] - delta)


# --- Outils pour le générateur de l'arbre et l'affichage ---

## Copie d'un effet de statistique dont la valeur est multipliée par k.
static func scaled(e: Dictionary, k: float) -> Dictionary:
	var c := e.duplicate()
	c["value"] = e["value"] * k
	return c


## Fusionne les effets additifs qui visent la même statistique (pour un affichage sur une ligne).
static func merged(list: Array) -> Array:
	var out: Array = []
	for e in list:
		var found := false
		if e.has("stat") and e["op"] != "more" and not e.has("if"):
			for o in out:
				if o.has("stat") and o["stat"] == e["stat"] and o["op"] == e["op"] and not o.has("if"):
					o["value"] += e["value"]
					found = true
					break
		if not found:
			out.append(e.duplicate())
	return out


## Texte affiché au joueur pour un effet.
static func describe(e: Dictionary) -> String:
	if e.get("hidden", false):
		return ""
	if e.has("text"):
		return e["text"]
	if e.has("attack_form") or e.has("attack_mod"):
		return AttackScript.describe_effect(e)
	if e.has("skill"):
		return Content.skills().get(e["skill"], {}).get("desc", "Nouvelle compétence")
	if not e.has("stat"):
		return ""
	var def: Dictionary = Content.stats().get(e["stat"], {})
	var label: String = def.get("label", e["stat"])
	var v: float = e["value"]
	var line := ""
	if e["op"] == "more":
		line = "%s ×%s" % [label, number(v, 2)]
	else:
		var sign := "+" if v >= 0.0 else "-"
		if e["op"] == "inc" or def.get("percent", false):
			line = "%s%s %% %s" % [sign, number(absf(v) * 100.0, 1), label]
		else:
			line = "%s%s %s" % [sign, number(absf(v), 1), label]
	if e.has("if"):
		var cond: Dictionary = e["if"]
		var text: String = Content.conditions().get(cond["state"], {}).get("label", cond["state"])
		line += " (%s)" % text.replace("{min}", number(float(cond.get("min", 0.0)), 1))
	return line


## Nombre à la française : virgule décimale, sans zéros inutiles.
static func number(v: float, decimals: int) -> String:
	var s := String.num(snappedf(v, pow(10.0, -decimals)), decimals)
	return s.replace(".", ",")
