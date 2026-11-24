## Musique et ambiances synthétisées par le code (appelées par synth.gd, enregistrées par gen_sounds.gd).
##
## Chaque région a cinq couches de 12 s (4 accords de 3 s), qui tournent ensemble en boucle et toujours en
## phase ; music.gd ne fait que régler leurs volumes, donc on passe de l'une à l'autre sans coupure :
##   sombre (exploration, terre morte), lumineux (exploration, terre vivante), combat (percussions et basse,
##   par-dessus l'exploration), coeur (chœur et battement, pendant le siège d'un Cœur), boss (thème du boss,
##   seul).
## Tout s'écrit « en anneau » : une note ou une réverbération qui dépasse la fin de la boucle revient au
## début, donc la boucle raccorde sans clic.
##
## Les réglages d'une région (data/audio.json › regions › <id> › music) complètent DEFAULTS (Ronce) :
## {"seed", "roots" (4 fondamentales, demi-tons depuis le ré), "dark", "bright", "combat", "heart", "boss"}.
## Voir data/README.md, « Son et ambiance ».
extends RefCounted

const Dsp = preload("res://scripts/synth_dsp.gd")

const RATE := Dsp.RATE
const CHORD_TIME := 3.0
const ROOTS := [0, -4, -9, -5]
const LOOP := 12.0
## Croche : 8 par accord.
const EIGHTH := CHORD_TIME / 8.0
const SIXTEENTH := CHORD_TIME / 16.0
## Version des formules (empreinte des pistes) : à changer quand le rendu change.
const VERSION := 2

## Fichier (couche) → section de réglages.
const LAYERS := {"sombre": "dark", "lumineux": "bright", "combat": "combat", "coeur": "heart", "boss": "boss"}
## Crête de chaque couche : l'exploration et le combat s'additionnent, le boss joue seul.
const PEAKS := {"sombre": 0.62, "lumineux": 0.62, "combat": 0.55, "coeur": 0.5, "boss": 0.78}
const KITS := ["frame", "taiko", "wood", "metal", "water"]
const VOWELS := {"a": [800.0, 1150.0, 2900.0], "o": [450.0, 800.0, 2830.0], "u": [325.0, 700.0, 2530.0], "e": [400.0, 1700.0, 2600.0]}

## Thème de Ronce (le monde) : ré mineur, accords de ré, si bémol, fa, la.
## motif : [croche de départ (0 à 31), note de l'accord (0 = fondamentale, 1, 2… puis l'octave), durée en
## croches, altération facultative en demi-tons].
const DEFAULTS := {
	"seed": 11,
	"roots": [0, -4, -9, -5],
	"dark": {"chord": [0, 7, 12, 15], "pad": 0.5, "pad_lp": 700.0, "drone": 0.28, "bell": 0.32, "bell_ratio": 3.5, "texture": 0.12, "verb": 0.45},
	"bright": {"chord": [0, 4, 7, 12], "octave": 1, "pattern": [0, 4, 7, 12, 16, 12, 7, 4], "pad": 0.35, "pad_lp": 1600.0,
		"pluck": 0.5, "pluck_tone": 0.5, "sparkle": 0.22, "sparkle_note": 19, "lead": 0.32, "lead_tone": "flute", "bass": 0.16, "verb": 0.35,
		"motif": [[0, 2, 2], [2, 1, 1], [3, 2, 1], [4, 3, 4], [8, 3, 2], [10, 2, 2], [12, 1, 4], [16, 2, 2], [18, 3, 1], [19, 2, 1], [20, 0, 4], [24, 1, 3], [27, 2, 1], [28, 3, 4]]},
	"combat": {"kit": "frame", "kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "..x...x...x...x.", "tom": "",
		"bass": [0, 0, 12, 0, 7, 0, 12, 3], "bass_vol": 0.4, "pulse": 0.3, "drums": 0.9, "verb": 0.15},
	"heart": {"vowel": "a", "choir": 0.6, "beat": 0.32, "shimmer": 0.2, "verb": 0.5},
	"boss": {"chord": [0, 7, 12, 15], "kit": "taiko", "kick": "x..x..x.x..x..x.", "snare": "....x.......x..x", "hat": "x.x.x.x.x.x.x.x.", "tom": "...........x.xx.",
		"bass": [0, 0, 12, 0, 0, 10, 12, 7], "bass_vol": 0.6, "brass": 0.42, "lead": 0.45, "lead_tone": "brass", "choir": 0.28, "pulse": 0.32, "pad": 0.32, "drums": 1.0, "verb": 0.25,
		"motif": [[0, 0, 1], [1, 0, 1], [2, 3, 2], [4, 2, 2], [6, 1, 2], [8, 0, 1], [9, 0, 1], [10, 3, 2], [12, 4, 4], [16, 0, 1], [17, 0, 1], [18, 3, 2], [20, 2, 2], [22, 1, 2], [24, 2, 3], [27, 3, 1], [28, 1, 4]]},
}

