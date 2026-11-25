## Musique et ambiances synthétisées par le code (appelées par synth.gd, enregistrées par gen_sounds.gd).
##
## Chaque région a cinq couches de 24 s (8 accords de 3 s), qui tournent ensemble en boucle et toujours en
## phase ; music.gd ne fait que régler leurs volumes, donc on passe de l'une à l'autre sans coupure :
##   sombre (exploration, terre morte), lumineux (exploration, terre vivante), combat (percussions et basse,
##   par-dessus l'exploration), coeur (chœur et battement, pendant le siège d'un Cœur), boss (thème du boss,
##   seul).
## Une boucle a deux moitiés de 12 s : A (les quatre accords de « roots », le thème) puis B (les quatre de
## « roots_b », une variation : la mélodie change, une contre-voix l'harmonise, les cordes montent, les
## percussions s'étoffent et finissent par un roulement). Le filtre général s'ouvre vers B et se referme.
## Tout s'écrit « en anneau » : une note, un écho ou une réverbération qui dépasse la fin de la boucle revient
## au début, donc la boucle raccorde sans clic.
##
## Les timbres imitent des instruments acoustiques (cordes frottées et pincées, bois, cuivres doux, marimba,
## kalimba, verre), dans un registre médium-grave, et un filtre doux coupe le haut du spectre : rien d'aigrelet.
##
## Les réglages d'une région (data/audio.json › regions › <id> › music) complètent DEFAULTS (Ronce) :
## {"seed", "roots" et "roots_b" (4 fondamentales chacune, demi-tons depuis le ré), "dark", "bright",
## "combat", "heart", "boss"}. Voir data/README.md, « Son et ambiance ».
extends RefCounted

const Dsp = preload("res://scripts/synth_dsp.gd")

const RATE := Dsp.RATE
const CHORD_TIME := 3.0
const ROOTS := [0, -4, -9, -5]
## Huit accords : A (roots) puis B (roots_b).
const CHORDS := 8
const LOOP := 24.0
## Les nappes d'ambiance gardent leur boucle de 12 s.
const BED_LOOP := 12.0
## Croche : 8 par accord.
const EIGHTH := CHORD_TIME / 8.0
const SIXTEENTH := CHORD_TIME / 16.0
## Version des formules (empreinte des pistes) : à changer quand le rendu change.
const VERSION := 4
const BED_VERSION := 2

## Fichier (couche) → section de réglages.
const LAYERS := {"sombre": "dark", "lumineux": "bright", "combat": "combat", "coeur": "heart", "boss": "boss"}
## Crête de chaque couche : l'exploration et le combat s'additionnent, le boss joue seul.
const PEAKS := {"sombre": 0.62, "lumineux": 0.62, "combat": 0.55, "coeur": 0.5, "boss": 0.78}
const KITS := ["frame", "taiko", "wood", "metal", "water"]
const VOWELS := {"a": [800.0, 1150.0, 2900.0], "o": [450.0, 800.0, 2830.0], "u": [325.0, 700.0, 2530.0], "e": [400.0, 1700.0, 2600.0]}
## Voix mélodiques (lead_tone, counter_tone) et instruments d'arpège (arp).
const TONES := ["flute", "clarinet", "horn", "horns", "brass", "cello", "glass"]
const ARPS := ["pizz", "harp", "marimba", "kalimba", "glock", "piano"]
## Modes des instruments frappés : rapports de fréquence, gains, amortissements (par seconde).
const MODES := {
	"marimba": [[1.0, 3.99, 9.9], [1.0, 0.32, 0.08], [2.6, 9.0, 22.0]],
	"kalimba": [[1.0, 5.95, 11.6], [1.0, 0.22, 0.06], [1.8, 9.0, 24.0]],
	"glock": [[1.0, 2.71, 5.03], [1.0, 0.28, 0.08], [1.4, 6.0, 14.0]],
	"piano": [[1.0, 2.002, 3.005, 4.012], [1.0, 0.38, 0.16, 0.06], [1.1, 2.2, 3.6, 5.5]],
	"bell": [[0.5, 1.0, 1.19, 1.5, 2.0], [0.45, 1.0, 0.45, 0.3, 0.22], [0.5, 0.8, 1.2, 1.6, 2.4]],
}

