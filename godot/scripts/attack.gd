## Attaque de base du Porte-Graine, décrite par res://data/attack.json.
##
## L'attaque a une FORME (graine, échardes, fouet, ronces vives…) et des MODIFICATEURS
## cumulables (fourche, ricochet, saignement…). L'arbre les change par deux effets de nœud :
##   {"attack_form": "fouet"}                     ajoute une forme (elles se cumulent)
##   {"attack_mod": "fourche", "value": 1}        ajoute un modificateur (cumulable)
## Trois sortes de formes (« kind ») : projectile, melee (arc autour du joueur) et beam (rayon d'Aube,
## instantané, qui traverse tout).
## Le moteur d'effets (effects.gd) les collecte ; resolve() en tire l'état de l'attaque, recalculé
## depuis les nœuds appris (rien n'est sauvegardé en plus).
##
## Formes cumulées : la forme principale est choisie par la règle de priorité ci-dessous ; chaque
## autre forme acquise tire aussi, en ÉCHO, à sa propre cadence et avec ses propres chiffres
## (_step_echoes). Les SYNERGIES (data/synergies.json) ajoutent un bonus quand deux formes,
## familles ou modificateurs se croisent.
##
## Règle de priorité de la forme principale : la « priority » la plus haute l'emporte (celle de
## l'effet si elle est écrite, sinon celle de la forme dans attack.json) ; à égalité, le nœud le
## plus loin de la graine (anneau le plus grand) ; à égalité encore, la dernière source dans
## l'ordre du moteur. Sans aucun effet, la forme est « start ».
##
## Le joueur appelle Attack.fire(player, cible) à sa cadence (Attack.interval) et Attack.step à
## chaque pas : rafales et répétitions partent avec un court décalage. Le dessin est dans
## attack_fx.gd (signatures, pièges, traînées) et projectile.gd (projectiles).
class_name Attack
extends RefCounted

const Content = preload("res://scripts/content.gd")
## Branche Vent : pousser et aspirer les ennemis (recul de la bourrasque, modificateur « repousse »).
const VentScript = preload("res://scripts/vent.gd")
## Plumes des Planeurs de cendre : une attaque « deflect » (la Bourrasque) les emporte.
const Feather = preload("res://scripts/vent_feather.gd")
## Statistique de dégâts de chaque famille d'attaque (comme les compétences, player.gd).
const TAG_STATS := {"corps_a_corps": "melee_damage", "projectile": "projectile_damage", "zone": "area_damage"}
## « Se battre chez soi » : bonus d'une forme de Ronce sur une terre ravivée de sa région (player.gd).
const HOME_BONUS := 0.15
const KINDS := ["projectile", "melee", "beam"]
const STACKS := ["sum", "min", "max"]


## Autoloads lus à l'exécution : ce script est aussi chargé par check_data.gd, sans scène de jeu.
static func _node(name: String):
	var ml = Engine.get_main_loop()
	return ml.root.get_node_or_null(name) if ml is SceneTree else null


static func _stats() -> Dictionary:
	var g = _node("Game")
	return g.stats if g != null else {}


## Son d'une forme d'attaque : dans le groupe « attaque » de Sfx, qui baisse les attaques cumulées qui partent
## sans cesse (sfx.gd › GROUP_*).
static func _sfx(id: String) -> void:
	var s = _node("Sfx")
	if s != null:
		s.play(id, Vector2.INF, 1.0, "attaque")


static func data() -> Dictionary:
	return Content._load("attack")


static func forms() -> Dictionary:
	return data().get("forms", {})


static func mods() -> Dictionary:
	return data().get("mods", {})


static func start_form() -> String:
	return str(data().get("start", "graine"))


# --- État de l'attaque ---

## État de l'attaque à partir des effets collectés par le moteur :
## forms_list : [{"form", "priority" (ou null), "ring", "order"}] ; mods_list : [effets attack_mod].
## Renvoie {"form": forme principale, "echoes": [autres formes acquises], "mods": {nom: valeur},
## "factor": facteur de l'attaque renforcée, "synergies": [synergies actives (data/synergies.json)]}.
## Les formes se cumulent : la principale (règle de priorité) tire à la cadence du joueur, chaque
## autre forme acquise tire aussi, en écho, à sa propre cadence et avec ses propres chiffres
## (« echo » de attack.json). Les modificateurs agissent sur toutes les formes où ils s'appliquent.
static func resolve(forms_list: Array, mods_list: Array) -> Dictionary:
	var all := forms()
	# Meilleure clé de chaque forme (une forme donnée par deux nœuds ne compte qu'une fois).
	var keys := {}
	for f in forms_list:
		var id := str(f["form"])
		if not all.has(id):
			continue
		var pr: float = float(f["priority"]) if f.get("priority") != null else float(all[id].get("priority", 0))
		var key := [pr, float(f.get("ring", 0)), float(f.get("order", 0))]
		if not keys.has(id) or _after(key, keys[id]):
			keys[id] = key
	var ids: Array = keys.keys()
	ids.sort_custom(func(a, b): return _after(keys[a], keys[b]) and keys[a] != keys[b])
	var best: String = ids[0] if not ids.is_empty() else start_form()
	var echoes: Array = ids.slice(1)
	var acc := _accumulate(mods_list)
	# Synergies : lues sur les formes et les modificateurs donnés par l'arbre (pas sur ceux
	# qu'elles ajoutent elles-mêmes), puis leurs modificateurs s'ajoutent aux autres.
	var active := active_synergies([best] + echoes, acc[0])
	if not active.is_empty():
		var extra: Array = mods_list.duplicate()
		for sid in active:
			for e in synergy(sid).get("effects", []):
				if e is Dictionary and e.has("attack_mod"):
					extra.append(e)
		acc = _accumulate(extra)
	return {"form": best, "echoes": echoes, "mods": acc[0], "factor": acc[1], "synergies": active}


## Cumule les effets attack_mod selon leur « stack » : [{nom: valeur}, facteur de la renforcée].
static func _accumulate(mods_list: Array) -> Array:
	var defs := mods()
	var out := {}
	var factor := 0.0
	for e in mods_list:
		var name := str(e["attack_mod"])
		if not defs.has(name):
			continue
		var v := float(e.get("value", 0.0))
		match str(defs[name].get("stack", "sum")):
			"min":
				out[name] = minf(float(out[name]), v) if out.has(name) else v
			"max":
				out[name] = maxf(float(out[name]), v) if out.has(name) else v
			_:
				out[name] = float(out.get(name, 0.0)) + v
		if name == "renforcee" and e.has("factor"):
			factor = maxf(factor, float(e["factor"]))
	if out.has("renforcee") and factor <= 0.0:
		factor = float(defs["renforcee"].get("factor", 2.0))
	for capped in ["enracine", "eblouit"]:
		if out.has(capped):
			out[capped] = minf(float(out[capped]), float(defs[capped].get("cap", 1.0)))
	return [out, factor]


## Toutes les formes actives : la principale, puis les échos.
static func all_forms(st: Dictionary) -> Array:
	return [str(st["form"])] + st.get("echoes", [])


## État d'une forme en écho : mêmes modificateurs que la forme principale, sa propre forme.
static func echo_state(st: Dictionary, id: String) -> Dictionary:
	return {"form": id, "mods": st["mods"], "factor": st.get("factor", 0.0), "echo": true}


## Réglages des échos (attack.json › « echo ») : part des dégâts, décalage du premier tir.
static func echo_def() -> Dictionary:
	return data().get("echo", {})


## Facteur de dégâts d'un état : 1 pour la forme principale, « echo.damage » pour un écho
## (« echo_damage » d'une forme passe devant).
static func echo_factor(st: Dictionary) -> float:
	if not st.get("echo", false):
		return 1.0
	var f := form_def(st)
	return float(f.get("echo_damage", echo_def().get("damage", 1.0)))


