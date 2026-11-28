## Synthèse sonore par le code : bruitages (ici) et musique (music_synth.gd, appelée par les fonctions
## music_* plus bas). tools/gen-sounds.sh enregistre le résultat en .wav dans res://assets/.
## Tout est calculé à partir de formules : aucun échantillon externe, donc aucune licence.
##
## Un bruitage est une superposition de couches (« layers »), chacune un oscillateur ou un bruit
## avec son enveloppe, sa courbe de hauteur et son filtre ; puis une petite réverbération (« verb »)
## et une mise à niveau (« peak », la crête visée, qui fixe le volume relatif des sons entre eux).
##
## Couche : wave (SINE, SQUARE, SAW, TRI, NOISE, METAL), f0 → f1 (Hz, glissé exponentiel ; « glide »:
## "lin" pour un glissé linéaire), dur, att (s), decay (raideur de l'extinction, 1,6 par défaut),
## delay (départ retardé, s), vol, duty (carré), vib [profondeur, Hz], trem [profondeur, Hz],
## arp (marches en demi-tons), voice2 (seconde voix, en demi-tons), fm [rapport, indice] (sinus modulé),
## filter "lp" / "hp" / "bp" avec cut (Hz, ou [départ, arrivée]) et res (0 à 0,95), drive (saturation),
## crush (bruit tenu à cette cadence, Hz : grain), click (craquement d'attaque).
## Couche « inst » : un instrument de la musique (mallet + kind, pluck + tone/damp, tone + tone, choir + vowel,
## bow, drum + f1/noise/cut) sur f0 et les « notes » (demi-tons), espacées de « step » (s) ; « grain » : wave
## "grain", nuée de grains de bruit filtré (density, grain, cut, res, pitch_spread). Les compétences s'en servent
## pour que chaque branche sonne avec les instruments de sa région.
## Son : layers, verb (part de réverbération), room (taille de la pièce, 0,3 à 1), peak,
## variants (nombre de variantes : fichiers <nom>.wav, <nom>__2.wav…), duck (baisse brève de la musique, 0 à 1).
extends RefCounted

const Dsp = preload("res://scripts/synth_dsp.gd")
const MusicSynth = preload("res://scripts/music_synth.gd")

const RATE := Dsp.RATE
const SINE := Dsp.SINE
const SQUARE := Dsp.SQUARE
const SAW := Dsp.SAW
const NOISE := Dsp.NOISE
const TRI := Dsp.TRI
const METAL := Dsp.METAL

## Version des formules : à changer quand le rendu change, pour que sound_test repère les fichiers périmés.
const VERSION := 3

