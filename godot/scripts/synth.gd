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
const VERSION := 2

const SOUNDS := {
	# --- Combat : coups, critiques, morts ------------------------------------------------------------------
	# Un coup = un claquement bref (bruit filtré qui descend) + un coup sourd (sinus qui chute) + un clic.
	"tir": {"peak": 0.34, "verb": 0.06, "room": 0.3, "layers": [
		{"wave": NOISE, "dur": 0.07, "att": 0.002, "filter": "bp", "cut": [3800.0, 1500.0], "res": 0.5, "vol": 0.8, "decay": 2.2},
		{"wave": TRI, "f0": 820.0, "f1": 360.0, "dur": 0.08, "att": 0.002, "vol": 0.5, "decay": 2.0}]},
	"impact": {"peak": 0.6, "verb": 0.08, "room": 0.35, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.014, "att": 0.0005, "filter": "hp", "cut": 2500.0, "vol": 0.6},
		{"wave": NOISE, "dur": 0.075, "att": 0.001, "filter": "bp", "cut": [2600.0, 800.0], "res": 0.45, "vol": 0.9, "decay": 2.4},
		{"wave": SINE, "f0": 190.0, "f1": 70.0, "dur": 0.1, "att": 0.001, "vol": 0.6, "drive": 0.35, "decay": 1.8}]},
	"impact_lourd": {"peak": 0.8, "verb": 0.16, "room": 0.5, "duck": 0.15, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.02, "att": 0.0005, "filter": "hp", "cut": 2000.0, "vol": 0.7},
		{"wave": NOISE, "dur": 0.2, "att": 0.001, "filter": "lp", "cut": [2200.0, 260.0], "res": 0.3, "vol": 0.9, "crush": 2400.0, "decay": 2.0},
		{"wave": SINE, "f0": 130.0, "f1": 42.0, "dur": 0.26, "att": 0.001, "vol": 1.0, "drive": 0.6, "decay": 1.5},
		{"wave": SINE, "f0": 58.0, "f1": 50.0, "dur": 0.32, "att": 0.01, "vol": 0.6, "decay": 1.3}]},
	"critique": {"peak": 0.75, "verb": 0.22, "room": 0.45, "variants": 2, "layers": [
		{"wave": NOISE, "dur": 0.016, "att": 0.0005, "filter": "hp", "cut": 3000.0, "vol": 0.7},
		{"wave": NOISE, "dur": 0.09, "att": 0.001, "filter": "bp", "cut": [3400.0, 1200.0], "res": 0.55, "vol": 0.8, "decay": 2.2},
		{"wave": SINE, "f0": 230.0, "f1": 75.0, "dur": 0.12, "att": 0.001, "vol": 0.55, "drive": 0.4},
		{"wave": METAL, "f0": 1480.0, "f1": 1440.0, "dur": 0.42, "att": 0.001, "vol": 0.42, "decay": 2.4},
		{"wave": SAW, "f0": 900.0, "f1": 2300.0, "dur": 0.13, "att": 0.004, "delay": 0.01, "filter": "bp", "cut": [1600.0, 4200.0], "res": 0.4, "vol": 0.35}]},
	"mort": {"peak": 0.62, "verb": 0.18, "room": 0.45, "variants": 3, "layers": [
		{"wave": NOISE, "dur": 0.3, "att": 0.002, "filter": "bp", "cut": [1800.0, 280.0], "res": 0.35, "vol": 0.9, "crush": 3000.0, "decay": 1.8},
		{"wave": SINE, "f0": 150.0, "f1": 46.0, "dur": 0.26, "att": 0.001, "vol": 0.6, "drive": 0.4},
		{"wave": TRI, "f0": 460.0, "f1": 120.0, "dur": 0.3, "att": 0.01, "delay": 0.03, "vol": 0.35, "vib": [0.04, 18.0]},
		{"wave": NOISE, "dur": 0.32, "att": 0.05, "delay": 0.08, "filter": "lp", "cut": [900.0, 200.0], "vol": 0.45, "crush": 700.0, "trem": [0.7, 23.0]}]},
	"mort_elite": {"peak": 0.85, "verb": 0.34, "room": 0.7, "duck": 0.3, "layers": [
		{"wave": NOISE, "dur": 0.03, "att": 0.0005, "filter": "hp", "cut": 2200.0, "vol": 0.7},
		{"wave": NOISE, "dur": 0.55, "att": 0.002, "filter": "lp", "cut": [2600.0, 160.0], "res": 0.3, "vol": 0.9, "crush": 2600.0, "decay": 1.6},
		{"wave": SINE, "f0": 100.0, "f1": 30.0, "dur": 0.7, "att": 0.002, "vol": 1.0, "drive": 0.55, "decay": 1.3},
		{"wave": METAL, "f0": 340.0, "f1": 300.0, "dur": 0.9, "att": 0.002, "vol": 0.35, "decay": 1.8},
		{"wave": NOISE, "dur": 0.45, "att": 0.01, "delay": 0.05, "filter": "hp", "cut": [5000.0, 2500.0], "vol": 0.3, "trem": [0.8, 31.0]},
		{"wave": TRI, "f0": 620.0, "f1": 110.0, "dur": 0.6, "att": 0.02, "delay": 0.06, "vol": 0.3, "vib": [0.05, 9.0], "voice2": -5.0}]},
	"degats": {"peak": 0.7, "verb": 0.1, "room": 0.35, "layers": [
		{"wave": NOISE, "dur": 0.05, "att": 0.001, "filter": "bp", "cut": [1800.0, 600.0], "res": 0.4, "vol": 0.7},
		{"wave": SAW, "f0": 210.0, "f1": 70.0, "dur": 0.24, "att": 0.002, "filter": "lp", "cut": [1600.0, 400.0], "vol": 0.7, "drive": 0.5},
		{"wave": SINE, "f0": 160.0, "f1": 55.0, "dur": 0.22, "att": 0.001, "vol": 0.9, "drive": 0.3}]},
	"etourdi": {"peak": 0.5, "verb": 0.25, "room": 0.4, "layers": [
		{"wave": SQUARE, "f0": 300.0, "f1": 110.0, "dur": 0.26, "att": 0.002, "duty": 0.25, "filter": "lp", "cut": 1800.0, "vol": 0.6},
		{"wave": SINE, "f0": 70.0, "f1": 60.0, "dur": 0.2, "att": 0.002, "vol": 0.6},
		{"wave": METAL, "f0": 2100.0, "f1": 2300.0, "dur": 0.5, "att": 0.01, "delay": 0.06, "vol": 0.3, "vib": [0.04, 7.0], "arp": [0, 4, 0, 4]}]},
	"chute": {"peak": 0.6, "verb": 0.5, "room": 0.85, "duck": 0.5, "layers": [
		{"wave": SINE, "f0": 330.0, "f1": 98.0, "dur": 1.5, "att": 0.02, "vol": 0.7, "voice2": -5.0, "vib": [0.015, 5.0]},
		{"wave": SAW, "f0": 165.0, "f1": 49.0, "dur": 1.5, "att": 0.1, "filter": "lp", "cut": [900.0, 160.0], "vol": 0.4},
		{"wave": NOISE, "dur": 1.2, "att": 0.3, "filter": "bp", "cut": [900.0, 250.0], "res": 0.5, "vol": 0.25},
		{"wave": SINE, "f0": 60.0, "f1": 38.0, "dur": 1.0, "att": 0.005, "vol": 0.6}]},
	"esquive": {"peak": 0.42, "verb": 0.08, "room": 0.3, "layers": [
		{"wave": NOISE, "dur": 0.2, "att": 0.05, "filter": "bp", "cut": [700.0, 3600.0], "res": 0.6, "vol": 0.9, "decay": 1.2},
		{"wave": NOISE, "dur": 0.12, "att": 0.03, "delay": 0.04, "filter": "hp", "cut": 4000.0, "vol": 0.25}]},
	# --- Compétences de Ronce et du socle ------------------------------------------------------------------
	"nova": {"peak": 0.8, "verb": 0.35, "room": 0.6, "duck": 0.15, "layers": [
		{"wave": SINE, "f0": 150.0, "f1": 38.0, "dur": 0.6, "att": 0.002, "vol": 1.0, "drive": 0.5, "decay": 1.4},
		{"wave": NOISE, "dur": 0.5, "att": 0.003, "filter": "lp", "cut": [3200.0, 200.0], "res": 0.2, "vol": 0.7},
		{"wave": NOISE, "dur": 0.35, "att": 0.002, "filter": "bp", "cut": [5200.0, 2200.0], "res": 0.6, "vol": 0.35, "trem": [0.6, 40.0]},
		{"wave": METAL, "f0": 620.0, "f1": 560.0, "dur": 0.7, "att": 0.002, "vol": 0.25}]},
	"nuage": {"peak": 0.45, "verb": 0.3, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.6, "att": 0.14, "filter": "bp", "cut": [1300.0, 450.0], "res": 0.45, "vol": 0.8, "trem": [0.35, 9.0], "decay": 1.2},
		{"wave": SINE, "f0": 240.0, "f1": 520.0, "dur": 0.16, "att": 0.01, "delay": 0.1, "vol": 0.25},
		{"wave": SINE, "f0": 300.0, "f1": 640.0, "dur": 0.14, "att": 0.01, "delay": 0.28, "vol": 0.2}]},
	"floraison": {"peak": 0.5, "verb": 0.5, "room": 0.7, "layers": [
		{"wave": SINE, "f0": 330.0, "dur": 0.95, "att": 0.03, "vol": 0.6, "arp": [0, 4, 7, 11, 16], "voice2": 12.0, "decay": 1.2},
		{"wave": TRI, "f0": 660.0, "dur": 0.9, "att": 0.05, "vol": 0.3, "arp": [0, 7, 11, 16, 19], "vib": [0.01, 6.0]},
		{"wave": NOISE, "dur": 0.7, "att": 0.25, "filter": "hp", "cut": 5000.0, "vol": 0.12}]},
	"fouet": {"peak": 0.62, "verb": 0.12, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.12, "att": 0.07, "filter": "bp", "cut": [1200.0, 5200.0], "res": 0.55, "vol": 0.7, "decay": 0.8},
		{"wave": NOISE, "dur": 0.045, "att": 0.0005, "delay": 0.1, "filter": "hp", "cut": 2200.0, "vol": 1.0, "click": true, "decay": 2.5},
		{"wave": SINE, "f0": 260.0, "f1": 120.0, "dur": 0.08, "att": 0.001, "delay": 0.1, "vol": 0.5}]},
	"racines": {"peak": 0.66, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": SAW, "f0": 70.0, "f1": 140.0, "dur": 0.5, "att": 0.08, "filter": "lp", "cut": [300.0, 900.0], "res": 0.4, "vol": 0.7, "vib": [0.06, 14.0], "drive": 0.4},
		{"wave": SQUARE, "f0": 95.0, "f1": 80.0, "dur": 0.4, "att": 0.02, "duty": 0.12, "filter": "bp", "cut": 600.0, "res": 0.6, "vol": 0.35, "trem": [0.8, 17.0]},
		{"wave": NOISE, "dur": 0.45, "att": 0.05, "filter": "lp", "cut": [700.0, 250.0], "vol": 0.5, "crush": 800.0}]},
	"volee": {"peak": 0.5, "verb": 0.1, "room": 0.35, "layers": [
		{"wave": NOISE, "dur": 0.16, "att": 0.03, "filter": "bp", "cut": [1800.0, 4200.0], "res": 0.5, "vol": 0.5},
		{"wave": NOISE, "dur": 0.03, "att": 0.0005, "filter": "bp", "cut": 3400.0, "res": 0.6, "vol": 0.8, "click": true},
		{"wave": NOISE, "dur": 0.03, "att": 0.0005, "delay": 0.035, "filter": "bp", "cut": 2900.0, "res": 0.6, "vol": 0.7},
		{"wave": NOISE, "dur": 0.03, "att": 0.0005, "delay": 0.07, "filter": "bp", "cut": 3800.0, "res": 0.6, "vol": 0.6}]},
	"saignee": {"peak": 0.66, "verb": 0.22, "room": 0.5, "layers": [
		{"wave": SAW, "f0": 70.0, "f1": 220.0, "dur": 0.45, "att": 0.01, "filter": "lp", "cut": [500.0, 1300.0], "res": 0.5, "vol": 0.6, "drive": 0.4},
		{"wave": NOISE, "dur": 0.4, "att": 0.02, "filter": "bp", "cut": [600.0, 1100.0], "res": 0.7, "vol": 0.45, "trem": [0.9, 26.0]},
		{"wave": SINE, "f0": 70.0, "f1": 52.0, "dur": 0.16, "att": 0.002, "vol": 0.8},
		{"wave": SINE, "f0": 70.0, "f1": 52.0, "dur": 0.16, "att": 0.002, "delay": 0.2, "vol": 0.6}]},
	# --- Annonces : un coup va partir (boss, élites) --------------------------------------------------------
	# Grave pour tous les boss (choix d'Antoine à l'écoute, 25/11 : l'ancienne « annonce_boss » sert partout).
	"annonce": {"peak": 0.72, "verb": 0.35, "room": 0.75, "layers": [
		{"wave": METAL, "f0": 220.0, "f1": 210.0, "dur": 0.8, "att": 0.002, "vol": 0.4, "decay": 1.6},
		{"wave": SAW, "f0": 110.0, "f1": 110.0, "dur": 0.9, "att": 0.25, "filter": "lp", "cut": [300.0, 2200.0], "res": 0.45, "vol": 0.6, "voice2": 7.0, "drive": 0.3},
		{"wave": SINE, "f0": 55.0, "f1": 55.0, "dur": 0.9, "att": 0.2, "vol": 0.5},
		{"wave": NOISE, "dur": 0.8, "att": 0.6, "filter": "hp", "cut": [600.0, 5000.0], "vol": 0.25}]},
	# --- Progression, Cœurs, ramassage --------------------------------------------------------------------
	"noeud": {"peak": 0.45, "verb": 0.4, "room": 0.6, "layers": [
		{"wave": SINE, "f0": 587.0, "dur": 0.4, "att": 0.004, "vol": 0.6, "arp": [0, 7, 12], "fm": [2.0, 1.2], "decay": 1.4},
		{"wave": METAL, "f0": 1760.0, "dur": 0.5, "att": 0.002, "delay": 0.02, "vol": 0.25}]},
	"niveau": {"peak": 0.55, "verb": 0.45, "room": 0.7, "duck": 0.2, "layers": [
		{"wave": TRI, "f0": 392.0, "dur": 0.75, "att": 0.005, "vol": 0.6, "arp": [0, 4, 7, 12, 16], "voice2": 12.0, "decay": 1.1},
		{"wave": SQUARE, "f0": 196.0, "dur": 0.75, "att": 0.005, "duty": 0.5, "filter": "lp", "cut": 1800.0, "vol": 0.25, "arp": [0, 4, 7, 12, 16]},
		{"wave": NOISE, "dur": 0.5, "att": 0.4, "filter": "bp", "cut": [1200.0, 6000.0], "res": 0.4, "vol": 0.2},
		{"wave": METAL, "f0": 2349.0, "dur": 0.7, "att": 0.002, "delay": 0.45, "vol": 0.25}]},
	"coeur": {"peak": 0.72, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"wave": SINE, "f0": 261.6, "dur": 2.2, "att": 0.02, "vol": 0.5, "arp": [0, 4, 7, 12, 16, 19], "voice2": 12.0, "decay": 1.0},
		{"wave": SAW, "f0": 130.8, "dur": 2.4, "att": 0.6, "filter": "bp", "cut": [600.0, 1100.0], "res": 0.5, "vol": 0.35, "voice2": 7.0, "vib": [0.008, 5.0], "decay": 1.0},
		{"wave": SINE, "f0": 65.4, "f1": 65.4, "dur": 2.2, "att": 0.05, "vol": 0.4, "decay": 1.2},
		{"wave": METAL, "f0": 1046.0, "dur": 1.6, "att": 0.002, "vol": 0.25},
		{"wave": NOISE, "dur": 1.6, "att": 0.8, "filter": "hp", "cut": [3000.0, 7000.0], "vol": 0.1}]},
	"ramasse": {"peak": 0.24, "verb": 0.12, "room": 0.3, "layers": [
		{"wave": SINE, "f0": 880.0, "f1": 1320.0, "dur": 0.09, "att": 0.002, "vol": 0.8, "voice2": 12.0},
		{"wave": SINE, "f0": 1760.0, "dur": 0.06, "att": 0.001, "delay": 0.02, "vol": 0.3, "fm": [3.5, 0.6]}]},
	"greffe": {"peak": 0.52, "verb": 0.45, "room": 0.7, "layers": [
		{"wave": TRI, "f0": 523.0, "dur": 0.6, "att": 0.004, "vol": 0.6, "arp": [0, 7, 12, 16], "voice2": 12.0},
		{"wave": METAL, "f0": 2093.0, "dur": 0.8, "att": 0.002, "delay": 0.1, "vol": 0.3},
		{"wave": NOISE, "dur": 0.5, "att": 0.2, "filter": "hp", "cut": 6000.0, "vol": 0.12}]},
	"seve": {"peak": 0.45, "verb": 0.45, "room": 0.6, "layers": [
		{"wave": SINE, "f0": 392.0, "dur": 0.75, "att": 0.01, "vol": 0.6, "arp": [0, 5, 9, 12], "vib": [0.01, 6.0]},
		{"wave": SINE, "f0": 1200.0, "f1": 600.0, "dur": 0.1, "att": 0.002, "vol": 0.3}]},
	# --- Interface ----------------------------------------------------------------------------------------
	"clic": {"peak": 0.2, "layers": [
		{"wave": SQUARE, "f0": 900.0, "f1": 700.0, "dur": 0.035, "att": 0.001, "duty": 0.5, "filter": "lp", "cut": 3200.0, "vol": 0.7},
		{"wave": NOISE, "dur": 0.008, "att": 0.0005, "filter": "hp", "cut": 3000.0, "vol": 0.3}]},
	"survol": {"peak": 0.1, "layers": [
		{"wave": SINE, "f0": 1200.0, "f1": 1400.0, "dur": 0.03, "att": 0.002, "vol": 1.0}]},
	# --- Spore (poison, nuages, propagation) : mouillé, sourd, granuleux ; rien de métallique. ---------------
	"spore_eclat": {"peak": 0.6, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.25, "att": 0.004, "filter": "lp", "cut": [1600.0, 300.0], "res": 0.3, "vol": 0.8, "crush": 1800.0},
		{"wave": SINE, "f0": 160.0, "f1": 60.0, "dur": 0.18, "att": 0.002, "vol": 0.8, "drive": 0.3},
		{"wave": SINE, "f0": 300.0, "f1": 900.0, "dur": 0.08, "att": 0.005, "delay": 0.1, "vol": 0.25},
		{"wave": SINE, "f0": 380.0, "f1": 1100.0, "dur": 0.07, "att": 0.005, "delay": 0.18, "vol": 0.2}]},
	"spore_nuage": {"peak": 0.48, "verb": 0.35, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.75, "att": 0.2, "filter": "bp", "cut": [900.0, 380.0], "res": 0.5, "vol": 0.8, "trem": [0.4, 7.0], "decay": 1.1},
		{"wave": SINE, "f0": 220.0, "f1": 600.0, "dur": 0.12, "att": 0.01, "delay": 0.15, "vol": 0.25},
		{"wave": SINE, "f0": 260.0, "f1": 700.0, "dur": 0.1, "att": 0.01, "delay": 0.35, "vol": 0.2},
		{"wave": SINE, "f0": 200.0, "f1": 520.0, "dur": 0.12, "att": 0.01, "delay": 0.5, "vol": 0.18}]},
	"spore_propage": {"peak": 0.45, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": SINE, "f0": 300.0, "dur": 0.5, "att": 0.02, "vol": 0.6, "arp": [0, 3, 6, 9, 12], "vib": [0.04, 11.0], "fm": [1.5, 0.8]},
		{"wave": NOISE, "dur": 0.4, "att": 0.05, "filter": "bp", "cut": [700.0, 1400.0], "res": 0.6, "vol": 0.3, "trem": [0.8, 19.0]}]},
	"spore_piege": {"peak": 0.5, "verb": 0.15, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.18, "att": 0.01, "filter": "lp", "cut": [700.0, 250.0], "vol": 0.7, "crush": 900.0},
		{"wave": SINE, "f0": 120.0, "f1": 180.0, "dur": 0.25, "att": 0.03, "vol": 0.6, "vib": [0.05, 12.0]},
		{"wave": SQUARE, "f0": 220.0, "f1": 110.0, "dur": 0.2, "att": 0.003, "duty": 0.25, "filter": "lp", "cut": 900.0, "vol": 0.3}]},
	"spore_toxine": {"peak": 0.58, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": SAW, "f0": 180.0, "f1": 520.0, "dur": 0.42, "att": 0.01, "filter": "bp", "cut": [500.0, 1500.0], "res": 0.6, "vol": 0.6, "voice2": 6.0, "vib": [0.05, 16.0]},
		{"wave": NOISE, "dur": 0.35, "att": 0.005, "filter": "lp", "cut": [1500.0, 400.0], "vol": 0.5, "crush": 1500.0},
		{"wave": SINE, "f0": 110.0, "f1": 55.0, "dur": 0.2, "att": 0.002, "vol": 0.6}]},
	"spore_flaque": {"peak": 0.5, "verb": 0.2, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.28, "att": 0.02, "filter": "bp", "cut": [600.0, 220.0], "res": 0.65, "vol": 0.8, "trem": [0.5, 13.0]},
		{"wave": SINE, "f0": 90.0, "f1": 60.0, "dur": 0.2, "att": 0.004, "vol": 0.6}]},
	"spore_division": {"peak": 0.45, "verb": 0.2, "room": 0.4, "layers": [
		{"wave": TRI, "f0": 420.0, "f1": 210.0, "dur": 0.24, "att": 0.004, "vol": 0.6, "voice2": -12.0, "vib": [0.1, 20.0]},
		{"wave": SINE, "f0": 500.0, "f1": 1200.0, "dur": 0.08, "att": 0.004, "delay": 0.12, "vol": 0.3}]},
	"spore_boss_eveil": {"peak": 0.82, "verb": 0.5, "room": 0.85, "duck": 0.6, "layers": [
		{"wave": SAW, "f0": 70.0, "f1": 190.0, "dur": 1.2, "att": 0.45, "filter": "lp", "cut": [250.0, 1200.0], "res": 0.5, "vol": 0.7, "voice2": -3.0, "vib": [0.05, 6.0], "drive": 0.3},
		{"wave": NOISE, "dur": 1.1, "att": 0.5, "filter": "bp", "cut": [300.0, 900.0], "res": 0.6, "vol": 0.4, "trem": [0.5, 5.0]},
		{"wave": SINE, "f0": 45.0, "f1": 55.0, "dur": 1.2, "att": 0.3, "vol": 0.6}]},
	"spore_boss_phase": {"peak": 0.8, "verb": 0.4, "room": 0.75, "duck": 0.4, "layers": [
		{"wave": SAW, "f0": 240.0, "f1": 90.0, "dur": 0.9, "att": 0.02, "filter": "lp", "cut": [1600.0, 300.0], "res": 0.5, "vol": 0.7, "voice2": 1.0, "vib": [0.08, 9.0]},
		{"wave": NOISE, "dur": 0.7, "att": 0.01, "filter": "lp", "cut": [1400.0, 200.0], "vol": 0.5, "crush": 1200.0},
		{"wave": SINE, "f0": 90.0, "f1": 35.0, "dur": 0.7, "att": 0.002, "vol": 0.8, "drive": 0.4}]},
	"spore_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": SINE, "f0": 220.0, "f1": 60.0, "dur": 2.0, "att": 0.02, "vol": 0.7, "voice2": -5.0, "vib": [0.04, 4.0]},
		{"wave": NOISE, "dur": 1.6, "att": 0.005, "filter": "lp", "cut": [2400.0, 120.0], "vol": 0.6, "crush": 2000.0},
		{"wave": SINE, "f0": 70.0, "f1": 28.0, "dur": 1.4, "att": 0.002, "vol": 0.8, "drive": 0.5},
		{"wave": SINE, "f0": 330.0, "f1": 990.0, "dur": 0.2, "att": 0.01, "delay": 0.5, "vol": 0.2},
		{"wave": SINE, "f0": 280.0, "f1": 840.0, "dur": 0.2, "att": 0.01, "delay": 0.8, "vol": 0.18}]},
	# --- Vent (vitesse, projectiles, mobilité) : souffles et sifflements clairs. -----------------------------
	"vent_lame": {"peak": 0.45, "verb": 0.1, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.13, "att": 0.03, "filter": "bp", "cut": [2400.0, 6500.0], "res": 0.7, "vol": 0.7},
		{"wave": SAW, "f0": 2600.0, "f1": 1800.0, "dur": 0.08, "att": 0.002, "filter": "bp", "cut": 3000.0, "res": 0.5, "vol": 0.3, "click": true}]},
	"vent_rafale": {"peak": 0.5, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.42, "att": 0.1, "filter": "bp", "cut": [900.0, 4200.0], "res": 0.65, "vol": 0.8, "decay": 1.2},
		{"wave": NOISE, "dur": 0.3, "att": 0.1, "delay": 0.08, "filter": "bp", "cut": [1800.0, 5600.0], "res": 0.7, "vol": 0.35}]},
	"vent_tornade": {"peak": 0.6, "verb": 0.3, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.95, "att": 0.25, "filter": "bp", "cut": [500.0, 2600.0], "res": 0.75, "vol": 0.8, "trem": [0.4, 6.0], "decay": 1.1},
		{"wave": NOISE, "dur": 0.9, "att": 0.3, "filter": "bp", "cut": [1200.0, 3600.0], "res": 0.8, "vol": 0.4, "trem": [0.5, 11.0]},
		{"wave": SINE, "f0": 80.0, "f1": 110.0, "dur": 0.9, "att": 0.2, "vol": 0.4}]},
	"vent_ruee": {"peak": 0.6, "verb": 0.12, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.26, "att": 0.02, "filter": "bp", "cut": [600.0, 5000.0], "res": 0.6, "vol": 0.9, "decay": 1.2},
		{"wave": SINE, "f0": 140.0, "f1": 60.0, "dur": 0.15, "att": 0.002, "vol": 0.7, "drive": 0.3},
		{"wave": NOISE, "dur": 0.015, "att": 0.0005, "filter": "hp", "cut": 3000.0, "vol": 0.5}]},
	"vent_appel": {"peak": 0.55, "verb": 0.3, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.65, "att": 0.45, "filter": "bp", "cut": [3800.0, 500.0], "res": 0.7, "vol": 0.8, "decay": 0.8},
		{"wave": SINE, "f0": 160.0, "f1": 420.0, "dur": 0.6, "att": 0.2, "vol": 0.4, "vib": [0.06, 8.0]},
		{"wave": SINE, "f0": 70.0, "f1": 50.0, "dur": 0.2, "att": 0.002, "delay": 0.55, "vol": 0.6}]},
	"vent_plongeon": {"peak": 0.55, "verb": 0.15, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.28, "att": 0.15, "filter": "bp", "cut": [5000.0, 900.0], "res": 0.7, "vol": 0.8, "decay": 0.9},
		{"wave": SINE, "f0": 120.0, "f1": 50.0, "dur": 0.15, "att": 0.002, "delay": 0.24, "vol": 0.8, "drive": 0.4}]},
	"vent_repousse": {"peak": 0.6, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": NOISE, "dur": 0.32, "att": 0.004, "filter": "lp", "cut": [2400.0, 400.0], "vol": 0.8},
		{"wave": SINE, "f0": 110.0, "f1": 40.0, "dur": 0.28, "att": 0.002, "vol": 0.9, "drive": 0.4},
		{"wave": NOISE, "dur": 0.3, "att": 0.05, "filter": "bp", "cut": [1500.0, 4000.0], "res": 0.6, "vol": 0.35}]},
	"vent_boss_eveil": {"peak": 0.82, "verb": 0.5, "room": 0.9, "duck": 0.6, "layers": [
		{"wave": NOISE, "dur": 1.3, "att": 0.55, "filter": "bp", "cut": [400.0, 3400.0], "res": 0.75, "vol": 0.8, "trem": [0.3, 4.0]},
		{"wave": SAW, "f0": 110.0, "f1": 220.0, "dur": 1.2, "att": 0.5, "filter": "lp", "cut": [400.0, 2000.0], "vol": 0.4, "voice2": 7.0},
		{"wave": METAL, "f0": 880.0, "dur": 1.0, "att": 0.002, "delay": 1.0, "vol": 0.3},
		{"wave": SINE, "f0": 55.0, "f1": 50.0, "dur": 1.2, "att": 0.4, "vol": 0.5}]},
	"vent_boss_phase": {"peak": 0.8, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.85, "att": 0.02, "filter": "bp", "cut": [4200.0, 600.0], "res": 0.7, "vol": 0.8},
		{"wave": SINE, "f0": 100.0, "f1": 35.0, "dur": 0.6, "att": 0.002, "vol": 0.8, "drive": 0.4},
		{"wave": METAL, "f0": 660.0, "dur": 0.8, "att": 0.002, "vol": 0.25}]},
	"vent_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": SINE, "f0": 520.0, "f1": 90.0, "dur": 1.9, "att": 0.02, "vol": 0.6, "voice2": 7.0, "vib": [0.05, 7.0]},
		{"wave": NOISE, "dur": 1.8, "att": 0.01, "filter": "bp", "cut": [3000.0, 300.0], "res": 0.6, "vol": 0.6},
		{"wave": SINE, "f0": 80.0, "f1": 28.0, "dur": 1.2, "att": 0.002, "vol": 0.8, "drive": 0.5},
		{"wave": METAL, "f0": 1320.0, "dur": 1.4, "att": 0.002, "delay": 0.6, "vol": 0.25}]},
	# --- Sève (vie, eau, régénération) : gouttes, clochettes, eau vive. -------------------------------------
	"seve_goutte": {"peak": 0.45, "verb": 0.3, "room": 0.5, "layers": [
		{"wave": SINE, "f0": 1400.0, "f1": 520.0, "dur": 0.14, "att": 0.002, "vol": 0.8, "decay": 2.0},
		{"wave": SINE, "f0": 900.0, "f1": 1300.0, "dur": 0.06, "att": 0.002, "delay": 0.05, "vol": 0.3}]},
	"seve_pousse": {"peak": 0.48, "verb": 0.35, "room": 0.55, "layers": [
		{"wave": TRI, "f0": 260.0, "dur": 0.5, "att": 0.05, "vol": 0.6, "arp": [0, 4, 7, 12], "vib": [0.03, 7.0]},
		{"wave": NOISE, "dur": 0.35, "att": 0.1, "filter": "lp", "cut": [400.0, 1500.0], "vol": 0.3, "crush": 1200.0}]},
	"seve_soin": {"peak": 0.48, "verb": 0.5, "room": 0.7, "layers": [
		{"wave": SINE, "f0": 440.0, "dur": 0.85, "att": 0.06, "vol": 0.6, "arp": [0, 7, 12, 16], "voice2": 12.0, "vib": [0.01, 5.0]},
		{"wave": SINE, "f0": 220.0, "dur": 0.9, "att": 0.2, "vol": 0.35, "fm": [2.0, 0.5]}]},
	"seve_source": {"peak": 0.45, "verb": 0.35, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.65, "att": 0.15, "filter": "bp", "cut": [1600.0, 900.0], "res": 0.5, "vol": 0.6, "trem": [0.6, 13.0]},
		{"wave": SINE, "f0": 1100.0, "f1": 700.0, "dur": 0.1, "att": 0.002, "delay": 0.1, "vol": 0.3},
		{"wave": SINE, "f0": 1300.0, "f1": 800.0, "dur": 0.09, "att": 0.002, "delay": 0.3, "vol": 0.25}]},
	"seve_eclosion": {"peak": 0.5, "verb": 0.45, "room": 0.65, "layers": [
		{"wave": SINE, "f0": 300.0, "dur": 0.6, "att": 0.08, "vol": 0.6, "arp": [0, 4, 9, 14], "voice2": 12.0},
		{"wave": NOISE, "dur": 0.4, "att": 0.2, "filter": "hp", "cut": 4000.0, "vol": 0.15}]},
	"seve_lien": {"peak": 0.5, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": SAW, "f0": 150.0, "f1": 300.0, "dur": 0.4, "att": 0.04, "filter": "lp", "cut": [600.0, 1400.0], "res": 0.5, "vol": 0.6, "vib": [0.05, 9.0]},
		{"wave": NOISE, "dur": 0.35, "att": 0.05, "filter": "bp", "cut": 900.0, "res": 0.7, "vol": 0.3, "trem": [0.8, 21.0]}]},
	"seve_boss_eveil": {"peak": 0.8, "verb": 0.55, "room": 0.9, "duck": 0.6, "layers": [
		{"wave": SINE, "f0": 90.0, "f1": 260.0, "dur": 1.3, "att": 0.45, "vol": 0.6, "voice2": 7.0, "vib": [0.04, 5.0]},
		{"wave": NOISE, "dur": 1.2, "att": 0.5, "filter": "bp", "cut": [600.0, 1600.0], "res": 0.5, "vol": 0.4, "trem": [0.5, 9.0]},
		{"wave": SINE, "f0": 45.0, "f1": 55.0, "dur": 1.2, "att": 0.3, "vol": 0.5}]},
	"seve_boss_phase": {"peak": 0.78, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"wave": TRI, "f0": 340.0, "f1": 110.0, "dur": 0.9, "att": 0.02, "vol": 0.6, "voice2": 4.0, "vib": [0.07, 8.0]},
		{"wave": NOISE, "dur": 0.6, "att": 0.01, "filter": "lp", "cut": [1800.0, 300.0], "vol": 0.4},
		{"wave": SINE, "f0": 90.0, "f1": 35.0, "dur": 0.6, "att": 0.002, "vol": 0.7, "drive": 0.3}]},
	"seve_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": SINE, "f0": 330.0, "f1": 70.0, "dur": 2.0, "att": 0.03, "vol": 0.6, "voice2": 12.0, "vib": [0.03, 4.0]},
		{"wave": NOISE, "dur": 1.5, "att": 0.01, "filter": "bp", "cut": [1800.0, 400.0], "res": 0.5, "vol": 0.5, "trem": [0.5, 11.0]},
		{"wave": SINE, "f0": 70.0, "f1": 30.0, "dur": 1.2, "att": 0.002, "vol": 0.7, "drive": 0.4},
		{"wave": SINE, "f0": 880.0, "dur": 1.0, "att": 0.01, "delay": 0.7, "vol": 0.2, "arp": [0, 4, 7, 12]}]},
	# --- Racine (bois, pierre) : bois qui craque, coups sourds. ---------------------------------------------
	"racine_ecorce": {"peak": 0.6, "verb": 0.2, "room": 0.45, "layers": [
		{"wave": SQUARE, "f0": 260.0, "f1": 140.0, "dur": 0.35, "att": 0.004, "duty": 0.2, "filter": "bp", "cut": [900.0, 500.0], "res": 0.6, "vol": 0.6, "vib": [0.08, 18.0]},
		{"wave": NOISE, "dur": 0.3, "att": 0.002, "filter": "bp", "cut": [1400.0, 600.0], "res": 0.5, "vol": 0.5, "trem": [0.9, 33.0]},
		{"wave": SINE, "f0": 120.0, "f1": 60.0, "dur": 0.2, "att": 0.002, "vol": 0.7}]},
	"racine_ancrage": {"peak": 0.7, "verb": 0.3, "room": 0.6, "layers": [
		{"wave": SAW, "f0": 75.0, "f1": 120.0, "dur": 0.55, "att": 0.1, "filter": "lp", "cut": [250.0, 700.0], "res": 0.5, "vol": 0.6, "vib": [0.05, 10.0], "drive": 0.4},
		{"wave": SINE, "f0": 90.0, "f1": 35.0, "dur": 0.4, "att": 0.002, "delay": 0.15, "vol": 0.9, "drive": 0.5},
		{"wave": NOISE, "dur": 0.35, "att": 0.002, "delay": 0.15, "filter": "lp", "cut": [1500.0, 200.0], "vol": 0.5, "crush": 1000.0}]},
	"racine_pieux": {"peak": 0.6, "verb": 0.15, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.18, "att": 0.002, "filter": "bp", "cut": [2400.0, 600.0], "res": 0.5, "vol": 0.8, "click": true},
		{"wave": SQUARE, "f0": 330.0, "f1": 180.0, "dur": 0.12, "att": 0.002, "duty": 0.15, "filter": "bp", "cut": 900.0, "res": 0.6, "vol": 0.4},
		{"wave": SINE, "f0": 140.0, "f1": 55.0, "dur": 0.16, "att": 0.002, "vol": 0.8}]},
	"racine_massue": {"peak": 0.75, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": SINE, "f0": 160.0, "f1": 45.0, "dur": 0.38, "att": 0.003, "vol": 1.0, "voice2": -5.0, "drive": 0.5},
		{"wave": NOISE, "dur": 0.25, "att": 0.002, "filter": "lp", "cut": [1600.0, 200.0], "vol": 0.6, "crush": 1400.0}]},
	"racine_boss_eveil": {"peak": 0.85, "verb": 0.5, "room": 0.9, "duck": 0.6, "layers": [
		{"wave": SAW, "f0": 60.0, "f1": 140.0, "dur": 1.4, "att": 0.5, "filter": "lp", "cut": [200.0, 800.0], "res": 0.55, "vol": 0.7, "voice2": -5.0, "vib": [0.07, 7.0], "drive": 0.4},
		{"wave": SQUARE, "f0": 90.0, "f1": 70.0, "dur": 1.2, "att": 0.3, "duty": 0.1, "filter": "bp", "cut": 500.0, "res": 0.7, "vol": 0.3, "trem": [0.9, 13.0]},
		{"wave": SINE, "f0": 40.0, "f1": 50.0, "dur": 1.3, "att": 0.4, "vol": 0.6}]},
	"racine_boss_phase": {"peak": 0.82, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"wave": SQUARE, "f0": 200.0, "f1": 70.0, "dur": 0.9, "att": 0.01, "duty": 0.25, "filter": "lp", "cut": [1400.0, 300.0], "res": 0.4, "vol": 0.5, "voice2": 3.0, "vib": [0.08, 12.0]},
		{"wave": SINE, "f0": 100.0, "f1": 32.0, "dur": 0.7, "att": 0.002, "vol": 0.9, "drive": 0.5},
		{"wave": NOISE, "dur": 0.6, "att": 0.002, "filter": "lp", "cut": [2000.0, 200.0], "vol": 0.5, "crush": 1200.0}]},
	"racine_boss_mort": {"peak": 0.88, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": NOISE, "dur": 2.0, "att": 0.03, "filter": "lp", "cut": [1600.0, 80.0], "vol": 0.7, "crush": 1600.0, "trem": [0.4, 5.0]},
		{"wave": SINE, "f0": 90.0, "f1": 26.0, "dur": 1.6, "att": 0.002, "vol": 0.9, "drive": 0.5, "voice2": -7.0},
		{"wave": SQUARE, "f0": 140.0, "f1": 60.0, "dur": 1.2, "att": 0.05, "duty": 0.12, "filter": "bp", "cut": 400.0, "res": 0.7, "vol": 0.3, "trem": [0.9, 9.0]}]},
	# Ennemis de Racine : chitine sèche (termite, scarabée), cri étouffé (mandragore), pierre lourde (tertre).
	"racine_termite_hit": {"peak": 0.4, "verb": 0.05, "room": 0.3, "layers": [
		{"wave": SQUARE, "f0": 1500.0, "f1": 900.0, "dur": 0.05, "att": 0.001, "duty": 0.2, "filter": "bp", "cut": 2200.0, "res": 0.5, "vol": 0.6, "click": true},
		{"wave": NOISE, "dur": 0.04, "att": 0.001, "filter": "hp", "cut": 3000.0, "vol": 0.4}]},
	"racine_termite_death": {"peak": 0.5, "verb": 0.12, "room": 0.35, "layers": [
		{"wave": NOISE, "dur": 0.18, "att": 0.001, "filter": "bp", "cut": [3200.0, 800.0], "res": 0.5, "vol": 0.8, "click": true, "trem": [0.8, 37.0]},
		{"wave": SINE, "f0": 200.0, "f1": 80.0, "dur": 0.1, "att": 0.001, "vol": 0.5}]},
	"racine_mandragore_hit": {"peak": 0.5, "verb": 0.12, "room": 0.4, "layers": [
		{"wave": SAW, "f0": 700.0, "f1": 420.0, "dur": 0.13, "att": 0.004, "filter": "bp", "cut": 1100.0, "res": 0.6, "vol": 0.7, "voice2": 6.0, "vib": [0.05, 22.0]},
		{"wave": NOISE, "dur": 0.05, "att": 0.001, "filter": "bp", "cut": 1800.0, "res": 0.4, "vol": 0.4}]},
	"racine_mandragore_death": {"peak": 0.62, "verb": 0.3, "room": 0.55, "layers": [
		{"wave": SAW, "f0": 900.0, "f1": 180.0, "dur": 0.55, "att": 0.005, "filter": "bp", "cut": [1600.0, 500.0], "res": 0.65, "vol": 0.7, "voice2": 6.0, "vib": [0.1, 16.0]},
		{"wave": NOISE, "dur": 0.3, "att": 0.002, "filter": "lp", "cut": [1200.0, 300.0], "vol": 0.5, "crush": 1500.0},
		{"wave": SINE, "f0": 120.0, "f1": 45.0, "dur": 0.25, "att": 0.002, "vol": 0.6}]},
	"racine_mandragore_jaillit": {"peak": 0.6, "verb": 0.25, "room": 0.5, "layers": [
		{"wave": SAW, "f0": 300.0, "f1": 1100.0, "dur": 0.42, "att": 0.04, "filter": "bp", "cut": [700.0, 2200.0], "res": 0.6, "vol": 0.7, "voice2": 6.0, "vib": [0.12, 18.0]},
		{"wave": NOISE, "dur": 0.2, "att": 0.002, "filter": "lp", "cut": [1500.0, 300.0], "vol": 0.6, "crush": 900.0},
		{"wave": SINE, "f0": 110.0, "f1": 50.0, "dur": 0.2, "att": 0.002, "vol": 0.7}]},
	"racine_scarabee_hit": {"peak": 0.55, "verb": 0.08, "room": 0.3, "layers": [
		{"wave": SQUARE, "f0": 520.0, "f1": 300.0, "dur": 0.07, "att": 0.001, "duty": 0.35, "filter": "bp", "cut": 1200.0, "res": 0.6, "vol": 0.6},
		{"wave": NOISE, "dur": 0.05, "att": 0.001, "filter": "bp", "cut": [3000.0, 1500.0], "res": 0.4, "vol": 0.6, "click": true},
		{"wave": SINE, "f0": 150.0, "f1": 70.0, "dur": 0.08, "att": 0.001, "vol": 0.7}]},
	"racine_scarabee_crit": {"peak": 0.72, "verb": 0.2, "room": 0.45, "layers": [
		{"wave": SAW, "f0": 400.0, "f1": 1100.0, "dur": 0.14, "att": 0.002, "filter": "bp", "cut": [1000.0, 3000.0], "res": 0.5, "vol": 0.5, "voice2": 7.0, "click": true},
		{"wave": METAL, "f0": 1180.0, "dur": 0.35, "att": 0.001, "vol": 0.4},
		{"wave": SINE, "f0": 180.0, "f1": 70.0, "dur": 0.12, "att": 0.001, "vol": 0.8, "drive": 0.4}]},
	"racine_scarabee_death": {"peak": 0.62, "verb": 0.15, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.32, "att": 0.002, "filter": "bp", "cut": [1500.0, 300.0], "res": 0.4, "vol": 0.8, "click": true, "crush": 2400.0},
		{"wave": SINE, "f0": 140.0, "f1": 45.0, "dur": 0.25, "att": 0.002, "vol": 0.8, "drive": 0.4}]},
	"racine_tertre_hit": {"peak": 0.6, "verb": 0.1, "room": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.1, "att": 0.002, "filter": "lp", "cut": [1200.0, 300.0], "vol": 0.8, "crush": 1300.0},
		{"wave": SINE, "f0": 100.0, "f1": 50.0, "dur": 0.12, "att": 0.001, "vol": 0.9, "drive": 0.3}]},
	"racine_tertre_death": {"peak": 0.75, "verb": 0.3, "room": 0.6, "layers": [
		{"wave": NOISE, "dur": 0.75, "att": 0.02, "filter": "lp", "cut": [1000.0, 90.0], "vol": 0.8, "crush": 900.0, "trem": [0.5, 9.0]},
		{"wave": SINE, "f0": 80.0, "f1": 30.0, "dur": 0.6, "att": 0.002, "vol": 0.9, "drive": 0.5}]},
	"racine_tertre_frappe": {"peak": 0.8, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": SINE, "f0": 120.0, "f1": 36.0, "dur": 0.45, "att": 0.003, "vol": 1.0, "voice2": -7.0, "drive": 0.6},
		{"wave": NOISE, "dur": 0.3, "att": 0.002, "filter": "lp", "cut": [2000.0, 150.0], "vol": 0.6, "crush": 1600.0}]},
	# --- Finale (la Flétrissure, sous la graine) : plus graves et plus lourds ; le creux résonne. -----------
	"finale_boss_eveil": {"peak": 0.88, "verb": 0.65, "room": 1.0, "duck": 0.7, "layers": [
		{"wave": SAW, "f0": 55.0, "f1": 160.0, "dur": 1.7, "att": 0.6, "filter": "lp", "cut": [180.0, 1000.0], "res": 0.6, "vol": 0.7, "voice2": -7.0, "vib": [0.05, 5.0], "drive": 0.4},
		{"wave": METAL, "f0": 110.0, "dur": 1.6, "att": 0.002, "delay": 1.3, "vol": 0.35},
		{"wave": NOISE, "dur": 1.5, "att": 0.7, "filter": "bp", "cut": [200.0, 1200.0], "res": 0.6, "vol": 0.4},
		{"wave": SINE, "f0": 36.0, "f1": 41.0, "dur": 1.7, "att": 0.4, "vol": 0.6}]},
	"finale_boss_phase": {"peak": 0.86, "verb": 0.55, "room": 1.0, "duck": 0.5, "layers": [
		{"wave": SAW, "f0": 300.0, "f1": 60.0, "dur": 1.1, "att": 0.02, "filter": "lp", "cut": [2000.0, 200.0], "res": 0.55, "vol": 0.6, "voice2": 6.0, "vib": [0.1, 8.0]},
		{"wave": SINE, "f0": 90.0, "f1": 28.0, "dur": 0.9, "att": 0.002, "vol": 0.9, "drive": 0.5},
		{"wave": METAL, "f0": 220.0, "dur": 1.2, "att": 0.002, "vol": 0.3}]},
	"finale_boss_mort": {"peak": 0.9, "verb": 0.7, "room": 1.0, "duck": 0.85, "layers": [
		{"wave": SINE, "f0": 440.0, "dur": 2.8, "att": 0.03, "vol": 0.5, "voice2": 12.0, "arp": [0, -5, -12], "vib": [0.04, 4.0]},
		{"wave": NOISE, "dur": 2.2, "att": 0.005, "filter": "lp", "cut": [3000.0, 80.0], "vol": 0.6, "crush": 2200.0},
		{"wave": SINE, "f0": 70.0, "f1": 24.0, "dur": 2.0, "att": 0.002, "vol": 0.9, "drive": 0.5},
		{"wave": METAL, "f0": 523.0, "dur": 2.4, "att": 0.002, "delay": 1.2, "vol": 0.3},
		{"wave": SINE, "f0": 261.6, "dur": 1.6, "att": 0.4, "delay": 1.3, "vol": 0.35, "arp": [0, 4, 7, 12]}]},
	# --- Aube (lumière, éclat, cloches) : clair, cristallin. -------------------------------------------------
	"aube_rayon": {"peak": 0.42, "verb": 0.2, "room": 0.5, "layers": [
		{"wave": SAW, "f0": 1200.0, "f1": 2400.0, "dur": 0.16, "att": 0.004, "filter": "bp", "cut": [1800.0, 4000.0], "res": 0.5, "vol": 0.5, "voice2": 12.0},
		{"wave": SINE, "f0": 2400.0, "dur": 0.2, "att": 0.002, "vol": 0.3, "fm": [3.5, 0.8]}]},
	"aube_eclat": {"peak": 0.45, "verb": 0.4, "room": 0.6, "layers": [
		{"wave": METAL, "f0": 1568.0, "dur": 0.45, "att": 0.002, "vol": 0.6},
		{"wave": SINE, "f0": 1568.0, "dur": 0.4, "att": 0.002, "vol": 0.4, "arp": [0, 7, 12], "voice2": 19.0}]},
	"aube_halo": {"peak": 0.48, "verb": 0.55, "room": 0.75, "layers": [
		{"wave": SINE, "f0": 392.0, "dur": 0.95, "att": 0.12, "vol": 0.6, "arp": [0, 4, 7, 12, 16], "voice2": 12.0, "vib": [0.01, 6.0]},
		{"wave": SINE, "f0": 784.0, "dur": 0.9, "att": 0.3, "vol": 0.25, "fm": [2.0, 0.4], "trem": [0.3, 6.0]}]},
	"aube_levant": {"peak": 0.5, "verb": 0.35, "room": 0.6, "layers": [
		{"wave": TRI, "f0": 220.0, "f1": 880.0, "dur": 0.8, "att": 0.3, "vol": 0.6, "voice2": 7.0, "vib": [0.02, 6.0]},
		{"wave": NOISE, "dur": 0.7, "att": 0.4, "filter": "bp", "cut": [1000.0, 5000.0], "res": 0.5, "vol": 0.2},
		{"wave": METAL, "f0": 1760.0, "dur": 0.6, "att": 0.002, "delay": 0.6, "vol": 0.25}]},
	"aube_cloche": {"peak": 0.5, "verb": 0.5, "room": 0.75, "layers": [
		{"wave": SINE, "f0": 1046.0, "dur": 0.9, "att": 0.002, "vol": 0.6, "fm": [3.5, 2.2], "decay": 1.6},
		{"wave": METAL, "f0": 1046.0, "dur": 0.9, "att": 0.002, "vol": 0.35},
		{"wave": SINE, "f0": 523.0, "dur": 0.8, "att": 0.004, "vol": 0.25}]},
	"aube_nova": {"peak": 0.75, "verb": 0.45, "room": 0.75, "duck": 0.15, "layers": [
		{"wave": SAW, "f0": 500.0, "f1": 2000.0, "dur": 0.4, "att": 0.02, "filter": "bp", "cut": [900.0, 4000.0], "res": 0.5, "vol": 0.5, "voice2": 12.0},
		{"wave": SINE, "f0": 140.0, "f1": 50.0, "dur": 0.4, "att": 0.002, "vol": 0.8, "drive": 0.3},
		{"wave": METAL, "f0": 1320.0, "dur": 0.8, "att": 0.002, "vol": 0.35},
		{"wave": NOISE, "dur": 0.5, "att": 0.01, "filter": "hp", "cut": [3000.0, 7000.0], "vol": 0.25}]},
	"aube_boss_eveil": {"peak": 0.82, "verb": 0.6, "room": 0.95, "duck": 0.6, "layers": [
		{"wave": SAW, "f0": 110.0, "f1": 880.0, "dur": 1.4, "att": 0.6, "filter": "lp", "cut": [400.0, 3000.0], "res": 0.4, "vol": 0.6, "voice2": 12.0, "vib": [0.03, 5.0]},
		{"wave": METAL, "f0": 1046.0, "dur": 1.2, "att": 0.002, "delay": 1.1, "vol": 0.35},
		{"wave": SINE, "f0": 55.0, "f1": 55.0, "dur": 1.3, "att": 0.4, "vol": 0.5}]},
	"aube_boss_phase": {"peak": 0.78, "verb": 0.5, "room": 0.85, "duck": 0.4, "layers": [
		{"wave": SQUARE, "f0": 1320.0, "f1": 330.0, "dur": 0.85, "att": 0.01, "duty": 0.3, "filter": "lp", "cut": [5000.0, 800.0], "vol": 0.45, "voice2": 7.0},
		{"wave": METAL, "f0": 880.0, "dur": 1.0, "att": 0.002, "vol": 0.4},
		{"wave": SINE, "f0": 100.0, "f1": 40.0, "dur": 0.5, "att": 0.002, "vol": 0.7}]},
	"aube_boss_mort": {"peak": 0.85, "verb": 0.65, "room": 1.0, "duck": 0.7, "layers": [
		{"wave": SINE, "f0": 1100.0, "f1": 110.0, "dur": 2.1, "att": 0.01, "vol": 0.5, "voice2": 12.0, "vib": [0.04, 6.0]},
		{"wave": METAL, "f0": 1568.0, "dur": 2.0, "att": 0.002, "vol": 0.35},
		{"wave": SINE, "f0": 392.0, "dur": 1.6, "att": 0.3, "delay": 0.6, "vol": 0.4, "arp": [0, 4, 7, 12]},
		{"wave": NOISE, "dur": 1.4, "att": 0.01, "filter": "hp", "cut": [2000.0, 6000.0], "vol": 0.25}]},
	# --- Ronce : sons de son boss (Ronce n'avait que l'annonce commune). --------------------------------------
	"ronce_boss_eveil": {"peak": 0.82, "verb": 0.5, "room": 0.85, "duck": 0.6, "layers": [
		{"wave": SAW, "f0": 73.4, "f1": 110.0, "dur": 1.3, "att": 0.4, "filter": "lp", "cut": [200.0, 1400.0], "res": 0.55, "vol": 0.6, "voice2": 3.0, "drive": 0.4},
		{"wave": NOISE, "dur": 1.0, "att": 0.6, "filter": "bp", "cut": [800.0, 3000.0], "res": 0.6, "vol": 0.3, "trem": [0.7, 15.0]},
		{"wave": SINE, "f0": 120.0, "f1": 36.0, "dur": 0.6, "att": 0.002, "delay": 1.0, "vol": 0.9, "drive": 0.5}]},
	"ronce_boss_phase": {"peak": 0.8, "verb": 0.4, "room": 0.8, "duck": 0.4, "layers": [
		{"wave": NOISE, "dur": 0.6, "att": 0.03, "filter": "bp", "cut": [1500.0, 5000.0], "res": 0.6, "vol": 0.5},
		{"wave": NOISE, "dur": 0.05, "att": 0.0005, "delay": 0.5, "filter": "hp", "cut": 2200.0, "vol": 0.9, "click": true},
		{"wave": SINE, "f0": 110.0, "f1": 35.0, "dur": 0.6, "att": 0.002, "delay": 0.5, "vol": 0.9, "drive": 0.5}]},
	"ronce_boss_mort": {"peak": 0.85, "verb": 0.6, "room": 0.95, "duck": 0.7, "layers": [
		{"wave": NOISE, "dur": 1.7, "att": 0.01, "filter": "bp", "cut": [2200.0, 200.0], "res": 0.4, "vol": 0.6, "crush": 2400.0, "trem": [0.4, 7.0]},
		{"wave": SINE, "f0": 90.0, "f1": 26.0, "dur": 1.4, "att": 0.002, "vol": 0.9, "drive": 0.5},
		{"wave": SINE, "f0": 293.7, "dur": 1.5, "att": 0.4, "delay": 0.8, "vol": 0.35, "arp": [0, 4, 7, 12]}]},
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
		length = maxf(length, float(l.get("delay", 0.0)) + float(l["dur"]))
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
