## Gamme de la zone, et accord des bruitages sur elle : aucun son du jeu ne sonne faux sur la musique.
##
## Chaque région joue dans une gamme (data/audio.json › regions › <id> › music › « mode », sur la tonique
## « key », en demi-tons depuis le ré) et enchaîne huit accords de 3 s (« roots », « roots_b », « qualities »).
## Un morceau de boss fait à la main déclare sa gamme dans regions › <id> › « hand_track » (« tonique », « mode »).
##
## Les bruitages sont rendus une fois pour toutes à des hauteurs fixes (synth.gd, souvent en ré). Au moment de
## jouer un son qui a des notes (pizz, marimba, cloche, violoncelle… : notes_of), Sfx demande ici de combien de
## demi-tons le transposer : la transposition la plus petite dont toutes les notes tombent dans la gamme de la
## zone où se trouve le héros, de préférence sur l'accord qui sonne à cet instant, sans note à un demi-ton d'une
## note de l'accord. Les sons sans notes (bruits, peaux, glissés) ne bougent pas.
##
## Logique pure (aucun nœud) : lue par sfx.gd et music.gd, vérifiée par tests/harmony_test.gd ;
## tools/gammes.sh imprime l'inventaire (quels sons ont des notes, gamme de chaque région, transpositions).
extends RefCounted

const Synth = preload("res://scripts/synth.gd")
const MusicSynth = preload("res://scripts/music_synth.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")

## Modes reconnus : degrés en demi-tons depuis la tonique (music_synth.gd › SCALES).
const MODES := MusicSynth.SCALES
## Noms des toniques (classe de hauteur, do = 0).
const NAMES := RegionAudio.HAND_TONICS
## La musique part du ré (synth_dsp.gd › hz : 73,416 Hz).
const D := 2
## Couches qui ont des notes (les « drum » sont des peaux qui glissent : pas de note).
const TONAL_INSTS := ["mallet", "pluck", "tone", "choir", "bow"]
## Un oscillateur est une note s'il tient sa hauteur (glissé de moins de ce rapport) assez longtemps.
const STEADY := 0.03
const MIN_DUR := 0.06
## Décalage de hauteur des variantes rendues (synth.gd › render) : compensé au moment de jouer.
const VARIANT_PITCH := [0.0, -0.045, 0.05, -0.02, 0.025]
## Transpositions essayées (demi-tons) autour de la hauteur demandée, et prix d'un demi-ton de transposition
## (un son trop transposé change de durée et de timbre).
const SHIFT_RANGE := [-5, 6]
const SHIFT_COST := 0.09
## Prix d'une note : sur l'accord 0 ; dans la gamme 0,3 (1 si elle frotte à un demi-ton d'une note de
## l.accord) ; hors de la gamme 4 (et best_shift écarte d'abord les notes fausses).
const COST_SCALE := 0.3
const COST_RUB := 1.0
const COST_OUT := 4.0

static var _notes_cache := {}
static var _region_cache := {}


# --- Notes d'un bruitage ------------------------------------------------------------------------------

## Notes d'un son de synth.gd : [[hauteur MIDI (réelle), poids], …], vide pour un son sans note.
static func notes_of(name: String) -> Array:
	if _notes_cache.has(name):
		return _notes_cache[name]
	var out: Array = []
	var def: Dictionary = Synth.SOUNDS.get(name, {})
	if def.get("harmony", true) != false:
		for l in def.get("layers", [def]):
			out.append_array(_layer_notes(l))
	_notes_cache[name] = out
	return out


static func is_tonal(name: String) -> bool:
	return not notes_of(name).is_empty()


static func _layer_notes(l: Dictionary) -> Array:
	var out: Array = []
	var vol := float(l.get("vol", 1.0))
	var notes: Array = l.get("notes", [0])
	if l.has("inst"):
		if not str(l["inst"]) in TONAL_INSTS:
			return out
		var f0 := float(l.get("f0", 220.0))
		for n in notes:
			out.append([midi(f0) + float(n), vol / sqrt(float(notes.size()))])
		return out
	var wave = l.get("wave", Synth.SINE)
	if not wave is int or wave == Synth.NOISE or wave == Synth.METAL:
		return out
	var f0 := float(l.get("f0", 440.0))
	var f1 := float(l.get("f1", f0))
	if absf(log(f1 / f0)) > STEADY or float(l.get("dur", 0.0)) < MIN_DUR:
		return out
	var steps: Array = l.get("arp", [0])
	for s in steps:
		out.append([midi(f0) + float(s), vol / sqrt(float(steps.size()))])
		if l.has("voice2"):
			out.append([midi(f0) + float(s) + float(l["voice2"]), vol * 0.6 / sqrt(float(steps.size()))])
	return out