## Ambiance de Ronce (le monde) : vent dans les ronces mortes ; oiseaux, grillons et feuillage quand la terre vit.
const BED_DEFAULTS := {
	"seed": 3,
	"dead": {"wind": 0.6, "wind_lp": 480.0, "gust": 0.6, "rumble": 0.0, "stream": 0.0, "waves": 0.0, "events": [{"kind": "creak", "rate": 0.15, "vol": 0.35}]},
	"alive": {"wind": 0.25, "wind_lp": 900.0, "gust": 0.4, "rumble": 0.0, "stream": 0.0, "waves": 0.0,
		"events": [{"kind": "bird", "rate": 0.45, "vol": 0.4}, {"kind": "cricket", "rate": 0.15, "vol": 0.2}, {"kind": "rustle", "rate": 0.25, "vol": 0.25}]},
}
const BED_EVENTS := ["bird", "cricket", "drip", "bubble", "creak", "chime", "rustle", "knock", "frog"]


## Réglages complets d'une section (« dark », « bright »…) : ceux de la région par-dessus ceux de Ronce.
static func section(style: Dictionary, sec: String) -> Dictionary:
	var out: Dictionary = DEFAULTS[sec].duplicate(true)
	var own = style.get(sec, {})
	if own is Dictionary:
		out.merge(own, true)
	return out


## Empreinte d'une couche (formules + réglages) : gen_sounds l'écrit à côté des pistes, sound_test la compare.
static func fingerprint(layer: String, style: Dictionary) -> int:
	return hash([VERSION, layer, style.get("seed", DEFAULTS["seed"]), style.get("roots", DEFAULTS["roots"]), section(style, LAYERS[layer]),
		section(style, "dark")["chord"] if layer in ["combat", "boss"] else 0, section(style, "bright")["chord"] if layer == "coeur" else 0])


static func bed_fingerprint(state: String, bed: Dictionary) -> int:
	return hash([VERSION, state, bed.get("seed", BED_DEFAULTS["seed"]), bed_section(bed, state)])


static func bed_section(bed: Dictionary, state: String) -> Dictionary:
	var out: Dictionary = BED_DEFAULTS[state].duplicate(true)
	var own = bed.get(state, {})
	if own is Dictionary:
		out.merge(own, true)
	return out


static func _blank() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(LOOP * RATE))
	return a


## Une couche de musique (sombre, lumineux, combat, coeur, boss).
static func render(layer: String, style := {}) -> PackedFloat32Array:
	var out := _blank()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(style.get("seed", DEFAULTS["seed"])) * 31 + hash(layer)
	var roots: Array = style.get("roots", DEFAULTS["roots"])
	var verb := 0.3
	match layer:
		"sombre":
			var st := section(style, "dark")
			_dark(out, st, roots, rng)
			verb = st["verb"]
		"lumineux":
			var st := section(style, "bright")
			_bright(out, st, roots, rng)
			verb = st["verb"]
		"combat":
			var st := section(style, "combat")
			_combat(out, st, section(style, "dark")["chord"], roots, rng)
			verb = st["verb"]
		"coeur":
			var st := section(style, "heart")
			_heart(out, st, section(style, "bright")["chord"], roots, rng)
			verb = st["verb"]
		"boss":
			var st := section(style, "boss")
			_boss(out, st, roots, rng)
			verb = st["verb"]
	Dsp.reverb(out, verb, 0.85, 0.45, true)
	_highpass(out, 38.0)
	return Dsp.normalize(out, PEAKS.get(layer, 0.6))


## Coupe l'infra-grave (inaudible, mais qui mange la marge), en anneau.
static func _highpass(out: PackedFloat32Array, fc: float) -> void:
	var svf := Dsp.Svf.new(1, fc, 0.0)
	var n := out.size()
	for i in n:
		svf.process(out[i])
	for i in n:
		out[i] = svf.process(out[i])


# --- Couches ---------------------------------------------------------------------------------------------