const SOUNDS := {
	# --- Combat : coups, critiques, morts ------------------------------------------------------------------
	# Tir de base : un « tock » de bois et un souffle bref.
	"tir": {"peak": 0.34, "verb": 0.06, "room": 0.3, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "bp", "cut": [1800.0, 800.0], "vol": 0.6, "res": 0.45, "decay": 2.2},
		{"inst": "drum", "f0": 260.0, "f1": 140.0, "dur": 0.07, "vol": 0.36, "noise": 0.3, "cut": 1500.0}]},
	# Un coup (Ronce et l'oasis) : un claquement de bois, des échardes et un coup sourd.
	# Chaque région a sa version (impact@spore…).
	"impact": {"peak": 0.6, "verb": 0.08, "room": 0.35, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "bp", "cut": [1900.0, 650.0], "vol": 0.8, "res": 0.4, "decay": 2.4},
		{"wave": "grain", "dur": 0.05, "att": 0.001, "density": 700.0, "grain": 0.003, "cut": 1500.0, "res": 0.4, "vol": 0.5, "decay": 2.5},
		{"inst": "drum", "f0": 170.0, "f1": 70.0, "dur": 0.12, "vol": 0.54, "noise": 0.3, "cut": 1100.0}]},
	# Coup lourd : une grosse caisse de bois, la terre qui tremble, des graviers.
	"impact_lourd": {"peak": 0.8, "verb": 0.16, "room": 0.5, "duck": 0.15, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1600.0, 220.0], "vol": 0.7, "res": 0.3, "decay": 2.0},
		{"inst": "drum", "f0": 120.0, "f1": 40.0, "dur": 0.36, "vol": 0.6, "noise": 0.5, "cut": 700.0},
		{"wave": SINE, "f0": 58.0, "f1": 48.0, "dur": 0.32, "att": 0.01, "vol": 0.5, "decay": 1.3},
		{"wave": "grain", "dur": 0.25, "att": 0.01, "density": 120.0, "grain": 0.008, "cut": [1200.0, 500.0], "res": 0.4, "vol": 0.35, "decay": 2.0}]},
	# Critique : le coup, plus fort, et un accord de pizz (ré, la) qui sonne la réussite.
	"critique": {"peak": 0.75, "verb": 0.22, "room": 0.45, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.07, "att": 0.002, "filter": "bp", "cut": [2400.0, 900.0], "vol": 0.8, "res": 0.5, "decay": 2.2},
		{"inst": "drum", "f0": 200.0, "f1": 70.0, "dur": 0.14, "vol": 0.54, "noise": 0.3, "cut": 1300.0},
		{"inst": "pluck", "f0": 146.8, "notes": [0, 7, 12], "step": 0.0, "dur": 0.5, "tone": 0.6, "vol": 0.6},
		{"inst": "mallet", "kind": "marimba", "f0": 293.7, "notes": [0, 7], "step": 0.03, "dur": 0.5, "vol": 0.3}]},
	# Un ennemi flétri s'effrite : il craque, tombe en miettes, une note de pizz qui retombe.
	"mort": {"peak": 0.62, "verb": 0.18, "room": 0.45, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.25, "att": 0.002, "filter": "bp", "cut": [1400.0, 260.0], "vol": 0.7, "res": 0.35, "decay": 1.8},
		{"wave": "grain", "dur": 0.35, "att": 0.005, "density": 160.0, "grain": 0.01, "cut": [900.0, 300.0], "res": 0.5, "vol": 0.55},
		{"inst": "drum", "f0": 140.0, "f1": 45.0, "dur": 0.25, "vol": 0.42, "noise": 0.2, "cut": 800.0},
		{"inst": "pluck", "f0": 73.4, "notes": [5, 0], "step": 0.06, "dur": 0.4, "tone": 0.3, "vol": 0.4}]},
	# Une élite tombe : grosse caisse, accord mineur des cordes, cloche grave, éboulis.
	"mort_elite": {"peak": 0.85, "verb": 0.34, "room": 0.7, "duck": 0.3, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 32.0, "dur": 0.7, "vol": 0.6, "noise": 0.4, "cut": 500.0},
		{"wave": NOISE, "dur": 0.55, "att": 0.002, "filter": "lp", "cut": [2000.0, 160.0], "vol": 0.6, "res": 0.3, "decay": 1.6},
		{"inst": "bow", "f0": 73.4, "notes": [0, 3, 7], "dur": 0.8, "att": 0.02, "cut": 900.0, "vol": 0.4},
		{"inst": "mallet", "kind": "bell", "f0": 146.8, "notes": [0], "step": 0.0, "dur": 1.2, "vol": 0.35},
		{"wave": "grain", "dur": 0.6, "att": 0.01, "density": 90.0, "grain": 0.012, "cut": [1000.0, 300.0], "res": 0.5, "vol": 0.35}]},
	# Le héros est touché : un choc sourd et une seconde mineure de pizz, qui grince.
	"degats": {"peak": 0.7, "verb": 0.1, "room": 0.35, "layers": [
		{"wave": NOISE, "dur": 0.05, "att": 0.002, "filter": "bp", "cut": [1500.0, 500.0], "vol": 0.6, "res": 0.4},
		{"inst": "drum", "f0": 160.0, "f1": 55.0, "dur": 0.22, "vol": 0.54, "noise": 0.2, "cut": 900.0},
		{"inst": "pluck", "f0": 146.8, "notes": [0, 1], "step": 0.0, "dur": 0.3, "tone": 0.5, "vol": 0.45}]},
	# Étourdi : un coup sourd et des étoiles de kalimba qui tournent (tierce mineure).
	"etourdi": {"peak": 0.5, "verb": 0.25, "room": 0.4, "layers": [
		{"inst": "drum", "f0": 90.0, "f1": 60.0, "dur": 0.2, "vol": 0.42},
		{"inst": "mallet", "kind": "kalimba", "f0": 587.3, "notes": [0, 3, 0, 3], "step": 0.09, "dur": 0.35, "vol": 0.35}]},
	# Le héros tombe : les violoncelles descendent, une cloche grave, un souffle qui s'éteint.
	"chute": {"peak": 0.6, "verb": 0.5, "room": 0.85, "duck": 0.5, "layers": [
		{"inst": "tone", "tone": "cello", "f0": 146.8, "notes": [7, 3, 0, -5], "step": 0.3, "dur": 0.6, "vol": 0.45},
		{"inst": "bow", "f0": 73.4, "notes": [0, 3, 7], "dur": 1.4, "att": 0.1, "cut": 700.0, "vol": 0.3},
		{"wave": NOISE, "dur": 1.2, "att": 0.3, "filter": "bp", "cut": [900.0, 250.0], "vol": 0.25, "res": 0.5},
		{"inst": "mallet", "kind": "bell", "f0": 73.4, "notes": [0], "step": 0.0, "dur": 1.5, "vol": 0.35},
		{"wave": SINE, "f0": 60.0, "f1": 38.0, "dur": 1.0, "att": 0.005, "vol": 0.5}]},
	# Esquive : un souffle bref qui passe, quelques feuilles.
	"esquive": {"peak": 0.42, "verb": 0.08, "room": 0.3, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.05, "filter": "bp", "cut": [500.0, 1400.0], "vol": 0.9, "res": 0.5, "decay": 1.2},
		{"wave": "grain", "dur": 0.12, "att": 0.01, "density": 60.0, "grain": 0.012, "cut": 1200.0, "res": 0.3, "vol": 0.3, "delay": 0.04}]},
	# Couronne d'épines : une couronne d'épines qui jaillit en cercle (crépitement d'épines qui s'ouvre), un
	# coup de violoncelles graves et un pizz de contrebasse.
	"nova": {"peak": 0.8, "verb": 0.35, "room": 0.6, "duck": 0.15, "layers": [
		{"wave": NOISE, "dur": 0.05, "att": 0.002, "filter": "lp", "cut": 1400.0, "vol": 0.6},
		{"inst": "drum", "f0": 110.0, "f1": 48.0, "dur": 0.5, "vol": 0.8},
		{"wave": "grain", "dur": 0.55, "att": 0.02, "density": 220.0, "grain": 0.008, "cut": [900.0, 2600.0], "res": 0.55, "vol": 0.55, "decay": 2.0},
		{"inst": "bow", "f0": 73.4, "notes": [0, 7, 12, 15], "dur": 0.6, "att": 0.04, "cut": 900.0, "vol": 0.45},
		{"inst": "pluck", "f0": 73.4, "notes": [0, 12], "step": 0.0, "dur": 0.9, "tone": 0.3, "vol": 0.6}]},
	# Nuage (attaque de Spore) : un pouf mou, des bulles, deux notes de marimba (fa#, sol).
	"nuage": {"peak": 0.45, "verb": 0.3, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.5, "att": 0.05, "filter": "lp", "cut": [700.0, 250.0], "vol": 0.6, "decay": 1.4},
		{"wave": "grain", "dur": 0.5, "att": 0.01, "density": 20.0, "grain": 0.04, "cut": [350.0, 600.0], "res": 0.85, "vol": 0.45},
		{"inst": "mallet", "kind": "marimba", "f0": 185.0, "notes": [0, 1], "step": 0.08, "dur": 0.4, "vol": 0.3}]},
	# Floraison : la fleur s'ouvre en arpège de kalimba, un souffle de chœur et un froissement de pétales.
	"floraison": {"peak": 0.5, "verb": 0.5, "room": 0.7, "layers": [
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 4, 7, 11, 14], "step": 0.07, "dur": 1.1, "vol": 0.55},
		{"inst": "choir", "vowel": "a", "f0": 155.6, "notes": [0, 7], "dur": 1.1, "vol": 0.35},
		{"wave": "grain", "dur": 0.7, "att": 0.15, "density": 90.0, "grain": 0.02, "cut": [700.0, 1800.0], "res": 0.3, "vol": 0.25}]},
	# Fouet de ronce : la tige fend l'air (souffle qui monte) puis claque sec au bout, avec un pizz grave.
	"fouet": {"peak": 0.62, "verb": 0.12, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.3, "att": 0.2, "filter": "bp", "cut": [350.0, 2400.0], "res": 0.55, "vol": 0.7, "decay": 3.0},
		{"wave": "grain", "dur": 0.05, "delay": 0.28, "att": 0.001, "density": 900.0, "grain": 0.004, "cut": 2200.0, "res": 0.4, "vol": 1.0, "decay": 2.5},
		{"inst": "drum", "f0": 180.0, "f1": 90.0, "dur": 0.12, "delay": 0.28, "noise": 0.4, "cut": 1500.0, "vol": 0.55},
		{"inst": "pluck", "f0": 73.4, "dur": 0.5, "delay": 0.28, "tone": 0.5, "vol": 0.5}]},
	# Racines voraces : la terre gronde, le bois craque en remontant, des racines grincent.
	"racines": {"peak": 0.66, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.6, "att": 0.05, "filter": "lp", "cut": [180.0, 420.0], "vol": 0.9, "decay": 1.4},
		{"inst": "drum", "f0": 70.0, "f1": 40.0, "dur": 0.5, "vol": 0.7},
		{"wave": "grain", "dur": 0.55, "delay": 0.05, "att": 0.1, "density": 70.0, "grain": 0.03, "cut": [300.0, 900.0], "res": 0.75, "vol": 0.55},
		{"inst": "pluck", "f0": 73.4, "notes": [7, 3, 0], "step": 0.08, "dur": 0.5, "tone": 0.2, "vol": 0.45}]},
	# Volée d'épines : une salve d'épines qui sifflent en partant, l'arc de ronce qui vibre.
	"volee": {"peak": 0.5, "verb": 0.1, "room": 0.35, "layers": [
		{"inst": "pluck", "f0": 110.0, "dur": 0.4, "tone": 0.45, "damp": 0.48, "vol": 0.55},
		{"wave": SINE, "f0": 1500.0, "f1": 700.0, "dur": 0.11, "att": 0.005, "vol": 0.25},
		{"wave": SINE, "f0": 1350.0, "f1": 620.0, "dur": 0.11, "att": 0.005, "delay": 0.04, "vol": 0.22},
		{"wave": SINE, "f0": 1650.0, "f1": 760.0, "dur": 0.11, "att": 0.005, "delay": 0.08, "vol": 0.2},
		{"wave": NOISE, "dur": 0.22, "att": 0.01, "filter": "bp", "cut": [2200.0, 900.0], "res": 0.5, "vol": 0.45, "trem": [0.6, 26.0]}]},
	# Saignée : un violoncelle qui gémit au demi-ton, un battement sourd, la sève aspirée.
	"saignee": {"peak": 0.66, "verb": 0.22, "room": 0.5, "layers": [
		{"inst": "tone", "tone": "cello", "f0": 146.8, "notes": [1, 0], "step": 0.25, "dur": 0.45, "vol": 0.5},
		{"inst": "drum", "f0": 66.0, "f1": 42.0, "dur": 0.3, "vol": 0.7},
		{"inst": "drum", "f0": 66.0, "f1": 42.0, "dur": 0.3, "delay": 0.18, "vol": 0.45},
		{"wave": NOISE, "dur": 0.6, "att": 0.25, "filter": "bp", "cut": [1400.0, 300.0], "res": 0.6, "vol": 0.5, "decay": 1.2}]},
	# --- Annonces : un coup va partir (boss, élites) --------------------------------------------------------
	# Grave pour tous les boss (choix d'Antoine à l'écoute, 25/11 : l'ancienne « annonce_boss » sert partout).
	"annonce": {"peak": 0.72, "verb": 0.35, "room": 0.75, "layers": [
		{"wave": METAL, "f0": 220.0, "f1": 210.0, "dur": 0.8, "att": 0.002, "vol": 0.4, "decay": 1.6},
		{"wave": SAW, "f0": 110.0, "f1": 110.0, "dur": 0.9, "att": 0.25, "filter": "lp", "cut": [300.0, 2200.0], "res": 0.45, "vol": 0.6, "voice2": 7.0, "drive": 0.3},
		{"wave": SINE, "f0": 55.0, "f1": 55.0, "dur": 0.9, "att": 0.2, "vol": 0.5},
		{"wave": NOISE, "dur": 0.8, "att": 0.6, "filter": "hp", "cut": [600.0, 5000.0], "vol": 0.25}]},
	# --- Progression, Cœurs, ramassage --------------------------------------------------------------------
	# Un nœud de l'arbre pris : marimba et pizz, une quinte qui s'ouvre.
	"noeud": {"peak": 0.45, "verb": 0.4, "room": 0.6, "layers": [
		{"inst": "mallet", "kind": "marimba", "f0": 293.7, "notes": [0, 7, 12], "step": 0.05, "dur": 0.6, "vol": 0.45},
		{"inst": "pluck", "f0": 146.8, "notes": [0], "step": 0.0, "dur": 0.5, "tone": 0.5, "vol": 0.35}]},
	# Niveau : un arpège de pizz qui monte, le cor qui répond, un souffle de chœur.
	"niveau": {"peak": 0.55, "verb": 0.45, "room": 0.7, "duck": 0.2, "layers": [
		{"inst": "pluck", "f0": 146.8, "notes": [0, 3, 7, 12, 15], "step": 0.08, "dur": 0.8, "tone": 0.6, "vol": 0.5},
		{"inst": "tone", "tone": "horn", "f0": 146.8, "notes": [0, 7], "step": 0.0, "dur": 0.9, "vol": 0.3, "delay": 0.3},
		{"inst": "choir", "vowel": "a", "f0": 146.8, "notes": [0], "step": 0.0, "dur": 1.0, "vol": 0.25, "delay": 0.2}]},
	# Un Cœur purifié (Ronce) : le chœur et les cordes passent en majeur, cloche, marimba qui s'envole.
	# Chaque région a sa version (coeur@spore…).
	"coeur": {"peak": 0.72, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"inst": "choir", "vowel": "a", "f0": 146.8, "notes": [0, 4, 7], "step": 0.0, "dur": 2.2, "vol": 0.3},
		{"inst": "bow", "f0": 73.4, "notes": [0, 7, 12, 16], "dur": 2.4, "att": 0.6, "cut": 1200.0, "vol": 0.4},
		{"inst": "mallet", "kind": "bell", "f0": 293.7, "notes": [0], "step": 0.0, "dur": 2.0, "vol": 0.35},
		{"inst": "mallet", "kind": "marimba", "f0": 293.7, "notes": [0, 4, 7, 12, 16, 19], "step": 0.12, "dur": 0.8, "vol": 0.35},
		{"wave": SINE, "f0": 73.4, "f1": 73.4, "dur": 2.2, "att": 0.05, "vol": 0.35, "decay": 1.2}]},
	# Une essence ramassée : une goutte de kalimba (la hauteur monte quand on enchaîne).
	"ramasse": {"peak": 0.24, "verb": 0.12, "room": 0.3, "layers": [
		{"inst": "mallet", "kind": "kalimba", "f0": 587.3, "notes": [0], "step": 0.0, "dur": 0.15, "vol": 0.6},
		{"wave": SINE, "f0": 587.3, "f1": 880.0, "dur": 0.05, "att": 0.002, "vol": 0.25}]},
	# Une greffe ramassée : marimba qui monte, un souffle de chœur, un froissement de feuilles.
	"greffe": {"peak": 0.52, "verb": 0.45, "room": 0.7, "layers": [
		{"inst": "mallet", "kind": "marimba", "f0": 392.0, "notes": [0, 7, 12, 16], "step": 0.07, "dur": 0.6, "vol": 0.45},
		{"inst": "choir", "vowel": "o", "f0": 196.0, "notes": [0], "step": 0.0, "dur": 0.6, "vol": 0.2},
		{"wave": "grain", "dur": 0.5, "att": 0.1, "density": 60.0, "grain": 0.02, "cut": [900.0, 1600.0], "res": 0.3, "vol": 0.2}]},
	# De la sève recueillie : quatre gouttes de kalimba et un ploc.
	"seve": {"peak": 0.45, "verb": 0.45, "room": 0.6, "layers": [
		{"inst": "mallet", "kind": "kalimba", "f0": 392.0, "notes": [0, 5, 9, 12], "step": 0.08, "dur": 0.6, "vol": 0.45},
		{"wave": SINE, "f0": 900.0, "f1": 420.0, "dur": 0.08, "att": 0.002, "vol": 0.3}]},
	# --- Interface ----------------------------------------------------------------------------------------
	# Clic : un petit bloc de bois.
	"clic": {"peak": 0.2, "layers": [
		{"wave": TRI, "f0": 700.0, "f1": 560.0, "dur": 0.04, "att": 0.001, "filter": "lp", "cut": 2400.0, "vol": 0.7},
		{"wave": NOISE, "dur": 0.012, "att": 0.0005, "filter": "bp", "cut": 1800.0, "vol": 0.3, "res": 0.4}]},
	# Survol : un effleurement.
	"survol": {"peak": 0.1, "layers": [
		{"wave": SINE, "f0": 880.0, "f1": 990.0, "dur": 0.03, "att": 0.002, "vol": 1.0}]},
	# Vesse-de-loup (éclatement) : la vesse crève (pouf mou), un nuage qui s'étale, des bulles.
	"spore_eclat": {"peak": 0.6, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.08, "att": 0.002, "filter": "lp", "cut": [1600.0, 300.0], "vol": 1.0},
		{"inst": "drum", "f0": 120.0, "f1": 60.0, "dur": 0.18, "vol": 0.6},
		{"wave": NOISE, "dur": 0.6, "att": 0.06, "delay": 0.03, "filter": "lp", "cut": [900.0, 250.0], "vol": 0.55, "decay": 1.3},
		{"wave": SINE, "f0": 260.0, "f1": 700.0, "dur": 0.06, "att": 0.004, "delay": 0.12, "vol": 0.25},
		{"wave": SINE, "f0": 220.0, "f1": 620.0, "dur": 0.06, "att": 0.004, "delay": 0.21, "vol": 0.2}]},
	# Nuage de spores : un souffle mou qui gonfle, des bulles qui montent, un marimba mouillé en écho.
	"spore_nuage": {"peak": 0.48, "verb": 0.35, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.9, "att": 0.25, "filter": "lp", "cut": [300.0, 900.0], "vol": 0.6, "decay": 1.4},
		{"wave": "grain", "dur": 0.8, "att": 0.1, "density": 25.0, "grain": 0.05, "cut": [300.0, 700.0], "res": 0.85, "vol": 0.5},
		{"inst": "mallet", "kind": "marimba", "f0": 185.0, "notes": [0, 1, 7], "step": 0.12, "dur": 0.8, "vol": 0.45}]},
	# Essaim : un bourdonnement grave d'insectes mous qui s'envolent, quelques notes de marimba.
	"spore_propage": {"peak": 0.45, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": SQUARE, "f0": 140.0, "f1": 165.0, "dur": 0.5, "att": 0.05, "duty": 0.3, "filter": "lp", "cut": 700.0, "vol": 0.4, "voice2": 0.4, "trem": [0.5, 31.0]},
		{"wave": SQUARE, "f0": 210.0, "f1": 190.0, "dur": 0.45, "att": 0.08, "delay": 0.05, "duty": 0.3, "filter": "lp", "cut": 900.0, "vol": 0.25, "trem": [0.6, 37.0]},
		{"inst": "mallet", "kind": "marimba", "f0": 370.0, "notes": [0, 3, 1], "step": 0.09, "dur": 0.5, "vol": 0.35}]},
	# Vesse-de-loup (posée) : un champignon mou qui s'enfonce dans la terre, glouglou.
	"spore_piege": {"peak": 0.5, "verb": 0.15, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.25, "att": 0.01, "filter": "bp", "cut": [700.0, 250.0], "res": 0.7, "vol": 0.6},
		{"wave": SINE, "f0": 160.0, "f1": 320.0, "dur": 0.22, "att": 0.01, "vol": 0.6, "vib": [0.08, 14.0]},
		{"wave": SINE, "f0": 240.0, "f1": 520.0, "dur": 0.07, "att": 0.004, "delay": 0.16, "vol": 0.25}]},
	# Éclosion : une poche de toxine qui fermente et éclate en bulles, marimba qui descend (phrygien).
	"spore_toxine": {"peak": 0.58, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "lp", "cut": 1200.0, "vol": 0.7},
		{"wave": "grain", "dur": 0.7, "att": 0.02, "density": 45.0, "grain": 0.04, "cut": [500.0, 250.0], "res": 0.85, "vol": 0.55},
		{"inst": "mallet", "kind": "marimba", "f0": 185.0, "notes": [7, 3, 1, 0], "step": 0.08, "dur": 0.7, "vol": 0.45},
		{"inst": "tone", "tone": "clarinet", "f0": 92.5, "dur": 0.5, "delay": 0.05, "vol": 0.25}]},
	# Flaque de spores : la boue qui clapote, un glouglou, des bulles.
	"spore_flaque": {"peak": 0.5, "verb": 0.2, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.28, "att": 0.02, "filter": "bp", "cut": [600.0, 220.0], "vol": 0.7, "res": 0.65, "trem": [0.5, 13.0]},
		{"wave": SINE, "f0": 170.0, "f1": 100.0, "dur": 0.2, "att": 0.004, "vol": 0.5, "vib": [0.08, 16.0]},
		{"wave": "grain", "dur": 0.4, "att": 0.01, "density": 25.0, "grain": 0.04, "cut": [400.0, 250.0], "res": 0.85, "vol": 0.35, "delay": 0.05}]},
	# Un champignon se divise : un pop mou et deux notes de marimba (demi-ton).
	"spore_division": {"peak": 0.45, "verb": 0.2, "room": 0.4, "layers": [
		{"wave": SINE, "f0": 200.0, "f1": 520.0, "dur": 0.07, "att": 0.004, "vol": 0.5},
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "lp", "cut": [1200.0, 300.0], "vol": 0.4},
		{"inst": "mallet", "kind": "marimba", "f0": 370.0, "notes": [0, 1], "step": 0.06, "dur": 0.35, "vol": 0.4, "delay": 0.05}]},
	# Réveil de l'Amanite-Mère : la clarinette grave en fa# phrygien, des bulles, un marimba sourd.
	"spore_boss_eveil": {"peak": 0.82, "verb": 0.5, "room": 0.85, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 92.5, "notes": [0, 1, 7], "dur": 1.2, "att": 0.5, "cut": 700.0, "vol": 0.4},
		{"inst": "tone", "tone": "clarinet", "f0": 92.5, "notes": [0, 1], "step": 0.5, "dur": 0.8, "vol": 0.4},
		{"wave": "grain", "dur": 1.2, "att": 0.3, "density": 25.0, "grain": 0.05, "cut": [300.0, 600.0], "res": 0.85, "vol": 0.4},
		{"inst": "mallet", "kind": "marimba", "f0": 185.0, "notes": [0, 1, 0], "step": 0.2, "dur": 0.5, "vol": 0.4, "delay": 0.8},
		{"inst": "drum", "f0": 70.0, "f1": 45.0, "dur": 0.6, "vol": 0.48, "delay": 1.0}]},
	# L'Amanite change de phase : bulles qui éclatent, marimba qui dégringole, tambour.
	"spore_boss_phase": {"peak": 0.8, "verb": 0.4, "room": 0.75, "duck": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.15, "att": 0.002, "filter": "lp", "cut": [1400.0, 300.0], "vol": 0.6},
		{"wave": "grain", "dur": 0.6, "att": 0.01, "density": 40.0, "grain": 0.04, "cut": [600.0, 250.0], "res": 0.85, "vol": 0.5},
		{"inst": "mallet", "kind": "marimba", "f0": 185.0, "notes": [12, 7, 1, 0], "step": 0.07, "dur": 0.5, "vol": 0.45},
		{"inst": "drum", "f0": 90.0, "f1": 35.0, "dur": 0.6, "vol": 0.54, "noise": 0.3, "cut": 600.0}]},
	# L'Amanite meurt : elle se vide en bulles, puis le marimba s'ouvre sur ré majeur (dans la gamme du marais, fa# phrygien).
	"spore_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": NOISE, "dur": 1.4, "att": 0.002, "filter": "lp", "cut": [1600.0, 120.0], "vol": 0.5, "res": 0.3},
		{"wave": "grain", "dur": 1.4, "att": 0.01, "density": 30.0, "grain": 0.05, "cut": [500.0, 250.0], "res": 0.85, "vol": 0.45},
		{"inst": "drum", "f0": 70.0, "f1": 28.0, "dur": 1.2, "vol": 0.6, "noise": 0.3, "cut": 500.0},
		{"inst": "tone", "tone": "cello", "f0": 92.5, "notes": [7, 1, 0], "step": 0.3, "dur": 0.6, "vol": 0.35},
		{"inst": "mallet", "kind": "marimba", "f0": 146.8, "notes": [0, 4, 7, 12, 16], "step": 0.12, "dur": 0.8, "vol": 0.4, "delay": 0.9},
		{"inst": "bow", "f0": 73.4, "notes": [0, 4, 7], "dur": 1.4, "att": 0.4, "cut": 1000.0, "vol": 0.3, "delay": 0.9}]},
	# --- Vent (vitesse, projectiles, mobilité) : souffles et sifflements clairs. -----------------------------
	# Lame de vent : un souffle tranchant et une corde de harpe pincée.
	"vent_lame": {"peak": 0.45, "verb": 0.1, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.13, "att": 0.03, "filter": "bp", "cut": [1000.0, 2000.0], "vol": 0.8, "res": 0.5},
		{"inst": "pluck", "f0": 392.0, "notes": [0], "step": 0.0, "dur": 0.3, "tone": 0.7, "vol": 0.35}]},
	# Rafale : deux souffles qui se croisent, un fil de flûte.
	"vent_rafale": {"peak": 0.5, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.42, "att": 0.1, "filter": "bp", "cut": [500.0, 1600.0], "vol": 0.8, "res": 0.6, "decay": 1.2},
		{"wave": NOISE, "dur": 0.3, "att": 0.1, "filter": "bp", "cut": [900.0, 2000.0], "vol": 0.35, "res": 0.6, "delay": 0.08},
		{"inst": "tone", "tone": "flute", "f0": 392.0, "notes": [0], "step": 0.0, "dur": 0.25, "vol": 0.15, "delay": 0.05}]},
	# Tornade : un tourbillon (souffle qui tourne), la flûte qui monte et retombe, des herbes arrachées.
	"vent_tornade": {"peak": 0.6, "verb": 0.3, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 1.0, "att": 0.3, "filter": "bp", "cut": [400.0, 1400.0], "res": 0.65, "vol": 0.8, "trem": [0.55, 7.0], "decay": 1.3},
		{"wave": NOISE, "dur": 0.9, "att": 0.25, "delay": 0.05, "filter": "lp", "cut": 500.0, "vol": 0.5, "trem": [0.4, 5.0]},
		{"inst": "tone", "tone": "flute", "f0": 392.0, "notes": [0, 5, 10, 7], "step": 0.12, "dur": 0.25, "vol": 0.3},
		{"wave": "grain", "dur": 0.7, "delay": 0.15, "att": 0.1, "density": 80.0, "grain": 0.015, "cut": [1200.0, 2400.0], "res": 0.35, "vol": 0.3}]},
	# Ruée : le héros fend l'air (souffle qui passe), un battement de plumes.
	"vent_ruee": {"peak": 0.6, "verb": 0.12, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.32, "att": 0.08, "filter": "bp", "cut": [500.0, 2200.0], "res": 0.5, "vol": 0.9, "decay": 2.0},
		{"wave": NOISE, "dur": 0.3, "att": 0.03, "filter": "lp", "cut": [900.0, 300.0], "vol": 0.5},
		{"wave": "grain", "dur": 0.25, "delay": 0.04, "att": 0.02, "density": 120.0, "grain": 0.01, "cut": 1600.0, "res": 0.3, "vol": 0.45, "decay": 2.0},
		{"inst": "pluck", "f0": 196.0, "notes": [0, 7], "step": 0.05, "dur": 0.4, "tone": 0.4, "vol": 0.25}]},
	# Appel d'air : l'air est aspiré vers le héros (souffle qui gonfle à l'envers), la flûte souffle une quinte.
	"vent_appel": {"peak": 0.55, "verb": 0.3, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.75, "att": 0.6, "filter": "bp", "cut": [2000.0, 450.0], "res": 0.6, "vol": 0.9, "decay": 4.0},
		{"wave": NOISE, "dur": 0.7, "att": 0.55, "filter": "lp", "cut": 400.0, "vol": 0.5, "decay": 4.0},
		{"inst": "tone", "tone": "flute", "f0": 293.7, "notes": [0, 7], "step": 0.0, "dur": 0.6, "vol": 0.25},
		{"inst": "drum", "f0": 90.0, "f1": 50.0, "dur": 0.3, "delay": 0.68, "vol": 0.5}]},
	# Plongeon : le souffle qui tombe en piqué, l'impact, la harpe qui retombe.
	"vent_plongeon": {"peak": 0.55, "verb": 0.15, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.28, "att": 0.15, "filter": "bp", "cut": [2200.0, 500.0], "vol": 0.8, "res": 0.6, "decay": 0.9},
		{"inst": "drum", "f0": 110.0, "f1": 45.0, "dur": 0.18, "vol": 0.48, "noise": 0.3, "cut": 900.0, "delay": 0.24},
		{"inst": "pluck", "f0": 196.0, "notes": [7, 0], "step": 0.05, "dur": 0.35, "tone": 0.7, "vol": 0.3, "delay": 0.24}]},
	# Repousse : une bourrasque qui part du héros, un coup, la flûte en quinte.
	"vent_repousse": {"peak": 0.6, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.32, "att": 0.002, "filter": "lp", "cut": [1800.0, 400.0], "vol": 0.8},
		{"inst": "drum", "f0": 110.0, "f1": 40.0, "dur": 0.28, "vol": 0.54, "noise": 0.3, "cut": 800.0},
		{"wave": NOISE, "dur": 0.3, "att": 0.05, "filter": "bp", "cut": [800.0, 1800.0], "vol": 0.35, "res": 0.6},
		{"inst": "tone", "tone": "flute", "f0": 293.7, "notes": [0, 7], "step": 0.0, "dur": 0.3, "vol": 0.2}]},
	# Réveil du Harfang : une bourrasque qui enfle, la flûte qui appelle en sol, la harpe qui s'envole.
	"vent_boss_eveil": {"peak": 0.82, "verb": 0.5, "room": 0.9, "duck": 0.6, "layers": [
		{"wave": NOISE, "dur": 1.3, "att": 0.55, "filter": "bp", "cut": [400.0, 1800.0], "vol": 0.7, "res": 0.65, "trem": [0.3, 4.0]},
		{"inst": "tone", "tone": "flute", "f0": 392.0, "notes": [0, 5, 10], "step": 0.3, "dur": 0.5, "vol": 0.3},
		{"inst": "pluck", "f0": 196.0, "notes": [0, 7, 12, 17, 19], "step": 0.07, "dur": 0.6, "tone": 0.7, "vol": 0.45, "delay": 1.0},
		{"inst": "drum", "f0": 65.0, "f1": 40.0, "dur": 0.6, "vol": 0.48, "delay": 1.0},
		{"wave": SINE, "f0": 49.0, "f1": 49.0, "dur": 1.2, "att": 0.4, "vol": 0.4}]},
	# Le Harfang change de phase : une rafale en piqué, la harpe qui dégringole, un tambour.
	"vent_boss_phase": {"peak": 0.8, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.85, "att": 0.02, "filter": "bp", "cut": [2000.0, 500.0], "vol": 0.7, "res": 0.65},
		{"inst": "pluck", "f0": 196.0, "notes": [19, 17, 12, 7, 0], "step": 0.04, "dur": 0.5, "tone": 0.7, "vol": 0.45},
		{"inst": "drum", "f0": 100.0, "f1": 35.0, "dur": 0.6, "vol": 0.54, "noise": 0.3, "cut": 700.0}]},
	# Le Harfang tombe : la flûte descend, le vent retombe, la harpe en sol majeur.
	"vent_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"inst": "tone", "tone": "flute", "f0": 392.0, "notes": [12, 10, 7, 5, 0], "step": 0.3, "dur": 0.6, "vol": 0.35},
		{"wave": NOISE, "dur": 1.8, "att": 0.01, "filter": "bp", "cut": [1600.0, 300.0], "vol": 0.5, "res": 0.6},
		{"inst": "drum", "f0": 80.0, "f1": 28.0, "dur": 1.0, "vol": 0.6, "noise": 0.3, "cut": 600.0},
		{"inst": "pluck", "f0": 196.0, "notes": [0, 4, 7, 12, 16], "step": 0.1, "dur": 0.9, "tone": 0.7, "vol": 0.4, "delay": 1.0}]},
	# --- Sève (vie, eau, régénération) : gouttes, clochettes, eau vive. -------------------------------------
	# Goutte de sève (attaque) : un ploc et une note de kalimba.
	"seve_goutte": {"peak": 0.45, "verb": 0.3, "room": 0.5, "layers": [
		{"wave": SINE, "f0": 900.0, "f1": 420.0, "dur": 0.12, "att": 0.002, "vol": 0.7, "decay": 2.0},
		{"inst": "mallet", "kind": "kalimba", "f0": 622.3, "notes": [0], "step": 0.0, "dur": 0.25, "vol": 0.3}]},
	# Une pousse : arpège de kalimba (mib lydien) et feuilles qui se déplient.
	"seve_pousse": {"peak": 0.48, "verb": 0.35, "room": 0.55, "layers": [
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 4, 7, 11], "step": 0.06, "dur": 0.5, "vol": 0.45},
		{"wave": "grain", "dur": 0.35, "att": 0.1, "density": 70.0, "grain": 0.02, "cut": [600.0, 1300.0], "res": 0.3, "vol": 0.3}]},
	# Cocon de sève : la sève s'enroule autour du héros (cor chaud), des gouttes de kalimba, un glouglou.
	"seve_soin": {"peak": 0.48, "verb": 0.5, "room": 0.7, "layers": [
		{"inst": "tone", "tone": "horn", "f0": 155.6, "notes": [0, 4, 7], "step": 0.0, "dur": 0.9, "vol": 0.3},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [7, 4, 0], "step": 0.1, "dur": 0.8, "vol": 0.4},
		{"wave": SINE, "f0": 300.0, "f1": 180.0, "dur": 0.08, "att": 0.005, "delay": 0.1, "vol": 0.25, "vib": [0.1, 20.0]}]},
	# Fontaine de sève : une source qui jaillit, des gouttes en arpège, un orgue de bois.
	"seve_source": {"peak": 0.45, "verb": 0.35, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.8, "att": 0.1, "filter": "bp", "cut": [600.0, 1500.0], "res": 0.4, "vol": 0.35, "trem": [0.4, 9.0]},
		{"wave": "grain", "dur": 0.8, "att": 0.05, "density": 30.0, "grain": 0.035, "cut": [700.0, 1300.0], "res": 0.85, "vol": 0.45},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 7, 4, 11, 14], "step": 0.08, "dur": 0.7, "vol": 0.4}]},
	# Cocon (éclosion) : le cocon s'ouvre comme une fleur : un éclat mou, un accord de kalimba et de cor.
	"seve_eclosion": {"peak": 0.5, "verb": 0.45, "room": 0.65, "layers": [
		{"wave": NOISE, "dur": 0.1, "att": 0.003, "filter": "lp", "cut": [1500.0, 400.0], "vol": 0.6},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 4, 7, 11], "step": 0.03, "dur": 1.0, "vol": 0.45},
		{"inst": "tone", "tone": "horn", "f0": 155.6, "notes": [0, 7], "step": 0.0, "dur": 0.7, "delay": 0.05, "vol": 0.25},
		{"wave": "grain", "dur": 0.5, "delay": 0.05, "att": 0.05, "density": 80.0, "grain": 0.02, "cut": [800.0, 1600.0], "res": 0.3, "vol": 0.25}]},
	# Liane buveuse : une liane qui se tend comme un élastique, le bois qui grince, la sève qui coule.
	"seve_lien": {"peak": 0.5, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": SINE, "f0": 110.0, "f1": 260.0, "dur": 0.4, "att": 0.03, "vol": 0.45, "vib": [0.03, 9.0], "drive": 0.2},
		{"wave": "grain", "dur": 0.35, "att": 0.05, "density": 60.0, "grain": 0.03, "cut": [400.0, 700.0], "res": 0.8, "vol": 0.4},
		{"inst": "tone", "tone": "cello", "f0": 155.6, "notes": [0, 4], "step": 0.15, "dur": 0.3, "vol": 0.3},
		{"wave": SINE, "f0": 280.0, "f1": 160.0, "dur": 0.08, "att": 0.005, "delay": 0.3, "vol": 0.25}]},
	# Réveil du Saule exsangue : le cor en mib lydien, la sève qui coule, kalimba.
	"seve_boss_eveil": {"peak": 0.8, "verb": 0.55, "room": 0.9, "duck": 0.6, "layers": [
		{"inst": "tone", "tone": "horn", "f0": 155.6, "notes": [0, 7], "step": 0.0, "dur": 1.2, "vol": 0.35},
		{"inst": "bow", "f0": 77.8, "notes": [0, 7, 12], "dur": 1.2, "att": 0.5, "cut": 900.0, "vol": 0.35},
		{"wave": NOISE, "dur": 1.2, "att": 0.5, "filter": "bp", "cut": [600.0, 1300.0], "vol": 0.3, "res": 0.4, "trem": [0.4, 9.0]},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 4, 6, 11], "step": 0.15, "dur": 0.5, "vol": 0.4, "delay": 0.6},
		{"inst": "drum", "f0": 65.0, "f1": 42.0, "dur": 0.6, "vol": 0.42, "delay": 1.0}]},
	# Le Saule change de phase : un glouglou, kalimba qui redescend, tambour.
	"seve_boss_phase": {"peak": 0.78, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"wave": SINE, "f0": 300.0, "f1": 140.0, "dur": 0.2, "att": 0.002, "vol": 0.5, "vib": [0.1, 14.0]},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [11, 6, 4, 0], "step": 0.07, "dur": 0.5, "vol": 0.45},
		{"inst": "drum", "f0": 90.0, "f1": 35.0, "dur": 0.6, "vol": 0.54, "noise": 0.3, "cut": 600.0}]},
	# Le Saule meurt : la sève s'écoule, le cor et la kalimba en mib majeur.
	"seve_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": NOISE, "dur": 1.5, "att": 0.01, "filter": "bp", "cut": [1300.0, 400.0], "vol": 0.4, "res": 0.5, "trem": [0.5, 11.0]},
		{"inst": "drum", "f0": 70.0, "f1": 30.0, "dur": 1.0, "vol": 0.6, "noise": 0.3, "cut": 500.0},
		{"inst": "tone", "tone": "horn", "f0": 155.6, "notes": [0, 4, 7], "step": 0.25, "dur": 1.0, "vol": 0.35, "delay": 0.6},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 4, 7, 11, 12, 16], "step": 0.1, "dur": 0.8, "vol": 0.4, "delay": 0.9},
		{"inst": "bow", "f0": 77.8, "notes": [0, 4, 7, 12], "dur": 1.4, "att": 0.4, "cut": 1000.0, "vol": 0.3, "delay": 0.7}]},
	# --- Racine (bois, pierre) : bois qui craque, coups sourds. ---------------------------------------------
	# Bouclier d'écorce : l'écorce se referme autour du héros : craquements de bois, un coup sourd, un violoncelle.
	"racine_ecorce": {"peak": 0.6, "verb": 0.2, "room": 0.45, "layers": [
		{"wave": "grain", "dur": 0.4, "att": 0.02, "density": 90.0, "grain": 0.025, "cut": [500.0, 900.0], "res": 0.8, "vol": 0.6},
		{"inst": "drum", "f0": 140.0, "f1": 100.0, "dur": 0.2, "delay": 0.3, "noise": 0.3, "cut": 900.0, "vol": 0.6},
		{"inst": "tone", "tone": "cello", "f0": 65.4, "notes": [0, 7], "step": 0.0, "dur": 0.5, "delay": 0.05, "vol": 0.3}]},
	# Ancrage : le héros s'ancre : une pierre qui tombe lourdement, la terre qui gronde, du gravier.
	"racine_ancrage": {"peak": 0.7, "verb": 0.3, "room": 0.6, "layers": [
		{"inst": "drum", "f0": 90.0, "f1": 38.0, "dur": 0.7, "noise": 0.4, "cut": 500.0, "vol": 1.0},
		{"wave": NOISE, "dur": 0.8, "att": 0.02, "filter": "lp", "cut": [300.0, 120.0], "vol": 0.6, "decay": 1.2},
		{"wave": "grain", "dur": 0.5, "delay": 0.03, "att": 0.005, "density": 120.0, "grain": 0.01, "cut": [1400.0, 600.0], "res": 0.4, "vol": 0.45, "decay": 2.0},
		{"inst": "bow", "f0": 65.4, "notes": [0, 7], "dur": 0.6, "att": 0.05, "cut": 600.0, "vol": 0.3}]},
	# Pieux : trois pieux de bois qui percent la terre l'un après l'autre.
	"racine_pieux": {"peak": 0.6, "verb": 0.15, "room": 0.4, "layers": [
		{"inst": "drum", "f0": 170.0, "f1": 110.0, "notes": [0, -2, -5], "step": 0.09, "dur": 0.16, "noise": 0.5, "cut": 1100.0, "vol": 0.65},
		{"wave": "grain", "dur": 0.35, "att": 0.005, "density": 140.0, "grain": 0.008, "cut": [1600.0, 700.0], "res": 0.4, "vol": 0.4},
		{"inst": "mallet", "kind": "marimba", "f0": 130.8, "notes": [0, -2, -5], "step": 0.09, "dur": 0.4, "vol": 0.35}]},
	# Massue de bois (attaque de Racine) : un coup de tambour, du gravier.
	"racine_massue": {"peak": 0.75, "verb": 0.2, "room": 0.5, "layers": [
		{"inst": "drum", "f0": 150.0, "f1": 45.0, "dur": 0.38, "vol": 0.6, "noise": 0.4, "cut": 800.0},
		{"wave": NOISE, "dur": 0.22, "att": 0.002, "filter": "lp", "cut": [1400.0, 220.0], "vol": 0.5},
		{"wave": "grain", "dur": 0.22, "att": 0.01, "density": 140.0, "grain": 0.008, "cut": [1200.0, 500.0], "res": 0.4, "vol": 0.35, "decay": 2.0}]},
	# Réveil du boss de Racine : trois coups de taiko, les violoncelles en do dorien, le bois qui craque.
	"racine_boss_eveil": {"peak": 0.85, "verb": 0.5, "room": 0.9, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 65.4, "notes": [0, 7], "dur": 1.4, "att": 0.5, "cut": 500.0, "vol": 0.4},
		{"inst": "drum", "f0": 60.0, "f1": 35.0, "dur": 0.5, "vol": 0.6, "noise": 0.3, "cut": 400.0, "notes": [0, 0, 0], "step": 0.35},
		{"wave": "grain", "dur": 1.2, "att": 0.3, "density": 50.0, "grain": 0.03, "cut": [300.0, 800.0], "res": 0.8, "vol": 0.4},
		{"inst": "tone", "tone": "cello", "f0": 65.4, "notes": [0, 3], "step": 0.4, "dur": 0.6, "vol": 0.35, "delay": 0.3}]},
	# Le boss de Racine change de phase : tambours qui descendent, gravier, marimba grave.
	"racine_boss_phase": {"peak": 0.82, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 32.0, "dur": 0.4, "vol": 0.6, "noise": 0.4, "cut": 500.0, "notes": [0, -2, -5], "step": 0.12},
		{"wave": "grain", "dur": 0.5, "att": 0.01, "density": 140.0, "grain": 0.01, "cut": [1200.0, 400.0], "res": 0.4, "vol": 0.4},
		{"inst": "mallet", "kind": "marimba", "f0": 130.8, "notes": [3, 0], "step": 0.12, "dur": 0.5, "vol": 0.4}]},
	# Le boss de Racine s'effondre : la pierre gronde, puis le marimba et les cordes s'ouvrent sur mib majeur (dans do dorien).
	"racine_boss_mort": {"peak": 0.88, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": NOISE, "dur": 2.0, "att": 0.03, "filter": "lp", "cut": [1400.0, 80.0], "vol": 0.6, "trem": [0.4, 5.0]},
		{"inst": "drum", "f0": 90.0, "f1": 26.0, "dur": 1.4, "vol": 0.6, "noise": 0.4, "cut": 400.0},
		{"wave": "grain", "dur": 1.0, "att": 0.01, "density": 90.0, "grain": 0.015, "cut": [1000.0, 300.0], "res": 0.4, "vol": 0.4},
		{"inst": "tone", "tone": "cello", "f0": 65.4, "notes": [7, 3, 0], "step": 0.3, "dur": 0.6, "vol": 0.35},
		{"inst": "mallet", "kind": "marimba", "f0": 155.6, "notes": [0, 4, 7, 12, 16], "step": 0.12, "dur": 0.8, "vol": 0.4, "delay": 0.9},
		{"inst": "bow", "f0": 77.8, "notes": [0, 4, 7, 12], "dur": 1.4, "att": 0.4, "cut": 1000.0, "vol": 0.3, "delay": 0.9}]},
	# Termite touché : un clic de chitine sèche.
	"racine_termite_hit": {"peak": 0.4, "verb": 0.05, "room": 0.3, "layers": [
		{"inst": "drum", "f0": 900.0, "f1": 600.0, "dur": 0.04, "vol": 0.42, "noise": 0.6, "cut": 1800.0},
		{"wave": "grain", "dur": 0.03, "att": 0.001, "density": 400.0, "grain": 0.003, "cut": 1600.0, "res": 0.4, "vol": 0.4}]},
	# Termite écrasé : une carapace qui craque.
	"racine_termite_death": {"peak": 0.5, "verb": 0.12, "room": 0.35, "layers": [
		{"wave": "grain", "dur": 0.18, "att": 0.001, "density": 260.0, "grain": 0.006, "cut": [1500.0, 600.0], "res": 0.45, "vol": 0.7},
		{"inst": "drum", "f0": 200.0, "f1": 80.0, "dur": 0.1, "vol": 0.3, "noise": 0.3, "cut": 1200.0}]},
	# Mandragore touchée : un petit cri étouffé de chœur.
	"racine_mandragore_hit": {"peak": 0.5, "verb": 0.12, "room": 0.4, "layers": [
		{"inst": "choir", "vowel": "i", "f0": 392.0, "notes": [0], "step": 0.0, "dur": 0.13, "vol": 0.6},
		{"wave": NOISE, "dur": 0.05, "att": 0.002, "filter": "bp", "cut": 1500.0, "vol": 0.3, "res": 0.4}]},
	# Mandragore arrachée : son cri qui retombe, la terre qui s'effrite.
	"racine_mandragore_death": {"peak": 0.62, "verb": 0.3, "room": 0.55, "layers": [
		{"inst": "choir", "vowel": "o", "f0": 329.6, "notes": [0, -5, -10], "step": 0.12, "dur": 0.25, "vol": 0.5},
		{"wave": "grain", "dur": 0.3, "att": 0.01, "density": 120.0, "grain": 0.012, "cut": [900.0, 300.0], "res": 0.4, "vol": 0.4},
		{"inst": "drum", "f0": 120.0, "f1": 45.0, "dur": 0.25, "vol": 0.36}]},
	# Une mandragore jaillit du sol : la terre éclate et elle crie en montant.
	"racine_mandragore_jaillit": {"peak": 0.6, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1400.0, 300.0], "vol": 0.6},
		{"inst": "drum", "f0": 110.0, "f1": 50.0, "dur": 0.2, "vol": 0.42, "noise": 0.3, "cut": 700.0},
		{"inst": "choir", "vowel": "a", "f0": 220.0, "notes": [0, 5, 12], "step": 0.08, "dur": 0.2, "vol": 0.5}]},
	# Scarabée touché : un toc sur la carapace.
	"racine_scarabee_hit": {"peak": 0.55, "verb": 0.08, "room": 0.3, "layers": [
		{"inst": "drum", "f0": 520.0, "f1": 300.0, "dur": 0.07, "vol": 0.48, "noise": 0.5, "cut": 1400.0},
		{"wave": SINE, "f0": 150.0, "f1": 70.0, "dur": 0.08, "att": 0.002, "vol": 0.5}]},
	# Critique sur un scarabée : la carapace se fend, marimba grave.
	"racine_scarabee_crit": {"peak": 0.72, "verb": 0.2, "room": 0.45, "layers": [
		{"inst": "drum", "f0": 520.0, "f1": 300.0, "dur": 0.08, "vol": 0.48, "noise": 0.6, "cut": 1500.0},
		{"wave": "grain", "dur": 0.12, "att": 0.001, "density": 300.0, "grain": 0.005, "cut": [1600.0, 800.0], "res": 0.4, "vol": 0.45},
		{"inst": "mallet", "kind": "marimba", "f0": 261.6, "notes": [0, 7], "step": 0.03, "dur": 0.4, "vol": 0.4},
		{"wave": SINE, "f0": 180.0, "f1": 70.0, "dur": 0.12, "att": 0.002, "vol": 0.6}]},
	# Scarabée brisé : carapace en morceaux.
	"racine_scarabee_death": {"peak": 0.62, "verb": 0.15, "room": 0.4, "layers": [
		{"wave": "grain", "dur": 0.3, "att": 0.001, "density": 200.0, "grain": 0.01, "cut": [1400.0, 400.0], "res": 0.45, "vol": 0.7},
		{"inst": "drum", "f0": 140.0, "f1": 45.0, "dur": 0.25, "vol": 0.48, "noise": 0.3, "cut": 900.0}]},
	# Tertre touché : un coup sourd dans la pierre, du gravier.
	"racine_tertre_hit": {"peak": 0.6, "verb": 0.1, "room": 0.4, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 50.0, "dur": 0.12, "vol": 0.54, "noise": 0.5, "cut": 700.0},
		{"wave": "grain", "dur": 0.12, "att": 0.001, "density": 160.0, "grain": 0.008, "cut": [1000.0, 500.0], "res": 0.4, "vol": 0.4}]},
	# Tertre effondré : un éboulis, un grondement.
	"racine_tertre_death": {"peak": 0.75, "verb": 0.3, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.75, "att": 0.02, "filter": "lp", "cut": [900.0, 90.0], "vol": 0.7, "trem": [0.5, 9.0]},
		{"inst": "drum", "f0": 80.0, "f1": 30.0, "dur": 0.6, "vol": 0.6, "noise": 0.3, "cut": 500.0},
		{"wave": "grain", "dur": 0.6, "att": 0.01, "density": 110.0, "grain": 0.012, "cut": [1100.0, 300.0], "res": 0.4, "vol": 0.45}]},
	# Le tertre frappe le sol : la terre tremble, des pierres roulent.
	"racine_tertre_frappe": {"peak": 0.8, "verb": 0.2, "room": 0.5, "layers": [
		{"inst": "drum", "f0": 120.0, "f1": 36.0, "dur": 0.45, "vol": 0.6, "noise": 0.5, "cut": 600.0},
		{"wave": NOISE, "dur": 0.3, "att": 0.002, "filter": "lp", "cut": [1600.0, 150.0], "vol": 0.5},
		{"wave": "grain", "dur": 0.35, "att": 0.01, "density": 140.0, "grain": 0.01, "cut": [1200.0, 400.0], "res": 0.4, "vol": 0.4, "decay": 2.0}]},
	# --- Finale (la Flétrissure, sous la graine) : plus graves et plus lourds ; le creux résonne. -----------
	# Réveil de la Flétrissure : cordes et cors en sib, triton qui grince, cloche grave, tambour.
	"finale_boss_eveil": {"peak": 0.88, "verb": 0.65, "room": 1.0, "duck": 0.7, "layers": [
		{"inst": "bow", "f0": 58.3, "notes": [0, 6, 12], "dur": 1.7, "att": 0.6, "cut": 700.0, "vol": 0.45},
		{"inst": "tone", "tone": "horns", "f0": 58.3, "notes": [0, 1], "step": 0.6, "dur": 0.9, "vol": 0.35, "delay": 0.2},
		{"inst": "mallet", "kind": "bell", "f0": 116.5, "notes": [0], "step": 0.0, "dur": 1.6, "vol": 0.4, "delay": 1.3},
		{"inst": "drum", "f0": 55.0, "f1": 32.0, "dur": 0.8, "vol": 0.6, "noise": 0.3, "cut": 400.0, "delay": 1.3},
		{"wave": SINE, "f0": 36.0, "f1": 41.0, "dur": 1.7, "att": 0.4, "vol": 0.5}]},
	# La Flétrissure change de phase : les cors tombent d'un triton, coup de tambour, cordes diminuées.
	"finale_boss_phase": {"peak": 0.86, "verb": 0.55, "room": 1.0, "duck": 0.5, "layers": [
		{"inst": "tone", "tone": "horns", "f0": 58.3, "notes": [6, 0], "step": 0.3, "dur": 0.6, "vol": 0.4},
		{"inst": "drum", "f0": 90.0, "f1": 28.0, "dur": 0.9, "vol": 0.6, "noise": 0.4, "cut": 500.0},
		{"inst": "bow", "f0": 58.3, "notes": [0, 3, 6], "dur": 1.0, "att": 0.05, "cut": 800.0, "vol": 0.35}]},
	# La Flétrissure meurt : tout s'effondre, puis chœur, cordes et cloche en sib majeur.
	"finale_boss_mort": {"peak": 0.9, "verb": 0.7, "room": 1.0, "duck": 0.85, "layers": [
		{"wave": NOISE, "dur": 2.2, "att": 0.002, "filter": "lp", "cut": [2000.0, 80.0], "vol": 0.6},
		{"inst": "drum", "f0": 70.0, "f1": 24.0, "dur": 2.0, "vol": 0.6, "noise": 0.4, "cut": 400.0},
		{"inst": "tone", "tone": "horns", "f0": 116.5, "notes": [0, -5, -12], "step": 0.4, "dur": 0.8, "vol": 0.35},
		{"inst": "choir", "vowel": "a", "f0": 116.5, "notes": [0, 4, 7], "step": 0.0, "dur": 1.8, "vol": 0.35, "delay": 1.2},
		{"inst": "bow", "f0": 58.3, "notes": [0, 7, 12, 16], "dur": 1.8, "att": 0.5, "cut": 1000.0, "vol": 0.35, "delay": 1.2},
		{"inst": "mallet", "kind": "bell", "f0": 233.1, "notes": [0], "step": 0.0, "dur": 2.2, "vol": 0.35, "delay": 1.3}]},
	# --- Aube (lumière, éclat, cloches) : clair, cristallin. -------------------------------------------------
	# Rayon (attaque d'Aube) : un verre qui chante bref, une lueur qui passe.
	"aube_rayon": {"peak": 0.42, "verb": 0.2, "room": 0.5, "layers": [
		{"inst": "tone", "tone": "glass", "f0": 440.0, "notes": [0], "step": 0.0, "dur": 0.18, "vol": 0.4},
		{"wave": NOISE, "dur": 0.1, "att": 0.02, "filter": "bp", "cut": [900.0, 1800.0], "vol": 0.3, "res": 0.4},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [7], "step": 0.0, "dur": 0.25, "vol": 0.2}]},
	# Éclat de lumière : glockenspiel en quinte sur un verre.
	"aube_eclat": {"peak": 0.45, "verb": 0.4, "room": 0.6, "layers": [
		{"inst": "mallet", "kind": "glock", "f0": 659.3, "notes": [0, 7], "step": 0.04, "dur": 0.45, "vol": 0.4},
		{"inst": "tone", "tone": "glass", "f0": 329.6, "notes": [0], "step": 0.0, "dur": 0.4, "vol": 0.25}]},
	# Halo : les verres montent en accord (la lydien), un souffle de chœur.
	"aube_halo": {"peak": 0.48, "verb": 0.55, "room": 0.75, "layers": [
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [0, 4, 7, 11], "step": 0.1, "dur": 0.8, "vol": 0.3},
		{"inst": "choir", "vowel": "i", "f0": 220.0, "notes": [0], "step": 0.0, "dur": 0.9, "vol": 0.2}]},
	# Lance d'aube : la lumière se charge (verre qui monte), la lance part (souffle) et frappe (cloche).
	"aube_levant": {"peak": 0.5, "verb": 0.35, "room": 0.6, "layers": [
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [0, 7, 12], "step": 0.06, "dur": 0.35, "vol": 0.3},
		{"wave": NOISE, "dur": 0.25, "att": 0.15, "delay": 0.15, "filter": "bp", "cut": [700.0, 2600.0], "res": 0.5, "vol": 0.5, "decay": 3.0},
		{"inst": "mallet", "kind": "bell", "f0": 440.0, "dur": 1.0, "delay": 0.35, "vol": 0.45}]},
	# Prisme : un éclat de lumière tiré par le prisme : une lame de verre qui tinte.
	"aube_cloche": {"peak": 0.5, "verb": 0.5, "room": 0.75, "layers": [
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0, 7], "step": 0.0, "dur": 0.8, "vol": 0.45},
		{"inst": "tone", "tone": "glass", "f0": 220.0, "dur": 0.4, "vol": 0.2},
		{"wave": NOISE, "dur": 0.08, "att": 0.002, "filter": "bp", "cut": 2200.0, "res": 0.5, "vol": 0.25}]},
	# Aurore : l'aube éclate autour du héros : un accord de verres qui s'ouvre, des cloches, un grave.
	"aube_nova": {"peak": 0.75, "verb": 0.45, "room": 0.75, "duck": 0.15, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 50.0, "dur": 0.5, "vol": 0.7},
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [0, 4, 7, 11], "step": 0.0, "dur": 0.9, "vol": 0.3},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0, 4, 7, 11, 14], "step": 0.05, "dur": 1.0, "vol": 0.35},
		{"inst": "mallet", "kind": "bell", "f0": 220.0, "dur": 1.6, "vol": 0.4},
		{"wave": NOISE, "dur": 0.5, "att": 0.01, "filter": "bp", "cut": [600.0, 1800.0], "res": 0.3, "vol": 0.35}]},
	# Réveil de la Phalène de verre : les verres montent en la, cloche, glockenspiel.
	"aube_boss_eveil": {"peak": 0.82, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [0, 7, 12], "step": 0.3, "dur": 1.0, "vol": 0.35},
		{"inst": "bow", "f0": 110.0, "notes": [0, 7], "dur": 1.3, "att": 0.5, "cut": 900.0, "vol": 0.3},
		{"inst": "mallet", "kind": "bell", "f0": 110.0, "notes": [0], "step": 0.0, "dur": 1.4, "vol": 0.4, "delay": 1.1},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0, 4, 6, 11], "step": 0.08, "dur": 0.6, "vol": 0.25, "delay": 1.1},
		{"wave": SINE, "f0": 55.0, "f1": 55.0, "dur": 1.3, "att": 0.4, "vol": 0.4}]},
	# La Phalène change de phase : le glockenspiel dégringole, le verre vibre, un tambour.
	"aube_boss_phase": {"peak": 0.78, "verb": 0.5, "room": 0.85, "duck": 0.4, "layers": [
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [16, 11, 7, 4, 0], "step": 0.05, "dur": 0.5, "vol": 0.35},
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [6], "step": 0.0, "dur": 0.8, "vol": 0.3},
		{"inst": "drum", "f0": 100.0, "f1": 40.0, "dur": 0.5, "vol": 0.54, "noise": 0.2, "cut": 700.0}]},
	# La Phalène se brise : éclats de verre, puis un accord de verres et une cloche en la majeur.
	"aube_boss_mort": {"peak": 0.85, "verb": 0.65, "room": 1.0, "duck": 0.7, "layers": [
		{"wave": "grain", "dur": 0.8, "att": 0.005, "density": 120.0, "grain": 0.01, "cut": [1800.0, 700.0], "res": 0.5, "vol": 0.4},
		{"inst": "drum", "f0": 90.0, "f1": 32.0, "dur": 0.9, "vol": 0.54, "noise": 0.2, "cut": 600.0},
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [0, 4, 7, 11], "step": 0.0, "dur": 1.6, "vol": 0.3, "delay": 0.6},
		{"inst": "mallet", "kind": "bell", "f0": 220.0, "notes": [0], "step": 0.0, "dur": 1.6, "vol": 0.35, "delay": 0.6},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0, 4, 7, 11, 12], "step": 0.1, "dur": 0.8, "vol": 0.25, "delay": 0.9}]},
	# --- Ronce : sons de son boss (Ronce n'avait que l'annonce commune). --------------------------------------
	# Réveil du boss de Ronce : les cordes montent en ré mineur, les épines crépitent, les cors, un tambour.
	"ronce_boss_eveil": {"peak": 0.82, "verb": 0.5, "room": 0.85, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 73.4, "notes": [0, 3, 7], "dur": 1.3, "att": 0.5, "cut": 800.0, "vol": 0.45},
		{"wave": "grain", "dur": 1.0, "att": 0.6, "density": 90.0, "grain": 0.008, "cut": [700.0, 1500.0], "res": 0.55, "vol": 0.35},
		{"inst": "tone", "tone": "horns", "f0": 73.4, "notes": [0, 7], "step": 0.0, "dur": 1.0, "vol": 0.35, "delay": 0.3},
		{"inst": "drum", "f0": 70.0, "f1": 40.0, "dur": 0.6, "vol": 0.6, "noise": 0.3, "cut": 500.0, "delay": 1.0}]},
	# Le boss de Ronce change de phase : épines qui crépitent, coup de tambour, pizz dissonant.
	"ronce_boss_phase": {"peak": 0.8, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"wave": "grain", "dur": 0.5, "att": 0.3, "density": 160.0, "grain": 0.006, "cut": [900.0, 2000.0], "res": 0.5, "vol": 0.4},
		{"inst": "drum", "f0": 110.0, "f1": 35.0, "dur": 0.6, "vol": 0.6, "noise": 0.4, "cut": 600.0, "delay": 0.45},
		{"inst": "pluck", "f0": 73.4, "notes": [0, 1], "step": 0.0, "dur": 0.6, "tone": 0.4, "vol": 0.6, "delay": 0.45}]},
	# Le boss de Ronce meurt : la ronce s'effondre, puis les cordes passent en ré majeur.
	"ronce_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": NOISE, "dur": 1.6, "att": 0.002, "filter": "lp", "cut": [1800.0, 150.0], "vol": 0.6, "res": 0.3, "trem": [0.4, 7.0]},
		{"inst": "drum", "f0": 90.0, "f1": 26.0, "dur": 1.2, "vol": 0.6, "noise": 0.3, "cut": 500.0},
		{"inst": "bow", "f0": 73.4, "notes": [0, 4, 7, 12], "dur": 1.6, "att": 0.4, "cut": 1100.0, "vol": 0.4, "delay": 0.6},
		{"inst": "mallet", "kind": "bell", "f0": 146.8, "notes": [0], "step": 0.0, "dur": 1.6, "vol": 0.3, "delay": 0.8},
		{"inst": "pluck", "f0": 146.8, "notes": [12, 7, 4, 0], "step": 0.15, "dur": 0.6, "tone": 0.5, "vol": 0.35, "delay": 0.8}]},
	# --- Variantes régionales : <son>@<région>, jouées à la place de <son> dans cette région (Sfx.play). ---
	# Coup — Spore (marais) : chair molle et bulles, marimba en fa# phrygien.
	"impact@spore": {"peak": 0.6, "verb": 0.1, "room": 0.35, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "bp", "cut": [1700.0, 600.0], "vol": 0.7, "res": 0.4, "decay": 2.4},
		{"inst": "drum", "f0": 170.0, "f1": 70.0, "dur": 0.12, "vol": 0.48, "noise": 0.25, "cut": 1000.0},
		{"wave": SINE, "f0": 200.0, "f1": 110.0, "dur": 0.07, "att": 0.002, "vol": 0.5, "vib": [0.1, 30.0]},
		{"wave": "grain", "dur": 0.12, "att": 0.01, "density": 40.0, "grain": 0.03, "cut": [500.0, 300.0], "res": 0.85, "vol": 0.4}]},
	# Critique — Spore (marais) : chair molle et bulles, marimba en fa# phrygien.
	"critique@spore": {"peak": 0.75, "verb": 0.22, "room": 0.45, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.07, "att": 0.002, "filter": "bp", "cut": [2200.0, 800.0], "vol": 0.7, "res": 0.5, "decay": 2.2},
		{"inst": "drum", "f0": 200.0, "f1": 70.0, "dur": 0.14, "vol": 0.54, "noise": 0.3, "cut": 1200.0},
		{"inst": "mallet", "kind": "marimba", "f0": 370.0, "notes": [0, 1, 7], "step": 0.03, "dur": 0.5, "vol": 0.4}]},
	# Coup lourd — Spore (marais) : chair molle et bulles, marimba en fa# phrygien.
	"impact_lourd@spore": {"peak": 0.8, "verb": 0.16, "room": 0.5, "duck": 0.15, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1500.0, 220.0], "vol": 0.6, "res": 0.3, "decay": 2.0},
		{"inst": "drum", "f0": 120.0, "f1": 40.0, "dur": 0.36, "vol": 0.6, "noise": 0.5, "cut": 700.0},
		{"wave": SINE, "f0": 69.375, "f1": 55.5, "dur": 0.3, "att": 0.01, "vol": 0.3},
		{"wave": SINE, "f0": 200.0, "f1": 110.0, "dur": 0.07, "att": 0.002, "vol": 0.8, "vib": [0.1, 30.0]},
		{"wave": "grain", "dur": 0.12, "att": 0.01, "density": 40.0, "grain": 0.03, "cut": [500.0, 300.0], "res": 0.85, "vol": 0.64}]},
	# Un ennemi meurt — Spore (marais) : chair molle et bulles, marimba en fa# phrygien.
	"mort@spore": {"peak": 0.62, "verb": 0.2, "room": 0.45, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "bp", "cut": [1300.0, 260.0], "vol": 0.5, "res": 0.35, "decay": 1.8},
		{"inst": "drum", "f0": 140.0, "f1": 45.0, "dur": 0.25, "vol": 0.42, "noise": 0.2, "cut": 800.0},
		{"wave": "grain", "dur": 0.45, "att": 0.01, "density": 30.0, "grain": 0.04, "cut": [450.0, 250.0], "res": 0.85, "vol": 0.5},
		{"inst": "mallet", "kind": "marimba", "f0": 185.0, "notes": [1, 0], "step": 0.08, "dur": 0.5, "vol": 0.35}]},
	# Une élite tombe — Spore (marais) : chair molle et bulles, marimba en fa# phrygien.
	"mort_elite@spore": {"peak": 0.85, "verb": 0.34, "room": 0.7, "duck": 0.3, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 32.0, "dur": 0.7, "vol": 0.6, "noise": 0.4, "cut": 500.0},
		{"wave": NOISE, "dur": 0.5, "att": 0.002, "filter": "lp", "cut": [1800.0, 160.0], "vol": 0.5, "res": 0.3, "decay": 1.6},
		{"inst": "bow", "f0": 92.5, "notes": [0, 3, 7], "dur": 0.8, "att": 0.02, "cut": 900.0, "vol": 0.35},
		{"inst": "tone", "tone": "clarinet", "f0": 92.5, "notes": [1, 0], "step": 0.25, "dur": 0.5, "vol": 0.3},
		{"inst": "mallet", "kind": "marimba", "f0": 185.0, "notes": [7, 1, 0], "step": 0.1, "dur": 0.6, "vol": 0.35}]},
	# Un Cœur purifié — Spore (marais) : chair molle et bulles, marimba en fa# phrygien.
	"coeur@spore": {"peak": 0.72, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 92.5, "notes": [0, 7, 12, 16], "dur": 2.4, "att": 0.6, "cut": 1200.0, "vol": 0.4},
		{"inst": "mallet", "kind": "bell", "f0": 185.0, "notes": [0], "step": 0.0, "dur": 2.0, "vol": 0.3},
		{"wave": SINE, "f0": 92.5, "f1": 92.5, "dur": 2.2, "att": 0.05, "vol": 0.35, "decay": 1.2},
		{"inst": "mallet", "kind": "marimba", "f0": 370.0, "notes": [0, 4, 7, 12, 16, 19], "step": 0.12, "dur": 0.8, "vol": 0.35},
		{"inst": "tone", "tone": "clarinet", "f0": 185.0, "notes": [0, 4, 7], "step": 0.35, "dur": 0.8, "vol": 0.25},
		{"inst": "choir", "vowel": "o", "f0": 185.0, "notes": [0, 4, 7], "step": 0.0, "dur": 2.2, "vol": 0.3}]},
	# Coup — Vent (plateaux) : souffles et plumes, harpe et flûte en sol mixolydien.
	"impact@vent": {"peak": 0.6, "verb": 0.1, "room": 0.35, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "bp", "cut": [1700.0, 600.0], "vol": 0.7, "res": 0.4, "decay": 2.4},
		{"inst": "drum", "f0": 170.0, "f1": 70.0, "dur": 0.12, "vol": 0.48, "noise": 0.25, "cut": 1000.0},
		{"wave": NOISE, "dur": 0.09, "att": 0.002, "filter": "bp", "cut": [1400.0, 600.0], "vol": 0.4, "res": 0.5},
		{"inst": "pluck", "f0": 196.0, "notes": [0], "step": 0.0, "dur": 0.25, "tone": 0.7, "vol": 0.3}]},
	# Critique — Vent (plateaux) : souffles et plumes, harpe et flûte en sol mixolydien.
	"critique@vent": {"peak": 0.75, "verb": 0.22, "room": 0.45, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.07, "att": 0.002, "filter": "bp", "cut": [2200.0, 800.0], "vol": 0.7, "res": 0.5, "decay": 2.2},
		{"inst": "drum", "f0": 200.0, "f1": 70.0, "dur": 0.14, "vol": 0.54, "noise": 0.3, "cut": 1200.0},
		{"inst": "pluck", "f0": 196.0, "notes": [0, 7, 12, 16], "step": 0.025, "dur": 0.5, "tone": 0.7, "vol": 0.5},
		{"inst": "tone", "tone": "flute", "f0": 392.0, "notes": [0], "step": 0.0, "dur": 0.25, "vol": 0.2}]},
	# Coup lourd — Vent (plateaux) : souffles et plumes, harpe et flûte en sol mixolydien.
	"impact_lourd@vent": {"peak": 0.8, "verb": 0.16, "room": 0.5, "duck": 0.15, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1500.0, 220.0], "vol": 0.6, "res": 0.3, "decay": 2.0},
		{"inst": "drum", "f0": 120.0, "f1": 40.0, "dur": 0.36, "vol": 0.6, "noise": 0.5, "cut": 700.0},
		{"wave": SINE, "f0": 73.5, "f1": 58.8, "dur": 0.3, "att": 0.01, "vol": 0.3},
		{"wave": NOISE, "dur": 0.09, "att": 0.002, "filter": "bp", "cut": [1400.0, 600.0], "vol": 0.64, "res": 0.5},
		{"inst": "pluck", "f0": 196.0, "notes": [0], "step": 0.0, "dur": 0.25, "tone": 0.7, "vol": 0.48}]},
	# Un ennemi meurt — Vent (plateaux) : souffles et plumes, harpe et flûte en sol mixolydien.
	"mort@vent": {"peak": 0.62, "verb": 0.2, "room": 0.45, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "bp", "cut": [1300.0, 260.0], "vol": 0.5, "res": 0.35, "decay": 1.8},
		{"inst": "drum", "f0": 140.0, "f1": 45.0, "dur": 0.25, "vol": 0.42, "noise": 0.2, "cut": 800.0},
		{"wave": "grain", "dur": 0.35, "att": 0.01, "density": 120.0, "grain": 0.01, "cut": [1400.0, 700.0], "res": 0.35, "vol": 0.4},
		{"inst": "pluck", "f0": 196.0, "notes": [7, 0], "step": 0.07, "dur": 0.4, "tone": 0.7, "vol": 0.35}]},
	# Une élite tombe — Vent (plateaux) : souffles et plumes, harpe et flûte en sol mixolydien.
	"mort_elite@vent": {"peak": 0.85, "verb": 0.34, "room": 0.7, "duck": 0.3, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 32.0, "dur": 0.7, "vol": 0.6, "noise": 0.4, "cut": 500.0},
		{"wave": NOISE, "dur": 0.5, "att": 0.002, "filter": "lp", "cut": [1800.0, 160.0], "vol": 0.5, "res": 0.3, "decay": 1.6},
		{"inst": "bow", "f0": 98.0, "notes": [0, 7, 12], "dur": 0.8, "att": 0.02, "cut": 900.0, "vol": 0.35},
		{"inst": "tone", "tone": "flute", "f0": 392.0, "notes": [7, 5, 0], "step": 0.15, "dur": 0.4, "vol": 0.3},
		{"wave": NOISE, "dur": 0.7, "att": 0.05, "filter": "bp", "cut": [1600.0, 300.0], "vol": 0.4, "res": 0.6}]},
	# Un Cœur purifié — Vent (plateaux) : souffles et plumes, harpe et flûte en sol mixolydien.
	"coeur@vent": {"peak": 0.72, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 98.0, "notes": [0, 7, 12, 16], "dur": 2.4, "att": 0.6, "cut": 1200.0, "vol": 0.4},
		{"inst": "mallet", "kind": "bell", "f0": 196.0, "notes": [0], "step": 0.0, "dur": 2.0, "vol": 0.3},
		{"wave": SINE, "f0": 98.0, "f1": 98.0, "dur": 2.2, "att": 0.05, "vol": 0.35, "decay": 1.2},
		{"inst": "pluck", "f0": 196.0, "notes": [0, 4, 7, 10, 12, 16, 19], "step": 0.09, "dur": 0.9, "tone": 0.7, "vol": 0.4},
		{"inst": "tone", "tone": "flute", "f0": 392.0, "notes": [0, 4, 7], "step": 0.35, "dur": 0.8, "vol": 0.25},
		{"inst": "choir", "vowel": "a", "f0": 196.0, "notes": [0, 4, 7], "step": 0.0, "dur": 2.2, "vol": 0.3}]},
	# Coup — Sève (vallée) : gouttes et glouglous, kalimba et cor en mib lydien.
	"impact@seve": {"peak": 0.6, "verb": 0.1, "room": 0.35, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "bp", "cut": [1700.0, 600.0], "vol": 0.7, "res": 0.4, "decay": 2.4},
		{"inst": "drum", "f0": 170.0, "f1": 70.0, "dur": 0.12, "vol": 0.48, "noise": 0.25, "cut": 1000.0},
		{"wave": SINE, "f0": 700.0, "f1": 300.0, "dur": 0.07, "att": 0.002, "vol": 0.4},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0], "step": 0.0, "dur": 0.25, "vol": 0.25}]},
	# Critique — Sève (vallée) : gouttes et glouglous, kalimba et cor en mib lydien.
	"critique@seve": {"peak": 0.75, "verb": 0.22, "room": 0.45, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.07, "att": 0.002, "filter": "bp", "cut": [2200.0, 800.0], "vol": 0.7, "res": 0.5, "decay": 2.2},
		{"inst": "drum", "f0": 200.0, "f1": 70.0, "dur": 0.14, "vol": 0.54, "noise": 0.3, "cut": 1200.0},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 4, 11], "step": 0.03, "dur": 0.5, "vol": 0.45},
		{"wave": SINE, "f0": 900.0, "f1": 400.0, "dur": 0.08, "att": 0.002, "vol": 0.2}]},
	# Coup lourd — Sève (vallée) : gouttes et glouglous, kalimba et cor en mib lydien.
	"impact_lourd@seve": {"peak": 0.8, "verb": 0.16, "room": 0.5, "duck": 0.15, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1500.0, 220.0], "vol": 0.6, "res": 0.3, "decay": 2.0},
		{"inst": "drum", "f0": 120.0, "f1": 40.0, "dur": 0.36, "vol": 0.6, "noise": 0.5, "cut": 700.0},
		{"wave": SINE, "f0": 58.35, "f1": 46.68, "dur": 0.3, "att": 0.01, "vol": 0.3},
		{"wave": SINE, "f0": 700.0, "f1": 300.0, "dur": 0.07, "att": 0.002, "vol": 0.64},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0], "step": 0.0, "dur": 0.25, "vol": 0.4}]},
	# Un ennemi meurt — Sève (vallée) : gouttes et glouglous, kalimba et cor en mib lydien.
	"mort@seve": {"peak": 0.62, "verb": 0.2, "room": 0.45, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "bp", "cut": [1300.0, 260.0], "vol": 0.5, "res": 0.35, "decay": 1.8},
		{"inst": "drum", "f0": 140.0, "f1": 45.0, "dur": 0.25, "vol": 0.42, "noise": 0.2, "cut": 800.0},
		{"wave": SINE, "f0": 300.0, "f1": 150.0, "dur": 0.12, "att": 0.002, "vol": 0.4, "vib": [0.1, 18.0]},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [7, 0], "step": 0.08, "dur": 0.5, "vol": 0.35}]},
	# Une élite tombe — Sève (vallée) : gouttes et glouglous, kalimba et cor en mib lydien.
	"mort_elite@seve": {"peak": 0.85, "verb": 0.34, "room": 0.7, "duck": 0.3, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 32.0, "dur": 0.7, "vol": 0.6, "noise": 0.4, "cut": 500.0},
		{"wave": NOISE, "dur": 0.5, "att": 0.002, "filter": "lp", "cut": [1800.0, 160.0], "vol": 0.5, "res": 0.3, "decay": 1.6},
		{"inst": "bow", "f0": 77.8, "notes": [0, 7, 12], "dur": 0.8, "att": 0.02, "cut": 900.0, "vol": 0.35},
		{"inst": "tone", "tone": "horn", "f0": 155.6, "notes": [6, 0], "step": 0.25, "dur": 0.5, "vol": 0.3},
		{"wave": "grain", "dur": 0.6, "att": 0.01, "density": 30.0, "grain": 0.035, "cut": [700.0, 400.0], "res": 0.85, "vol": 0.4}]},
	# Un Cœur purifié — Sève (vallée) : gouttes et glouglous, kalimba et cor en mib lydien.
	"coeur@seve": {"peak": 0.72, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 77.8, "notes": [0, 7, 12, 16], "dur": 2.4, "att": 0.6, "cut": 1200.0, "vol": 0.4},
		{"inst": "mallet", "kind": "bell", "f0": 311.2, "notes": [0], "step": 0.0, "dur": 2.0, "vol": 0.3},
		{"wave": SINE, "f0": 77.8, "f1": 77.8, "dur": 2.2, "att": 0.05, "vol": 0.35, "decay": 1.2},
		{"inst": "mallet", "kind": "kalimba", "f0": 311.1, "notes": [0, 4, 6, 11, 12, 16], "step": 0.12, "dur": 0.8, "vol": 0.4},
		{"inst": "tone", "tone": "horn", "f0": 155.6, "notes": [0, 4, 7], "step": 0.35, "dur": 0.9, "vol": 0.25},
		{"inst": "choir", "vowel": "a", "f0": 155.6, "notes": [0, 4, 7], "step": 0.0, "dur": 2.2, "vol": 0.3}]},
	# Coup — Aube (rivage) : verre qui tinte, glockenspiel et verres en la lydien.
	"impact@aube": {"peak": 0.6, "verb": 0.1, "room": 0.35, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "bp", "cut": [1700.0, 600.0], "vol": 0.7, "res": 0.4, "decay": 2.4},
		{"inst": "drum", "f0": 170.0, "f1": 70.0, "dur": 0.12, "vol": 0.48, "noise": 0.25, "cut": 1000.0},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0], "step": 0.0, "dur": 0.25, "vol": 0.2},
		{"wave": NOISE, "dur": 0.05, "att": 0.002, "filter": "bp", "cut": 1500.0, "vol": 0.3, "res": 0.5}]},
	# Critique — Aube (rivage) : verre qui tinte, glockenspiel et verres en la lydien.
	"critique@aube": {"peak": 0.75, "verb": 0.22, "room": 0.45, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.07, "att": 0.002, "filter": "bp", "cut": [2200.0, 800.0], "vol": 0.7, "res": 0.5, "decay": 2.2},
		{"inst": "drum", "f0": 200.0, "f1": 70.0, "dur": 0.14, "vol": 0.54, "noise": 0.3, "cut": 1200.0},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0, 4, 11], "step": 0.025, "dur": 0.6, "vol": 0.35},
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [0], "step": 0.0, "dur": 0.4, "vol": 0.2}]},
	# Coup lourd — Aube (rivage) : verre qui tinte, glockenspiel et verres en la lydien.
	"impact_lourd@aube": {"peak": 0.8, "verb": 0.16, "room": 0.5, "duck": 0.15, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1500.0, 220.0], "vol": 0.6, "res": 0.3, "decay": 2.0},
		{"inst": "drum", "f0": 120.0, "f1": 40.0, "dur": 0.36, "vol": 0.6, "noise": 0.5, "cut": 700.0},
		{"wave": SINE, "f0": 82.5, "f1": 66.0, "dur": 0.3, "att": 0.01, "vol": 0.3},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0], "step": 0.0, "dur": 0.25, "vol": 0.32},
		{"wave": NOISE, "dur": 0.05, "att": 0.002, "filter": "bp", "cut": 1500.0, "vol": 0.48, "res": 0.5}]},
	# Un ennemi meurt — Aube (rivage) : verre qui tinte, glockenspiel et verres en la lydien.
	"mort@aube": {"peak": 0.62, "verb": 0.2, "room": 0.45, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "bp", "cut": [1300.0, 260.0], "vol": 0.5, "res": 0.35, "decay": 1.8},
		{"inst": "drum", "f0": 140.0, "f1": 45.0, "dur": 0.25, "vol": 0.42, "noise": 0.2, "cut": 800.0},
		{"wave": "grain", "dur": 0.3, "att": 0.01, "density": 140.0, "grain": 0.008, "cut": [1600.0, 800.0], "res": 0.5, "vol": 0.35},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [7, 0], "step": 0.07, "dur": 0.5, "vol": 0.25}]},
	# Une élite tombe — Aube (rivage) : verre qui tinte, glockenspiel et verres en la lydien.
	"mort_elite@aube": {"peak": 0.85, "verb": 0.34, "room": 0.7, "duck": 0.3, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 32.0, "dur": 0.7, "vol": 0.6, "noise": 0.4, "cut": 500.0},
		{"wave": NOISE, "dur": 0.5, "att": 0.002, "filter": "lp", "cut": [1800.0, 160.0], "vol": 0.5, "res": 0.3, "decay": 1.6},
		{"inst": "bow", "f0": 110.0, "notes": [0, 7, 12], "dur": 0.8, "att": 0.02, "cut": 900.0, "vol": 0.35},
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [6, 0], "step": 0.25, "dur": 0.6, "vol": 0.3},
		{"inst": "mallet", "kind": "bell", "f0": 220.0, "notes": [0], "step": 0.0, "dur": 1.2, "vol": 0.3}]},
	# Un Cœur purifié — Aube (rivage) : verre qui tinte, glockenspiel et verres en la lydien.
	"coeur@aube": {"peak": 0.72, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 110.0, "notes": [0, 7, 12, 16], "dur": 2.4, "att": 0.6, "cut": 1200.0, "vol": 0.4},
		{"inst": "mallet", "kind": "bell", "f0": 220.0, "notes": [0], "step": 0.0, "dur": 2.0, "vol": 0.3},
		{"wave": SINE, "f0": 110.0, "f1": 110.0, "dur": 2.2, "att": 0.05, "vol": 0.35, "decay": 1.2},
		{"inst": "mallet", "kind": "glock", "f0": 440.0, "notes": [0, 4, 6, 11, 12, 16], "step": 0.12, "dur": 0.8, "vol": 0.3},
		{"inst": "tone", "tone": "glass", "f0": 220.0, "notes": [0, 4, 7], "step": 0.0, "dur": 1.6, "vol": 0.3},
		{"inst": "choir", "vowel": "i", "f0": 220.0, "notes": [0, 4, 7], "step": 0.0, "dur": 2.2, "vol": 0.25}]},
	# Coup — Racine (forêt pétrifiée) : bois et pierre, tambours et marimba grave en do dorien.
	"impact@racine": {"peak": 0.6, "verb": 0.1, "room": 0.35, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.06, "att": 0.002, "filter": "bp", "cut": [1700.0, 600.0], "vol": 0.7, "res": 0.4, "decay": 2.4},
		{"inst": "drum", "f0": 170.0, "f1": 70.0, "dur": 0.12, "vol": 0.48, "noise": 0.25, "cut": 1000.0},
		{"inst": "drum", "f0": 320.0, "f1": 220.0, "dur": 0.05, "vol": 0.3, "noise": 0.4, "cut": 1400.0},
		{"wave": "grain", "dur": 0.08, "att": 0.01, "density": 200.0, "grain": 0.006, "cut": 900.0, "res": 0.4, "vol": 0.3}]},
	# Critique — Racine (forêt pétrifiée) : bois et pierre, tambours et marimba grave en do dorien.
	"critique@racine": {"peak": 0.75, "verb": 0.22, "room": 0.45, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.07, "att": 0.002, "filter": "bp", "cut": [2200.0, 800.0], "vol": 0.7, "res": 0.5, "decay": 2.2},
		{"inst": "drum", "f0": 200.0, "f1": 70.0, "dur": 0.14, "vol": 0.54, "noise": 0.3, "cut": 1200.0},
		{"inst": "drum", "f0": 320.0, "f1": 220.0, "dur": 0.06, "vol": 0.3, "noise": 0.4, "cut": 1400.0},
		{"inst": "mallet", "kind": "marimba", "f0": 261.6, "notes": [0, 7, 9], "step": 0.03, "dur": 0.5, "vol": 0.4}]},
	# Coup lourd — Racine (forêt pétrifiée) : bois et pierre, tambours et marimba grave en do dorien.
	"impact_lourd@racine": {"peak": 0.8, "verb": 0.16, "room": 0.5, "duck": 0.15, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1500.0, 220.0], "vol": 0.6, "res": 0.3, "decay": 2.0},
		{"inst": "drum", "f0": 120.0, "f1": 40.0, "dur": 0.36, "vol": 0.6, "noise": 0.5, "cut": 700.0},
		{"wave": SINE, "f0": 65.4, "f1": 52.32, "dur": 0.3, "att": 0.01, "vol": 0.3},
		{"inst": "drum", "f0": 320.0, "f1": 220.0, "dur": 0.05, "vol": 0.48, "noise": 0.4, "cut": 1400.0},
		{"wave": "grain", "dur": 0.08, "att": 0.01, "density": 200.0, "grain": 0.006, "cut": 900.0, "res": 0.4, "vol": 0.48}]},
	# Un ennemi meurt — Racine (forêt pétrifiée) : bois et pierre, tambours et marimba grave en do dorien.
	"mort@racine": {"peak": 0.62, "verb": 0.2, "room": 0.45, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "bp", "cut": [1300.0, 260.0], "vol": 0.5, "res": 0.35, "decay": 1.8},
		{"inst": "drum", "f0": 140.0, "f1": 45.0, "dur": 0.25, "vol": 0.42, "noise": 0.2, "cut": 800.0},
		{"wave": "grain", "dur": 0.4, "att": 0.01, "density": 140.0, "grain": 0.012, "cut": [900.0, 300.0], "res": 0.4, "vol": 0.5},
		{"inst": "mallet", "kind": "marimba", "f0": 130.8, "notes": [7, 0], "step": 0.08, "dur": 0.5, "vol": 0.35}]},
	# Une élite tombe — Racine (forêt pétrifiée) : bois et pierre, tambours et marimba grave en do dorien.
	"mort_elite@racine": {"peak": 0.85, "verb": 0.34, "room": 0.7, "duck": 0.3, "layers": [
		{"inst": "drum", "f0": 100.0, "f1": 32.0, "dur": 0.7, "vol": 0.6, "noise": 0.4, "cut": 500.0},
		{"wave": NOISE, "dur": 0.5, "att": 0.002, "filter": "lp", "cut": [1800.0, 160.0], "vol": 0.5, "res": 0.3, "decay": 1.6},
		{"inst": "bow", "f0": 65.4, "notes": [0, 3, 7], "dur": 0.8, "att": 0.02, "cut": 900.0, "vol": 0.35},
		{"inst": "tone", "tone": "cello", "f0": 65.4, "notes": [3, 0], "step": 0.25, "dur": 0.5, "vol": 0.35},
		{"inst": "drum", "f0": 70.0, "f1": 40.0, "dur": 0.5, "vol": 0.36, "delay": 0.2}]},
	# Un Cœur purifié — Racine (forêt pétrifiée) : bois et pierre, tambours et marimba grave en do dorien.
	"coeur@racine": {"peak": 0.72, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"inst": "bow", "f0": 65.4, "notes": [0, 7, 12, 16], "dur": 2.4, "att": 0.6, "cut": 1200.0, "vol": 0.4},
		{"inst": "mallet", "kind": "bell", "f0": 261.6, "notes": [0], "step": 0.0, "dur": 2.0, "vol": 0.3},
		{"wave": SINE, "f0": 65.4, "f1": 65.4, "dur": 2.2, "att": 0.05, "vol": 0.35, "decay": 1.2},
		{"inst": "mallet", "kind": "marimba", "f0": 261.6, "notes": [0, 4, 7, 9, 12, 16], "step": 0.12, "dur": 0.8, "vol": 0.4},
		{"inst": "tone", "tone": "cello", "f0": 130.8, "notes": [0, 4, 7], "step": 0.35, "dur": 0.9, "vol": 0.25},
		{"inst": "drum", "f0": 60.0, "f1": 40.0, "dur": 0.8, "vol": 0.3},
		{"inst": "choir", "vowel": "o", "f0": 130.8, "notes": [0, 4, 7], "step": 0.0, "dur": 2.2, "vol": 0.3}]},
}


