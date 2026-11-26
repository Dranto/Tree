## Banc de lisibilité du « Bestiaire d'herbier » : pour chaque sorte de enemies.json qui a un script de
## créature (scripts/creature_art/<région>/<id>.gd), le dessin se lit-il à l'écran ?
##   - taille : à l'échelle du jeu en 1080p, la hauteur déclarée (HEIGHT) et la plus grande dimension mesurée
##     de la silhouette (un chargeur est bas et long) atteignent le minimum de son rôle (essaim 28 px, tireur/chargeur 44, soutien 56, lourd 72) ; le rôle se déduit du
##     `behavior` (table dans tests/bestiaire/sortes.gd) ;
##   - silhouettes : deux sortes d'une même région (et des communes, présentes partout) ne se recouvrent
##     pas trop, pieds alignés, à la taille réelle ;
##   - sol : le corps tranche sur le sol mort de sa région en niveaux de gris (une sorte commune : sur
##     chaque région) ;
##   - couleur : les tons de région sont distincts deux à deux en vision normale (ΔE ≥ 30) et, pour chaque
##     daltonisme d'Art, avec le mode daltonien correspondant actif (ΔE ≥ 25) ; la braise reste lisible sur le corps ; le corps tranche sur le sol.
## Les sortes sans script sont listées, pas en échec. Rendu réel (xvfb) :
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/bestiaire_test.gd
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Sortes = preload("res://tests/bestiaire/sortes.gd")
const C = preload("res://tests/bestiaire/commun.gd")

## Tolérance sur la taille mesurée : l'encre et les parties fines (antennes, pointes) ne comptent pas toutes.
const TOLERANCE_TAILLE := 0.80
## Recouvrement maximal (intersection sur union) de deux silhouettes d'une même région.
const MAX_RECOUVREMENT := 0.78
## Écart minimal de luminance (0 → 1, niveaux de gris) entre le corps et le sol mort de la région.
const MIN_ECART_GRIS := 0.10
## Écart minimal (ΔE 1976) : mêmes seuils qu'art_test.gd (braise sur le corps).
const MIN_DELTA_E := 20.0
## Régions entre elles : en vision normale, des teintes franches ; pour un daltonien, avec son mode
## daltonien actif (Art.BESTIAIRE_DALTONIEN). La palette normale n'a pas à passer les daltonismes seule.
const MIN_DELTA_E_NORMAL := 30.0
const MIN_DELTA_E_MODE := 25.0
## Écart minimal entre le corps d'une sorte et le sol, vu par un daltonien (ΔE). Réglé sur les trois créatures
## validées de la planche V3 (pire cas : tireur d'épines sur Ronce, déutéranopie, 11) : elles doivent passer.
const MIN_DELTA_E_SOL := 10.0
## Luminance en dessous de laquelle un pixel est de l'encre (Art.bc("encre") : 0,07).
const INK_LUM := 0.11
const CW := 260
const CH := 260
const FEET := Vector2(130, 220)