## Thème de Ronce (le monde) : ré mineur. A : ré, si bémol, fa, la ; B : do, sol, si bémol, la.
## motif : [croche de départ (0 à 31), note de l'accord (0 = fondamentale, 1, 2… puis l'octave), durée en
## croches, altération facultative en demi-tons]. motif_b (vide : variation tirée de motif) joue en B.
const DEFAULTS := {
	"seed": 11,
	"roots": [0, -4, -9, -5],
	"roots_b": [-2, -7, -4, -5],
	"dark": {"chord": [0, 7, 12, 15], "pad": 0.5, "pad_lp": 650.0, "drone": 0.3, "bell": 0.3, "bell_ratio": 3.5, "texture": 0.12, "verb": 0.5,
		"strings": 0.35, "piano": 0.22, "sweep": 0.5},
	"bright": {"chord": [0, 4, 7, 12], "octave": 1, "pattern": [0, 4, 7, 12, 16, 12, 7, 4], "pattern_b": [], "arp": "pizz", "pad": 0.32, "pad_lp": 1100.0,
		"pluck": 0.5, "pluck_tone": 0.4, "sparkle": 0.2, "sparkle_note": 19, "lead": 0.34, "lead_tone": "cello", "lead_octave": 2, "bass": 0.2, "verb": 0.4,
		"counter": 0.24, "counter_tone": "horn", "strings": 0.25, "echo": 0.18, "sweep": 0.4,
		"motif": [[0, 2, 2], [2, 1, 1], [3, 2, 1], [4, 3, 4], [8, 3, 2], [10, 2, 2], [12, 1, 4], [16, 2, 2], [18, 3, 1], [19, 2, 1], [20, 0, 4], [24, 1, 3], [27, 2, 1], [28, 3, 4]],
		"motif_b": []},
	"combat": {"kit": "frame", "kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "..x...x...x...x.", "tom": "",
		"bass": [0, 0, 12, 0, 7, 0, 12, 3], "bass_vol": 0.42, "pulse": 0.3, "drums": 0.9, "verb": 0.22, "horn": 0.25, "fill": 0.6, "swell": 0.3, "density": 0.5},
	"heart": {"vowel": "a", "choir": 0.6, "beat": 0.32, "shimmer": 0.2, "verb": 0.5, "solo": 0.22, "strings": 0.25},
	"boss": {"chord": [0, 7, 12, 15], "kit": "taiko", "kick": "x..x..x.x..x..x.", "snare": "....x.......x..x", "hat": "x.x.x.x.x.x.x.x.", "tom": "...........x.xx.",
		"bass": [0, 0, 12, 0, 0, 10, 12, 7], "bass_vol": 0.6, "brass": 0.42, "lead": 0.45, "lead_tone": "horns", "lead_octave": 2, "choir": 0.3, "pulse": 0.3, "pad": 0.3,
		"drums": 1.0, "density": 1.0, "verb": 0.3, "counter": 0.3, "counter_tone": "cello", "gong": 0.5, "fill": 0.8, "echo": 0.12,
		"motif": [[0, 0, 1], [1, 0, 1], [2, 3, 2], [4, 2, 2], [6, 1, 2], [8, 0, 1], [9, 0, 1], [10, 3, 2], [12, 4, 4], [16, 0, 1], [17, 0, 1], [18, 3, 2], [20, 2, 2], [22, 1, 2], [24, 2, 3], [27, 3, 1], [28, 1, 4]],
		"motif_b": []},
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


## Les huit fondamentales d'une boucle : A puis B. Sans « roots_b », B reprend A dans un autre ordre.
static func progression(style: Dictionary) -> Array:
	var a: Array = style.get("roots", DEFAULTS["roots"])
	var b: Array = style.get("roots_b", [])
	if b.size() != 4:
		b = DEFAULTS["roots_b"] if not style.has("roots") else [a[2], a[3], a[0], a[1]]
	return a + b


## Empreinte d'une couche (formules + réglages) : gen_sounds l'écrit à côté des pistes, sound_test la compare.
static func fingerprint(layer: String, style: Dictionary) -> int:
	return hash([VERSION, layer, style.get("seed", DEFAULTS["seed"]), progression(style), section(style, LAYERS[layer]),
		section(style, "dark")["chord"] if layer in ["combat", "boss"] else 0, section(style, "bright") if layer == "coeur" else 0])


static func bed_fingerprint(state: String, bed: Dictionary) -> int:
	return hash([BED_VERSION, state, bed.get("seed", BED_DEFAULTS["seed"]), bed_section(bed, state)])


static func bed_section(bed: Dictionary, state: String) -> Dictionary:
	var out: Dictionary = BED_DEFAULTS[state].duplicate(true)
	var own = bed.get(state, {})
	if own is Dictionary:
		out.merge(own, true)
	return out


static func _blank(seconds := LOOP) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


## Une couche de musique (sombre, lumineux, combat, coeur, boss).
## Trois bus : « main » (sec), « pads » (nappes, passées dans un chorus) et « lead » (voix, passées dans un
## écho) ; puis réverbération, balayage du filtre, couleur douce et crête.
static func render(layer: String, style := {}) -> PackedFloat32Array:
	var bus := {"main": _blank(), "pads": _blank(), "lead": _blank()}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(style.get("seed", DEFAULTS["seed"])) * 31 + hash(layer)
	var roots := progression(style)
	var st := section(style, LAYERS[layer])
	match layer:
		"sombre":
			_dark(bus, st, roots, rng)
		"lumineux":
			_bright(bus, st, roots, rng)
		"combat":
			_combat(bus, st, section(style, "dark")["chord"], roots, rng)
		"coeur":
			_heart(bus, st, section(style, "bright"), roots, rng)
		"boss":
			_boss(bus, st, roots, rng)
	_chorus(bus["pads"], 0.012, 0.004, 0.5)
	_echo(bus["lead"], EIGHTH * 3.0, 0.38, float(st.get("echo", 0.15)), 1800.0)
	var out: PackedFloat32Array = bus["main"]
	for i in out.size():
		out[i] += bus["pads"][i] + bus["lead"][i]
	Dsp.reverb(out, float(st["verb"]), 0.9, 0.5, true)
	var sweep := float(st.get("sweep", 0.0))
	if sweep > 0.0:
		_sweep(out, 2400.0, 2400.0 + 6000.0 * sweep)
	_warm(out, 6500.0)
	_highpass(out, 38.0)
	_glue(out, 1.3)
	return Dsp.normalize(out, PEAKS.get(layer, 0.6))


## Coupe l'infra-grave (inaudible, mais qui mange la marge), en anneau.
static func _highpass(out: PackedFloat32Array, fc: float) -> void:
	var svf := Dsp.Svf.new(1, fc, 0.0)
	var n := out.size()
	for i in n:
		svf.process(out[i])
	for i in n:
		out[i] = svf.process(out[i])


## Couleur douce : passe-bas à deux pôles, en anneau (le haut du spectre, qui fait « tchip », est adouci).
static func _warm(out: PackedFloat32Array, fc: float) -> void:
	var svf := Dsp.Svf.new(0, fc, 0.05)
	var n := out.size()
	for i in n:
		svf.process(out[i])
	for i in n:
		out[i] = svf.process(out[i])


## Saturation de bande légère sur tout le mélange : resserre les crêtes, épaissit le grave.
static func _glue(out: PackedFloat32Array, amount: float) -> void:
	var m := 0.0001
	for v in out:
		m = maxf(m, absf(v))
	var k := tanh(amount)
	for i in out.size():
		out[i] = tanh(out[i] / m * amount) / k


## Filtre qui s'ouvre vers le milieu de la boucle (moitié B) et se referme pour raccorder ; il ne fait
## qu'adoucir l'aigu (40 % du son passe sans filtre).
static func _sweep(out: PackedFloat32Array, lo: float, hi: float) -> void:
	var svf := Dsp.Svf.new(0, lo, 0.1)
	var n := out.size()
	for pas in 2:
		for i in n:
			if i % 64 == 0:
				var k := 0.5 - 0.5 * cos(TAU * (float(i) / n - 0.08))
				svf.set_params(lo * pow(hi / lo, k), 0.1)
			var y := svf.process(out[i])
			if pas == 1:
				out[i] = y + (out[i] - y) * 0.4


## Chorus : copie retardée dont le retard ondule (une période qui divise la boucle).
static func _chorus(buf: PackedFloat32Array, base: float, depth: float, mix: float) -> void:
	var n := buf.size()
	var src := buf.duplicate()
	var rate := 12.0 / LOOP
	for i in n:
		var t := float(i) / RATE
		var d := (base + depth * sin(TAU * rate * t)) * RATE
		var p := float(i) - d
		var i0 := int(floor(p))
		var fr := p - i0
		var a: float = src[posmod(i0, n)]
		var b: float = src[posmod(i0 + 1, n)]
		buf[i] = src[i] * (1.0 - mix * 0.4) + lerpf(a, b, fr) * mix


## Écho (retour filtré), en anneau : deux passages pour que la queue de la fin revienne au début.
static func _echo(buf: PackedFloat32Array, delay: float, fb: float, mix: float, lp: float) -> void:
	if mix <= 0.0:
		return
	var n := buf.size()
	var d := int(delay * RATE)
	var wet := PackedFloat32Array()
	wet.resize(n)
	var svf := Dsp.Svf.new(0, lp, 0.0)
	for pas in 2:
		for i in n:
			var j := posmod(i - d, n)
			wet[i] = svf.process(buf[j] + wet[j] * fb)
	for i in n:
		buf[i] += wet[i] * mix


## Variation d'une mélodie pour la moitié B : la première phrase monte d'une note de l'accord (la contre-voix,
## qui reprend la mélodie d'origine, l'harmonise alors à la tierce), la fin retombe sur la fondamentale.
static func vary(motif: Array) -> Array:
	var out: Array = []
	for i in motif.size():
		var m: Array = motif[i].duplicate()
		if int(m[0]) < 16:
			m[1] = int(m[1]) + 1
		elif int(m[0]) >= 24 and i == motif.size() - 1:
			m[1] = 0
		out.append(m)
	return out


# --- Couches ---------------------------------------------------------------------------------------------

static func _dark(bus: Dictionary, st: Dictionary, roots: Array, rng: RandomNumberGenerator) -> void:
	var chord: Array = st["chord"]
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var b := c >= 4
		var freqs: Array = []
		for s in chord:
			freqs.append(Dsp.hz(roots[c] + s, 1))
		_pad(bus["pads"], t0, CHORD_TIME, freqs, st["pad"] * (1.0 if b else 0.85), st["pad_lp"], rng)
		# Bourdon : fondamentale et quinte graves, qui se relaient d'un accord à l'autre.
		_pad(bus["main"], t0, CHORD_TIME, [Dsp.hz(roots[c], 0), Dsp.hz(roots[c] + 7, 0)], st["drone"], 260.0, rng, 0.002, true)
		# Cordes graves (B) : une section de violoncelles qui monte doucement.
		if b and st["strings"] > 0.0:
			var sw := 0.6 + 0.4 * float(c - 4) / 3.0
			_ensemble(bus["pads"], t0, CHORD_TIME, [Dsp.hz(roots[c], 0), Dsp.hz(roots[c] + chord[1], 1), Dsp.hz(roots[c] + chord[2], 1)], st["strings"] * sw, 900.0, rng, 0.6)
		# Cloche grave, au début d'un accord sur deux.
		if st["bell"] > 0.0 and c % 2 == 0:
			_mallet(bus["main"], t0 + 0.02, Dsp.hz(roots[c] + chord[(c * 3 + 1) % chord.size()], 2), st["bell"] * 0.8, "bell", 5.0)
		# Piano feutré : deux ou trois notes de l'accord, posées en des endroits qui changent.
		if st["piano"] > 0.0:
			var count := 2 if not b else 3
			for k in count:
				var at := t0 + EIGHTH * float(rng.randi_range(1, 7))
				var note: int = chord[rng.randi_range(0, chord.size() - 1)]
				_mallet(bus["lead"], at, Dsp.hz(roots[c] + note, 2 if k < 2 else 1), st["piano"] * rng.randf_range(0.6, 1.0), "piano", 2.6)
	if st["texture"] > 0.0:
		_breath(bus["main"], st["texture"], 450.0, rng)


static func _bright(bus: Dictionary, st: Dictionary, roots: Array, rng: RandomNumberGenerator) -> void:
	var chord: Array = st["chord"]
	var oct := int(st["octave"])
	var pattern: Array = st["pattern"]
	var pattern_b: Array = st["pattern_b"]
	if pattern_b.is_empty():
		pattern_b = pattern.duplicate()
		pattern_b.reverse()
	var arp := str(st["arp"])
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var b := c >= 4
		var freqs: Array = []
		for s in chord:
			freqs.append(Dsp.hz(roots[c] + s, maxi(oct, 1)))
		_pad(bus["pads"], t0, CHORD_TIME, freqs, st["pad"], st["pad_lp"], rng)
		if b and st["strings"] > 0.0:
			_ensemble(bus["pads"], t0, CHORD_TIME, [Dsp.hz(roots[c] + chord[0], 1), Dsp.hz(roots[c] + chord[1], 1), Dsp.hz(roots[c] + chord[2], 2)], st["strings"], 1300.0, rng, 0.4)
		if st["bass"] > 0.0:
			_bass(bus["main"], t0, CHORD_TIME * 0.45, Dsp.hz(roots[c], 0), st["bass"], 0.2)
			_bass(bus["main"], t0 + CHORD_TIME * 0.5, CHORD_TIME * 0.4, Dsp.hz(roots[c] + (7 if b else 0), 0), st["bass"] * 0.7, 0.2)
		# Arpège : clairsemé au début (une note sur deux), plein ensuite, renversé en B.
		var pat: Array = pattern_b if b else pattern
		var step := CHORD_TIME / pat.size()
		for j in pat.size():
			if c < 2 and j % 2 == 1:
				continue
			var acc := 1.0 if j % 4 == 0 else 0.72
			_arp(bus["main"], arp, t0 + j * step + rng.randf_range(0.0, 0.01), Dsp.hz(roots[c] + float(pat[j]), oct + 1), st["pluck"] * acc * rng.randf_range(0.85, 1.0), float(st["pluck_tone"]), rng)
		if st["sparkle"] > 0.0 and (b or c % 2 == 1):
			_mallet(bus["lead"], t0 + CHORD_TIME * 0.5, Dsp.hz(roots[c] + float(st["sparkle_note"]), 1), st["sparkle"], "glock", 2.0)
	var motif: Array = st["motif"]
	var motif_b: Array = st["motif_b"] if not st["motif_b"].is_empty() else vary(motif)
	var lo := int(st["lead_octave"])
	_melody(bus["lead"], motif, chord, roots, 0, lo, st["lead"], str(st["lead_tone"]), rng)
	_melody(bus["lead"], motif_b, chord, roots, 4, lo, st["lead"], str(st["lead_tone"]), rng)
	if st["counter"] > 0.0:
		_melody(bus["lead"], motif, chord, roots, 4, lo, st["counter"], str(st["counter_tone"]), rng)


static func _combat(bus: Dictionary, st: Dictionary, chord: Array, roots: Array, rng: RandomNumberGenerator) -> void:
	_drums(bus["main"], st, rng, roots.size())
	var bass: Array = st["bass"]
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var b := c >= 4
		for j in bass.size():
			if bass[j] == null:
				continue
			var semis := float(bass[j])
			# En B, la basse saute à l'octave sur les contretemps.
			if b and j % 2 == 1 and semis == 0.0:
				semis = 12.0
			_bass(bus["main"], t0 + j * (CHORD_TIME / bass.size()), CHORD_TIME / bass.size() * 0.9, Dsp.hz(roots[c] + semis, 0), st["bass_vol"], 0.5)
		if st["pulse"] > 0.0:
			# Cordes en spiccato : ostinato de doubles croches, qui s'arpège en B.
			for j in 16:
				var note: float = roots[c] + (chord[1] if j % 4 == 2 else 0.0)
				if b and j % 4 == 3:
					note = roots[c] + chord[2]
				_spiccato(bus["pads"], t0 + j * SIXTEENTH, SIXTEENTH * 0.8, Dsp.hz(note, 1), st["pulse"] * (1.0 if j % 4 == 0 else 0.6))
		if b and st["horn"] > 0.0:
			for s in chord.slice(0, 3):
				_tone(bus["pads"], "horn", t0, EIGHTH * 3.0, Dsp.hz(roots[c] + s, 1), st["horn"] * 0.55, rng)
	if st["swell"] > 0.0:
		_swell(bus["main"], 4.0 * CHORD_TIME, 1.4, st["swell"], rng)
		_swell(bus["main"], LOOP, 1.4, st["swell"] * 0.7, rng)


static func _heart(bus: Dictionary, st: Dictionary, bright: Dictionary, roots: Array, rng: RandomNumberGenerator) -> void:
	var chord: Array = bright["chord"]
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var b := c >= 4
		var voices: Array = chord.slice(0, 4 if b else 3)
		for s in voices:
			_choir(bus["pads"], t0, CHORD_TIME, Dsp.hz(roots[c] + s, 1), st["choir"], str(st["vowel"]), rng)
		if b and st["strings"] > 0.0:
			_ensemble(bus["pads"], t0, CHORD_TIME, [Dsp.hz(roots[c], 0), Dsp.hz(roots[c] + chord[2], 1)], st["strings"], 800.0, rng, 0.5)
		if st["shimmer"] > 0.0:
			_tone(bus["lead"], "glass", t0, CHORD_TIME * 0.9, Dsp.hz(roots[c] + chord[chord.size() - 1], 2), st["shimmer"], rng)
	# Battement de cœur : « poum-poum » à chaque noire (0,75 s) ; en B, un battement fantôme s'y ajoute.
	if st["beat"] > 0.0:
		for k in int(LOOP / (EIGHTH * 2.0)):
			var t := k * EIGHTH * 2.0
			_kick(bus["main"], t, st["beat"], "heart")
			_kick(bus["main"], t + 0.16, st["beat"] * 0.6, "heart")
			if t >= LOOP * 0.5 and k % 2 == 1:
				_kick(bus["main"], t + EIGHTH, st["beat"] * 0.3, "heart")
	# En B, la mélodie de la terre vivante revient, au verre, très doucement.
	if st["solo"] > 0.0:
		_melody(bus["lead"], bright["motif"], chord, roots, 4, 2, st["solo"], "glass", rng)


static func _boss(bus: Dictionary, st: Dictionary, roots: Array, rng: RandomNumberGenerator) -> void:
	var chord: Array = st["chord"]
	_drums(bus["main"], st, rng, roots.size())
	var bass: Array = st["bass"]
	for c in roots.size():
		var t0: float = c * CHORD_TIME
		var b := c >= 4
		var freqs: Array = []
		for s in chord:
			freqs.append(Dsp.hz(roots[c] + s, 1))
		if st["pad"] > 0.0:
			_ensemble(bus["pads"], t0, CHORD_TIME, freqs, st["pad"], 1000.0, rng, 0.25)
		for j in bass.size():
			if bass[j] == null:
				continue
			_bass(bus["main"], t0 + j * (CHORD_TIME / bass.size()), CHORD_TIME / bass.size() * 0.85, Dsp.hz(roots[c] + float(bass[j]), 0), st["bass_vol"], 0.7)
		if st["brass"] > 0.0:
			# Accords de cuivres graves sur les temps forts (1 et le « et » du 3) ; en B, un de plus sur le 4.
			var hits := [0.0, EIGHTH * 5.0] if not b else [0.0, EIGHTH * 3.0, EIGHTH * 5.0, EIGHTH * 7.0]
			for at in hits:
				for s in chord.slice(0, 3):
					_tone(bus["pads"], "brass", t0 + at, EIGHTH * 1.6, Dsp.hz(roots[c] + s, 1), st["brass"] * 0.45, rng)
		if st["pulse"] > 0.0:
			for j in 16:
				_spiccato(bus["pads"], t0 + j * SIXTEENTH, SIXTEENTH * 0.7, Dsp.hz(roots[c] + (12.0 if j % 2 == 1 else 0.0), 1), st["pulse"] * (1.0 if j % 4 == 0 else 0.55))
		if st["choir"] > 0.0:
			_choir(bus["pads"], t0, CHORD_TIME, Dsp.hz(roots[c] + chord[0], 1), st["choir"], "o", rng)
			_choir(bus["pads"], t0, CHORD_TIME, Dsp.hz(roots[c] + chord[1], 1), st["choir"] * 0.8, "o", rng)
			if b:
				_choir(bus["pads"], t0, CHORD_TIME, Dsp.hz(roots[c] + chord[2], 1), st["choir"] * 0.7, "a", rng)
		if st["gong"] > 0.0 and c % 4 == 0:
			_hit(bus["main"], t0, 1.6, 66.0, 40.0, st["gong"] * 0.7, 1.0, 0.0, 300.0, null)
			_mallet(bus["main"], t0, Dsp.hz(roots[c], 1), st["gong"] * 0.6, "bell", 4.0)
	var motif: Array = st["motif"]
	var motif_b: Array = st["motif_b"] if not st["motif_b"].is_empty() else vary(motif)
	var lo := int(st["lead_octave"])
	_melody(bus["lead"], motif, chord, roots, 0, lo, st["lead"], str(st["lead_tone"]), rng)
	_melody(bus["lead"], motif_b, chord, roots, 4, lo, st["lead"], str(st["lead_tone"]), rng)
	if st["counter"] > 0.0:
		_melody(bus["lead"], motif, chord, roots, 4, lo, st["counter"], str(st["counter_tone"]), rng)
	_swell(bus["main"], LOOP, 1.6, 0.35, rng)


## Mélodie : chaque note est prise dans l'accord en cours (motif : [croche, note de l'accord, durée, altération]).
## first : premier accord (0 pour A, 4 pour B).
static func _melody(out: PackedFloat32Array, motif: Array, chord: Array, roots: Array, first: int, octave: int, vol: float, tone: String, rng: RandomNumberGenerator) -> void:
	if vol <= 0.0:
		return
	for m in motif:
		var stp := int(m[0])
		var c := first + (stp / 8) % 4
		var idx := int(m[1])
		var semis: float = chord[posmod(idx, chord.size())] + 12.0 * floorf(float(idx) / chord.size()) + (float(m[3]) if m.size() > 3 else 0.0)
		var f := Dsp.hz(roots[c] + semis, octave)
		var v := vol * rng.randf_range(0.85, 1.0) * (1.0 if stp % 4 == 0 else 0.9)
		_tone(out, tone, first * CHORD_TIME + stp * EIGHTH + rng.randf_range(0.0, 0.012), float(m[2]) * EIGHTH, f, v, rng)


## Percussions : motifs de 16 doubles croches par accord (« x » frappe, « o » frappe douce, « . » rien).
## En B, des toms graves s'ajoutent ; « fill » : roulement de toms à la fin de chaque moitié.
static func _drums(out: PackedFloat32Array, st: Dictionary, rng: RandomNumberGenerator, chords: int) -> void:
	var kit := str(st["kit"])
	var vol: float = st["drums"]
	var fill := float(st.get("fill", 0.0))
	var density := float(st.get("density", 0.0))
	for c in chords:
		var b := c >= 4
		var end_of_half := c % 4 == 3
		for j in 16:
			var t: float = c * CHORD_TIME + j * SIXTEENTH
			var hum := rng.randf_range(-0.004, 0.004)
			if fill > 0.0 and end_of_half and j >= (12 if c == chords - 1 else 14):
				var f := 150.0 - 14.0 * float(j - 12)
				_tom(out, t + hum, vol * fill * (0.7 + 0.1 * float(j - 12)), f)
				continue
			var hit := {}
			for part in ["kick", "snare", "hat", "tom"]:
				var pat := str(st.get(part, ""))
				if part == "tom" and pat.is_empty() and b and fill > 0.0:
					pat = "......x.......x."
				if pat.is_empty():
					continue
				var ch := pat[j % pat.length()]
				if ch == ".":
					continue
				var v := vol * (1.0 if ch == "x" else 0.5) * rng.randf_range(0.88, 1.0)
				hit[part] = true
				match part:
					"kick":
						_kick(out, t + hum, v, kit)
					"snare":
						_snare(out, t + hum, v * 0.8, kit, rng)
					"hat":
						_hat(out, t + hum, v * (0.5 if j % 2 == 0 else 0.38), kit, rng)
					"tom":
						_tom(out, t + hum, v * 0.7, 98.0 if j % 2 == 0 else 74.0)
			# Densité : hochet en doubles croches, frappes fantômes, reprises de grosse caisse, toms en B.
			if density > 0.0:
				if not hit.has("hat"):
					_hat(out, t + hum, vol * density * (0.3 if j % 4 == 2 else 0.18), kit, rng)
				if not hit.has("snare") and j in [7, 10, 15]:
					_snare(out, t + hum, vol * density * 0.28, kit, rng)
				if density >= 0.8 and not hit.has("kick") and (j == 14 or (b and j == 11)):
					_kick(out, t + hum, vol * 0.55, kit)
				if density >= 0.8 and b and not hit.has("tom") and j % 4 == 2:
					_tom(out, t + hum, vol * density * 0.45, 130.0 if j % 8 == 2 else 110.0)


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
	var svf := Dsp.Svf.new(0, lp, 0.1)
	var svf2 := Dsp.Svf.new(0, lp, 0.0)
	var ph := PackedFloat32Array()
	for k in freqs.size() * 3:
		ph.append(rng.randf())
	var g := vol / sqrt(float(freqs.size())) * 0.35
	for i in cnt:
		var t := float(i) / RATE
		var k := float(i) / cnt
		var env := sin(PI * k)
		env = env * env * (3.0 - 2.0 * env)
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
			svf.set_params(lp * (1.0 + 0.2 * sin(TAU * t / dur)), 0.1)
		s = svf2.process(svf.process(s))
		out[posmod(i0 + i, n)] += s * env * g


## Section de cordes frottées : deux voix désaccordées par note, vibrato lent, archet qui s'installe
## (attaque « attack » en secondes), filtre de caisse.
static func _ensemble(out: PackedFloat32Array, t0: float, dur: float, freqs: Array, vol: float, lp: float, rng: RandomNumberGenerator, attack: float) -> void:
	if vol <= 0.0:
		return
	var n := out.size()
	var rel := 0.5
	var i0 := int(t0 * RATE)
	var cnt := int((dur + rel) * RATE)
	var svf := Dsp.Svf.new(0, lp, 0.2)
	var body := Dsp.Svf.new(2, 420.0, 0.5)
	var ph := PackedFloat32Array()
	var vr := PackedFloat32Array()
	for k in freqs.size() * 2:
		ph.append(rng.randf())
		vr.append(rng.randf_range(4.6, 5.8))
	var g := vol / sqrt(float(freqs.size())) * 0.3
	for i in cnt:
		var t := float(i) / RATE
		var s := 0.0
		for fi in freqs.size():
			var f: float = freqs[fi]
			for d in 2:
				var idx := fi * 2 + d
				var fr := f * (1.0 + (0.004 if d == 1 else -0.003) + 0.004 * sin(TAU * vr[idx] * t))
				ph[idx] = ph[idx] + fr / RATE
				s += Dsp.osc(Dsp.SAW, ph[idx], fr / RATE, 0.5, rng)
		s = svf.process(s)
		s += body.process(s) * 0.5
		var env := smoothstep(0.0, attack, t)
		if t > dur:
			env *= 1.0 - smoothstep(0.0, rel, t - dur)
		out[posmod(i0 + i, n)] += s * env * g


## Cordes en spiccato (notes brèves, archet sautillé), filtrées bas.
static func _spiccato(out: PackedFloat32Array, t0: float, dur: float, f: float, vol: float) -> void:
	var n := out.size()
	var cnt := int((dur + 0.08) * RATE)
	var i0 := int(t0 * RATE)
	var svf := Dsp.Svf.new(0, minf(f * 5.0, 2200.0), 0.2)
	var ph := 0.0
	var ph2 := 0.37
	for i in cnt:
		var t := float(i) / RATE
		ph += f / RATE
		ph2 += f * 1.004 / RATE
		var s := Dsp.osc(Dsp.SAW, ph, f / RATE, 0.5, null) * 0.55 + Dsp.osc(Dsp.SAW, ph2, f / RATE, 0.5, null) * 0.45
		s = svf.process(s)
		var env := minf(1.0, t / 0.012) * exp(-t * 2.5 / maxf(dur, 0.05)) * minf(1.0, float(cnt - i) / (0.02 * RATE))
		out[(i0 + i) % n] += s * env * vol * 0.32


## Voix mélodique : flute (flûte en bois, souffle), clarinet (anche, harmoniques impaires), horn (cor doux),
## horns (pupitre de cors à l'octave, rond), brass (cuivres graves, pour les accords plaqués), cello (violoncelle à l'archet, caisse), glass (harmonica de verre).
static func _tone(out: PackedFloat32Array, tone: String, t0: float, dur: float, f: float, vol: float, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	var rel := {"glass": 0.5, "cello": 0.22, "horn": 0.2, "horns": 0.25, "brass": 0.15}.get(tone, 0.12) as float
	var att := {"flute": 0.05, "clarinet": 0.04, "horn": 0.09, "horns": 0.1, "brass": 0.05, "cello": 0.1, "glass": 0.18}.get(tone, 0.05) as float
	var cnt := int((dur + rel) * RATE)
	var i0 := int(t0 * RATE)
	var svf := Dsp.Svf.new(0, clampf(f * 8.0, 1200.0, 3500.0), 0.2)
	var body := Dsp.Svf.new(2, 300.0, 0.55)
	var body2 := Dsp.Svf.new(2, 950.0, 0.5)
	var breath := Dsp.Svf.new(2, minf(f * 2.0, 3000.0), 0.5)
	var ph := rng.randf()
	var vr := rng.randf_range(4.8, 5.6)
	for i in cnt:
		var t := float(i) / RATE
		var vd := 0.005 if tone == "cello" else (0.004 if tone in ["flute", "glass"] else 0.002)
		var vib := 1.0 + vd * sin(TAU * vr * t) * clampf((t - 0.2) * 3.0, 0.0, 1.0)
		ph += f * vib / RATE
		var dt := f / RATE
		var s := 0.0
		match tone:
			"flute":
				s = sin(TAU * ph) + 0.16 * sin(TAU * ph * 2.0) + 0.05 * sin(TAU * ph * 3.0)
				s += breath.process(rng.randf_range(-1.0, 1.0)) * 0.1
			"clarinet":
				s = Dsp.osc(Dsp.SQUARE, ph, dt, 0.5, null) * 0.5
				if i % 32 == 0:
					svf.set_params(minf(f * (1.6 + 1.0 * minf(1.0, t / 0.1)), 1200.0), 0.1)
				s = svf.process(s) + breath.process(rng.randf_range(-1.0, 1.0)) * 0.04
			"horn":
				var br := minf(1.0, t / 0.15) * 0.8
				s = sin(TAU * ph) + 0.45 * br * sin(TAU * ph * 2.0) + 0.22 * br * sin(TAU * ph * 3.0) + 0.08 * br * sin(TAU * ph * 4.0)
				s *= 0.8
			"horns":
				# Pupitre de cors : la note et son octave grave, harmoniques douces qui s'ouvrent à l'attaque.
				var br := minf(1.0, t / 0.12) * (0.7 + 0.15 * exp(-t * 4.0))
				s = sin(TAU * ph) + 0.4 * br * sin(TAU * ph * 2.0) + 0.15 * br * sin(TAU * ph * 3.0)
				s += 0.7 * (sin(PI * ph) + 0.35 * br * sin(TAU * ph))
				s *= 0.6
			"brass":
				s = Dsp.osc(Dsp.SAW, ph, dt, 0.5, null)
				if i % 32 == 0:
					svf.set_params(minf(f * (1.5 + 3.0 * minf(1.0, t / 0.08) * (0.6 + 0.4 * exp(-t * 3.0))), 1500.0), 0.2)
				s = svf.process(s) * 0.85
			"cello":
				s = Dsp.osc(Dsp.SAW, ph, dt, 0.5, null)
				s = svf.process(s)
				s = s * 0.6 + body.process(s) * 0.7 + body2.process(s) * 0.35
				s += breath.process(rng.randf_range(-1.0, 1.0)) * 0.03
			"glass":
				s = sin(TAU * ph) + 0.22 * sin(TAU * ph * 2.0) + 0.08 * sin(TAU * ph * 3.01)
				s *= 1.0 - 0.15 * (0.5 + 0.5 * sin(TAU * 4.0 * t))
		var env := smoothstep(0.0, att, t)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / rel)
		out[(i0 + i) % n] += s * env * vol * 0.3


## Arpège : corde pincée (pizz, harp) ou lame frappée (marimba, kalimba, glock, piano).
static func _arp(out: PackedFloat32Array, kind: String, t0: float, f: float, vol: float, tone: float, rng: RandomNumberGenerator) -> void:
	match kind:
		"pizz":
			_pluck(out, t0, f, vol, 1.0, 0.2 + tone * 0.6, 0.42, rng)
		"harp":
			_pluck(out, t0, f, vol * 0.9, 2.0, 0.25 + tone * 0.5, 0.48, rng)
		_:
			_mallet(out, t0, f, vol * 0.9, kind, 1.6 + tone)


## Note pincée (corde de Karplus-Strong) : tone de 0 (sourde) à 1 (claire) ; damp : longueur de la note.
static func _pluck(out: PackedFloat32Array, t0: float, f: float, vol: float, dur: float, tone: float, damp: float, rng: RandomNumberGenerator) -> void:
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
		lp += (0.15 + 0.6 * tone) * (x - lp)
		buf[i] = lp
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	var w := 0
	var prev := 0.0
	for i in cnt:
		var a := buf[(w - d0 + size * 4) % size]
		var b := buf[(w - d0 - 1 + size * 4) % size]
		var y := lerpf(a, b, frac)
		var nv := (y * damp + prev * (1.0 - damp)) * 0.997
		prev = y
		buf[w] = nv
		w = (w + 1) % size
		var env := minf(1.0, float(cnt - i) / (0.05 * RATE))
		out[(i0 + i) % n] += y * vol * 0.55 * env


## Lame ou cloche frappée : quelques modes qui s'amortissent chacun à son rythme, attaque feutrée.
static func _mallet(out: PackedFloat32Array, t0: float, f: float, vol: float, kind: String, dur: float) -> void:
	var md: Array = MODES.get(kind, MODES["marimba"])
	var ratios: Array = md[0]
	var gains: Array = md[1]
	var decays: Array = md[2]
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	var nm := ratios.size()
	var dph := PackedFloat32Array()
	var g := PackedFloat32Array()
	var dk := PackedFloat32Array()
	for m in nm:
		var fr: float = f * float(ratios[m])
		dph.append(TAU * fr / RATE)
		g.append(float(gains[m]) if fr < 4500.0 else 0.0)
		dk.append(exp(-float(decays[m]) / RATE))
	var amp := g.duplicate()
	# Toucher de la mailloche : bref bruit feutré (donne la netteté de l'attaque sans aigu qui pique).
	var click := Dsp.Svf.new(2, clampf(f * 3.0, 900.0, 2600.0), 0.3)
	var nclick := int(0.012 * RATE)
	for i in cnt:
		var s := 0.0
		for m in nm:
			s += sin(dph[m] * i) * amp[m]
			amp[m] = amp[m] * dk[m]
		if i < nclick:
			var noise := fposmod(sin(float(i0 + i) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
			s += click.process(noise) * 1.2 * exp(-float(i) / (0.003 * RATE))
		var env := minf(1.0, float(i) / (0.004 * RATE)) * minf(1.0, float(cnt - i) / (0.05 * RATE))
		out[(i0 + i) % n] += s * env * vol * 0.3


## Basse : contrebasse pincée (corde) doublée d'un grave rond ; punch : attaque plus marquée (0 à 1).
static func _bass(out: PackedFloat32Array, t0: float, dur: float, f: float, vol: float, punch: float) -> void:
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int(t0 * RATE)
	var ph := 0.0
	for i in cnt:
		var t := float(i) / RATE
		ph += f / RATE
		var s := sin(TAU * ph) + 0.25 * sin(TAU * ph * 2.0) + 0.1 * sin(TAU * ph * 3.0)
		s = Dsp.drive(s * 0.7, 0.2 + punch * 0.3)
		var env := minf(1.0, t / 0.008) * (0.55 + 0.45 * exp(-t * (3.0 + 8.0 * punch))) * minf(1.0, float(cnt - i) / (0.04 * RATE))
		out[(i0 + i) % n] += s * env * vol * 0.42


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
		var y := f1.process(s) + f2.process(s) * 0.55 + f3.process(s) * 0.12
		var env := sin(PI * k)
		out[posmod(i0 + i, n)] += y * env * vol * 0.2


## Souffle : bruit filtré qui respire lentement (période de 6 s).
static func _breath(out: PackedFloat32Array, vol: float, fc: float, rng: RandomNumberGenerator) -> void:
	var svf := Dsp.Svf.new(2, fc, 0.6)
	var n := out.size()
	for pas in 2:
		for i in n:
			var s := svf.process(rng.randf_range(-1.0, 1.0))
			if pas == 1:
				var t := float(i) / RATE
				out[i] += s * vol * 0.25 * (0.5 + 0.5 * sin(TAU * t / 6.0))


## Souffle qui monte jusqu'à « at » (cymbale frottée à l'envers) : annonce le changement de moitié.
static func _swell(out: PackedFloat32Array, at: float, dur: float, vol: float, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	var cnt := int(dur * RATE)
	var i0 := int((at - dur) * RATE)
	var svf := Dsp.Svf.new(2, 1200.0, 0.3)
	for i in cnt:
		var k := float(i) / cnt
		if i % 64 == 0:
			svf.set_params(700.0 + 1600.0 * k, 0.3)
		var s := svf.process(rng.randf_range(-1.0, 1.0))
		out[posmod(i0 + i, n)] += s * k * k * vol * 0.35 * minf(1.0, float(cnt - i) / (0.02 * RATE))


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


## Grosse caisse de chaque jeu : toutes graves et rondes (taiko, tambour sur cadre, tambour de bois,
## grosse caisse d'eau, grosse caisse et gong).
static func _kick(out: PackedFloat32Array, t: float, vol: float, kit: String) -> void:
	match kit:
		"taiko":
			_hit(out, t, 0.7, 86.0, 46.0, vol, 1.0, 0.0, 400.0, null)
		"heart":
			_hit(out, t, 0.3, 66.0, 42.0, vol, 1.0, 0.0, 200.0, null)
		"wood":
			_hit(out, t, 0.3, 120.0, 92.0, vol, 1.0, 0.0, 300.0, null)
			_hit(out, t, 0.5, 60.0, 46.0, vol * 0.6, 1.0, 0.0, 300.0, null)
		"water":
			_hit(out, t, 0.4, 92.0, 46.0, vol, 1.0, 0.0, 300.0, null)
		"metal":
			_hit(out, t, 0.45, 78.0, 44.0, vol, 1.0, 0.0, 300.0, null)
		_:
			_hit(out, t, 0.4, 96.0, 46.0, vol, 1.0, 0.0, 300.0, null)


## Frappe du milieu : peau claquée, bois, petit gong ou goutte ; jamais de caisse claire stridente.
static func _snare(out: PackedFloat32Array, t: float, vol: float, kit: String, rng: RandomNumberGenerator) -> void:
	match kit:
		"taiko":
			_hit(out, t, 0.18, 260.0, 210.0, vol * 0.9, 0.7, 0.7, 1200.0, rng)
		"wood":
			_hit(out, t, 0.09, 560.0, 540.0, vol * 0.8, 0.8, 0.15, 1200.0, rng)
			_hit(out, t, 0.07, 880.0, 860.0, vol * 0.3, 0.4, 0.0, 1200.0, null)
		"metal":
			_hit(out, t, 0.45, 310.0, 305.0, vol * 0.7, 0.6, 0.3, 1400.0, rng, true)
		"water":
			_hit(out, t, 0.11, 300.0, 620.0, vol * 0.8, 0.8, 0.25, 1200.0, rng)
		_:
			_hit(out, t, 0.2, 190.0, 160.0, vol, 0.55, 0.9, 1300.0, rng)


## Petite frappe rapide : hochet de graines (bruit étroit et feutré) ; petite cymbale à doigt pour « metal ».
static func _hat(out: PackedFloat32Array, t: float, vol: float, kit: String, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	if kit == "metal":
		_hit(out, t, 0.18, 1850.0, 1840.0, vol * 0.35, 0.5, 0.0, 3000.0, null, true)
		return
	var cnt := int(0.08 * RATE)
	var i0 := int(t * RATE)
	if i0 < 0:
		i0 += n
	var svf := Dsp.Svf.new(2, 2600.0 if kit != "wood" else 1900.0, 0.35)
	for i in cnt:
		var tt := float(i) / RATE
		var env := minf(1.0, tt / 0.008) * exp(-tt * 45.0)
		out[(i0 + i) % n] += svf.process(rng.randf_range(-1.0, 1.0)) * env * vol * 0.45


static func _tom(out: PackedFloat32Array, t: float, vol: float, f: float) -> void:
	_hit(out, t, 0.45, f * 1.35, f, vol, 1.0, 0.0, 300.0, null)


# --- Ambiances ---------------------------------------------------------------------------------------------

## Nappe d'ambiance d'une région (state : "dead" ou "alive"), boucle de 12 s sans couture (BED_LOOP).
## bed : data/audio.json › regions › <id> › bed ({"seed", "dead": {...}, "alive": {...}}).
static func render_bed(state: String, bed := {}) -> PackedFloat32Array:
	var st := bed_section(bed, state)
	var out := _blank(BED_LOOP)
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
				amp = 0.6 + 0.2 * sin(TAU * t * 7.0 / BED_LOOP) + 0.15 * sin(TAU * t * 23.0 / BED_LOOP + 1.0) + 0.1 * sin(TAU * t * 61.0 / BED_LOOP + 2.0)
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
		var count := int(round(float(ev.get("rate", 0.2)) * BED_LOOP))
		for e in count:
			_event(out, kind, rng.randf() * BED_LOOP, float(ev.get("vol", 0.3)), rng)
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


## Cloche en synthèse FM (rapport inharmonique, indice qui décroît) : carillons des ambiances.
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
