## Synthèse sonore par le code (façon sfxr) : bruitages et couches de musique.
## Utilisé par tools/gen_sounds.gd, qui enregistre le résultat en .wav dans res://assets/.
## Tout est calculé à partir de formules : aucun échantillon externe, donc aucune licence.
extends RefCounted

const RATE := 22050
const SINE := 0
const SQUARE := 1
const SAW := 2
const NOISE := 3
const TRI := 4

## Bruitages : forme d'onde, fréquence de départ et d'arrivée (Hz), durée (s), attaque (s),
## filtre passe-bas (0 = aucun, sinon fréquence de coupure), vibrato (profondeur relative, vitesse Hz),
## volume, rapport cyclique du carré, deuxième voix (écart en demi-tons, 0 = aucune).
const SOUNDS := {
	"tir": {"wave": SQUARE, "f0": 760.0, "f1": 380.0, "dur": 0.09, "att": 0.004, "lp": 5000.0, "vol": 0.22, "duty": 0.3},
	"impact": {"wave": NOISE, "f0": 900.0, "f1": 300.0, "dur": 0.07, "att": 0.001, "lp": 2600.0, "vol": 0.3, "body": 160.0},
	"critique": {"wave": SAW, "f0": 520.0, "f1": 1500.0, "dur": 0.16, "att": 0.002, "lp": 6000.0, "vol": 0.3, "voice2": 7.0, "click": true},
	"mort": {"wave": NOISE, "f0": 700.0, "f1": 120.0, "dur": 0.32, "att": 0.004, "lp": 1800.0, "vol": 0.34, "body": 90.0},
	"chute": {"wave": SINE, "f0": 330.0, "f1": 98.0, "dur": 1.3, "att": 0.02, "lp": 1600.0, "vol": 0.4, "body": 55.0, "voice2": -5.0, "vib": [0.02, 5.0]},
	"noeud": {"wave": TRI, "f0": 440.0, "f1": 880.0, "dur": 0.34, "att": 0.006, "lp": 0.0, "vol": 0.32, "voice2": 12.0, "vib": [0.01, 7.0]},
	"niveau": {"wave": SQUARE, "f0": 392.0, "f1": 392.0, "dur": 0.7, "att": 0.005, "lp": 4500.0, "vol": 0.24, "duty": 0.5, "arp": [0, 4, 7, 12]},
	"esquive": {"wave": NOISE, "f0": 1800.0, "f1": 4200.0, "dur": 0.16, "att": 0.03, "lp": 5200.0, "vol": 0.22},
	"degats": {"wave": SAW, "f0": 190.0, "f1": 70.0, "dur": 0.22, "att": 0.002, "lp": 1500.0, "vol": 0.36},
	"nova": {"wave": SINE, "f0": 140.0, "f1": 55.0, "dur": 0.5, "att": 0.004, "lp": 1200.0, "vol": 0.5, "body": 70.0, "voice2": 7.0},
	"nuage": {"wave": NOISE, "f0": 1200.0, "f1": 500.0, "dur": 0.55, "att": 0.12, "lp": 1500.0, "vol": 0.24, "vib": [0.15, 9.0]},
	"floraison": {"wave": SINE, "f0": 330.0, "f1": 330.0, "dur": 0.9, "att": 0.05, "lp": 0.0, "vol": 0.28, "arp": [0, 4, 7, 11, 16], "voice2": 12.0},
	"fouet": {"wave": NOISE, "f0": 3400.0, "f1": 900.0, "dur": 0.2, "att": 0.002, "lp": 4800.0, "vol": 0.3, "click": true},
	"racines": {"wave": SAW, "f0": 90.0, "f1": 150.0, "dur": 0.45, "att": 0.08, "lp": 700.0, "vol": 0.34, "vib": [0.06, 14.0]},
	"volee": {"wave": NOISE, "f0": 2600.0, "f1": 1400.0, "dur": 0.14, "att": 0.002, "lp": 5200.0, "vol": 0.24, "click": true, "vib": [0.08, 30.0]},
	"saignee": {"wave": SAW, "f0": 70.0, "f1": 220.0, "dur": 0.45, "att": 0.01, "lp": 1300.0, "vol": 0.36, "body": 55.0, "voice2": -5.0},
	"annonce": {"wave": SAW, "f0": 150.0, "f1": 460.0, "dur": 0.7, "att": 0.3, "lp": 2400.0, "vol": 0.34, "voice2": 6.0, "vib": [0.03, 11.0]},
	"coeur": {"wave": SINE, "f0": 261.6, "f1": 261.6, "dur": 1.8, "att": 0.02, "lp": 0.0, "vol": 0.4, "arp": [0, 4, 7, 12, 16, 19], "voice2": 12.0},
	"ramasse": {"wave": SINE, "f0": 880.0, "f1": 1320.0, "dur": 0.09, "att": 0.002, "lp": 0.0, "vol": 0.14, "voice2": 12.0},
	"greffe": {"wave": TRI, "f0": 523.0, "f1": 523.0, "dur": 0.55, "att": 0.004, "lp": 0.0, "vol": 0.3, "arp": [0, 7, 12, 16], "voice2": 12.0},
	"seve": {"wave": SINE, "f0": 392.0, "f1": 392.0, "dur": 0.7, "att": 0.01, "lp": 0.0, "vol": 0.3, "arp": [0, 5, 9, 12], "vib": [0.01, 6.0]},
	"clic": {"wave": SQUARE, "f0": 900.0, "f1": 700.0, "dur": 0.04, "att": 0.001, "lp": 4000.0, "vol": 0.16, "duty": 0.5},
	"survol": {"wave": SINE, "f0": 1200.0, "f1": 1400.0, "dur": 0.03, "att": 0.002, "lp": 0.0, "vol": 0.08},
}


