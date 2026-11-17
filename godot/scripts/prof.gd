## Profil du banc de performance (« -- --benchmark --profile ») : temps passé dans chaque partie
## du dessin et de l'animation, cumulé sur le banc puis affiché par image.
## Usage : « var p0 := Prof.t0() » au début d'une fonction, « Prof.add("clé", p0) » à la fin.
## Hors profil, t0() renvoie 0 et add() ne fait rien (coût négligeable).
class_name Prof
extends RefCounted

static var on := false
static var usec: Dictionary = {}
static var calls: Dictionary = {}


static func t0() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(key: String, start: int) -> void:
	if not on:
		return
	usec[key] = usec.get(key, 0) + Time.get_ticks_usec() - start
	calls[key] = calls.get(key, 0) + 1


static func reset() -> void:
	usec.clear()
	calls.clear()


## Lignes du rapport, de la plus chère à la moins chère, en ms par image.
static func report(frames: int) -> PackedStringArray:
	var keys := usec.keys()
	keys.sort_custom(func(a, b): return usec[a] > usec[b])
	var out := PackedStringArray()
	for k in keys:
		out.append("PROFIL %-28s %7.2f ms/image  %7.1f appels/image" % [k, usec[k] / 1000.0 / maxf(1.0, frames), calls[k] / maxf(1.0, frames)])
	return out