static func midi(hz: float) -> float:
	return 69.0 + 12.0 * log(hz / 440.0) / log(2.0)


## Écart (demi-tons) entre la note la plus forte d'un son et la note tempérée la plus proche.
static func detune_of(notes: Array) -> float:
	var best := -1.0
	var dev := 0.0
	for n in notes:
		if float(n[1]) > best:
			best = float(n[1])
			dev = float(n[0]) - roundf(float(n[0]))
	return dev


# --- Gamme et accords d'une zone ----------------------------------------------------------------------

## Classes de hauteur d'un mode sur une tonique.
static func scale_of(tonic: int, mode: String) -> Array:
	var out: Array = []
	for d in MODES.get(mode, MODES["eolien"]):
		out.append(posmod(tonic + int(d), 12))
	return out


## Harmonie d'une région ("" : le monde, Ronce) : {"tonic", "mode", "scale", "chords" (8 accords de 3 s, en
## classes de hauteur : fondamentale, tierce, quinte, septième)}.
static func region(id: String) -> Dictionary:
	if _region_cache.has(id):
		return _region_cache[id]
	var style := {} if id == "" else RegionAudio.music_style(id)
	var key := int(style.get("key", MusicSynth.DEFAULTS["key"]))
	var mode := str(style.get("mode", MusicSynth.DEFAULTS["mode"]))
	var tonic := posmod(D + key, 12)
	var roots := MusicSynth.progression(style)
	var quals := MusicSynth.qualities(style)
	var chords: Array = []
	for c in roots.size():
		var r := posmod(D + int(roots[c]), 12)
		var ch := [r]
		for iv in MusicSynth.QUALITIES.get(str(quals[c]), [3, 7, 10]):
			ch.append(posmod(r + int(iv), 12))
		chords.append(ch)
	var h := {"tonic": tonic, "mode": mode, "scale": scale_of(tonic, mode), "chords": chords}
	_region_cache[id] = h
	return h


## Gamme d'un morceau de boss fait à la main (regions › <id> › hand_track), {} s'il n'en déclare pas.
static func hand_track(id: String) -> Dictionary:
	var ht = RegionAudio.of(id).get("hand_track", {})
	if not ht is Dictionary or not str(ht.get("tonique", "")) in NAMES:
		return {}
	var tonic: int = NAMES.find(str(ht["tonique"]))
	var mode := str(ht.get("mode", "eolien"))
	return {"tonic": tonic, "mode": mode, "scale": scale_of(tonic, mode), "chords": []}


## Ce qui sonne à un instant : la gamme et l'accord (vide : la gamme seule).
static func context(h: Dictionary, clock := 0.0) -> Dictionary:
	var chords: Array = h.get("chords", [])
	var chord: Array = []
	if not chords.is_empty():
		chord = chords[int(floorf(clock / MusicSynth.CHORD_TIME)) % chords.size()]
	return {"scale": h.get("scale", MODES["eolien"]), "chord": chord}


static func clear_cache() -> void:
	_notes_cache.clear()
	_region_cache.clear()


# --- Accord d'un son sur la zone ---------------------------------------------------------------------

## Prix d'une classe de hauteur sur ce qui sonne.
static func note_cost(pc: int, ctx: Dictionary) -> float:
	var chord: Array = ctx.get("chord", [])
	if pc in chord:
		return 0.0
	var rub := false
	for c in chord:
		if posmod(pc - int(c), 12) in [1, 11]:
			rub = true
	if pc in ctx.get("scale", []):
		return COST_RUB if rub else COST_SCALE
	return COST_OUT + (COST_RUB if rub else 0.0)


## Prix (moyen, pondéré) des notes transposées de « shift » demi-tons.
static func cost(notes: Array, shift: int, ctx: Dictionary) -> float:
	var total := 0.0
	var w := 0.0
	for n in notes:
		total += float(n[1]) * note_cost(posmod(int(roundf(float(n[0]))) + shift, 12), ctx)
		w += float(n[1])
	return total / maxf(w, 0.0001)