## Rend un bruitage décrit dans SOUNDS (échantillons entre -1 et 1).
static func render(name: String) -> PackedFloat32Array:
	var p: Dictionary = SOUNDS[name]
	var n := int(p["dur"] * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var phase := 0.0
	var phase2 := 0.0
	var phase_body := 0.0
	var lp_state := 0.0
	var noise_hold := 0.0
	var arp: Array = p.get("arp", [])
	var vib: Array = p.get("vib", [0.0, 0.0])
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var f: float = lerpf(p["f0"], p["f1"], k)
		if arp.size() > 0:
			# Arpège : la hauteur monte par marches égales sur la durée du son.
			var step := mini(arp.size() - 1, int(k * arp.size()))
			f = p["f0"] * pow(2.0, arp[step] / 12.0)
		f *= 1.0 + vib[0] * sin(TAU * vib[1] * t)
		phase += f / RATE
		var s := _wave(p["wave"], phase, p.get("duty", 0.5), rng, f, noise_hold)
		if p["wave"] == NOISE:
			noise_hold = s
		if p.has("voice2"):
			phase2 += f * pow(2.0, p["voice2"] / 12.0) / RATE
			s = s * 0.65 + _wave(p["wave"], phase2, p.get("duty", 0.5), rng, f, noise_hold) * 0.35
		if p.has("body"):
			# Coup sourd sous le bruit : sinusoïde qui descend.
			phase_body += lerpf(p["body"] * 1.8, p["body"] * 0.6, k) / RATE
			s = s * 0.6 + sin(TAU * phase_body) * 0.9
		if p.get("click", false) and t < 0.004:
			s += rng.randf_range(-1.0, 1.0)
		if p["lp"] > 0.0:
			var a: float = clampf(TAU * p["lp"] / RATE, 0.0, 1.0)
			lp_state += a * (s - lp_state)
			s = lp_state
		# Enveloppe : attaque courte puis décroissance douce jusqu'à zéro (pas de clic final).
		var env := minf(1.0, t / maxf(p["att"], 0.0005)) * pow(1.0 - k, 1.6)
		out[i] = clampf(s * env * p["vol"], -1.0, 1.0)
	return out


static func _wave(kind: int, phase: float, duty: float, rng: RandomNumberGenerator, f: float, held: float) -> float:
	var ph := fposmod(phase, 1.0)
	match kind:
		SINE:
			return sin(TAU * phase)
		SQUARE:
			return 1.0 if ph < duty else -1.0
		SAW:
			return ph * 2.0 - 1.0
		TRI:
			return absf(ph * 4.0 - 2.0) - 1.0
		_:
			# Bruit « tenu » : se renouvelle à la fréquence demandée, donc plus grave quand f baisse.
			if rng.randf() < clampf(f / RATE * 2.0, 0.02, 1.0):
				return rng.randf_range(-1.0, 1.0)
			return held
	return 0.0


# --- Musique -----------------------------------------------------------------------------

## Durée d'un accord et nombre d'accords d'une boucle : 4 × 3 s = 12 s, qui boucle sans coupure
## parce que chaque note naît et s'éteint à l'intérieur de son accord.
const CHORD_TIME := 3.0
## Fondamentales en demi-tons depuis Ré (Ré, Si bémol, Sol, La).
const ROOTS := [0, -4, -9, -5]
const D2 := 73.416


static func _hz(root: int, semis: float, octave := 0) -> float:
	return D2 * pow(2.0, (root + semis) / 12.0 + octave)


## Couche sombre (terre morte) : accords mineurs tenus, vent grave, rien de brillant.
static func music_dark() -> PackedFloat32Array:
	var out := _blank(CHORD_TIME * ROOTS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var minor := [0, 7, 12, 15]
	for c in ROOTS.size():
		for s in minor:
			var f := _hz(ROOTS[c], s)
			_swell(out, c * CHORD_TIME, CHORD_TIME, f, 0.09, 0.35)
			_swell(out, c * CHORD_TIME, CHORD_TIME, f * 1.004, 0.05, 0.35)
	# Vent : bruit filtré en continu, modulé lentement (période 6 s, donc 2 cycles par boucle).
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp += 0.03 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] += lp * (0.7 + 0.5 * sin(TAU * t / 6.0)) * 0.9
	# Cloche sourde au début de chaque accord.
	for c in ROOTS.size():
		_pluck(out, c * CHORD_TIME, _hz(ROOTS[c], 0, 1), 0.10, 2.4)
	return _limit(out, 0.8)


## Couche lumineuse (terre vivante) : mêmes fondamentales, accords majeurs et arpèges.
static func music_bright() -> PackedFloat32Array:
	var out := _blank(CHORD_TIME * ROOTS.size())
	var major := [0, 4, 7, 12]
	for c in ROOTS.size():
		for s in major:
			_swell(out, c * CHORD_TIME, CHORD_TIME, _hz(ROOTS[c], s, 1), 0.07, 0.3)
		# Arpège en croches : 3 s ÷ 0,375 s = 8 notes par accord.
		var pattern := [0, 4, 7, 12, 16, 12, 7, 4]
		for j in pattern.size():
			var start: float = c * CHORD_TIME + j * 0.375
			_pluck(out, start, _hz(ROOTS[c], pattern[j], 2), 0.12, 0.9)
	# Scintillement aigu, léger.
	for c in ROOTS.size():
		_pluck(out, c * CHORD_TIME + 1.5, _hz(ROOTS[c], 19, 2), 0.05, 1.4)
	return _limit(out, 0.8)


static func _blank(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


## Note tenue qui gonfle puis s'éteint : nulle aux deux bouts, donc sans clic à la boucle.
static func _swell(out: PackedFloat32Array, start: float, dur: float, f: float, vol: float, rise: float) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		if i0 + i >= out.size():
			break
		var k := float(i) / n
		var env := sin(PI * pow(k, rise * 2.0 + 0.5))
		env = maxf(env, 0.0)
		out[i0 + i] += sin(TAU * f * i / RATE) * env * vol


## Note pincée : attaque immédiate, décroissance exponentielle, extinction forcée en fin de durée.
static func _pluck(out: PackedFloat32Array, start: float, f: float, vol: float, dur: float) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		if i0 + i >= out.size():
			break
		var t := float(i) / RATE
		var fade := minf(1.0, float(n - i) / (0.05 * RATE))
		var env := exp(-t * 4.0 / dur * 1.6) * minf(1.0, t / 0.004) * fade
		var s := sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0)
		out[i0 + i] += s * env * vol


static func _limit(a: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in a:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in a.size():
		a[i] *= g
	return a


## Octets d'un fichier WAV (mono, 16 bits).
static func to_wav(samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)   # "RIFF"
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)   # "WAVE"
	h.encode_u32(12, 0x20746d66)  # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)           # PCM
	h.encode_u16(22, 1)           # mono
	h.encode_u32(24, RATE)
	h.encode_u32(28, RATE * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)  # "data"
	h.encode_u32(40, data.size())
	h.append_array(data)
	return h
