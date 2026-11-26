## Banc de lisibilité du monde (refonte « Paysages d'herbier », tâche Q) : le vrai jeu posé sur un cadre de
## chaque région, flétri puis ravivé, avec le héros et trois Flétris ; mesures en niveaux de gris et en couleur
## (voir tests/paysages_banc/banc.gd).
##
## Par cadre (région × état) :
##   - le Flétri ressort : écart de luminosité (L*) du corps avec le sol voisin ≥ « fletri_dl_min », le héros ≥ « heros_dl_min » ;
##   - le sol n'est jamais plus contrasté qu'un Flétri (gradient p95 du sol ≤ celui du moins marqué − marge) ni que le décor ;
##   - l'annonce d'attaque (cercle, cône, ligne de la charte) se lit sur ce sol : ΔE médian ≥ « annonce_de_min » ;
##   - le héros et les Flétris restent distincts de leur sol pour un daltonien (ΔE des couleurs simulées) ;
##   - densité du décor ≤ « densite_max » éléments à l'écran.
## Par région : le ravivé est nettement plus clair que le flétri ; deux régions ravivées se distinguent
## (ΔE du sol au centre du cadre, aussi en vision daltonienne, comme art_test.gd).
##
## Les cibles sont dans tests/paysages_banc/seuils.json, avec les « écarts connus » du monde d'avant la refonte.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 -s res://tests/paysages_test.gd -- [options]
##   --regions=ronce,spore   seulement ces régions (par défaut les six, ~1 min 10)
##   --rapport               un tableau des mesures de chaque cadre
##   --images=DOSSIER        enregistre les cinq images de chaque cadre et le montage
##   --strict                ignore les écarts connus (la refonte est finie quand tout passe ainsi)
##   --ecrire-connus         réécrit « connus » dans seuils.json d'après cette mesure
## Avec -s, Game n'est pas visible à la compilation : tout est chargé à l'exécution.
extends SceneTree

const SEUILS_PATH := "res://tests/paysages_banc/seuils.json"

var Banc
var failures := 0
var ecarts := 0
var regles: Array = []
var cibles: Dictionary
var connus: Dictionary
var tolerance := 1.5
var strict := false
var ecrire := false
var rapport := false
var nouveaux := {}


func _initialize() -> void:
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k):
			return a.substr(k.length())
	return d


func _flag(k: String) -> bool:
	return k in OS.get_cmdline_user_args()


## Une mesure contre sa cible. « min » : la valeur doit être au moins la cible ; « max » : au plus.
func check(cle: String, valeur: float, mode: String, cible: float, quoi: String) -> void:
	var ok := valeur >= cible if mode == "min" else valeur <= cible
	var txt := "%s : %.1f (cible %s %.1f)" % [quoi, valeur, "≥" if mode == "min" else "≤", cible]
	if ok:
		if connus.has(cle) and not strict:
			regles.append(cle)
			print("  RÉGLÉ  ", txt)
		elif rapport:
			print("  ok     ", txt)
		return
	if ecrire:
		nouveaux[cle] = {"valeur": snappedf(valeur, 0.1), "cible": cible}
		ecarts += 1
		print("  écart  ", txt)
		return
	if not strict and connus.has(cle):
		var k := float(connus[cle]["valeur"])
		var pire := valeur < k - tolerance if mode == "min" else valeur > k + tolerance
		if not pire:
			ecarts += 1
			print("  écart connu ", txt, " [noté ", k, "]")
			return
		txt += " — PIRE que l'écart noté (%.1f)" % k
	failures += 1
	print("  ÉCHEC  ", txt, "  <", cle, ">")


func dur(ok: bool, quoi: String) -> void:
	if not ok:
		failures += 1
		print("  ÉCHEC  ", quoi)


func _run() -> void:
	Banc = load("res://tests/paysages_banc/banc.gd")
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SEUILS_PATH))
	cibles = s["cibles"]
	connus = s["connus"]
	tolerance = float(s.get("tolerance_connus", 1.5))
	strict = _flag("--strict")
	ecrire = _flag("--ecrire-connus")
	rapport = _flag("--rapport")
	var regions: Array = Banc.REGIONS
	if _arg("--regions=", "") != "":
		regions = _arg("--regions=", "").split(",")
	var dossier := _arg("--images=", "")
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)

	var main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	main.tree_ui.play_intro = false
	await process_frame
	var banc = Banc.new(self, main)
	banc.figer()
	var mesures := {}
	var pleines := []
	for r in regions:
		dur(r in Banc.REGIONS, "région inconnue « %s »" % r)
		for etat in Banc.ETATS:
			var cadre: Dictionary = await banc.poser(r, etat)
			var im: Dictionary = await banc.prendre(cadre)
			mesures[r + ":" + etat] = banc.mesurer(cadre, im)
			pleines.append(im["plein"])
			if dossier != "":
				for k in im:
					im[k].save_png("%s/%s_%s_%s.png" % [dossier, r, etat, k])
	if dossier != "":
		Banc.montage(pleines, 4, Vector2i(560, 315)).save_png(dossier + "/montage.png")

	print("Cadres")
	for r in regions:
		for etat in Banc.ETATS:
			_cadre(r, etat, mesures[r + ":" + etat])
	print("Régions")
	for r in regions:
		_region(r, mesures[r + ":fletri"], mesures[r + ":ravive"])
	if regions.size() > 1:
		print("Régions ravivées, deux à deux")
		for i in regions.size():
			for j in range(i + 1, regions.size()):
				_paire(regions[i], regions[j], mesures[regions[i] + ":ravive"], mesures[regions[j] + ":ravive"])

	if ecrire:
		s["connus"] = nouveaux
		var f := FileAccess.open(SEUILS_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(s, "  ", false) + "\n")
		f.close()
		print("seuils.json : %d écarts notés" % nouveaux.size())
	print("")
	if not regles.is_empty():
		print("RÉGLÉS (à retirer de « connus » : --ecrire-connus) : ", ", ".join(regles))
	if failures > 0:
		print("ÉCHEC : %d mesure(s) hors cible (et %d écarts connus)" % [failures, ecarts])
	else:
		print("OK : lisibilité du monde (%d écarts connus du monde d'avant la refonte)" % ecarts)
	quit(1 if failures > 0 else 0)


