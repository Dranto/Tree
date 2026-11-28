## Partition d'un boss sur son morceau fait à la main (boss_sync.gd) : ce qui frappe sur quel temps.
## Écrit pour l'Amanite-Mère à partir de la partition de la Mère-Ronce (boss_ronce.gd › SCORE,
## DRUMS_POWER), pour que les boss suivants la reprennent sans la recopier.
##
## Le boss donne :
##   - « score » : par phase, {"loop": section du morceau, "phrases": [{"coups": [[temps, attaque]…],
##     "ondes": [mesures], "deluge": bool}…]} ; une phrase = quatre mesures, elles se répètent ;
##   - « power » : par phase, ce que la batterie déclenche : « ondes » (mesures où une grosse caisse
##     franche lance une onde, les autres un pouls), « roll »/« roll_grid » (caisses claires : jets par
##     coup, 0 : rien ; seulement les doubles croches multiples de la grille), « spark »/« spark_grid »
##     (charlestons), « prick » (caisses douces, 0 : rien) ;
##   - « announce » : annonce (temps) de chaque attaque de la partition, « drum_lead » : annonce des
##     coups de batterie qui en ont une (onde, pouls, piqure), « fallback » : coups de batterie quand le
##     morceau n'en donne pas (une phrase, doubles croches par mesure).
## Coups de batterie produits : onde, pouls, roulement (caisse claire), aiguille (charleston), piqure
## (caisse douce) ; le boss les joue à sa façon (fire). Tests : ronce_musique_test, spore_musique_test.
extends RefCounted

const SOURCES := ["kick", "kick_doux", "caisse", "charleston", "caisse_douce"]

var boss
var score: Dictionary
var power: Dictionary
var announce: Dictionary
var drum_lead: Dictionary
var fallback: Dictionary
var min_announce := 2.0

## Temps du morceau où commence la boucle de la phase (-1 : pas encore calée), ses coups
## ({"beat", "kind", "phrase"}), sa batterie ({"beat", "kind", "deluge"}) et sa longueur (temps).
var origin := -1.0
var phase := 0
var hits: Array = []
var drums: Array = []
var length := 32.0
var _last := -INF
var _done := -INF
var _skip_toggle := false
## Coups sautés (l'attaque d'avant débordait) : 0 si la partition est bien écrite (tests) ; attaques
## lancées ; coups de batterie joués, par sorte.
var skipped := 0
var played := 0
var drums_played: Dictionary = {}


func _init(b, s: Dictionary, p: Dictionary, a: Dictionary, lead: Dictionary, fb: Dictionary) -> void:
	boss = b
	score = s
	power = p
	announce = a
	drum_lead = lead
	fallback = fb


## Vrai quand la partition mène le combat (la phase en a une et le morceau tourne) ; la cale sur la
## boucle de la phase au premier passage.
func ready() -> bool:
	if not boss.on_music_grid() or not score.has(boss.phase):
		return false
	if phase != boss.phase or origin < 0.0:
		build()
	return true


## À rappeler en changeant de phase : la partition se recale au retour de la batterie.
func reset() -> void:
	origin = -1.0


## Pose la partition de la phase : sa boucle commence à la mesure où le combat a repris (resume_bar).
func build() -> void:
	var sync = boss.sync
	phase = boss.phase
	var bb: int = sync.beats
	var start_bar: int = sync.resume_bar if sync.resume_bar >= 0 else int(floor(sync.bars_now()))
	origin = float(start_bar * bb)
	var cfg: Dictionary = score[phase]
	var sec: Dictionary = sync.data.get("sections", {}).get(cfg["loop"], {})
	var bars := 8
	if sec.has("mesures"):
		bars = int(sec["mesures"][1]) - int(sec["mesures"][0]) + 1
	length = float(bars * bb)
	var coups: Dictionary = sec.get("coups", {})
	var phrases: Array = cfg["phrases"]
	var pw: Dictionary = power[phase]
	hits = []
	drums = []
	for i in int(ceil(bars / 4.0)):
		var ph: Dictionary = phrases[i % phrases.size()]
		var base := float(i * 4 * bb)
		for h in ph["coups"]:
			if float(h[0]) + base < length:
				hits.append({"beat": base + float(h[0]), "kind": str(h[1]), "phrase": i})
		var flood: bool = ph.get("deluge", false)
		var wave_bars: Array = ph.get("ondes", pw["ondes"])
		for m in 4:
			var bar_i: int = i * 4 + m
			if bar_i >= bars:
				continue
			for src in SOURCES:
				var kind := kind_of(src, m in wave_bars, flood, pw)
				if kind == "":
					continue
				var grid := grid_of(src, flood, pw)
				var list: Array = coups[src][bar_i] if coups.has(src) and bar_i < coups[src].size() else fallback[src][m]
				for six in list:
					if int(six) % grid == 0:
						drums.append({"beat": float(bar_i * bb) + float(six) / 4.0, "kind": kind, "deluge": flood})
	drums.sort_custom(func(a, b): return a["beat"] < b["beat"])
	# Les coups trop proches de la reprise pour s'annoncer ne comptent pas comme sautés.
	_last = boss.beats_now() + min_announce - 0.25
	# Le premier coup de la boucle (le drop) part tout de suite, sans s'annoncer.
	_done = boss.beats_now() - float(drum_lead.get("onde", 2.0)) - 0.01