## Vrai si la clé a (priorité, anneau, ordre) passe devant b, dans cet ordre.
static func _after(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return true


## État de l'attaque de la partie (moteur d'effets de Game), ou la forme de départ sans Game.
static func current() -> Dictionary:
	var game = _node("Game")
	if game != null and game.effects != null and game.effects.has_method("attack_state"):
		return game.effects.attack_state()
	return {"form": start_form(), "mods": {}, "factor": 0.0}


## Valeur d'un modificateur (0 s'il est absent ou sans effet sur la forme).
static func mod(st: Dictionary, name: String) -> float:
	if not applies(name, str(st["form"])):
		return 0.0
	return float(st["mods"].get(name, 0.0))


## Vrai si le modificateur agit sur la forme (« forms » de attack.json, toutes par défaut).
static func applies(name: String, form: String) -> bool:
	var def: Dictionary = mods().get(name, {})
	return not def.has("forms") or form in def["forms"]


static func form_def(st: Dictionary) -> Dictionary:
	return forms().get(str(st["form"]), forms().get(start_form(), {}))


## Secondes entre deux attaques : 1 / (vitesse d'attaque × cadence de la forme).
static func interval(stats: Dictionary, st := {}) -> float:
	if st.is_empty():
		st = current()
	return 1.0 / maxf(0.05, float(stats.get("fire_rate", 1.0)) * float(form_def(st).get("rate", 1.0)))


## Portée de l'attaque en pixels (forme, modificateur « portee »).
static func reach(st := {}) -> float:
	if st.is_empty():
		st = current()
	return float(form_def(st).get("range", 700.0)) * (1.0 + mod(st, "portee"))


## Multiplicateur des familles d'attaque (tags) d'une forme, et du bonus « se battre chez soi ».
static func multiplier(player, tags: Array, branch: String) -> float:
	var s := _stats()
	var m := 1.0
	for tag in tags:
		m *= float(s.get(TAG_STATS.get(tag, ""), 1.0))
	if branch != "" and player != null and player.has_method("fighting_at_home") and player.fighting_at_home(branch):
		m *= 1.0 + HOME_BONUS
	return m


## Dégâts d'un coup de l'attaque : dégâts de base × facteur de la forme × familles.
## La graine sans modificateur donne exactement l'ancien tir : dégâts × dégâts des projectiles.
static func hit_damage(player, st: Dictionary) -> float:
	var f := form_def(st)
	var base: float = player.current_damage() if player != null and player.has_method("current_damage") else float(_stats().get("damage", 1.0))
	var dmg: float = base * float(f.get("damage", 1.0)) * multiplier(player, f.get("tags", []), str(f.get("branch", ""))) * echo_factor(st)
	# Élan (Vent) : bonus tant que le joueur se déplace (ou vient de bouger).
	var elan := mod(st, "elan")
	if elan > 0.0 and player != null and "still_time" in player and float(player.still_time) < 0.25:
		dmg *= 1.0 + elan
	return dmg


# --- Tir ---

static func _rt(player) -> Dictionary:
	if not "attack_rt" in player:
		return {"count": 0, "queue": []}
	if player.attack_rt.is_empty():
		player.attack_rt = {"count": 0, "queue": []}
	return player.attack_rt


## Lance l'attaque de base vers la cible (un ennemi, une position, ou null : vers player.aim_point).
## Compte les attaques (renforcée, volée), puis met en file les échardes de la rafale et les
## répétitions. « st » : l'état d'une forme en écho (echo_state) ; vide, la forme principale.
## Renvoie la description du tir (pour les tests).
static func fire(player, target = null, st := {}) -> Dictionary:
	if st.is_empty():
		st = current()
	var rt := _rt(player)
	var echo: bool = st.get("echo", false)
	var n := 0
	if echo:
		# Chaque écho compte ses propres attaques (une sur N renforcée, en couronne).
		var counts: Dictionary = rt.get("counts", {})
		counts[st["form"]] = int(counts.get(st["form"], 0)) + 1
		rt["counts"] = counts
		n = int(counts[st["form"]])
	else:
		rt["count"] = int(rt["count"]) + 1
		n = int(rt["count"])
	var shot := {
		"dir": _dir_to(player, target),
		"target": target,
		"empowered": _every(st, "renforcee", n),
		"ring": _every(st, "volee", n),
	}
	if echo:
		shot["echo"] = str(st["form"])
	var f := form_def(st)
	_emit(player, st, shot)
	# Rafale (échardes) : les tirs suivants partent avec un court décalage.
	var burst := int(f.get("burst", 1))
	for i in range(1, burst):
		var later := shot.duplicate()
		later["t"] = float(f.get("burst_gap", 0.06)) * i
		later["burst"] = i
		rt["queue"].append(later)
	# Répétition : toute l'attaque (rafale comprise) repart.
	var again := int(round(mod(st, "repetition")))
	var delay := float(mods().get("repetition", {}).get("delay", 0.14))
	for r in range(1, again + 1):
		for i in burst:
			var rep := shot.duplicate()
			rep["t"] = delay * r + float(f.get("burst_gap", 0.06)) * i
			rep["burst"] = i
			rep["repeat"] = r
			rt["queue"].append(rep)
	if "shoot_anim" in player:
		player.shoot_anim = 0.12   # recul de la lanterne (player.SHOOT_ANIM)
	return shot


## Tire une salve tout autour du joueur avec la forme et les modificateurs actuels
## (action « attack_salvo » des effets déclenchés). count : nombre de directions.
static func salvo(player, count: int) -> void:
	var st := current()
	_emit(player, st, {"dir": player.aim if "aim" in player else Vector2.RIGHT, "target": null, "empowered": false, "ring": true, "ring_count": maxi(1, count), "salvo": true})


## À chaque pas de jeu : fait tirer les formes en écho quand leur cadence le permet, puis
## fait partir les tirs en file (rafale, répétition).
static func step(player, delta: float) -> void:
	if not "attack_rt" in player:
		return
	var st := current()
	if not player.attack_rt.is_empty():
		_step_queue(player, st, delta)
	# Après la file : un écho qui tire maintenant ne voit pas sa rafale avancer dans le même pas.
	if not st.get("echoes", []).is_empty():
		_step_echoes(player, st, delta)


static func _step_queue(player, st: Dictionary, delta: float) -> void:
	var q: Array = player.attack_rt["queue"]
	if q.is_empty():
		return
	var i := 0
	while i < q.size():
		q[i]["t"] = float(q[i]["t"]) - delta
		if q[i]["t"] <= 0.0:
			var shot: Dictionary = q[i]
			q.remove_at(i)
			var sst := st
			if shot.has("echo"):
				# L'écho a pu disparaître (arbre changé) : son tir en file se perd.
				if not shot["echo"] in st.get("echoes", []):
					continue
				sst = echo_state(st, shot["echo"])
			# Une cible encore en vie est suivie ; sinon le tir garde sa direction.
			var tg = shot.get("target")
			if is_instance_valid(tg) and tg is Node2D and not tg.get("dead"):
				shot["dir"] = _dir_to(player, tg)
			_emit(player, sst, shot)
		else:
			i += 1


## Formes en écho : chacune a sa recharge (sa cadence × la vitesse d'attaque) et tire dès qu'un
## ennemi est à sa portée. Le premier tir d'un écho est décalé (« echo.offset » × sa recharge)
## pour ne pas partir dans la même image que la forme principale.
static func _step_echoes(player, st: Dictionary, delta: float) -> void:
	var rt := _rt(player)
	var cds: Dictionary = rt.get("echo_cd", {})
	rt["echo_cd"] = cds
	var s := _stats()
	for id in st["echoes"]:
		var est := echo_state(st, id)
		if not cds.has(id):
			cds[id] = interval(s, est) * float(echo_def().get("offset", 0.5))
		cds[id] = float(cds[id]) - delta
		if float(cds[id]) > 0.0:
			continue
		var pick := _echo_target(player, est)
		if pick.is_empty():
			# Personne à sa portée : l'écho regarde de nouveau un peu plus tard (pas à chaque image).
			cds[id] = float(echo_def().get("retry", 0.1))
			continue
		fire(player, pick[0], est)
		cds[id] = float(cds[id]) + interval(s, est)


## Cible d'un écho : [cible] ou [] s'il n'y a personne à sa portée. La cible du joueur si elle
## est à portée, sinon l'ennemi visible le plus proche. En visée « curseur », l'écho part vers le
## curseur (cible null) dès qu'un ennemi est à sa portée.
static func _echo_target(player, est: Dictionary) -> Array:
	var main = player.main if "main" in player else null
	if main == null or not main.has_method("enemies_near"):
		return []
	var r := reach(est)
	var settings = _node("Settings")
	var cursor: bool = settings != null and str(settings.get("aim_mode")) == "curseur" and not bool(main.get("autotest"))
	var tg = player.get("target")
	if not cursor and is_instance_valid(tg) and tg is Node2D and not tg.get("dead") \
			and tg.position.distance_to(player.position) <= r + float(tg.get("radius") if tg.get("radius") != null else 0.0):
		return [tg]
	var best = null
	var best_d := INF
	for e in main.enemies_near(player.position, r):
		if e.dead or (e.has_method("hidden") and e.hidden()):
			continue
		var d: float = e.position.distance_squared_to(player.position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return []
	return [null] if cursor else [best]


static func _every(st: Dictionary, name: String, n: int) -> bool:
	var every := int(round(mod(st, name)))
	return every > 0 and n % every == 0


static func _dir_to(player, target) -> Vector2:
	var at = null
	if target is Vector2:
		at = target
	elif is_instance_valid(target) and target is Node2D:
		at = target.position
	elif "aim" in player:
		return player.aim   # pas de cible : la visée du joueur (vers aim_point), comme l'ancien tir
	if at != null:
		var off: Vector2 = at - player.position
		if off.length() > 1.0:
			return off.normalized()
	return player.aim if "aim" in player else Vector2.RIGHT


## Un tir : selon la forme, un éventail de projectiles ou un coup en arc.
static func _emit(player, st: Dictionary, shot: Dictionary) -> void:
	var f := form_def(st)
	match str(f.get("kind", "projectile")):
		"melee":
			_strike(player, st, shot)
		"beam":
			_beam(player, st, shot)
		_:
			_shoot(player, st, shot)


static func _directions(st: Dictionary, shot: Dictionary, count: int, spread: float) -> Array:
	var dir: Vector2 = shot["dir"]
	var out: Array = []
	if shot.get("ring", false):
		var n: int = int(shot.get("ring_count", 0))
		if n <= 0:
			n = int(mods().get("volee", {}).get("count", 10)) + count - 1
		for i in n:
			out.append(dir.rotated(i * TAU / n))
		return out
	var jitter := 0.0
	var f := form_def(st)
	if f.has("jitter"):
		# Rafale : un léger écart d'un tir à l'autre, toujours le même (rejouable).
		jitter = float(f["jitter"]) * [0.0, 1.0, -1.0, 0.5, -0.5][int(shot.get("burst", 0)) % 5]
	for i in count:
		# Même calcul que l'ancien tir (angle puis vecteur) : la graine sans modificateur part exactement pareil.
		out.append(Vector2.from_angle(dir.angle() + jitter + (i - (count - 1) / 2.0) * spread))
	return out


## Formes à projectiles (graine, échardes, ronces vives).
static func _shoot(player, st: Dictionary, shot: Dictionary) -> void:
	var main = player.main
	var s := _stats()
	var f := form_def(st)
	var form := str(st["form"])
	var empowered: bool = shot.get("empowered", false)
	var defs := mods()
	var count := int(s["projectiles"])
	if empowered:
		count += int(defs.get("renforcee", {}).get("extra", 2))
	var dmg := hit_damage(player, st)
	if empowered:
		dmg *= float(st["factor"])
	var size: float = float(s["projectile_size"]) * float(f.get("size", 1.0)) * (1.0 + mod(st, "taille"))
	if empowered:
		size *= float(defs.get("renforcee", {}).get("size", 1.5))
	var speed := float(f.get("speed", 640.0))
	var life := reach(st) / maxf(speed, 1.0)
	# Spores lobées : la spore vole en cloche jusqu'à la cible (au plus la portée) et n'éclate qu'à l'arrivée.
	var lob: bool = f.get("lob", false)
	if lob and not shot.get("ring", false):
		life = clampf(_target_distance(player, shot.get("target")), 80.0, reach(st)) / maxf(speed, 1.0)
	var pierce := int(s["pierce"]) + int(f.get("pierce", 0))
	var branch := str(f.get("branch", ""))
	var on_hit := _hit_mods(st)
	# Ronce vive : dégâts de chaque à-coup du piège (dégâts de base × réglage × familles du piège).
	var trap_dmg := 0.0
	if form == "ronce_vive":
		var base: float = player.current_damage() if player.has_method("current_damage") else float(s.get("damage", 1.0))
		trap_dmg = base * float(f.get("trap_damage", 0.5)) * float(f.get("trap_tick", 0.5)) * multiplier(player, f.get("trap_tags", ["zone"]), str(f.get("branch", ""))) * echo_factor(st)
		if empowered:
			trap_dmg *= float(st["factor"])
	if shot.get("burst", 0) == 0 and not shot.get("salvo", false):
		_sfx(str(f.get("sound", "tir")))
	# Traînée d'épines : seul le tir de tête (centre de l'éventail, premier de la rafale) en sème,
	# pour qu'elle reste lisible et dans son budget de dessin.
	var quiet := on_hit.duplicate()
	quiet.erase("trainee")
	var dirs := _directions(st, shot, count, float(f.get("spread", 0.14)))
	var lead := -1 if int(shot.get("burst", 0)) > 0 or shot.get("ring", false) else int(dirs.size() / 2)
	for i in dirs.size():
		var dir: Vector2 = dirs[i]
		var p = main.spawn_projectile(player.position + dir * 18.0, dir * speed, dmg, pierce, size)
		p.life = life
		p.style = form
		p.branch = branch
		p.empowered = empowered
		p.attack = on_hit if i == lead else quiet
		if f.get("return", false):
			# Lame de vent : elle part jusqu'à la portée, puis revient au joueur (projectile.gd).
			p.home = player
			p.returning = true
		if form == "ronce_vive":
			p.plant = true
			p.trap_dmg = trap_dmg
		if lob:
			p.lob = life
	if shot.get("burst", 0) == 0:
		var fx_pos: Vector2 = player.position + Vector2(shot["dir"]) * player.radius * 1.5
		if player.has_method("_sig"):
			player._sig("graine_depart", {"pos": fx_pos, "dir": shot["dir"]})
		if empowered:
			_afx(main, "renforcee", {"pos": player.position, "follow": player, "element": str(f.get("element", "seve"))})
		if shot.get("ring", false):
			_afx(main, "volee", {"pos": player.position, "r": 60.0, "element": str(f.get("element", "seve"))})


## Distance du joueur à la cible d'un tir (ennemi, position, ou point visé).
static func _target_distance(player, target) -> float:
	if target is Vector2:
		return player.position.distance_to(target)
	if is_instance_valid(target) and target is Node2D:
		return player.position.distance_to(target.position)
	if "aim_point" in player:
		return player.position.distance_to(player.aim_point)
	return 400.0


## Modificateurs qu'un projectile emporte (copie, pour qu'un changement de l'arbre en vol ne le touche pas).
static func _hit_mods(st: Dictionary) -> Dictionary:
	var out := {"form": str(st["form"])}
	for name in st["mods"]:
		var v := mod(st, name)
		if v != 0.0:
			out[name] = v
	return out


## Fouet : coup en arc devant le joueur, au corps à corps.
static func _strike(player, st: Dictionary, shot: Dictionary) -> void:
	var main = player.main
	var s := _stats()
	var f := form_def(st)
	var empowered: bool = shot.get("empowered", false)
	var dir: Vector2 = shot["dir"]
	var r: float = reach(st) * (1.0 + 0.5 * mod(st, "taille"))
	var arc: float = float(f.get("arc", 1.9)) * (1.0 + mod(st, "taille"))
	# Projectiles en plus (statistique « projectiles ») : au corps à corps, un arc plus ouvert.
	arc *= 1.0 + float(data().get("melee_arc_per_projectile", 0.25)) * maxf(0.0, float(s.get("projectiles", 1)) - 1.0)
	var dmg := hit_damage(player, st)
	if empowered:
		dmg *= float(st["factor"])
		r *= 1.25
		arc *= float(mods().get("renforcee", {}).get("size", 1.5))
	if shot.get("ring", false):
		arc = TAU
	arc = minf(arc, TAU)
	if shot.get("burst", 0) == 0:
		_sfx(str(f.get("sfx", "fouet")))
	_afx(main, str(f.get("fx", "fouet")), {"pos": player.position, "dir": dir, "r": r, "arc": arc, "follow": player,
		"empowered": empowered, "flip": int(shot.get("repeat", 0)) % 2 == 1})
	if empowered:
		_afx(main, "renforcee", {"pos": player.position, "follow": player, "element": str(f.get("element", "epine"))})
	var on_hit := _hit_mods(st)
	var kb := float(f.get("knockback", 0.0))
	if f.get("deflect", false):
		_deflect(main, player.position, dir, r, arc)
	var struck := 0
	var first = null
	var touched := {}
	for e in main.enemies_near(player.position, r):
		var d: Vector2 = e.position - player.position
		if arc < TAU and d.length() > 1.0 and absf(dir.angle_to(d)) > arc / 2.0 + e.radius / maxf(d.length(), 1.0):
			continue
		struck += 1
		touched[e.get_instance_id()] = true
		if first == null:
			first = e
		hit(main, e, dmg, str(f.get("branch", "")), on_hit)
		apply_on_hit(main, on_hit, e, dmg, e.position)
		if e.dead:
			continue
		if kb > 0.0 and d.length() > 0.1:
			VentScript.push(e, d.normalized() * kb)
		if main.has_method("on_melee_hit"):
			main.on_melee_hit(e, dmg)
	# Secousse (Racine) : un coup qui porte secoue le sol devant le joueur, une fois par coup.
	if struck > 0 and on_hit.has("secousse"):
		_quake(main, player.position + dir * r * (0.75 if arc < TAU else 0.0), dmg * float(on_hit["secousse"]),
			str(f.get("branch", "")), arc >= TAU)
	# Les modificateurs pensés pour les projectiles et le rayon agissent aussi sur un coup qui porte :
	# depuis la cible du coup (ou le premier ennemi touché), dans l'axe joueur → cible.
	if first != null:
		var tg = shot.get("target")
		if is_instance_valid(tg) and tg is Node2D and touched.has(tg.get_instance_id()):
			first = tg
		var axis: Vector2 = first.position - player.position
		first_hit(main, on_hit, first, dmg, first.position, axis.normalized() if axis.length() > 1.0 else dir, "melee", str(f.get("branch", "")), touched)


## Le souffle emporte les plumes de cendre prises dans son cône (le vent contre le vent).
static func _deflect(main, from: Vector2, dir: Vector2, r: float, arc: float) -> void:
	for sh in main.projectiles_layer.get_children():
		if sh.get_script() != Feather or sh.is_queued_for_deletion():
			continue
		var d: Vector2 = sh.position - from
		if d.length() > r or (arc < TAU and d.length() > 1.0 and absf(dir.angle_to(d)) > arc / 2.0):
			continue
		main.fx.ring(sh.position, 3.0, 18.0, 0.25, Art.ec("vent"), 2.0)
		sh.queue_free()


# --- Rayon d'aube ---

## Rayon d'aube (forme « beam ») : un ou plusieurs rayons partent d'un coup jusqu'à la portée et
## frappent tout ce qu'ils traversent (une fois chacun), dans l'ordre du plus proche au plus loin.
static func _beam(player, st: Dictionary, shot: Dictionary) -> void:
	var main = player.main
	var s := _stats()
	var f := form_def(st)
	var empowered: bool = shot.get("empowered", false)
	var defs := mods()
	var count := int(s.get("projectiles", 1))
	if empowered:
		count += int(defs.get("renforcee", {}).get("extra", 2))
	var dmg := hit_damage(player, st)
	var width: float = float(f.get("width", 14.0)) * float(s.get("projectile_size", 1.0)) * float(f.get("size", 1.0)) * (1.0 + mod(st, "taille"))
	if empowered:
		dmg *= float(st["factor"])
		width *= float(defs.get("renforcee", {}).get("size", 1.5))
	if shot.get("burst", 0) == 0 and not shot.get("salvo", false):
		# « aube_rayon » : son de la branche (synth.gd, PR du son d'Aube) ; muet tant qu'il n'existe pas.
		_sfx(str(f.get("sound", "aube_rayon")))
	var on_hit := _hit_mods(st)
	var branch := str(f.get("branch", ""))
	for dir in _directions(st, shot, count, float(f.get("spread", 0.2))):
		var struck := beam_line(main, player.position + dir * 18.0, dir, reach(st), width, dmg, on_hit, branch, empowered)
		if not struck.is_empty():
			var touched := {}
			for e in struck:
				touched[e.get_instance_id()] = true
			first_hit(main, on_hit, struck[0], dmg, struck[0].position, dir, "beam", branch, touched)
	if empowered:
		_afx(main, "renforcee", {"pos": player.position, "follow": player, "element": str(f.get("element", "lumiere"))})
	if shot.get("ring", false):
		_afx(main, "volee", {"pos": player.position, "r": 60.0, "element": str(f.get("element", "lumiere"))})


## Un rayon de « from » vers « dir », long de « length », large de « width » : frappe chaque ennemi
## qu'il traverse (effets au coup compris) et se brise à son premier ennemi (« refraction »).
## « skip » : ennemi à ne pas frapper (celui où un rayon brisé prend naissance). Renvoie les touchés.
static func beam_line(main, from: Vector2, dir: Vector2, length: float, width: float, dmg: float, m: Dictionary,
		branch := "aube", empowered := false, skip = null) -> Array:
	_afx(main, str(forms().get(str(m.get("form", "rayon")), {}).get("fx", "rayon")),
		{"pos": from, "dir": dir, "len": length, "w": width, "empowered": empowered})
	var out: Array = []
	for e in beam_targets(main, from, dir, length, width, skip):
		if e.dead:
			continue
		hit(main, e, dmg, branch, m)
		apply_on_hit(main, m, e, dmg, e.position)
		out.append(e)
	if m.has("refraction") and not out.is_empty():
		var def: Dictionary = mods().get("refraction", {})
		var first = out[0]
		var at: Vector2 = from + dir * clampf((first.position - from).dot(dir), 0.0, length)
		var rest := m.duplicate()
		rest.erase("refraction")
		var n := int(round(float(m["refraction"])))
		var ang := float(def.get("angle", 0.55))
		for i in n:
			var side := -1.0 if i % 2 == 0 else 1.0
			var k := float(i / 2 + 1)
			beam_line(main, at, dir.rotated(side * ang * k), length * float(def.get("length", 0.5)), width * 0.7,
				dmg * float(def.get("factor", 0.6)), rest, branch, false, first)
	return out


## Ennemis traversés par un rayon (segment de largeur « width »), du plus proche au plus loin.
static func beam_targets(main, from: Vector2, dir: Vector2, length: float, width: float, skip = null) -> Array:
	var half := length / 2.0
	var hits: Array = []
	for e in main.enemies_near(from + dir * half, half + width):
		if e.dead or e == skip:
			continue
		var rel: Vector2 = e.position - from
		var along := rel.dot(dir)
		if along < -e.radius or along > length + e.radius or absf(rel.cross(dir)) > width / 2.0 + e.radius:
			continue
		hits.append([along, e])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	return hits.map(func(h): return h[1])


## Un coup de l'attaque de base : la forme peut viser plus juste (« crit » de attack.json) et
## l'incandescence ajoute des dégâts aux critiques (main.hit_crit_bonus / hit_crit_extra).
static func hit(main, e, dmg: float, branch: String, m: Dictionary) -> void:
	var tuned: bool = "hit_crit_bonus" in main
	if tuned:
		main.hit_crit_bonus = float(forms().get(str(m.get("form", "")), {}).get("crit", 0.0))
		main.hit_crit_extra = float(m.get("incandescence", 0.0))
	# Forme du coup (le fouet tranche, enemy_remains.gd) : apparence de la mort seulement.
	var fx = main.get("fx")
	if fx != null and "hit_form" in fx:
		fx.hit_form = str(m.get("form", ""))
	main.player_hit_enemy(e, dmg, true, branch)
	if fx != null and "hit_form" in fx:
		fx.hit_form = ""
	if tuned:
		main.hit_crit_bonus = 0.0
		main.hit_crit_extra = 0.0


# --- Effets au coup ---

## Modificateurs appliqués à chaque ennemi touché par l'attaque (projectile ou fouet) :
## saignement, poison, enracinement, éclat à la mort.
static func apply_on_hit(main, m: Dictionary, e, dmg: float, at: Vector2) -> void:
	var defs := mods()
	var s := _stats()
	# Sangsue (Sève) : chaque coup rend une part de ses dégâts, même celui qui tue.
	if m.has("sangsue"):
		_heal(main, dmg * float(m["sangsue"]))
	# Aubier (Racine) : chaque coup couvre le joueur d'écorce, même celui qui tue.
	if m.has("aubier"):
		_bark(main, dmg * float(m["aubier"]))
	if e.dead:
		if m.has("eclat"):
			_shards(main, m, at, dmg * float(m["eclat"]))
		if m.has("bouffee"):
			_puff(main, at, dmg * float(m["bouffee"]))
		if m.has("rosee"):
			_dew(main, at, float(m["rosee"]))
		return
	if m.has("saignement"):
		e.apply_status("saignement", dmg * float(m["saignement"]), float(defs["saignement"].get("duration", 4.0)) * float(s.get("bleed_duration", 1.0)))
	if m.has("poison"):
		e.apply_poison(dmg * float(m["poison"]), float(defs["poison"].get("duration", 3.0)))
	if m.has("repousse") and "player" in main and main.player != null:
		var away: Vector2 = e.position - main.player.position
		if away.length() > 0.1:
			VentScript.push(e, away.normalized() * float(m["repousse"]))
	if m.has("enracine") and main.rng.randf() < float(m["enracine"]):
		e.apply_status("enracine", 1.0, float(defs["enracine"].get("duration", 0.8)) * float(s.get("root_duration", 1.0)))
		_afx(main, "enracine", {"pos": e.position, "r": float(e.radius)})
	if m.has("eblouit") and main.rng.randf() < float(m["eblouit"]):
		e.apply_status("ebloui", float(defs["eblouit"].get("crit", 0.2)), float(defs["eblouit"].get("duration", 2.5)))


## Aubier (Racine) : « amount » points de bouclier d'écorce, sans dépasser « cap » × la vie maximale.
static func _bark(main, amount: float) -> void:
	if amount <= 0.0 or not ("player" in main) or main.player == null or not ("bark" in main.player):
		return
	var pl = main.player
	var cap := float(_stats().get("max_hp", 100.0)) * float(mods().get("aubier", {}).get("cap", 0.15))
	var before: float = pl.bark
	pl.bark = minf(cap, pl.bark + amount)
	if before <= 0.0 and pl.bark > 0.0:
		_afx(main, "aubier", {"pos": pl.position, "follow": pl})


## Secousse (Racine) : le sol se soulève au point « at » ; les ennemis autour (« radius » de
## attack.json × taille des zones, plus large autour du joueur pour un coup en couronne) subissent
## « dmg ».
static func _quake(main, at: Vector2, dmg: float, branch: String, ring := false) -> void:
	var r := float(mods().get("secousse", {}).get("radius", 80.0)) * float(_stats().get("area", 1.0)) * (1.6 if ring else 1.0)
	_afx(main, "secousse", {"pos": at, "r": r})
	for e in main.enemies_near(at, r):
		if not e.dead:
			main.player_hit_enemy(e, dmg, false, branch)


## Soigne le joueur de « amount » points de vie (Sève : sangsue, perles, rosée).
static func _heal(main, amount: float) -> void:
	if amount > 0.0 and "player" in main and main.player != null:
		main.player.heal(amount)


## Rosée (Sève) : l'ennemi tué rend « part » de la vie maximale, au plus « per_second » fois par
## seconde (l'horloge est celle du joueur, pour rester rejouable).
static func _dew(main, at: Vector2, part: float) -> void:
	if not ("player" in main) or main.player == null:
		return
	var pl = main.player
	var rt := _rt(pl)
	var every := 1.0 / maxf(float(mods().get("rosee", {}).get("per_second", 4)), 0.1)
	var now: float = float(pl.t) if "t" in pl else 0.0
	if now - float(rt.get("dew_at", -INF)) < every:
		return
	rt["dew_at"] = now
	_heal(main, float(_stats().get("max_hp", 100.0)) * part)
	_afx(main, "rosee", {"from": at, "pos": pl.position, "follow": pl})


## Perles de sève : la perle éclabousse les ennemis autour de l'impact (« splash » × ses dégâts,
## dans « splash_radius » × taille des zones) et rend au joueur « leech » × ses dégâts.
static func _splash(p, e, f: Dictionary) -> void:
	var main = p.main
	_heal(main, p.damage * float(f.get("leech", 0.0)))
	var part := float(f.get("splash", 0.0))
	if part <= 0.0:
		return
	var r := float(f.get("splash_radius", 50.0)) * float(_stats().get("area", 1.0)) * maxf(1.0, p.radius / 6.0 / 1.35)
	_afx(main, "perle_eclat", {"pos": e.position, "r": r})
	for o in main.enemies_near(e.position, r):
		if o != e and not o.dead:
			main.player_hit_enemy(o, p.damage * part, false, "seve")


## Éclat à la mort : des épines partent en étoile de l'ennemi tué. Elles ne refont pas d'éclat.
static func _shards(main, m: Dictionary, at: Vector2, dmg: float) -> void:
	var def: Dictionary = mods().get("eclat", {})
	var n := int(def.get("count", 6))
	var speed := float(def.get("speed", 430.0))
	var turn := float(main.rng.randf()) * TAU
	_afx(main, "eclat", {"pos": at})
	for i in n:
		var dir := Vector2.from_angle(turn + i * TAU / n)
		var p = main.spawn_projectile(at + dir * 8.0, dir * speed, dmg, 0, 0.7)
		p.life = float(def.get("life", 0.36))
		p.style = "eclat"
		p.branch = "ronce"


## Premier ennemi touché par un tir de l'attaque : les modificateurs qu'une forme n'a pas « en
## natif » y prennent une forme commune, pour que tous les modificateurs se combinent avec toutes
## les formes. « kind » : projectile (fourche, ricochet, saut, traînée natifs), return (lame qui
## revient : fourche et traînée natives), lob (spore lobée, à l'impact), melee (secousse native),
## beam (réfraction native).
##   fourche     : des éclats partent en éventail du point d'impact (un rayon : rayons obliques) ;
##   ricochet    : le coup rebondit d'ennemi en ennemi (chaîne) ; saut : idem vers les empoisonnés ;
##   traînée     : une touffe d'épines au point d'impact ;
##   réfraction  : des rayons obliques partent du point d'impact ;
##   secousse    : le sol se soulève au point d'impact.
## « touched » : ennemis déjà frappés par ce tir (la chaîne ne les reprend pas).
static func first_hit(main, m: Dictionary, e, dmg: float, at: Vector2, dir: Vector2, kind: String, branch: String, touched := {}) -> void:
	if main == null or m.is_empty():
		return
	var defs := mods()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	# Part des dégâts des versions communes (réglage de l'équilibre : attack.json › first_hit.factor).
	dmg *= float(data().get("first_hit", {}).get("factor", 1.0))
	if m.has("fourche") and kind in ["lob", "melee"]:
		_spray(main, m, at, dir, int(round(float(m["fourche"]))), dmg * float(defs.get("fourche", {}).get("factor", 0.6)), branch, e)
	if m.has("fourche") and kind == "beam":
		_oblique(main, m, at, dir, int(round(float(m["fourche"]))), dmg * float(defs.get("fourche", {}).get("factor", 0.6)), branch, e, ["fourche", "refraction"])
	if m.has("ricochet") and not kind in ["projectile"]:
		_chain(main, m, e, dmg, int(round(float(m["ricochet"]))), "ricochet", branch, touched)
	if m.has("saut") and not kind in ["projectile"]:
		_chain(main, m, e, dmg, int(round(float(m["saut"]))), "saut", branch, touched)
	if m.has("trainee"):
		# Une touffe au point d'impact pour toutes les formes (un projectile en sème aussi en vol).
		trail(main, at, dmg, float(m["trainee"]))
	if m.has("refraction") and kind != "beam":
		_oblique(main, m, at, dir, int(round(float(m["refraction"]))), dmg * float(defs.get("refraction", {}).get("factor", 0.6)), branch, e, ["refraction", "fourche"])
	if m.has("secousse") and kind != "melee":
		_quake(main, at, dmg * float(m["secousse"]), branch, false)


## Modificateurs sans les effets « au premier coup » (pour ce qu'ils font naître : pas de boucle).
static func _calm(m: Dictionary, drop: Array) -> Dictionary:
	var out := m.duplicate()
	for k in drop:
		out.erase(k)
	return out


## Fourche d'un coup qui n'est pas un projectile : n éclats en éventail depuis le point d'impact.
static func _spray(main, m: Dictionary, at: Vector2, dir: Vector2, n: int, dmg: float, branch: String, skip) -> void:
	if n <= 0 or not main.has_method("spawn_projectile"):
		return
	var def: Dictionary = mods().get("fourche", {})
	var ang := float(def.get("angle", 0.42))
	var calm := _calm(m, ["fourche", "ricochet", "saut", "refraction", "secousse", "trainee"])
	_afx(main, "fourche", {"pos": at, "dir": dir, "n": n, "a": ang, "element": _element(m)})
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := float(i / 2 + 1)
		var v := dir.rotated(side * ang * k) * float(def.get("speed", 620.0))
		var c = main.spawn_projectile(at + v.normalized() * 10.0, v, dmg, 0, 0.8)
		c.life = float(def.get("life", 0.4))
		c.style = "eclat"
		c.branch = branch
		c.attack = calm
		c.forked = true
		c.primed = true
		if skip != null and is_instance_valid(skip):
			c.hit[skip.get_instance_id()] = true


## Rayons obliques (réfraction, ou fourche d'un rayon) depuis le point d'impact.
static func _oblique(main, m: Dictionary, at: Vector2, dir: Vector2, n: int, dmg: float, branch: String, skip, drop: Array) -> void:
	if n <= 0:
		return
	var def: Dictionary = mods().get("refraction", {})
	var ang := float(def.get("angle", 0.55))
	var length := float(forms().get("rayon", {}).get("range", 640.0)) * float(def.get("length", 0.5))
	var width := float(forms().get("rayon", {}).get("width", 26.0)) * 0.7
	var calm := _calm(m, drop)
	calm["form"] = "rayon"
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := float(i / 2 + 1)
		beam_line(main, at, dir.rotated(side * ang * k), length, width, dmg, calm, branch, false, skip)


## Ricochet ou saut d'un coup qui n'est pas un projectile : le coup passe d'ennemi en ennemi
## (au plus n fois, dans la portée « reach » du modificateur, × « factor » à chaque fois).
## Le saut ne va que vers les ennemis empoisonnés.
static func _chain(main, m: Dictionary, from, dmg: float, n: int, name: String, branch: String, touched: Dictionary) -> void:
	var def: Dictionary = mods().get(name, {})
	var seen := touched.duplicate()
	var cur = from
	var calm := _calm(m, ["fourche", "ricochet", "saut", "refraction", "secousse", "trainee"])
	for i in n:
		if cur == null or not is_instance_valid(cur):
			return
		var best = null
		var best_d := INF
		for o in main.enemies_near(cur.position, float(def.get("reach", 240.0))):
			if o.dead or o == cur or seen.has(o.get_instance_id()):
				continue
			if name == "saut" and float(o.get("poison_time") if o.get("poison_time") != null else 0.0) <= 0.0:
				continue
			var d: float = o.position.distance_squared_to(cur.position)
			if d < best_d:
				best_d = d
				best = o
		if best == null:
			return
		dmg *= float(def.get("factor", 0.8))
		seen[best.get_instance_id()] = true
		_afx(main, name, {"pos": cur.position, "to": best.position, "element": _element(m)})
		hit(main, best, dmg, branch, calm)
		apply_on_hit(main, calm, best, dmg, best.position)
		cur = best


## Un projectile de l'attaque a touché l'ennemi e (appelé par projectile.gd) : effets au coup,
## puis fourche au premier coup.
static func on_projectile_hit(p, e) -> void:
	var m: Dictionary = p.attack
	apply_on_hit(p.main, m, e, p.damage, e.position)
	var f: Dictionary = forms().get(str(m.get("form", "")), {})
	if f.has("splash") or f.has("leech"):
		_splash(p, e, f)
	if not p.primed:
		# Premier coup du projectile (ses branches, rebonds et sauts ne recomptent pas).
		p.primed = true
		first_hit(p.main, m, e, p.damage, p.position, p.vel.normalized(), "return" if p.returning else "projectile", p.branch, p.hit)
	if m.has("fourche") and not p.forked:
		p.forked = true
		var def: Dictionary = mods().get("fourche", {})
		var n := int(round(float(m["fourche"])))
		var ang := float(def.get("angle", 0.42))
		var dir: Vector2 = p.vel.normalized()
		_afx(p.main, "fourche", {"pos": p.position, "dir": dir, "n": n, "a": ang, "element": _element(m)})
		for i in n:
			# Les branches s'ouvrent de part et d'autre, de plus en plus écartées.
			var side := -1.0 if i % 2 == 0 else 1.0
			var k := float(i / 2 + 1)
			var c = p.main.spawn_projectile(p.position, p.vel.rotated(side * ang * k), p.damage * float(def.get("factor", 0.6)), 0, p.radius / 6.0)
			c.life = maxf(0.15, p.life)
			c.style = p.style
			c.branch = p.branch
			c.attack = m
			c.forked = true
			c.primed = true
			c.plant = p.plant
			c.trap_dmg = p.trap_dmg
			c.hit = p.hit.duplicate()


## Le projectile p ne perfore plus : il saute vers un ennemi empoisonné ou ricoche s'il lui reste des
## sauts ou des rebonds (renvoie true, il continue), sinon il s'arrête (une ronce vive se plante d'abord).
static func on_projectile_end(p, last_hit) -> bool:
	var m: Dictionary = p.attack
	if int(round(float(m.get("saut", 0.0)))) > p.jumps and _jump(p, last_hit):
		return true
	if int(round(float(m.get("ricochet", 0.0)))) > p.bounces:
		var def: Dictionary = mods().get("ricochet", {})
		var best = null
		var best_d := INF
		for o in p.main.enemies_near(p.position, float(def.get("reach", 240.0))):
			if o.dead or o == last_hit or p.hit.has(o.get_instance_id()):
				continue
			var d: float = o.position.distance_squared_to(p.position)
			if d < best_d:
				best_d = d
				best = o
		if best != null:
			p.bounces += 1
			var speed: float = p.vel.length()
			var to: Vector2 = (best.position - p.position).normalized()
			_afx(p.main, "ricochet", {"pos": p.position, "to": best.position, "element": _element(m)})
			p.vel = to * speed
			p.damage *= float(def.get("factor", 0.8))
			p.life = maxf(p.life, sqrt(best_d) / maxf(speed, 1.0) + 0.1)
			p.queue_redraw()
			return true
	if p.plant:
		plant(p.main, p.position, p.trap_dmg, m)
	return false


## Saut : le projectile repart vers l'ennemi empoisonné le plus proche qu'il n'a pas encore touché.
## Renvoie false s'il n'y en a aucun à portée (le projectile peut alors ricocher ou s'arrêter).
static func _jump(p, last_hit) -> bool:
	var def: Dictionary = mods().get("saut", {})
	var best = null
	var best_d := INF
	for o in p.main.enemies_near(p.position, float(def.get("reach", 260.0))):
		if o.dead or o == last_hit or p.hit.has(o.get_instance_id()) or float(o.get("poison_time")) <= 0.0:
			continue
		var d: float = o.position.distance_squared_to(p.position)
		if d < best_d:
			best_d = d
			best = o
	if best == null:
		return false
	p.jumps += 1
	var speed: float = p.vel.length()
	_afx(p.main, "saut", {"pos": p.position, "to": best.position})
	p.vel = (best.position - p.position).normalized() * speed
	p.damage *= float(def.get("factor", 0.9))
	p.life = maxf(p.life, sqrt(best_d) / maxf(speed, 1.0) + 0.1)
	p.queue_redraw()
	return true


## Spores lobées : la spore p touche le sol. Elle blesse tout ce qui est dans son rayon d'éclatement
## (avec les effets au coup de l'attaque) et laisse un petit nuage toxique.
static func land(p) -> void:
	var main = p.main
	var f: Dictionary = forms().get(str(p.style), {})
	var s := _stats()
	var m: Dictionary = p.attack
	var grow: float = float(s.get("area", 1.0)) * (1.0 + float(m.get("taille", 0.0))) * (1.5 if p.empowered else 1.0)
	var r: float = float(f.get("burst_radius", 56.0)) * grow
	_afx(main, "eclosion_spore", {"pos": p.position, "r": r})
	var first = null
	var touched := {}
	for e in main.enemies_near(p.position, r):
		if e.dead:
			continue
		touched[e.get_instance_id()] = true
		if first == null:
			first = e
		hit(main, e, p.damage, p.branch, m)
		apply_on_hit(main, m, e, p.damage, e.position)
	if first != null:
		first_hit(main, m, first, p.damage, p.position, p.vel.normalized(), "lob", p.branch, touched)
	var tick := float(f.get("cloud_tick", 0.5))
	# Dégâts du nuage : part des dégâts du coup par seconde, à chaque à-coup.
	cloud(main, p.position, float(f.get("cloud_radius", 60.0)) * grow, float(f.get("cloud_duration", 2.4)), tick,
		p.damage * float(f.get("cloud_damage", 0.4)) * tick, int(f.get("cloud_max", 8)), "lobee")


## Bouffée : un ennemi tué par l'attaque libère un petit nuage de spores (dmg : dégâts par seconde).
static func _puff(main, at: Vector2, dps: float) -> void:
	var def: Dictionary = mods().get("bouffee", {})
	var tick := float(def.get("tick", 0.5))
	var r := float(def.get("radius", 54.0)) * float(_stats().get("area", 1.0))
	cloud(main, at, r, float(def.get("duration", 2.4)), tick, dps * tick, int(def.get("max", 10)), "bouffee")


## Petit nuage toxique au sol (spores lobées, bouffée) : à chaque à-coup, « dmg » à chaque ennemi
## dedans (coup de Spore) et un peu de poison, pour que la cible compte comme empoisonnée.
## « group » : les nuages d'une même origine se comptent ensemble (« max » à la fois).
static func cloud(main, pos: Vector2, r: float, dur: float, tick: float, dmg: float, cap: int, group := "nuage") -> void:
	if main == null or not "attack_fx" in main or main.attack_fx == null:
		return
	main.attack_fx.add_zone({
		"kind": "nuage", "group": group, "pos": pos, "r": r, "dur": dur, "tick": tick, "dmg": dmg,
		"bleed": 0.0, "root": 0.0, "poison": dmg / maxf(tick, 0.05) * 0.3, "branch": "spore", "max": cap,
	})


## Ronce vive : plante une ronce piégeuse à pos. dmg : dégâts de chaque à-coup ; elle immobilise
## brièvement un ennemi qui y entre (« trap_root ») et le fait saigner avec le modificateur « saignement ».
static func plant(main, pos: Vector2, dmg: float, m: Dictionary) -> void:
	if not "attack_fx" in main or main.attack_fx == null:
		return
	var f: Dictionary = forms().get("ronce_vive", {})
	var s := _stats()
	main.attack_fx.add_zone({
		"kind": "piege", "pos": pos,
		"r": float(f.get("trap_radius", 36.0)) * float(s.get("area", 1.0)) * (1.0 + float(m.get("taille", 0.0))),
		"dur": float(f.get("trap_duration", 2.6)),
		"tick": float(f.get("trap_tick", 0.5)),
		"dmg": dmg,
		"bleed": float(m.get("saignement", 0.0)),
		"root": float(f.get("trap_root", 0.0)) * float(s.get("root_duration", 1.0)),
		"max": int(f.get("trap_max", 10)),
	})


## Traînée d'épines : une touffe d'épines au sol, qui blesse ce qui la traverse.
static func trail(main, pos: Vector2, dmg: float, factor: float) -> void:
	if not "attack_fx" in main or main.attack_fx == null:
		return
	var def: Dictionary = mods().get("trainee", {})
	main.attack_fx.add_zone({
		"kind": "trainee", "pos": pos, "r": float(def.get("radius", 18.0)),
		"dur": float(def.get("duration", 1.6)), "tick": float(def.get("tick", 0.4)),
		"dmg": dmg * factor * float(def.get("tick", 0.4)), "bleed": 0.0, "root": 0.0,
		"max": int(def.get("max", 72)),
	})


static func _element(m: Dictionary) -> String:
	return str(forms().get(str(m.get("form", "graine")), {}).get("element", "seve"))


## Signature de l'attaque (attack_fx.gd), si le jeu en a une.
static func _afx(main, id: String, d: Dictionary) -> void:
	if main != null and "attack_fx" in main and main.attack_fx != null:
		main.attack_fx.play(id, d)


# --- Textes ---

## Texte d'un effet attack_form ou attack_mod pour les infobulles.
static func describe_effect(e: Dictionary) -> String:
	if e.has("attack_form"):
		var f: Dictionary = forms().get(str(e["attack_form"]), {})
		return Loc.t("Attaque de base : %s. %s") % [Loc.data(str(f.get("name", e["attack_form"]))).to_lower(), Loc.data(str(f.get("desc", "")))]
	if e.has("attack_mod"):
		var name := str(e["attack_mod"])
		var def: Dictionary = mods().get(name, {})
		return Loc.t("Attaque : %s") % mod_text(name, float(e.get("value", 0.0)), float(e.get("factor", def.get("factor", 0.0))))
	return ""


## Phrase d'un modificateur avec sa valeur ({v} valeur, {p} pourcentage, {n} « une sur N », {f} facteur).
static func mod_text(name: String, v: float, factor := 0.0) -> String:
	var def: Dictionary = mods().get(name, {})
	var t := Loc.data(str(def.get("text", name)))
	t = t.replace("{v}", _num(v)).replace("{p}", _num(v * 100.0)).replace("{n}", _num(v)).replace("{f}", _num(factor))
	return t


## Lignes qui décrivent un état de l'attaque (forme principale, échos, modificateurs, synergies).
static func describe(st: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var f := form_def(st)
	out.append(Loc.t("%s : %s") % [Loc.data(str(f.get("name", st["form"]))), Loc.data(str(f.get("desc", "")))])
	for id in st.get("echoes", []):
		var ef: Dictionary = forms().get(id, {})
		out.append(Loc.t("En écho, %s : %s") % [Loc.data(str(ef.get("name", id))).to_lower(), Loc.data(str(ef.get("desc", "")))])
	var names: Array = st["mods"].keys()
	names.sort()
	for name in names:
		var line := mod_text(name, float(st["mods"][name]), float(st.get("factor", 0.0)))
		if not applies_any(name, st):
			line += Loc.t(" (sans effet sur : %s)") % Loc.t(", ").join(all_forms(st).map(func(id): return _form_name(id).to_lower()))
		out.append(line)
	for sid in st.get("synergies", []):
		out.append(Loc.t("Synergie « %s » : %s") % [_syn_name(sid), synergy_text(sid)])
	return out


## Vrai si le modificateur agit sur au moins une des formes actives.
static func applies_any(name: String, st: Dictionary) -> bool:
	for id in all_forms(st):
		if applies(name, id):
			return true
	return false


static func _form_name(id: String) -> String:
	return Loc.data(str(forms().get(id, {}).get("name", id)))


static func _syn_name(sid: String) -> String:
	return Loc.data(str(synergy(sid).get("name", sid)))


## Différences entre deux états, pour l'aperçu de l'arbre : [{"text": "Attaque : Graines → Fouet"}, …].
## Une forme ajoutée à côté de la principale part en écho : « Attaque : + fouet, en écho ».
static func diff(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	var had := all_forms(before)
	var has := all_forms(after)
	if before["form"] != after["form"]:
		var line := Loc.t("Attaque : %s → %s") % [_form_name(before["form"]), _form_name(after["form"])]
		if before["form"] in has:
			line += Loc.t(" (%s continue en écho)") % _form_name(before["form"]).to_lower()
		out.append({"stat": "attack_form", "text": line})
	for id in has:
		if id != after["form"] and not id in had:
			out.append({"stat": "attack_form", "text": Loc.t("Attaque : + %s, en écho (tire en plus, à sa cadence)") % _form_name(id).to_lower()})
	for id in had:
		if not id in has and id != start_form():
			out.append({"stat": "attack_form", "text": Loc.t("Attaque : − %s") % _form_name(id).to_lower()})
	var names := {}
	for n in before["mods"]:
		names[n] = true
	for n in after["mods"]:
		names[n] = true
	var keys: Array = names.keys()
	keys.sort()
	for n in keys:
		var a := float(before["mods"].get(n, 0.0))
		var b := float(after["mods"].get(n, 0.0))
		if absf(a - b) < 0.0001 and float(before.get("factor", 0.0)) == float(after.get("factor", 0.0)):
			continue
		var label := Loc.data(str(mods().get(n, {}).get("name", n)))
		var line := ""
		if not before["mods"].has(n):
			line = Loc.t("Attaque : + %s (%s)") % [label.to_lower(), mod_text(n, b, float(after.get("factor", 0.0)))]
		elif not after["mods"].has(n):
			line = Loc.t("Attaque : − %s") % label.to_lower()
		else:
			line = Loc.t("Attaque, %s : %s → %s") % [label.to_lower(), _num(a), _num(b)]
		if not applies_any(n, after):
			line += Loc.t(" (sans effet sur cette forme)")
		out.append({"stat": "attack_mod", "text": line})
	for sid in after.get("synergies", []):
		if not sid in before.get("synergies", []):
			out.append({"stat": "synergy", "text": Loc.t("Synergie : + %s (%s)") % [_syn_name(sid), synergy_text(sid)]})
	for sid in before.get("synergies", []):
		if not sid in after.get("synergies", []):
			out.append({"stat": "synergy", "text": Loc.t("Synergie : − %s") % _syn_name(sid)})
	return out


# --- Synergies (data/synergies.json) ---

## Familles de conditions d'une synergie : une forme active, un modificateur reçu de l'arbre,
## une famille d'attaque (tags), une branche, un nombre de formes actives.
const NEEDS := ["form", "mod", "family", "branch", "forms"]


static func synergies() -> Dictionary:
	return Content._load("synergies").get("synergies", {})


static func synergy(id: String) -> Dictionary:
	return synergies().get(id, {})


## Synergies dont toutes les conditions sont vraies, dans l'ordre du fichier.
static func active_synergies(form_ids: Array, mod_values: Dictionary) -> Array:
	var out: Array = []
	var all := synergies()
	for sid in all:
		var sy = all[sid]
		if sy is Dictionary and _meets(sy.get("needs", []), form_ids, mod_values):
			out.append(sid)
	return out


static func _meets(needs: Array, form_ids: Array, mod_values: Dictionary) -> bool:
	if needs.is_empty():
		return false
	for n in needs:
		if not need_met(n, form_ids, mod_values):
			return false
	return true


## Une condition de synergie est-elle remplie par ces formes et ces modificateurs ?
static func need_met(n: Dictionary, form_ids: Array, mod_values: Dictionary) -> bool:
	if n.has("form"):
		return str(n["form"]) in form_ids
	if n.has("mod"):
		return float(mod_values.get(str(n["mod"]), 0.0)) > 0.0
	if n.has("forms"):
		return form_ids.size() >= int(n["forms"])
	for id in form_ids:
		var f: Dictionary = forms().get(id, {})
		if n.has("family") and (str(n["family"]) in f.get("tags", []) or str(n["family"]) in f.get("trap_tags", [])):
			return true
		if n.has("branch") and str(f.get("branch", "")) == str(n["branch"]):
			return true
	return false


const BRANCH_NAMES := {"ronce": "Ronce", "spore": "Spore", "vent": "Vent", "seve": "Sève", "aube": "Aube", "racine": "Racine"} # i18n
const FAMILY_NAMES := {"corps_a_corps": "une attaque au corps à corps", "projectile": "une attaque à projectiles", "zone": "une attaque de zone"} # i18n

## Texte d'une condition : « Fouet », « une attaque de zone », « trois formes »…
static func need_text(n: Dictionary) -> String:
	if n.has("form"):
		return _form_name(str(n["form"]))
	if n.has("mod"):
		return Loc.data(str(mods().get(str(n["mod"]), {}).get("name", n["mod"])))
	if n.has("family"):
		return Loc.t(str(FAMILY_NAMES.get(str(n["family"]), n["family"])))
	if n.has("branch"):
		return Loc.t("une forme de %s") % Loc.t(str(BRANCH_NAMES.get(str(n["branch"]), n["branch"])))
	if n.has("forms"):
		return Loc.t("%d formes d'attaque") % int(n["forms"])
	return "?"


## Conditions d'une synergie : « Rayon d'aube + Lames de vent ».
static func synergy_needs(sid: String) -> String:
	var parts := PackedStringArray()
	for n in synergy(sid).get("needs", []):
		parts.append(need_text(n))
	return " + ".join(parts)


## Phrase d'une synergie : « Rayon d'aube + Lames de vent : … ».
static func synergy_text(sid: String) -> String:
	return Loc.t("%s : %s") % [synergy_needs(sid), Loc.data(str(synergy(sid).get("desc", "")))]


## Synergies où entrent les effets d'un nœud (sa forme, ses modificateurs), pour l'infobulle de
## l'arbre : [[texte, active]]. « st » : l'attaque actuelle (pour dire ce qui manque).
static func synergy_hints(effects: Array, st: Dictionary) -> Array:
	var out: Array = []
	var gives_forms: Array = []
	var gives_mods: Array = []
	for e in effects:
		if e is Dictionary and e.has("attack_form"):
			gives_forms.append(str(e["attack_form"]))
		elif e is Dictionary and e.has("attack_mod"):
			gives_mods.append(str(e["attack_mod"]))
	if gives_forms.is_empty() and gives_mods.is_empty():
		return out
	var all := synergies()
	var active: Array = st.get("synergies", [])
	for sid in all:
		var sy: Dictionary = all[sid]
		var concerned := false
		for n in sy.get("needs", []):
			if (n.has("form") and str(n["form"]) in gives_forms) or (n.has("mod") and str(n["mod"]) in gives_mods):
				concerned = true
			for id in gives_forms:
				if need_met(n, [id], {}) and (n.has("family") or n.has("branch")):
					concerned = true
		if not concerned:
			continue
		# Active : la phrase entière ; possible : le nom et ce qu'elle demande, pour rester court.
		if sid in active:
			out.append([Loc.t("Synergie « %s » : %s") % [_syn_name(sid), synergy_text(sid)], true])
		else:
			out.append([Loc.t("Synergie possible « %s » : %s") % [_syn_name(sid), synergy_needs(sid)], false])
	return out


## Effets de statistiques et réactions des synergies actives (les attack_mod sont déjà dans l'état).
static func synergy_effects(ids: Array) -> Array:
	var out: Array = []
	for sid in ids:
		for e in synergy(sid).get("effects", []):
			if e is Dictionary and not e.has("attack_mod"):
				out.append(e)
	return out


## Nombre selon la langue (virgule décimale en français), sans zéros inutiles.
static func _num(v: float) -> String:
	return Loc.num(v, 2)


# --- Vérification des données ---

## Erreurs de data/attack.json (formes, modificateurs, forme de départ).
static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var d := data()
	if d.is_empty():
		errors.append("attack.json est absent, vide ou illisible")
		return errors
	var all := forms()
	if not all.has(start_form()):
		errors.append("attack.json : la forme de départ « %s » n'existe pas" % start_form())
	for id in all:
		var f = all[id]
		var w := "attack.json, forme « %s »" % id
		if not f is Dictionary:
			errors.append(w + " : doit être un objet")
			continue
		if str(f.get("name", "")) == "" or str(f.get("desc", "")) == "":
			errors.append(w + " : « name » et « desc » sont obligatoires")
		if not str(f.get("kind", "")) in KINDS:
			errors.append("%s : « kind » doit valoir %s" % [w, " ou ".join(KINDS)])
		for k in ["damage", "rate", "range"]:
			if not (f.get(k) is float or f.get(k) is int) or float(f[k]) <= 0.0:
				errors.append("%s : « %s » doit être un nombre positif" % [w, k])
		if str(f.get("kind", "")) == "projectile" and not (f.get("speed") is float or f.get("speed") is int):
			errors.append(w + " : une forme à projectiles demande « speed »")
		if str(f.get("kind", "")) == "melee" and not (f.get("arc") is float or f.get("arc") is int):
			errors.append(w + " : une forme au corps à corps demande « arc »")
		if str(f.get("kind", "")) == "beam" and not (f.get("width") is float or f.get("width") is int):
			errors.append(w + " : un rayon demande « width »")
		for tag in f.get("tags", []) + f.get("trap_tags", []):
			if not TAG_STATS.has(tag):
				errors.append("%s : famille inconnue « %s » (attendu : %s)" % [w, tag, ", ".join(TAG_STATS.keys())])
		if not Art.ELEMENTS.has(str(f.get("element", ""))):
			errors.append("%s : « element » doit être un élément de la charte (art.gd)" % w)
	for name in mods():
		var m = mods()[name]
		var w := "attack.json, modificateur « %s »" % name
		if not m is Dictionary or str(m.get("name", "")) == "" or str(m.get("text", "")) == "":
			errors.append(w + " : « name » et « text » sont obligatoires")
			continue
		if not str(m.get("stack", "sum")) in STACKS:
			errors.append("%s : « stack » doit valoir %s" % [w, ", ".join(STACKS)])
		for fid in m.get("forms", []):
			if not all.has(fid):
				errors.append("%s : forme inconnue « %s »" % [w, fid])
	var echo = d.get("echo", {})
	if not echo is Dictionary or not (echo.get("damage", 1.0) is float or echo.get("damage", 1.0) is int) or float(echo.get("damage", 1.0)) <= 0.0:
		errors.append("attack.json : « echo.damage » doit être un nombre positif")
	errors.append_array(validate_synergies())
	return errors


## Erreurs de data/synergies.json (conditions ; les effets sont vérifiés par content.gd).
static func validate_synergies() -> PackedStringArray:
	var errors := PackedStringArray()
	var all := synergies()
	for sid in all:
		var sy = all[sid]
		var w := "synergies.json, synergie « %s »" % sid
		if not sy is Dictionary or str(sy.get("name", "")) == "" or str(sy.get("desc", "")) == "":
			errors.append(w + " : « name » et « desc » sont obligatoires")
			continue
		var needs = sy.get("needs", [])
		if not needs is Array or needs.size() < 2 and not (needs.size() == 1 and needs[0] is Dictionary and needs[0].has("forms")):
			errors.append(w + " : « needs » demande au moins deux conditions")
			continue
		for n in needs:
			if not n is Dictionary or n.size() != 1 or not str(n.keys()[0]) in NEEDS:
				errors.append("%s : une condition est un objet à une clé parmi %s" % [w, ", ".join(NEEDS)])
				continue
			if n.has("form") and not forms().has(str(n["form"])):
				errors.append("%s : forme inconnue « %s »" % [w, n["form"]])
			if n.has("mod") and not mods().has(str(n["mod"])):
				errors.append("%s : modificateur inconnu « %s »" % [w, n["mod"]])
			if n.has("family") and not TAG_STATS.has(str(n["family"])):
				errors.append("%s : famille inconnue « %s »" % [w, n["family"]])
		var effects = sy.get("effects", [])
		if not effects is Array or effects.is_empty():
			errors.append(w + " : aucun effet")
			continue
		for e in effects:
			if e is Dictionary and e.has("attack_form"):
				errors.append(w + " : une synergie ne donne pas de forme (« attack_form »)")
	return errors