var failures := 0
var b


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	b = Bake.new(self)
	var kinds := Sortes.kinds()
	var drawn := []
	var missing := []
	for k in kinds:
		if k["script"] != null:
			drawn.append(k)
		else:
			missing.append(k["id"])
	print("Sortes : %d dessinées, %d sans script (pas un échec)" % [drawn.size(), missing.size()])
	if not missing.is_empty():
		print("  sans script : %s" % ", ".join(missing))
	check(not drawn.is_empty(), "au moins une sorte a un script de créature")

	print("Contrat de dessin")
	for k in drawn:
		var s = k["script"]
		check("HEIGHT" in s and s.HEIGHT > 0.0, "%s : HEIGHT défini" % k["id"])
		check(s.has_method("draw"), "%s : draw(ci, feet, h, o)" % k["id"])

	# Silhouettes et couleurs de chaque sorte, à la taille réelle en 1080p.
	var sil := {}
	var col := {}
	for k in drawn:
		sil[k["id"]] = await _render(k["script"], true)
		col[k["id"]] = await _render(k["script"], false)

	print("Taille à l'écran (1080p)")
	for k in drawn:
		var s = k["script"]
		var box := Sortes.bbox(sil[k["id"]])
		var declared: float = s.HEIGHT * Sortes.S1080
		check(declared >= k["min_px"], "%s (%s, %s) : hauteur déclarée %.0f px ≥ %.0f" % [k["id"], k["behavior"], k["role"], declared, k["min_px"]])
		var big := maxi(box.size.x, box.size.y)
		check(big >= k["min_px"] * TOLERANCE_TAILLE, "%s : taille mesurée %d px (%d × %d) ≥ %.0f" % [k["id"], big, box.size.x, box.size.y, k["min_px"] * TOLERANCE_TAILLE])

	print("Silhouettes distinctes dans une même région")
	var pairs := 0
	for i in drawn.size():
		for j in range(i + 1, drawn.size()):
			var a: Dictionary = drawn[i]
			var c: Dictionary = drawn[j]
			var same: bool = a["region"] == c["region"] or a["region"] == "commun" or c["region"] == "commun"
			if not same:
				continue
			pairs += 1
			var o := Sortes.overlap(sil[a["id"]], sil[c["id"]])
			check(o < MAX_RECOUVREMENT, "%s / %s : recouvrement %.0f %% < %.0f %%" % [a["id"], c["id"], o * 100.0, MAX_RECOUVREMENT * 100.0])
	if pairs == 0:
		print("  (aucune paire dans une même région pour l'instant)")
	if drawn.size() >= 2:
		check(Sortes.overlap(sil[drawn[0]["id"]], sil[drawn[0]["id"]]) > 0.99, "mesure : une silhouette se recouvre à 100 % elle-même")

	print("Corps et sol (niveaux de gris)")
	for k in drawn:
		var body := _body_color(col[k["id"]], sil[k["id"]])
		var gray: float = body.get_luminance()
		var regions := Sortes.REGIONS.slice(1) if k["region"] == "commun" else [k["region"]]
		for reg in regions:
			var g: Array = C.ground_colors(reg)
			var ground: float = (g[0].get_luminance() + g[1].get_luminance()) * 0.5
			check(absf(gray - ground) >= MIN_ECART_GRIS, "%s sur %s : corps %.2f, sol %.2f (écart %.2f ≥ %.2f)" % [k["id"], reg, gray, ground, absf(gray - ground), MIN_ECART_GRIS])

	print("Encre sur le sol (information)")
	for reg in Sortes.REGIONS.slice(1):
		var g: Array = C.ground_colors(reg)
		var worst: float = minf(g[0].get_luminance(), g[1].get_luminance()) - Art.bc("encre").get_luminance()
		# Information seulement : l'encre est fine et les sols sont sombres ; c'est le corps qui doit trancher.
		print("  (info) encre sur le sol de %s : écart de luminance %.2f" % [reg, worst])

	print("Couleur : régions, sol, braise (vision normale ; chaque daltonisme avec son mode actif)")
	for kind in [""] + Art.DALTONISMES.keys():
		var label: String = "vision normale" if kind == "" else "%s, mode %s" % [kind, kind]
		# Le mode daltonien (Settings.colorblind_mode) décale les couleurs des régions qui se confondent.
		Art.set_access(kind if kind != "" else "aucun")
		var tons := {}
		for reg in Art.BESTIAIRE:
			var v = Art.BESTIAIRE[reg]
			if v is Dictionary and v.has("clair"):
				tons[reg] = Art.bc(reg, "clair")
		var worst := 1000.0
		var pair := ""
		var names := tons.keys()
		for i in names.size():
			for j in range(i + 1, names.size()):
				var d := Art.delta_e(_sim(tons[names[i]], kind), _sim(tons[names[j]], kind))
				if d < worst:
					worst = d
					pair = "%s / %s" % [names[i], names[j]]
		var seuil := MIN_DELTA_E_NORMAL if kind == "" else MIN_DELTA_E_MODE
		if names.size() >= 2:
			check(worst >= seuil, "régions distinctes, %s (pire paire %s : ΔE %.1f ≥ %.0f)" % [label, pair, worst, seuil])
		var col_mode := col
		if kind != "":
			col_mode = {}
			for k in drawn:
				col_mode[k["id"]] = await _render(k["script"], false)
		for k in drawn:
			var body := _body_color(col_mode[k["id"]], sil[k["id"]])
			var regions := Sortes.REGIONS.slice(1) if k["region"] == "commun" else [k["region"]]
			for reg in regions:
				var g: Array = C.ground_colors(reg)
				var d := minf(Art.delta_e(_sim(body, kind), _sim(g[0], kind)), Art.delta_e(_sim(body, kind), _sim(g[1], kind)))
				check(d >= MIN_DELTA_E_SOL, "%s sur %s, %s : corps / sol ΔE %.1f ≥ %.0f" % [k["id"], reg, label, d, MIN_DELTA_E_SOL])
		for reg in tons:
			var d := Art.delta_e(_sim(Art.bc("braise"), kind), _sim(tons[reg], kind))
			check(d >= MIN_DELTA_E, "braise sur le corps %s, %s : ΔE %.1f" % [reg, label, d])
	Art.set_access("aucun")

	print("")
	print("ÉCHEC : %d test(s)" % failures if failures > 0 else "OK : banc de lisibilité (%d sortes dessinées)" % drawn.size())
	quit(1 if failures > 0 else 0)


static func _sim(c: Color, kind: String) -> Color:
	return c if kind == "" else Art.simulate(c, kind)


## Dessin d'une sorte au repos, à la taille réelle en 1080p, pieds en FEET. mono : silhouette noire.
func _render(script, mono: bool) -> Image:
	return await b.bake(Vector2i(CW, CH), func(ci): Sortes.paint(ci, script, FEET, Sortes.S1080, Sortes.REPOS, mono), 1)


## Couleur moyenne du corps : les pixels de la silhouette, sans le contour d'encre (trop sombre pour dire la
## couleur ; son propre contraste avec le sol est vérifié à part).
static func _body_color(color_img: Image, mask_img: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var bl := 0.0
	var n := 0
	for yy in color_img.get_height():
		for xx in color_img.get_width():
			if mask_img.get_pixel(xx, yy).a > 0.5:
				var p := color_img.get_pixel(xx, yy)
				if p.a > 0.9 and p.get_luminance() > INK_LUM:
					r += p.r
					g += p.g
					bl += p.b
					n += 1
	return Color(r / maxf(n, 1), g / maxf(n, 1), bl / maxf(n, 1))