## Ce qu'une source de la batterie déclenche dans cette phase ("" : rien).
static func kind_of(src: String, wave_bar: bool, flood: bool, pw: Dictionary) -> String:
	match src:
		"kick":
			return "onde" if (flood or wave_bar) else "pouls"
		"kick_doux":
			return "pouls"
		"caisse":
			return "roulement" if int(pw["roll"]) > 0 or flood else ""
		"charleston":
			return "aiguille" if int(pw["spark"]) > 0 or flood else ""
		"caisse_douce":
			return "piqure" if int(pw["prick"]) > 0 or flood else ""
	return ""


## Grille des doubles croches gardées pour une source (1 : toutes).
static func grid_of(src: String, flood: bool, pw: Dictionary) -> int:
	if flood:
		return 1
	match src:
		"caisse":
			return int(pw["roll_grid"])
		"charleston":
			return int(pw["spark_grid"])
	return 1


## Charge de la partition de la phase, en projectiles et coups par temps : ce qui doit monter à
## chaque phase (tests). Une attaque compte quatre, une onde trois pouls.
func weight() -> float:
	var pw: Dictionary = power[phase]
	var w := 4.0 * hits.size()
	for d in drums:
		match d["kind"]:
			"onde":
				w += 3.0
			"pouls":
				w += 1.0
			"roulement":
				w += float(maxi(int(pw["roll"]), 4 if d["deluge"] else 0))
			"aiguille":
				w += float(int(pw["spark"]) + (1 if d["deluge"] else 0))
			"piqure":
				w += float(maxi(int(pw["prick"]), 1))
	return w / maxf(1.0, length)


## Temps absolu (depuis le début du morceau) du prochain coup de la partition après « after ».
func next_hit(after: float) -> Dictionary:
	var loop_i := floorf((after - origin) / length)
	for k in 2:
		var o := origin + (loop_i + k) * length
		for h in hits:
			var at: float = o + float(h["beat"])
			if at > after + 0.001:
				return {"at": at, "kind": h["kind"], "phrase": h["phrase"]}
	return {}


## Entre deux attaques : {} tant que l'annonce du prochain coup ne doit pas partir (« wait » : secondes
## d'attente), sinon {"kind", "at"} à lancer pour qu'il frappe juste sur son temps. « swap » remplace
## une attaque impossible (ex. invocation quand tout est éclos). Un coup que l'attaque d'avant a trop
## serré est sauté ; enraciné (cadence < 1), le boss saute un coup sur deux sans quitter la grille.
func step(swap := Callable()) -> Dictionary:
	var now: float = boss.beats_now()
	var after := maxf(_last, now + min_announce - 0.25)
	var nxt := next_hit(after)
	if nxt.is_empty():
		return {}
	var kind: String = nxt["kind"]
	if swap.is_valid():
		kind = swap.call(kind)
	var lead: float = announce.get(kind, 3)
	var left: float = nxt["at"] - now
	if left > lead:
		return {"wait": (left - lead) * boss.beat_len()}
	var planned := next_hit(_last)
	if not planned.is_empty() and planned["at"] < nxt["at"] - 0.001:
		skipped += 1
	_last = nxt["at"]
	if boss.cadence() < 0.999:
		_skip_toggle = not _skip_toggle
		if _skip_toggle:
			return {}
	played += 1
	return {"kind": kind, "at": nxt["at"]}


## La batterie : chaque coup dont l'annonce (drum_lead) part maintenant appelle fire(sorte, s avant le
## coup, déluge).
func drums_step(fire: Callable) -> void:
	var now: float = boss.beats_now()
	var loop_i := floorf((_done - origin) / length)
	for k in 2:
		var o := origin + (loop_i + k) * length
		for d in drums:
			var at: float = o + float(d["beat"])
			var start: float = at - float(drum_lead.get(d["kind"], 0.0))
			if start <= _done or start > now:
				continue
			drums_played[d["kind"]] = int(drums_played.get(d["kind"], 0)) + 1
			fire.call(d["kind"], (at - now) * boss.beat_len(), bool(d.get("deluge", false)))
	_done = now