static func _dark(out: PackedFloat32Array, st: Dictionary, roots: Array, rng: RandomNumberGenerator) -> void:
	var chord: Array = st["chord"]
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var freqs: Array = []
		for s in chord:
			freqs.append(Dsp.hz(roots[c] + s, 1))
		_pad(out, t0, CHORD_TIME, freqs, st["pad"], st["pad_lp"], rng)
		# Bourdon : fondamentale et quinte graves, qui se relaient d'un accord à l'autre.
		_pad(out, t0, CHORD_TIME, [Dsp.hz(roots[c], 0), Dsp.hz(roots[c] + 7, 0)], st["drone"], 260.0, rng, 0.002, true)
		if st["bell"] > 0.0:
			_bell(out, t0 + 0.02, Dsp.hz(roots[c] + chord[(c * 3 + 1) % chord.size()], 3), st["bell"], 3.4, st["bell_ratio"], 1.6)
			if c % 2 == 1:
				_bell(out, t0 + 1.875, Dsp.hz(roots[c] + chord[chord.size() - 1], 2), st["bell"] * 0.6, 2.6, st["bell_ratio"], 1.2)
	if st["texture"] > 0.0:
		_breath(out, st["texture"], 500.0, rng)


static func _bright(out: PackedFloat32Array, st: Dictionary, roots: Array, rng: RandomNumberGenerator) -> void:
	var chord: Array = st["chord"]
	var oct := int(st["octave"])
	var pattern: Array = st["pattern"]
	var step := CHORD_TIME / pattern.size()
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var freqs: Array = []
		for s in chord:
			freqs.append(Dsp.hz(roots[c] + s, oct))
		_pad(out, t0, CHORD_TIME, freqs, st["pad"], st["pad_lp"], rng)
		if st["bass"] > 0.0:
			_bass(out, t0, CHORD_TIME * 0.9, Dsp.hz(roots[c], 0), st["bass"], 0.0)
		for j in pattern.size():
			var acc := 1.0 if j % 4 == 0 else 0.75
			_pluck(out, t0 + j * step + rng.randf_range(0.0, 0.008), Dsp.hz(roots[c] + pattern[j], oct + 2), st["pluck"] * acc, 1.4, st["pluck_tone"], rng)
		if st["sparkle"] > 0.0:
			_bell(out, t0 + CHORD_TIME * 0.5, Dsp.hz(roots[c] + st["sparkle_note"], 2), st["sparkle"], 2.2, 3.0, 1.0)
	_melody(out, st["motif"], chord, roots, 3, st["lead"], str(st["lead_tone"]), rng)


static func _combat(out: PackedFloat32Array, st: Dictionary, chord: Array, roots: Array, rng: RandomNumberGenerator) -> void:
	_drums(out, st, rng)
	var bass: Array = st["bass"]
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		for j in bass.size():
			if bass[j] == null:
				continue
			_bass(out, t0 + j * (CHORD_TIME / bass.size()), CHORD_TIME / bass.size() * 0.9, Dsp.hz(roots[c] + float(bass[j]), 0), st["bass_vol"], 0.5)
		if st["pulse"] > 0.0:
			for j in 16:
				var note: float = roots[c] + (chord[1] if j % 4 == 2 else 0.0)
				_stab(out, t0 + j * SIXTEENTH, SIXTEENTH * 0.8, Dsp.hz(note, 2), st["pulse"] * (1.0 if j % 4 == 0 else 0.6), 1500.0)


static func _heart(out: PackedFloat32Array, st: Dictionary, chord: Array, roots: Array, rng: RandomNumberGenerator) -> void:
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		for s in chord.slice(0, 3):
			_choir(out, t0, CHORD_TIME, Dsp.hz(roots[c] + s, 2), st["choir"], str(st["vowel"]), rng)
		if st["shimmer"] > 0.0:
			_shimmer(out, t0, CHORD_TIME, Dsp.hz(roots[c] + chord[chord.size() - 1], 3), st["shimmer"])
	# Battement de cœur : « poum-poum » à chaque noire (0,75 s).
	if st["beat"] > 0.0:
		for b in int(LOOP / (EIGHTH * 2.0)):
			var t := b * EIGHTH * 2.0
			_kick(out, t, st["beat"], "heart")
			_kick(out, t + 0.16, st["beat"] * 0.6, "heart")