## Noms de fichiers d'un son : <nom> puis <nom>__2, <nom>__3… pour ses variantes.
static func variant_names(name: String) -> Array:
	var out := [name]
	for v in range(2, int(SOUNDS[name].get("variants", 1)) + 1):
		out.append("%s__%d" % [name, v])
	return out


## Rend un bruitage décrit dans SOUNDS (échantillons entre -1 et 1). variant : 0 pour le son de base,
## 1, 2… pour ses variantes (hauteur et hasard légèrement décalés).
static func render(name: String, variant := 0) -> PackedFloat32Array:
	var p: Dictionary = SOUNDS[name]
	var layers: Array = p.get("layers", [p])
	var verb := float(p.get("verb", 0.0))
	var room := float(p.get("room", 0.5))
	var length := 0.0
	for l in layers:
		var span := float(l.get("step", 0.0)) * maxf(0.0, float(l.get("notes", [0]).size() - 1))
		length = maxf(length, float(l.get("delay", 0.0)) + span + float(l["dur"]) + (0.3 if l.has("inst") else 0.0))
	var tail := (0.15 + 0.7 * room) if verb > 0.0 else 0.0
	var out := PackedFloat32Array()
	out.resize(int((length + tail) * RATE) + 1)
	var pitch: float = 1.0 + [0.0, -0.045, 0.05, -0.02, 0.025][variant % 5]
	for li in layers.size():
		_render_layer(out, layers[li], hash(name) + li * 7919 + variant * 104729, pitch)
	if verb > 0.0:
		Dsp.reverb(out, verb, room, 0.4)
	# Extinction forcée sur les 25 dernières millisecondes (aucun clic en fin de fichier).
	var fade := int(0.025 * RATE)
	for i in fade:
		out[out.size() - 1 - i] *= float(i) / fade
	return Dsp.normalize(out, float(p.get("peak", 0.6)))


