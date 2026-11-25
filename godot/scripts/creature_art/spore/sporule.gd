## Sporule (Spore, essaim), « Bestiaire d'herbier » : une des deux boules du Scissipore, détachée à sa mort.
## Petite vesse ronde, un seul gros œil de braise, quatre filaments de mycélium qui trottent très vite.
## Elle n'annonce rien : elle fonce au contact (la frappe n'est qu'un petit bond en avant).
##
## Pose : t, walk, moving, k, strike (0 → 1, -1 : aucune), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const Sp = preload("res://scripts/creature_art/spore/commun.gd")

## 100 unités en px du jeu : ~30 px de haut en 1080p (essaim).
const HEIGHT := 25.0
## La sorte dessine elle-même son collier d'élite (elle n'est jamais élite en jeu, mais la pose existe).
const DRAWS_ELITE := true


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var elite: bool = o.get("elite", false)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 34.0)
	# Trot rapide : la boule sautille et penche en avant ; petit bond à la frappe.
	var hop := 0.0 if strike < 0.0 else sin(PI * strike)
	var bob := -absf(sin(walk * 2.0)) * 8.0 * mv - 16.0 * hop + sin(t * 5.0) * 1.2
	var lean := 0.16 * mv + 0.2 * hop + 0.12 * hit
	var sq := Vector2(1.0 + 0.14 * hit + 0.06 * k, 1.0 - 0.16 * hit - 0.05 * k)
	var xf := base * Transform2D(0.0, Vector2(0, -22 + bob)) * Transform2D(lean, sq, 0.0, Vector2.ZERO)
	var hy := Art.bc("spore", "chapeau").darkened(0.1)
	for i in 4:
		var far := i % 2 == 0
		var x0 := -18.0 + i * 12.0
		var ph := walk * 2.0 + i * PI * 0.5
		var foot := Vector2(x0 * 1.6 + sin(ph) * 12.0 * mv, -maxf(cos(ph), 0.0) * 8.0 * mv)
		var hip := base.affine_inverse() * (xf * Vector2(x0 * 0.8, -6))
		var knee := hip.lerp(foot, 0.5) + Vector2(5 if foot.x > hip.x else -5, -5)
		var pts := PackedVector2Array([hip, knee, foot])
		Ink.brush(ci, base, pts, 8.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, base, pts, 5.0, hy.darkened(0.35) if far else hy, 1.0, 0.0)
	var fl := Sp.flesh()
	var pal := {"clair": fl["clair"].lightened(0.06), "ombre": fl["ombre"], "reflet": fl["reflet"]}
	Sp.puffball(ci, xf, Vector2(0, -38), 38.0, 40.0, pal, 0.3 + 0.7 * k, 7, 1.4)
	# Une fente de Flétrissure sur le dos.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-30, -54), Vector2(-24, -44), Vector2(-30, -34)]), 3.0, Art.bc("braise"))
	if elite:
		Sp.elite_caps(ci, xf, [Vector2(-18, -74), Vector2(14, -74)], t)
	# Le grand œil de braise, qui regarde la cible (plissé sous le coup).
	var lk := Vector2(cos(clampf(la, -0.8, 0.8)), sin(clampf(la, -0.8, 0.8))) * 3.0
	var eye := Vector2(16, -40)
	Ink.flat(ci, xf, Ink.oval(eye, 13.0, 12.0, 20), Art.bc("ronge"), 1.6)
	if hit > 0.4:
		Ink.brush(ci, xf, PackedVector2Array([eye + Vector2(-9, 0), eye + Vector2(9, -1)]), 3.4, Art.bc("braise").darkened(0.3))
	else:
		Ink.ember(ci, xf, Ink.oval(eye + lk, 8.0, 8.0, 16), 0.5 + 0.5 * k)
		Ink.flat(ci, xf, Ink.oval(eye + lk * 1.6, 3.0, 4.2, 10), Ink.encre())