func _cadre(r: String, etat: String, m: Dictionary) -> void:
	var tag := "%s %s" % [r, etat]
	var cle := "%s:%s" % [r, etat]
	dur(m["region_ici"] == r, "%s : le cadre est dans la région « %s »" % [tag, m["region_ici"]])
	var perso_ok := true
	for p in m["persos"]:
		if not p["trouve"]:
			perso_ok = false
			dur(false, "%s : %s introuvable à l'image (%d pixels changés)" % [tag, p["kind"], p["pixels"]])
	if not perso_ok:
		return
	var heros: Dictionary = m["persos"][0]
	var fletris: Array = m["persos"].slice(1)
	var f_dl := 1000.0
	var f_p95 := 1000.0
	for p in fletris:
		f_dl = minf(f_dl, p["dl"])
		f_p95 = minf(f_p95, p["p95"])
	if rapport:
		print("  %-14s sol p95 %4.1f  décor %5.1f  lieux %5.1f  héros ΔL %4.1f  Flétris ΔL min %4.1f  p95 min %4.1f  annonce min %4.1f  décor %d" % [tag, m["sol_p95"], m["decor_p95"], m["lieux_p95"], heros["dl"], f_dl, f_p95, _annonce_min(m), m["densite"]])
	check("fletri_dl:" + cle, f_dl, "min", cibles["fletri_dl_min"], "%s : le Flétri le moins lisible se détache du sol (ΔL)" % tag)
	check("heros_dl:" + cle, heros["dl"], "min", cibles["heros_dl_min"], "%s : le héros se détache du sol (ΔL)" % tag)
	check("sol_sous_perso:" + cle, m["sol_p95"], "max", f_p95 - cibles["sol_sous_perso_marge"], "%s : le sol moins contrasté que les Flétris (gradient p95)" % tag)
	if m["decor_p95"] >= 0.0:
		check("sol_sous_decor:" + cle, m["sol_p95"], "max", m["decor_p95"] - cibles["sol_sous_decor_marge"], "%s : le sol moins contrasté que le décor (gradient p95)" % tag)
	check("annonce:" + cle, _annonce_min(m), "min", cibles["annonce_de_min"], "%s : l'annonce d'attaque se lit sur le sol (ΔE médian)" % tag)
	check("densite:" + cle, float(m["densite"]), "max", float(cibles["densite_max"]), "%s : éléments de décor à l'écran" % tag)
	for kind in Art.DALTONISMES:
		var pire := 1000.0
		for p in m["persos"]:
			pire = minf(pire, Art.delta_e(Art.simulate(p["couleur"], kind), Art.simulate(p["sol"], kind)))
		check("dalto_perso:%s:%s" % [kind, cle], pire, "min", cibles["perso_de_dalto_min"], "%s : personnages distincts du sol en %s (ΔE)" % [tag, kind])


func _annonce_min(m: Dictionary) -> float:
	var v := 1000.0
	for a in m["annonces"]:
		v = minf(v, a["de_median"])
	return v


func _region(r: String, f: Dictionary, v: Dictionary) -> void:
	var lf: float = Art.lab(f["sol_centre"]).x
	var lv: float = Art.lab(v["sol_centre"]).x
	if rapport:
		print("  %-14s sol L* flétri %4.1f  ravivé %4.1f" % [r, lf, lv])
	check("ravive_plus_clair:" + r, lv - lf, "min", cibles["ravive_plus_clair_min"], "%s : le ravivé est plus clair que le flétri (L* du sol au centre)" % r)


func _paire(a: String, b: String, ma: Dictionary, mb: Dictionary) -> void:
	var ca: Color = ma["sol_centre"]
	var cb: Color = mb["sol_centre"]
	var tag := "%s / %s" % [a, b]
	check("regions_de:%s:%s" % [a, b], Art.delta_e(ca, cb), "min", cibles["regions_de_min"], "%s : sols ravivés distincts (ΔE)" % tag)
	var pire := 1000.0
	for kind in Art.DALTONISMES:
		pire = minf(pire, Art.delta_e(Art.simulate(ca, kind), Art.simulate(cb, kind)))
	check("regions_de_dalto:%s:%s" % [a, b], pire, "min", cibles["regions_de_dalto_min"], "%s : sols ravivés distincts en vision daltonienne (ΔE)" % tag)
