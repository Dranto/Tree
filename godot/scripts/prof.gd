## Profil du banc de performance (« -- --benchmark --profile ») : temps passé dans chaque partie
## du dessin et de l'animation, cumulé sur le banc puis affiché par image.
## Usage : « var p0 := Prof.t0() » au début d'une fonction, « Prof.add("clé", p0) » à la fin.
## Hors profil, t0() renvoie 0 et add() ne fait rien (coût négligeable).
class_name Prof
extends RefCounted

static var on := false
static var usec: Dictionary = {}
static var calls: Dictionary = {}
## Temps de chaque clé dans l'image en cours (pour dire ce qui coûte dans un à-coup du banc).
static var frame: Dictionary = {}


static func t0() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(key: String, start: int) -> void:
	if not on:
		return
	var d := Time.get_ticks_usec() - start
	usec[key] = usec.get(key, 0) + d
	frame[key] = frame.get(key, 0) + d
	calls[key] = calls.get(key, 0) + 1


static func reset() -> void:
	spikes.clear()
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


## Pics par clé : [nombre d'images où la clé a pris plus de SPIKE_USEC, pire temps en µs].
const SPIKE_USEC := 6000
static var spikes: Dictionary = {}


static func frame_reset() -> void:
	for k in frame:
		var s: Array = spikes.get(k, [0, 0])
		if frame[k] > SPIKE_USEC:
			s[0] += 1
		s[1] = maxi(s[1], frame[k])
		spikes[k] = s
	frame.clear()


## Lignes des pics : les clés qui ont pris plus de SPIKE_USEC dans une image, de la pire à la moins pire.
static func spike_report() -> PackedStringArray:
	var keys := spikes.keys().filter(func(k): return spikes[k][0] > 0)
	keys.sort_custom(func(a, b): return spikes[a][1] > spikes[b][1])
	var out := PackedStringArray()
	for k in keys:
		out.append("PIC %-34s pire %6.1f ms, %4d images de plus de %d ms" % [k, spikes[k][1] / 1000.0, spikes[k][0], SPIKE_USEC / 1000])
	return out


## Les n clés les plus chères de l'image en cours, « clé ms ».
static func frame_top(n: int) -> String:
	var keys := frame.keys()
	keys.sort_custom(func(a, b): return frame[a] > frame[b])
	var out := PackedStringArray()
	for k in keys.slice(0, n):
		out.append("%s %.1f" % [k, frame[k] / 1000.0])
	return ", ".join(out)