## Notes fausses (ni dans la gamme, ni dans l'accord) une fois transposées de « shift ».
static func _wrong(notes: Array, shift: int, ctx: Dictionary) -> int:
	var k := 0
	for n in notes:
		var pc := posmod(int(roundf(float(n[0]))) + shift, 12)
		if not pc in ctx.get("scale", []) and not pc in ctx.get("chord", []):
			k += 1
	return k


## Notes hors de la gamme une fois transposées de « shift ».
static func out_of_scale(notes: Array, shift: int, scale: Array) -> int:
	var k := 0
	for n in notes:
		if not posmod(int(roundf(float(n[0]))) + shift, 12) in scale:
			k += 1
	return k


## Transposition (demi-tons entiers) qui accorde ces notes sur ce qui sonne, au plus près de « wanted »
## (hauteur demandée par le jeu, ex. ramassages qui montent).
static func best_shift(notes: Array, ctx: Dictionary, wanted := 0.0) -> int:
	var base := int(roundf(wanted))
	var best := base
	var best_cost := INF
	for s in range(base + SHIFT_RANGE[0], base + SHIFT_RANGE[1] + 1):
		# D'abord le moins de notes fausses (hors de la gamme et de l'accord), puis le prix.
		var c := 100.0 * _wrong(notes, s, ctx) + cost(notes, s, ctx) + SHIFT_COST * absf(float(s) - wanted)
		if c < best_cost - 0.0001:
			best_cost = c
			best = s
	return best


## Transpositions qui gardent un son juste, pour varier un son répété (sfx.gd) : la meilleure (best_shift)
## d'abord, puis, à au plus VARY_RANGE demi-tons d'elle, celles dont toutes les notes tombent sur l'accord qui
## sonne (comme best_shift, une note de l'accord compte juste), puis celles dont toutes les notes sont dans la
## gamme sans frotter à un demi-ton de l'accord ; les plus
## proches d'abord dans chaque groupe, au plus VARY_COUNT en tout. Un son répété en rafale « marche » ainsi sur
## les notes justes au lieu de rejouer la même note.
const VARY_RANGE := 5
const VARY_COUNT := 3

static func shifts_in_key(notes: Array, ctx: Dictionary, wanted := 0.0) -> Array:
	var best := best_shift(notes, ctx, wanted)
	var on_chord: Array = []
	var in_scale: Array = []
	for d in range(-VARY_RANGE, VARY_RANGE + 1):
		var s := best + d
		if d == 0 or _wrong(notes, s, ctx) > 0:
			continue
		var worst := 0.0
		for n in notes:
			worst = maxf(worst, note_cost(posmod(int(roundf(float(n[0]))) + s, 12), ctx))
		if worst <= 0.0001 and not ctx.get("chord", []).is_empty():
			on_chord.append(s)
		elif worst <= COST_SCALE + 0.0001:
			in_scale.append(s)
	var closer := func(a, b): return absi(a - best) < absi(b - best) or (absi(a - best) == absi(b - best) and a > b)
	on_chord.sort_custom(closer)
	in_scale.sort_custom(closer)
	return ([best] + on_chord + in_scale).slice(0, VARY_COUNT)


## Facteur de vitesse (pitch_scale) qui joue la variante « variant » du son « name » dans la gamme de ce qui
## sonne : transposition, plus le retour sur la note tempérée et l'annulation du décalage de la variante.
## pitch : hauteur demandée par le jeu (1 = normale). Un son sans note garde « pitch ».
## step : rang dans une rafale du même son (0 : la meilleure note ; 1, 2… : les autres notes de shifts_in_key).
static func pitch_for(name: String, ctx: Dictionary, variant := 0, pitch := 1.0, step := 0) -> float:
	var notes := notes_of(name)
	if notes.is_empty():
		return pitch
	var wanted := 12.0 * log(maxf(pitch, 0.01)) / log(2.0)
	var vp := 1.0 + float(VARIANT_PITCH[variant % VARIANT_PITCH.size()])
	var shift := best_shift(notes, ctx, wanted)
	if step > 0:
		var all := shifts_in_key(notes, ctx, wanted)
		shift = all[step % all.size()]
	return pow(2.0, (float(shift) - detune_of(notes)) / 12.0) / vp


static func pc_name(pc: int) -> String:
	return NAMES[posmod(pc, 12)]