static func _boss(out: PackedFloat32Array, st: Dictionary, roots: Array, rng: RandomNumberGenerator) -> void:
	var chord: Array = st["chord"]
	_drums(out, st, rng)
	var bass: Array = st["bass"]
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var freqs: Array = []
		for s in chord:
			freqs.append(Dsp.hz(roots[c] + s, 1))
		if st["pad"] > 0.0:
			_pad(out, t0, CHORD_TIME, freqs, st["pad"], 1100.0, rng)
		for j in bass.size():
			if bass[j] == null:
				continue
			_bass(out, t0 + j * (CHORD_TIME / bass.size()), CHORD_TIME / bass.size() * 0.85, Dsp.hz(roots[c] + float(bass[j]), 0), st["bass_vol"], 0.7)
		if st["brass"] > 0.0:
			# Accords cuivrés sur les temps forts (1 et le « et » du 3).
			for at in [0.0, EIGHTH * 5.0]:
				for s in chord.slice(0, 3):
					_stab(out, t0 + at, EIGHTH * 1.6, Dsp.hz(roots[c] + s, 1), st["brass"] * 0.5, 2200.0)
		if st["pulse"] > 0.0:
			for j in 16:
				_stab(out, t0 + j * SIXTEENTH, SIXTEENTH * 0.7, Dsp.hz(roots[c] + (12.0 if j % 2 == 1 else 0.0), 2), st["pulse"] * (1.0 if j % 4 == 0 else 0.55), 1800.0)
		if st["choir"] > 0.0:
			_choir(out, t0, CHORD_TIME, Dsp.hz(roots[c] + chord[0], 1), st["choir"], "o", rng)
			_choir(out, t0, CHORD_TIME, Dsp.hz(roots[c] + chord[1], 1), st["choir"] * 0.8, "o", rng)
	_melody(out, st["motif"], chord, roots, 3, st["lead"], str(st["lead_tone"]), rng)


## Mélodie : chaque note est prise dans l'accord en cours (motif : [croche, note de l'accord, durée, altération]).
static func _melody(out: PackedFloat32Array, motif: Array, chord: Array, roots: Array, octave: int, vol: float, tone: String, rng: RandomNumberGenerator) -> void:
	if vol <= 0.0:
		return
	for m in motif:
		var stp := int(m[0])
		var c := (stp / 8) % roots.size()
		var idx := int(m[1])
		var semis: float = chord[posmod(idx, chord.size())] + 12.0 * floorf(float(idx) / chord.size()) + (float(m[3]) if m.size() > 3 else 0.0)
		var f := Dsp.hz(roots[c] + semis, octave)
		_lead(out, stp * EIGHTH, float(m[2]) * EIGHTH, f, vol, tone, rng)


## Percussions : motifs de 16 doubles croches par accord (« x » frappe, « o » frappe douce, « . » rien).
static func _drums(out: PackedFloat32Array, st: Dictionary, rng: RandomNumberGenerator) -> void:
	var kit := str(st["kit"])
	var vol: float = st["drums"]
	for c in int(LOOP / CHORD_TIME):
		for j in 16:
			var t: float = c * CHORD_TIME + j * SIXTEENTH
			var hum := rng.randf_range(-0.004, 0.004)
			for part in ["kick", "snare", "hat", "tom"]:
				var pat := str(st.get(part, ""))
				if pat.is_empty():
					continue
				var ch := pat[j % pat.length()]
				if ch == ".":
					continue
				var v := vol * (1.0 if ch == "x" else 0.5) * rng.randf_range(0.9, 1.0)
				match part:
					"kick":
						_kick(out, t + hum, v, kit)
					"snare":
						_snare(out, t + hum, v * 0.8, kit, rng)
					"hat":
						_hat(out, t + hum, v * 0.6, kit, rng)
					"tom":
						_tom(out, t + hum, v * 0.7, 110.0 if j % 2 == 0 else 82.0)


# --- Instruments (tous écrits en anneau) ------------------------------------------------------------------

## Nappe : trois dents de scie désaccordées par note, filtrées ; fondu d'entrée et de sortie qui chevauche
## l'accord suivant. soft : sinusoïdes (bourdon).
static func _pad(out: PackedFloat32Array, t0: float, dur: float, freqs: Array, vol: float, lp: float, rng: RandomNumberGenerator, detune := 0.006, soft := false) -> void:
	if vol <= 0.0:
		return
	var n := out.size()
	var over := 0.9
	var i0 := int((t0 - over * 0.5) * RATE)
	var cnt := int((dur + over) * RATE)
	var svf := Dsp.Svf.new(0, lp, 0.15)
	var svf2 := Dsp.Svf.new(0, lp, 0.0)
	var ph := PackedFloat32Array()
	for k in freqs.size() * 3:
		ph.append(rng.randf())
	var g := vol / sqrt(float(freqs.size())) * 0.35
	for i in cnt:
		var t := float(i) / RATE
		var k := float(i) / cnt
		var env := sin(PI * k)
		env = env * env * (3.0 - 2.0 * env) if env < 1.0 else 1.0
		var s := 0.0
		for fi in freqs.size():
			var f: float = freqs[fi]
			for d in 3:
				var fr := f * (1.0 + (d - 1) * detune)
				var idx := fi * 3 + d
				ph[idx] = ph[idx] + fr / RATE
				if soft:
					s += sin(TAU * ph[idx]) * 0.6
				else:
					s += Dsp.osc(Dsp.SAW, ph[idx], fr / RATE, 0.5, rng)
		if i % 64 == 0:
			svf.set_params(lp * (1.0 + 0.25 * sin(TAU * t / dur)), 0.15)
		s = svf2.process(svf.process(s))
		var j := (i0 + i) % n
		if j < 0:
			j += n
		out[j] += s * env * g


