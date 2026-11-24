## Briques de synthèse partagées par les bruitages (synth.gd) et la musique (music_synth.gd) :
## oscillateurs sans repliement, filtre d'état variable, réverbération, saturation douce.
## Tout est déterministe (graines fixes) : deux générations donnent les mêmes octets.
extends RefCounted

const RATE := 22050

const SINE := 0
const SQUARE := 1
const SAW := 2
const NOISE := 3
const TRI := 4
## Partiels inharmoniques (cloche, métal) : 1, 2,76, 5,40, 8,93 fois la fondamentale.
const METAL := 5
const METAL_RATIOS := [1.0, 2.756, 5.404, 8.933]
const METAL_GAINS := [1.0, 0.6, 0.4, 0.25]


## Correction PolyBLEP : arrondit le saut d'une dent de scie ou d'un carré (pas de sifflement de repliement).
static func polyblep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


## Un échantillon d'oscillateur. phase : en tours (non bornée) ; dt : fréquence / RATE.
static func osc(kind: int, phase: float, dt: float, duty: float, rng: RandomNumberGenerator) -> float:
	var ph := fposmod(phase, 1.0)
	dt = clampf(dt, 0.00001, 0.45)
	match kind:
		SINE:
			return sin(TAU * phase)
		SQUARE:
			var v := 1.0 if ph < duty else -1.0
			v += polyblep(ph, dt)
			v -= polyblep(fposmod(ph - duty + 1.0, 1.0), dt)
			return v
		SAW:
			return ph * 2.0 - 1.0 - polyblep(ph, dt)
		TRI:
			return absf(ph * 4.0 - 2.0) - 1.0
		METAL:
			var s := 0.0
			for i in METAL_RATIOS.size():
				s += sin(TAU * phase * METAL_RATIOS[i]) * METAL_GAINS[i]
			return s * 0.45
		_:
			return rng.randf_range(-1.0, 1.0)


## Saturation douce (0 : aucune) : épaissit un coup sourd sans écrêter.
static func drive(s: float, amount: float) -> float:
	if amount <= 0.0:
		return s
	var k := 1.0 + amount * 6.0
	return tanh(s * k) / tanh(k)


## Filtre d'état variable (forme « TPT », stable jusqu'au haut du spectre).
## mode : 0 passe-bas, 1 passe-haut, 2 passe-bande. res : 0 (doux) à 0,95 (résonant).
class Svf:
	var mode := 0
	var g := 0.0
	var k := 1.4
	var a1 := 0.0
	var a2 := 0.0
	var a3 := 0.0
	var ic1 := 0.0
	var ic2 := 0.0

	func _init(m := 0, fc := 1000.0, res := 0.0) -> void:
		mode = m
		set_params(fc, res)

	func set_params(fc: float, res: float) -> void:
		g = tan(PI * clampf(fc, 20.0, RATE * 0.45) / RATE)
		k = 2.0 - 2.0 * clampf(res, 0.0, 0.97)
		a1 = 1.0 / (1.0 + g * (g + k))
		a2 = g * a1
		a3 = g * a2

	func process(x: float) -> float:
		var v3 := x - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		if mode == 0:
			return v2
		if mode == 1:
			return x - k * v1 - v2
		return v1 * k


## Réverbération (quatre peignes amortis puis deux passe-tout, façon Schroeder), mélangée à « mix ».
## size : 0,3 (petite pièce) à 1 (grande salle). circular : la queue de la fin revient au début
## (boucles de musique et d'ambiance, qui raccordent alors sans coupure).
static func reverb(a: PackedFloat32Array, mix: float, size := 0.7, damp := 0.35, circular := false) -> void:
	if mix <= 0.0 or a.is_empty():
		return
	var n := a.size()
	var fb := 0.70 + 0.27 * clampf(size, 0.0, 1.0)
	# Tous les tampons dans un seul tableau (un tableau par filtre serait recopié à chaque écriture).
	var c_len := PackedInt32Array()
	var c_off := PackedInt32Array()
	var c_pos := PackedInt32Array()
	var c_f := PackedFloat32Array()
	var total := 0
	for L in [557, 617, 683, 743, 811, 877]:
		var l := int(L * (0.6 + 0.6 * size))
		c_len.append(l)
		c_off.append(total)
		c_pos.append(0)
		c_f.append(0.0)
		total += l
	var a_len := PackedInt32Array()
	var a_off := PackedInt32Array()
	var a_pos := PackedInt32Array()
	for L in [225, 341, 441]:
		a_len.append(L)
		a_off.append(total)
		a_pos.append(0)
		total += L
	var buf := PackedFloat32Array()
	buf.resize(total)
	var wet := PackedFloat32Array()
	wet.resize(n)
	var nc := c_len.size()
	var na := a_len.size()
	var passes := 2 if circular else 1
	for pas in passes:
		var record := pas == passes - 1
		for i in n:
			var x: float = a[i] * 0.2
			var s := 0.0
			for c in nc:
				var j: int = c_off[c] + c_pos[c]
				var y: float = buf[j]
				var f: float = y * (1.0 - damp) + c_f[c] * damp
				c_f[c] = f
				buf[j] = x + f * fb
				c_pos[c] = (c_pos[c] + 1) % c_len[c]
				s += y
			for c in na:
				var j: int = a_off[c] + a_pos[c]
				var bo: float = buf[j]
				buf[j] = s + bo * 0.5
				a_pos[c] = (a_pos[c] + 1) % a_len[c]
				s = bo - s
			if record:
				wet[i] = s
	for i in n:
		a[i] = a[i] * (1.0 - mix * 0.5) + wet[i] * mix


## Ramène la crête à « peak » (gain identique sur tout le son).
static func normalize(a: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in a:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in a.size():
		a[i] *= g
	return a


## Fréquence en Hz d'une note : demi-tons depuis le ré grave (73,4 Hz) et octaves en plus.
static func hz(semis: float, octave := 0) -> float:
	return 73.416 * pow(2.0, semis / 12.0 + octave)