static func _render_layer(out: PackedFloat32Array, l: Dictionary, seed: int, pitch: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if l.has("inst"):
		_render_inst(out, l, rng, pitch)
		return
	if str(l.get("wave", "")) == "grain":
		_render_grains(out, l, rng)
		return
	var wave := int(l.get("wave", SINE))
	var dur := float(l["dur"])
	var n := int(dur * RATE)
	var i0 := int(float(l.get("delay", 0.0)) * RATE)
	var f0 := float(l.get("f0", 440.0)) * pitch
	var f1 := float(l.get("f1", l.get("f0", 440.0))) * pitch
	var lin := str(l.get("glide", "exp")) == "lin"
	var att := maxf(float(l.get("att", 0.002)), 0.0005)
	var decay := float(l.get("decay", 1.6))
	var vol := float(l.get("vol", 1.0))
	var duty := float(l.get("duty", 0.5))
	var arp: Array = l.get("arp", [])
	var vib: Array = l.get("vib", [0.0, 0.0])
	var trem: Array = l.get("trem", [0.0, 0.0])
	var fm: Array = l.get("fm", [0.0, 0.0])
	var v2 := float(l.get("voice2", 0.0))
	var has_v2 := l.has("voice2")
	var drv := float(l.get("drive", 0.0))
	var crush := float(l.get("crush", 0.0))
	var click := bool(l.get("click", false))
	var svf = null
	var cut0 := 0.0
	var cut1 := 0.0
	if l.has("filter"):
		var c = l.get("cut", 1000.0)
		cut0 = float(c[0]) if c is Array else float(c)
		cut1 = float(c[1]) if c is Array else cut0
		svf = Dsp.Svf.new({"lp": 0, "hp": 1, "bp": 2}.get(str(l["filter"]), 0), cut0, float(l.get("res", 0.0)))
	var res := float(l.get("res", 0.0))
	var phase := 0.0
	var phase2 := 0.0
	var held := 0.0
	var hold_acc := 1.0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var f: float = lerpf(f0, f1, k) if lin else f0 * pow(f1 / f0, k)
		if arp.size() > 0:
			var step := mini(arp.size() - 1, int(k * arp.size()))
			f = f0 * pow(2.0, float(arp[step]) / 12.0)
		f *= 1.0 + float(vib[0]) * sin(TAU * float(vib[1]) * t)
		phase += f / RATE
		var env := minf(1.0, t / att) * pow(1.0 - k, decay)
		var s := 0.0
		if wave == NOISE:
			if crush > 0.0:
				hold_acc += crush / RATE
				if hold_acc >= 1.0:
					hold_acc -= 1.0
					held = rng.randf_range(-1.0, 1.0)
				s = held
			else:
				s = rng.randf_range(-1.0, 1.0)
		elif wave == SINE and float(fm[1]) > 0.0:
			s = sin(TAU * phase + float(fm[1]) * env * sin(TAU * phase * float(fm[0])))
		else:
			s = Dsp.osc(wave, phase, f / RATE, duty, rng)
		if has_v2 and wave != NOISE:
			phase2 += f * pow(2.0, v2 / 12.0) / RATE
			s = s * 0.65 + Dsp.osc(wave, phase2, f * pow(2.0, v2 / 12.0) / RATE, duty, rng) * 0.4
		if click and t < 0.004:
			s += rng.randf_range(-1.0, 1.0)
		if svf != null:
			if cut1 != cut0 and i % 16 == 0:
				svf.set_params(cut0 * pow(cut1 / cut0, k), res)
			s = svf.process(s)
		if drv > 0.0:
			s = Dsp.drive(s, drv)
		if float(trem[0]) > 0.0:
			s *= 1.0 - float(trem[0]) * (0.5 + 0.5 * sin(TAU * float(trem[1]) * t))
		var j := i0 + i
		if j < out.size():
			out[j] += s * env * vol


## Couche « inst » : un instrument de la musique (music_synth.gd), joué une fois ou en suite de notes.
## inst : mallet (kind : marimba, kalimba, glock, piano, bell), pluck (tone 0 à 1, damp), tone (tone : flute,
## clarinet, horn, horns, cello, glass), bow (section de cordes, accord « notes » tenu), choir (vowel), drum
## (f0 → f1, peau grave). notes : demi-tons au-dessus de f0, joués tous les « step » secondes (0 : ensemble).
static func _render_inst(out: PackedFloat32Array, l: Dictionary, rng: RandomNumberGenerator, pitch: float) -> void:
	var inst := str(l["inst"])
	var f0 := float(l.get("f0", 220.0)) * pitch
	var dur := float(l["dur"])
	var t0 := float(l.get("delay", 0.0))
	var vol := float(l.get("vol", 1.0))
	var notes: Array = l.get("notes", [0])
	var step := float(l.get("step", 0.0))
	if inst == "bow":
		var freqs: Array = []
		for nt in notes:
			freqs.append(f0 * pow(2.0, float(nt) / 12.0))
		MusicSynth._ensemble(out, t0, dur, freqs, vol * 2.0, float(l.get("cut", 1200.0)), rng, float(l.get("att", 0.2)))
		return
	for k in notes.size():
		var f := f0 * pow(2.0, float(notes[k]) / 12.0)
		var t := t0 + step * k
		var v := vol * (1.0 - 0.12 * k / maxf(1.0, notes.size()))
		match inst:
			"mallet":
				MusicSynth._mallet(out, t, f, v * 2.2, str(l.get("kind", "marimba")), dur)
			"pluck":
				MusicSynth._pluck(out, t, f, v * 1.6, dur, float(l.get("tone", 0.4)), float(l.get("damp", 0.45)), rng)
			"tone":
				MusicSynth._tone(out, str(l.get("tone", "horn")), t, dur, f, v * 2.4, rng)
			"choir":
				MusicSynth._choir(out, t, dur, f, v * 3.0, str(l.get("vowel", "o")), rng)
			"drum":
				MusicSynth._hit(out, t, dur, f, float(l.get("f1", f0 * 0.5)) * pitch, v * 1.6, 1.0, float(l.get("noise", 0.0)), float(l.get("cut", 800.0)), rng)


## Couche « grain » : nuée de petits grains de bruit filtré (feuilles, épines, graviers, bulles qui crépitent).
## density (grains par seconde), grain (durée d'un grain, s), cut (bande, Hz, ou [départ, arrivée]), res,
## pitch_spread (écart de la bande d'un grain à l'autre, en part), et l'enveloppe habituelle (att, decay).
static func _render_grains(out: PackedFloat32Array, l: Dictionary, rng: RandomNumberGenerator) -> void:
	var dur := float(l["dur"])
	var i0 := int(float(l.get("delay", 0.0)) * RATE)
	var att := maxf(float(l.get("att", 0.002)), 0.0005)
	var decay := float(l.get("decay", 1.6))
	var vol := float(l.get("vol", 1.0))
	var c = l.get("cut", 1500.0)
	var cut0 := float(c[0]) if c is Array else float(c)
	var cut1 := float(c[1]) if c is Array else cut0
	var gdur := float(l.get("grain", 0.012))
	var spread := float(l.get("pitch_spread", 0.3))
	var count := int(float(l.get("density", 60.0)) * dur)
	var gn := int(gdur * RATE)
	for g in count:
		var k := rng.randf()
		var start := i0 + int(k * dur * RATE)
		var env := minf(1.0, k * dur / att) * pow(1.0 - k, decay)
		var fc := cut0 * pow(cut1 / cut0, k) * (1.0 + rng.randf_range(-spread, spread))
		var svf := Dsp.Svf.new(2, fc, float(l.get("res", 0.5)))
		var gv := vol * env * rng.randf_range(0.5, 1.0)
		for i in gn:
			var j := start + i
			if j >= out.size():
				break
			var w := sin(PI * float(i) / gn)
			out[j] += svf.process(rng.randf_range(-1.0, 1.0)) * w * w * gv


# --- Musique et ambiance (music_synth.gd) ------------------------------------------------------------

## Durée d'un accord ; une boucle en a 8 (A puis B) : 8 × 3 s = 24 s.
const CHORD_TIME := MusicSynth.CHORD_TIME
const ROOTS := MusicSynth.ROOTS
## Couches de musique d'une région, dans l'ordre : nom de fichier → rôle.
const MUSIC_LAYERS := MusicSynth.LAYERS


## Couche de musique « layer » (sombre, lumineux, combat, coeur, boss) d'un style de région ({} : Ronce).
static func music_layer(layer: String, style := {}) -> PackedFloat32Array:
	return MusicSynth.render(layer, style)


static func music_dark(style := {}) -> PackedFloat32Array:
	return MusicSynth.render("sombre", style)


static func music_bright(style := {}) -> PackedFloat32Array:
	return MusicSynth.render("lumineux", style)


## Nappe d'ambiance (vent, oiseaux, eau…) d'une région : state "mort" ou "vif".
static func ambience_bed(state: String, bed := {}) -> PackedFloat32Array:
	return MusicSynth.render_bed(state, bed)


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