## Note pincée (corde de Karplus-Strong) : tone de 0 (sourde) à 1 (claire).
static func _pluck(out: PackedFloat32Array, t0: float, f: float, vol: float, dur: float, tone: float, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	var delay := RATE / f - 0.5
	var d0 := int(delay)
	var frac := delay - d0
	var size := d0 + 2
	var buf := PackedFloat32Array()
	buf.resize(size)
	var lp := 0.0
	for i in size:
		var x := rng.randf_range(-1.0, 1.0)
		lp += (0.2 + 0.8 * tone) * (x - lp)
		buf[i] = lp
	var damp := 0.4 + 0.1 * tone
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	var w := 0
	var prev := 0.0
	for i in cnt:
		var a := buf[(w - d0 + size * 4) % size]
		var b := buf[(w - d0 - 1 + size * 4) % size]
		var y := lerpf(a, b, frac)
		var nv := (y * damp + prev * (1.0 - damp)) * 0.996
		prev = y
		buf[w] = nv
		w = (w + 1) % size
		var env := minf(1.0, float(cnt - i) / (0.05 * RATE))
		out[(i0 + i) % n] += y * vol * 0.5 * env


## Cloche en synthèse FM (rapport inharmonique, indice qui décroît).
static func _bell(out: PackedFloat32Array, t0: float, f: float, vol: float, dur: float, ratio: float, index: float) -> void:
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	for i in cnt:
		var t := float(i) / RATE
		var e := exp(-t * 4.5 / dur)
		var s := sin(TAU * f * t + index * e * sin(TAU * f * ratio * t))
		var fade := minf(1.0, float(cnt - i) / (0.04 * RATE)) * minf(1.0, t / 0.002)
		out[(i0 + i) % n] += s * e * vol * 0.3 * fade


## Basse : sinus et triangle saturés ; punch : attaque plus marquée (0 à 1).
static func _bass(out: PackedFloat32Array, t0: float, dur: float, f: float, vol: float, punch: float) -> void:
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	var ph := 0.0
	for i in cnt:
		var t := float(i) / RATE
		ph += f / RATE
		var s := sin(TAU * ph) + 0.35 * (absf(fposmod(ph, 1.0) * 4.0 - 2.0) - 1.0)
		s = Dsp.drive(s * 0.7, 0.3 + punch * 0.4)
		var env := minf(1.0, t / 0.006) * (0.65 + 0.35 * exp(-t * (4.0 + 10.0 * punch))) * minf(1.0, float(cnt - i) / (0.03 * RATE))
		out[(i0 + i) % n] += s * env * vol * 0.45


## Note brève de cordes ou de cuivres : dent de scie filtrée, enveloppe courte.
static func _stab(out: PackedFloat32Array, t0: float, dur: float, f: float, vol: float, lp: float) -> void:
	var n := out.size()
	var cnt := int((dur + 0.06) * RATE)
	var i0 := int(t0 * RATE)
	var svf := Dsp.Svf.new(0, lp, 0.3)
	var ph := 0.0
	var ph2 := 0.37
	for i in cnt:
		var t := float(i) / RATE
		ph += f / RATE
		ph2 += f * 1.005 / RATE
		var s := (fposmod(ph, 1.0) * 2.0 - 1.0 - Dsp.polyblep(fposmod(ph, 1.0), f / RATE)) * 0.6
		s += (fposmod(ph2, 1.0) * 2.0 - 1.0 - Dsp.polyblep(fposmod(ph2, 1.0), f / RATE)) * 0.4
		if i % 32 == 0:
			svf.set_params(lp * (0.5 + 1.0 * exp(-t * 18.0)), 0.3)
		s = svf.process(s)
		var env := minf(1.0, t / 0.004) * exp(-t * 3.0 / maxf(dur, 0.05)) * minf(1.0, float(cnt - i) / (0.02 * RATE))
		out[(i0 + i) % n] += s * env * vol * 0.4


## Voix lead : « flute » (sinus soufflé) ou « brass » (dent de scie qui s'ouvre), vibrato retardé.
static func _lead(out: PackedFloat32Array, t0: float, dur: float, f: float, vol: float, tone: String, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	var rel := 0.12
	var cnt := int((dur + rel) * RATE)
	var i0 := int(t0 * RATE)
	var svf := Dsp.Svf.new(0, 900.0, 0.35)
	var breath := Dsp.Svf.new(2, f * 2.0, 0.5)
	var ph := 0.0
	var brass := tone == "brass"
	for i in cnt:
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * sin(TAU * 5.2 * t) * clampf((t - 0.18) * 4.0, 0.0, 1.0)
		ph += f * vib / RATE
		var s := 0.0
		if brass:
			s = fposmod(ph, 1.0) * 2.0 - 1.0 - Dsp.polyblep(fposmod(ph, 1.0), f / RATE)
			if i % 32 == 0:
				svf.set_params(f * (2.0 + 5.0 * minf(1.0, t / 0.08) * (0.6 + 0.4 * exp(-t * 3.0))), 0.35)
			s = svf.process(s) * 0.8
		else:
			s = sin(TAU * ph) + 0.18 * sin(TAU * ph * 2.0) + 0.06 * sin(TAU * ph * 3.0)
			s += breath.process(rng.randf_range(-1.0, 1.0)) * 0.12
		var env := minf(1.0, t / (0.05 if brass else 0.04))
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / rel)
		out[(i0 + i) % n] += s * env * vol * 0.3


## Chœur : deux dents de scie désaccordées dans les formants d'une voyelle, vibrato lent.
static func _choir(out: PackedFloat32Array, t0: float, dur: float, f: float, vol: float, vowel: String, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	var over := 0.8
	var i0 := int((t0 - over * 0.5) * RATE)
	var cnt := int((dur + over) * RATE)
	var fm: Array = VOWELS.get(vowel, VOWELS["a"])
	var f1 := Dsp.Svf.new(2, fm[0], 0.8)
	var f2 := Dsp.Svf.new(2, fm[1], 0.8)
	var f3 := Dsp.Svf.new(2, fm[2], 0.8)
	var ph := rng.randf()
	var ph2 := rng.randf()
	var vr := rng.randf_range(4.6, 5.4)
	for i in cnt:
		var t := float(i) / RATE
		var k := float(i) / cnt
		var v := 1.0 + 0.007 * sin(TAU * vr * t)
		ph += f * v / RATE
		ph2 += f * 1.007 * v / RATE
		var s := (fposmod(ph, 1.0) * 2.0 - 1.0) + (fposmod(ph2, 1.0) * 2.0 - 1.0)
		var y := f1.process(s) + f2.process(s) * 0.6 + f3.process(s) * 0.25
		var env := sin(PI * k)
		var j := (i0 + i) % n
		if j < 0:
			j += n
		out[j] += y * env * vol * 0.18


## Scintillement : sinus aigu en trémolo rapide.
static func _shimmer(out: PackedFloat32Array, t0: float, dur: float, f: float, vol: float) -> void:
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	for i in cnt:
		var t := float(i) / RATE
		var k := float(i) / cnt
		var s := sin(TAU * f * t) * (0.5 + 0.5 * sin(TAU * 7.5 * t))
		out[(i0 + i) % n] += s * sin(PI * k) * vol * 0.12


## Souffle : bruit filtré qui respire lentement (période de 6 s, deux fois par boucle).
static func _breath(out: PackedFloat32Array, vol: float, fc: float, rng: RandomNumberGenerator) -> void:
	var svf := Dsp.Svf.new(2, fc, 0.6)
	var n := out.size()
	for pas in 2:
		for i in n:
			var s := svf.process(rng.randf_range(-1.0, 1.0))
			if pas == 1:
				var t := float(i) / RATE
				out[i] += s * vol * 0.25 * (0.5 + 0.5 * sin(TAU * t / 6.0))


# --- Percussions -----------------------------------------------------------------------------------------

static func _hit(out: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, vol: float, tone_amt: float, noise_amt: float, ncut: float, rng: RandomNumberGenerator, metal := false) -> void:
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	if i0 < 0:
		i0 += n
	var svf := Dsp.Svf.new(2 if ncut > 1500.0 else 0, ncut, 0.4)
	var ph := 0.0
	for i in cnt:
		var t := float(i) / RATE
		var k := float(i) / cnt
		var f := f0 * pow(f1 / f0, minf(1.0, t / (dur * 0.5)))
		ph += f / RATE
		var s := 0.0
		if tone_amt > 0.0:
			if metal:
				s = (sin(TAU * ph) + 0.6 * sin(TAU * ph * 2.756) + 0.4 * sin(TAU * ph * 5.404)) * 0.5 * tone_amt
			else:
				s = Dsp.drive(sin(TAU * ph), 0.3) * tone_amt
		if noise_amt > 0.0 and rng != null:
			s += svf.process(rng.randf_range(-1.0, 1.0)) * noise_amt * exp(-t * 12.0 / dur)
		var env := minf(1.0, t / 0.0015) * pow(1.0 - k, 2.2)
		out[(i0 + i) % n] += s * env * vol * 0.5


static func _kick(out: PackedFloat32Array, t: float, vol: float, kit: String) -> void:
	match kit:
		"taiko":
			_hit(out, t, 0.7, 95.0, 48.0, vol * 1.1, 1.0, 0.0, 400.0, null)
		"heart":
			_hit(out, t, 0.3, 70.0, 45.0, vol, 1.0, 0.0, 200.0, null)
		"wood", "water", "metal":
			_hit(out, t, 0.3, 110.0, 55.0, vol, 1.0, 0.0, 300.0, null)
		_:
			_hit(out, t, 0.35, 120.0, 52.0, vol, 1.0, 0.0, 300.0, null)


static func _snare(out: PackedFloat32Array, t: float, vol: float, kit: String, rng: RandomNumberGenerator) -> void:
	match kit:
		"taiko":
			_hit(out, t, 0.12, 420.0, 380.0, vol, 0.4, 1.2, 2600.0, rng)
		"wood":
			_hit(out, t, 0.08, 820.0, 800.0, vol, 0.8, 0.2, 3000.0, rng)
			_hit(out, t, 0.06, 1260.0, 1240.0, vol, 0.4, 0.0, 3000.0, null)
		"metal":
			_hit(out, t, 0.25, 600.0, 590.0, vol, 0.5, 0.8, 3200.0, rng, true)
		"water":
			_hit(out, t, 0.09, 420.0, 900.0, vol, 0.7, 0.4, 1800.0, rng)
		_:
			_hit(out, t, 0.16, 210.0, 180.0, vol, 0.5, 1.3, 1800.0, rng)


static func _hat(out: PackedFloat32Array, t: float, vol: float, kit: String, rng: RandomNumberGenerator) -> void:
	match kit:
		"metal":
			_hit(out, t, 0.06, 5200.0, 5100.0, vol, 0.4, 0.8, 7000.0, rng, true)
		"wood":
			_hit(out, t, 0.03, 2400.0, 2300.0, vol, 0.3, 0.8, 4500.0, rng)
		_:
			_hit(out, t, 0.05, 6000.0, 6000.0, vol, 0.0, 2.5, 6500.0, rng)


static func _tom(out: PackedFloat32Array, t: float, vol: float, f: float) -> void:
	_hit(out, t, 0.4, f * 1.4, f, vol, 1.0, 0.0, 300.0, null)


# --- Ambiances ---------------------------------------------------------------------------------------------

## Nappe d'ambiance d'une région (state : "dead" ou "alive"), boucle de 12 s sans couture.
## bed : data/audio.json › regions › <id> › bed ({"seed", "dead": {...}, "alive": {...}}).
static func render_bed(state: String, bed := {}) -> PackedFloat32Array:
	var st := bed_section(bed, state)
	var out := _blank()
	var n := out.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(bed.get("seed", BED_DEFAULTS["seed"])) * 97 + hash(state)
	# Bruits continus : vent (bourrasques lentes), grondement, ruisseau, vagues. Deux passages : le
	# premier amorce les filtres, pour que la fin raccorde le début.
	var wind := Dsp.Svf.new(2, st["wind_lp"], 0.35)
	var rumble := Dsp.Svf.new(0, 90.0, 0.2)
	var stream := Dsp.Svf.new(2, 1800.0, 0.3)
	var waves := Dsp.Svf.new(0, 600.0, 0.1)
	var amp := 0.0
	for pas in 2:
		for i in n:
			var t := float(i) / RATE
			var s := 0.0
			if st["wind"] > 0.0:
				var g: float = 1.0 - float(st["gust"]) * (0.5 + 0.5 * sin(TAU * t / 6.0 + 0.7 * sin(TAU * t / 4.0)))
				if i % 64 == 0:
					wind.set_params(st["wind_lp"] * (0.7 + 0.6 * g), 0.35)
				s += wind.process(rng.randf_range(-1.0, 1.0)) * st["wind"] * g
			if st["rumble"] > 0.0:
				s += rumble.process(rng.randf_range(-1.0, 1.0)) * st["rumble"] * 3.0
			if st["stream"] > 0.0:
				# Clapotis : modulations dont les périodes divisent 12 s (la boucle raccorde).
				amp = 0.6 + 0.2 * sin(TAU * t * 7.0 / LOOP) + 0.15 * sin(TAU * t * 23.0 / LOOP + 1.0) + 0.1 * sin(TAU * t * 61.0 / LOOP + 2.0)
				s += stream.process(rng.randf_range(-1.0, 1.0)) * st["stream"] * amp
			if st["waves"] > 0.0:
				var w := pow(0.5 + 0.5 * sin(TAU * t / 6.0 - 1.2), 2.0)
				if i % 64 == 0:
					waves.set_params(300.0 + 1500.0 * w, 0.1)
				s += waves.process(rng.randf_range(-1.0, 1.0)) * st["waves"] * (0.2 + w)
			if pas == 1:
				out[i] += s * 0.5
	for ev in st["events"]:
		var kind := str(ev.get("kind", "bird"))
		var count := int(round(float(ev.get("rate", 0.2)) * LOOP))
		for e in count:
			_event(out, kind, rng.randf() * LOOP, float(ev.get("vol", 0.3)), rng)
	Dsp.reverb(out, 0.3, 0.8, 0.5, true)
	return Dsp.normalize(out, 0.5)


static func _event(out: PackedFloat32Array, kind: String, t0: float, vol: float, rng: RandomNumberGenerator) -> void:
	match kind:
		"bird":
			# Deux à cinq gazouillis : glissés rapides en FM, aigus.
			var f := rng.randf_range(2200.0, 3600.0)
			for k in rng.randi_range(2, 5):
				_chirp(out, t0 + k * rng.randf_range(0.08, 0.14), 0.07, f * rng.randf_range(0.9, 1.15), f * rng.randf_range(1.2, 1.5), vol)
		"cricket":
			var f := rng.randf_range(4200.0, 4800.0)
			for k in 6:
				_chirp(out, t0 + k * 0.045, 0.025, f, f, vol * 0.6)
		"drip":
			_chirp(out, t0, 0.09, rng.randf_range(1100.0, 1600.0), rng.randf_range(500.0, 700.0), vol)
		"bubble":
			_chirp(out, t0, 0.08, rng.randf_range(250.0, 400.0), rng.randf_range(700.0, 1100.0), vol)
		"frog":
			for k in 3:
				_hit(out, t0 + k * 0.11, 0.09, 260.0, 200.0, vol * 0.6, 1.0, 0.0, 300.0, null)
		"creak":
			# Bois qui grince : dent de scie grave dans un filtre résonant, hauteur qui hésite.
			var svf := Dsp.Svf.new(2, 700.0, 0.85)
			var n := out.size()
			var cnt := int(rng.randf_range(0.4, 0.8) * RATE)
			var i0 := int(t0 * RATE)
			var f := rng.randf_range(70.0, 130.0)
			var ph := 0.0
			for i in cnt:
				var k := float(i) / cnt
				ph += f * (1.0 + 0.15 * sin(TAU * 3.0 * k)) / RATE
				var s := svf.process(1.0 if fposmod(ph, 1.0) < 0.1 else 0.0)
				out[(i0 + i) % n] += s * sin(PI * k) * vol * 0.4
		"chime":
			_bell(out, t0, rng.randf_range(1400.0, 2600.0), vol, 2.0, 3.5, 1.2)
		"knock":
			_hit(out, t0, 0.12, 300.0, 240.0, vol, 1.0, 0.3, 1200.0, rng)
		"rustle":
			var svf := Dsp.Svf.new(1, 2500.0, 0.2)
			var n := out.size()
			var cnt := int(rng.randf_range(0.3, 0.7) * RATE)
			var i0 := int(t0 * RATE)
			for i in cnt:
				var k := float(i) / cnt
				var s := svf.process(rng.randf_range(-1.0, 1.0)) * (0.5 + 0.5 * sin(TAU * 17.0 * k * (1.0 + k)))
				out[(i0 + i) % n] += s * sin(PI * k) * vol * 0.35


static func _chirp(out: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, vol: float) -> void:
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	var ph := 0.0
	for i in cnt:
		var k := float(i) / cnt
		ph += f0 * pow(f1 / f0, k) / RATE
		out[(i0 + i) % n] += sin(TAU * ph) * sin(PI * k) * vol * 0.35
