## Charte graphique du jeu, en code : palette par rôle, identité des éléments, traits, ombres,
## lueurs, icônes vectorielles et grammaire des annonces de danger.
##
## Règle : aucune couleur, épaisseur ou ombre n'est écrite en dur ailleurs. On écrit
## `Art.c("ennemi")`, `Art.ec("poison")`, `Art.TRAIT`, `Art.icon(ci, "fouet", rect)`…
## L'intention (pourquoi ces choix) est décrite dans docs/charte-graphique.md.
##
## Tout est statique : rien à instancier. Les fonctions de dessin prennent le CanvasItem qui dessine
## (à appeler depuis son _draw).
class_name Art
extends RefCounted

# --- Palette sémantique ---
#
# Hiérarchie de lecture : le fond est sourd et désaturé, ce qui se ramasse ou s'utilise est clair
# et chaud, ce qui fait mal est saturé et contrasté.
const PALETTE := {
	# Fond : sourd, désaturé, sombre. Ne doit jamais attirer l'œil plus qu'un ennemi.
	"sol_mort": Color("3b3631"),
	"sol_vivant": Color("3e5a35"),
	"brume": Color("5c5650"),
	"decor": Color("27221f"),
	"decor_vivant": Color("4d6a3f"),
	# Le héros et ses alliés : clairs, ronds, organiques.
	"joueur": Color("f3ead2"),
	"joueur_accent": Color("8af5c0"),
	"allie": Color("a9e6a0"),
	# Les Flétris : sombres et saturés, contour clair pour ressortir sur le sol.
	"ennemi": Color("6a2a3c"),
	"ennemi_contour": Color("f09a8a"),
	"ennemi_oeil": Color("ffb347"),
	"elite": Color("ff4fb0"),
	# Les dangers : rouge vif, puis éclair blanc chaud au moment du coup.
	"danger": Color("ff3348"),
	"danger_annonce": Color(1.0, 0.2, 0.282, 0.30),
	"danger_eclair": Color("fff4e6"),
	# Ce qui s'utilise ou se ramasse : clair et chaud.
	"interactif": Color("f4d9a0"),
	"butin": Color("ffd84a"),
	# Interface, direction « Herbier » (jalon 10) : encre ivoire, filets d'or, papier brun chaud.
	# Mêmes valeurs que ui_theme.gd, qui les lit ici.
	"texte": Color("efe6cf"),
	"texte_doux": Color("a99c80"),
	"accent": Color("7fd36b"),
	"or": Color("d9b566"),
	"encre_rouge": Color("d98a76"),
	"papier": Color("221c15"),
	"papier_sombre": Color("17130e"),
	"panneau": Color(0.118, 0.098, 0.074, 0.95),
	# Traits et ombres.
	"contour": Color("140f0c"),
	"ombre": Color(0.0, 0.0, 0.0, 0.35),
}

# --- Accessibilité (jalon 11) ---
#
# Modes daltoniens : seuls les rôles qui portent un signal (danger, élite, butin) changent, vers
# des teintes que chaque forme de daltonisme distingue du sol, du héros et entre elles (palette
# d'Okabe et Ito). Vérifié par tests/access_test.gd (simulation de Machado et al., 2009).
const PALETTES_DALTONIENNES := {
	"protanopie": {
		"danger": Color("ff8a1f"), "danger_annonce": Color(1.0, 0.54, 0.12, 0.32), "danger_eclair": Color("fff4e6"),
		"elite": Color("4fb4ff"), "butin": Color("fff04a"),
	},
	"deuteranopie": {
		"danger": Color("ff7a14"), "danger_annonce": Color(1.0, 0.48, 0.08, 0.32), "danger_eclair": Color("fff4e6"),
		"elite": Color("4fa0ff"), "butin": Color("fff04a"),
	},
	"tritanopie": {
		"danger": Color("ff2e4a"), "danger_annonce": Color(1.0, 0.18, 0.29, 0.32), "danger_eclair": Color("ffffff"),
		"elite": Color("2fe0d0"), "butin": Color("ffb0d8"),
	},
}
## Contraste renforcé : voile d'annonce plus opaque.
const ANNONCE_CONTRASTE := 0.46

static var _access := {}
## Vrai quand un mode d'accessibilité est actif : les annonces de danger gagnent des hachures
## (la forme porte le signal, pas seulement la couleur).
static var motifs := false


## Applique le mode daltonien (Settings.COLORBLIND_MODES) et le contraste renforcé à c().
static func set_access(mode: String, contraste := false) -> void:
	_access = PALETTES_DALTONIENNES.get(mode, {}).duplicate()
	if contraste:
		var a: Color = _access.get("danger_annonce", PALETTE["danger_annonce"])
		_access["danger_annonce"] = Color(a, ANNONCE_CONTRASTE)
	motifs = mode != "aucun" or contraste


## Couleur de rôle par nom. Un nom inconnu est une erreur (magenta à l'écran, message en console).
static func c(role: String) -> Color:
	if _access.has(role):
		return _access[role]
	if PALETTE.has(role):
		return PALETTE[role]
	push_error("Art.c : rôle de couleur inconnu « %s »" % role)
	return Color.MAGENTA


## Groupes de la palette, dans l'ordre de la planche.
# Noms de la planche de la charte (outil de développement), jamais montrés en jeu. # i18n: non (début)
const GROUPES := [
	["Fond", ["sol_mort", "sol_vivant", "brume", "decor", "decor_vivant"]],
	["Héros et alliés", ["joueur", "joueur_accent", "allie"]],
	["Flétris", ["ennemi", "ennemi_contour", "ennemi_oeil", "elite"]],
	["Danger", ["danger", "danger_annonce", "danger_eclair"]],
	["Utile", ["interactif", "butin"]],
	["Interface", ["texte", "texte_doux", "accent", "or", "encre_rouge"]],
	["Papier, traits", ["papier", "papier_sombre", "panneau", "contour", "ombre"]],
]

# --- Éléments ---
#
# Chaque élément a une couleur principale, une couleur claire (reflet, cœur d'une lueur), une
# sombre (contour, ombre), un motif et une icône. La couleur seule ne suffit jamais : le motif
# porte aussi l'information (lisible par les daltoniens et en noir et blanc).
const ELEMENTS := {
	"epine": {
		"nom": "Épine", "sens": "physique : pointes, perforation, dégâts renvoyés",
		"couleur": Color("dcb878"), "clair": Color("f4ead0"), "sombre": Color("6e5428"),
		"motif": "pointes",
	},
	"saignement": {
		"nom": "Saignement", "sens": "dégâts dans la durée, cumulables",
		"couleur": Color("7a0c22"), "clair": Color("e0435a"), "sombre": Color("3a0410"),
		"motif": "gouttes",
	},
	"racine": {
		"nom": "Racine", "sens": "immobilise, tient, protège",
		"couleur": Color("857a44"), "clair": Color("9fbf5a"), "sombre": Color("3e321a"),
		"motif": "noeuds",
	},
	"poison": {
		"nom": "Poison", "sens": "affaiblit, se répand en nuage",
		"couleur": Color("9d6ae8"), "clair": Color("d6c0ff"), "sombre": Color("3e2266"),
		"motif": "bulles",
	},
	"cendre": {
		"nom": "Cendre", "sens": "brûle, explose : l'arme des Flétris",
		"couleur": Color("f0601a"), "clair": Color("ffc56a"), "sombre": Color("5a1e08"),
		"motif": "braises",
	},
	"seve": {
		"nom": "Sève", "sens": "la vie : soins, essences, sol ravivé",
		"couleur": Color("8af5c0"), "clair": Color("eafff4"), "sombre": Color("1f6a4a"),
		"motif": "lueur",
	},
	"vent": {
		"nom": "Vent", "sens": "pousse, disperse, accélère : souffles et rafales",
		"couleur": Color("a4bcd4"), "clair": Color("e8f2fa"), "sombre": Color("2e4458"),
		"motif": "rafales",
	},
	"lumiere": {
		"nom": "Lumière", "sens": "éblouit, révèle, frappe juste : rayons et coups critiques",
		"couleur": Color("fffb3d"), "clair": Color("fffde6"), "sombre": Color("6e6410"),
		"motif": "rayons",
	},
}
# i18n: non (fin)
const ELEMENT_IDS := ["epine", "saignement", "racine", "poison", "cendre", "seve", "vent", "lumiere"]

## Couleur d'un élément : variante "couleur" (par défaut), "clair" ou "sombre".
static func ec(element: String, variante := "couleur") -> Color:
	if ELEMENTS.has(element):
		return ELEMENTS[element][variante]
	push_error("Art.ec : élément inconnu « %s »" % element)
	return Color.MAGENTA


## Élément dominant d'une compétence (pour sa couleur, ses particules et son icône).
const ELEMENT_DE_COMPETENCE := {
	"graine": "seve", "nova": "epine", "fouet": "epine", "volee": "epine", "racines": "racine",
	"saignee": "saignement", "cloud": "poison", "bloom": "seve",
	"vesse": "poison", "essaim": "poison", "eclosion": "poison",
	"tornade": "vent", "ruee": "vent", "appel_air": "vent",
	"aurore": "lumiere", "prisme": "lumiere", "lance_aube": "lumiere",
	"liane": "seve", "fontaine": "seve", "cocon": "seve",
	"ecorce": "racine", "ancrage": "racine", "pieux": "racine",
}

# --- Bestiaire d'herbier (refonte des personnages, vague 0 : planche de direction) ---
#
# Couleur du corps d'un Flétri = sa région (deux tons et une lumière : « clair », « ombre »,
# « reflet »), plus un « detail » propre à la région (feuille sèche, ocre, lichen). La braise
# (« braise », « braise_coeur ») est le signe commun de l'ennemi ; le « ronge » est la Flétrissure
# qui mange la bête. Le héros garde son corps crème ; ses feuilles prennent la couleur de son build.
# Utilisé seulement par scripts/creature_art/ (planche), rien n'est encore branché dans le jeu.
const BESTIAIRE := {
	"encre": Color("1a1210"),
	"braise": Color("ff8a2a"),
	"braise_coeur": Color("ffd27a"),
	"ronge": Color("2b1a22"),
	"os": Color("e6d2a8"),
	"ronce": {"clair": Color("8e3a55"), "ombre": Color("4e1a33"), "reflet": Color("d98aa0"), "detail": Color("6b6a3a")},
	"racine": {"clair": Color("9a8f7a"), "ombre": Color("564c3e"), "reflet": Color("d8cfb8"), "detail": Color("b5893f")},
	"vent": {"clair": Color("a3b6c8"), "ombre": Color("5a6a80"), "reflet": Color("e4eef7"), "detail": Color("d6c27e"),
		"plume": Color("77869c"), "duvet": Color("dfe2dc"), "aile": Color("c8d4df")},
	# Aube : verre pâle et mauve des falaises (corps, clair pour trancher sur le calcaire et se distinguer
	# de Vent et de Racine même pour un daltonien), verre clair (ailes, aiguilles), lumière d'or sale (detail).
	"aube": {"clair": Color("e2d8f4"), "ombre": Color("7c6c9c"), "reflet": Color("fcf9ff"), "detail": Color("e6c25a"),
		"verre": Color("bfe0ea"), "verre_ombre": Color("587886"), "lueur": Color("fff2c4")},
	# Sève (R4) : vert profond de mare (distinct des autres régions pour les daltoniens, bestiaire_test), loin du vert menthe de la sève vivante ; detail = vase ocre ; vase = limon du fond.
	"seve": {"clair": Color("308533"), "ombre": Color("1e5c2a"), "reflet": Color("b0e6a8"), "detail": Color("a88d52"), "vase": Color("4a3f30")},
}
## Porte-Graine qui évolue (planche v3) : teinte claire du corps (le héros reste clair, les Flétris
## sombres), feuilles et accent de chaque branche. « aucun » : la graine commune du début.
const FEUILLES_BUILD := {
	"aucun": {"corps": Color("f3ead2"), "clair": Color("6fae58"), "ombre": Color("355e2c"), "reflet": Color("c6ecb0"), "detail": Color("8af5c0"), "accent": Color("8af5c0"), "lueur": Color("eafff4")},
	"ronce": {"corps": Color("f2cfc4"), "clair": Color("5f7d3a"), "ombre": Color("2f3f1f"), "reflet": Color("b9cf8a"), "detail": Color("e0675e"), "accent": Color("d4485a"), "lueur": Color("ff9a8a")},
	"seve": {"corps": Color("c9f7e2"), "clair": Color("4fd69a"), "ombre": Color("1f7a56"), "reflet": Color("d6fff0"), "detail": Color("eafff4"), "accent": Color("eafff4"), "lueur": Color("eafff4")},
	"racine": {"corps": Color("e6d1a8"), "clair": Color("7a8a3c"), "ombre": Color("3e4a1e"), "reflet": Color("c9d68a"), "detail": Color("8a6a3e"), "accent": Color("c08a3e"), "lueur": Color("f2d27a")},
	"vent": {"corps": Color("e4eef7"), "clair": Color("a4bcd4"), "ombre": Color("4e6680"), "reflet": Color("f2f8ff"), "detail": Color("fdf6dc"), "accent": Color("8fb4e0"), "lueur": Color("d8ecff")},
	"spore": {"corps": Color("efe2f5"), "clair": Color("a07cc0"), "ombre": Color("4a3560"), "reflet": Color("e2d0f2"), "detail": Color("d9a64a"), "accent": Color("b48ae6"), "lueur": Color("e2ccff")},
	"aube": {"corps": Color("fbf3dc"), "clair": Color("d9b860"), "ombre": Color("6e5a2e"), "reflet": Color("fff4c8"), "detail": Color("fffb3d"), "accent": Color("f0c840"), "lueur": Color("fffde6")},
}


## Couleurs du monde « Paysages d'herbier » (refonte du monde, vague 0 : planche W, scripts/world_art/).
## Par région puis par état : « fletri » (le Cœur vit : couleurs bues, cendre, braise dans les fissures),
## « apaise » (terre morte apaisée hors du bord de vie, une fois le Cœur purifié), « ravive » (dans le bord
## de vie : la couleur propre à la région revient). Le vert sève reste réservé au bord de vie et à la graine.
const MONDE := {
	"commun": {
		"seve": Color("8af5c0"), "seve_clair": Color("eafff4"), "seve_sombre": Color("1f7a56"),
		"encre_decor": Color("1f1614"), "lumiere": Color("ffe9bf"), "nuit": Color("120c10"),
		"pierre": {"clair": Color("948a7c"), "ombre": Color("5a524a"), "reflet": Color("cbc2b2")},
	},
	"ronce": {
		# Sol en couches et décor cuit (scripts/world_bake/, ex-prototype P) : lavis, matière, détails en grappes.
		"sol_couches": {
			# Lavis (couche 1) : grandes formes sans bruit fin. Flétri sombre, ravivé nettement plus clair.
			"lavis_mort_sombre": Color("2e2224"), "lavis_mort_clair": Color("47343a"),
			"lavis_vif_sombre": Color("4f6b34"), "lavis_vif_clair": Color("86a24a"),
			# Matière (couche 2) : encre fine des tiges rampantes, épines, fissures.
			"encre_morte": Color("1f1318"), "tige_morte": Color("5a3442"), "fissure": Color("1a1214"),
			"encre_vive": Color("2c3a1a"), "tige_vive": Color("3f5a26"), "feuille": Color("6f9a3a"),
			# Détails en grappes (couche 3) : cailloux, feuilles sèches ; herbe, fleurs et baies.
			"caillou": Color("6b5a58"), "caillou_lumiere": Color("9a8783"), "feuille_seche": Color("6e4a3a"),
			"herbe": Color("5e8a36"), "herbe_claire": Color("a6c860"), "fleur": Color("f08a8a"),
			"fleur_coeur": Color("ffe2a0"), "baie": Color("d4485a"), "pousse": Color("b8e070"),
		},
		"fletri": {
			"sol": Color("4f3d35"), "sol_clair": Color("62493b"), "sol_sombre": Color("3b2d2a"),
			"matiere": Color("2a1d1a"), "feuille": Color("7d4b30"), "feuille_2": Color("94603a"),
			"cendre": Color("8c837c"), "touffe": Color("6d5a3e"), "touffe_2": Color("51442f"),
			"bois": {"clair": Color("54403a"), "ombre": Color("2e221f"), "reflet": Color("7a6458")},
			"ronce": {"clair": Color("4c3036"), "ombre": Color("2a1a1f"), "reflet": Color("7a5a60")},
			"feuillage": {"clair": Color("4e3f33"), "ombre": Color("2e2520"), "reflet": Color("6e5c4a")},
			"pierre": {"clair": Color("5c514a"), "ombre": Color("352c28"), "reflet": Color("7c6e62")},
			"fleur": Color("8a6a5a"), "fruit": Color("2e1a24"),
			"air": Color("5a4650"), "voile": Color("1b1216"), "particule": Color("9a8f88"),
		},
		"apaise": {
			"sol": Color("67503f"), "sol_clair": Color("7a604a"), "sol_sombre": Color("523f34"),
			"matiere": Color("3a2a22"), "feuille": Color("8e5c36"), "feuille_2": Color("a87444"),
			"cendre": Color("a39a8e"), "touffe": Color("7e7a46"), "touffe_2": Color("5e5c32"),
		},
		"ravive": {
			"sol": Color("728840"), "sol_clair": Color("8ea352"), "sol_sombre": Color("536a2e"),
			"matiere": Color("44572a"), "feuille": Color("c2cf74"), "feuille_2": Color("6f8a3a"),
			"cendre": Color("e8e0c8"), "touffe": Color("5f8c38"), "touffe_2": Color("3f6a28"),
			"bois": {"clair": Color("7a5a44"), "ombre": Color("45322a"), "reflet": Color("a8866a")},
			"ronce": {"clair": Color("6f8a3a"), "ombre": Color("39531f"), "reflet": Color("b8d27a")},
			"feuillage": {"clair": Color("6a8c3c"), "ombre": Color("324f22"), "reflet": Color("b4cc78")},
			"pierre": {"clair": Color("a69584"), "ombre": Color("6a5a4c"), "reflet": Color("d8cab4")},
			"fleur": Color("f4a3b4"), "fleur_coeur": Color("f7d36a"), "fleur_2": Color("fff0e6"), "fruit": Color("4a1c42"),
			"air": Color("ffe2c4"), "voile": Color("3a2620"), "particule": Color("ffc2cc"),
		},
	},
	"spore": {
		"fletri": {
			"sol": Color("43384c"), "sol_clair": Color("54485c"), "sol_sombre": Color("32293b"),
			"matiere": Color("231c2b"), "feuille": Color("6c5a74"), "feuille_2": Color("82708a"),
			"cendre": Color("a89cb2"), "touffe": Color("5e5562"), "touffe_2": Color("463f4c"),
			"eau": Color("2a2338"), "eau_reflet": Color("7a6e94"),
			"bois": {"clair": Color("5a4c5c"), "ombre": Color("332a36"), "reflet": Color("8a7a8e")},
			"chapeau": {"clair": Color("554666"), "ombre": Color("3b2f4a"), "reflet": Color("9c88ae")},
			"pied": {"clair": Color("5e5768"), "ombre": Color("383242"), "reflet": Color("7e7688")},
			"feuillage": {"clair": Color("5c5866"), "ombre": Color("38343f"), "reflet": Color("86808e")},
			"pierre": {"clair": Color("5a5464"), "ombre": Color("38333f"), "reflet": Color("7a7486")},
			"fleur": Color("8a7a96"), "fruit": Color("2a2034"), "lueur": Color("9a88b0"),
			"air": Color("4a4060"), "voile": Color("120e1a"), "particule": Color("a898c0"),
		},
		"apaise": {
			"sol": Color("4e4a5c"), "sol_clair": Color("5e5a6c"), "sol_sombre": Color("3c384a"),
			"matiere": Color("2c2838"), "feuille": Color("6e6a7e"), "feuille_2": Color("848098"),
			"cendre": Color("b4aec2"), "touffe": Color("5a6a6a"), "touffe_2": Color("44504e"),
			"eau": Color("26283a"), "eau_reflet": Color("70789a"),
		},
		"ravive": {
			"sol": Color("2a7069"), "sol_clair": Color("3f9184"), "sol_sombre": Color("1c5352"),
			"matiere": Color("17423f"), "feuille": Color("7fd0b8"), "feuille_2": Color("3e9484"),
			"cendre": Color("d8fff2"), "touffe": Color("3fa08a"), "touffe_2": Color("237062"),
			"eau": Color("1d4a64"), "eau_reflet": Color("9fe8e2"),
			"bois": {"clair": Color("6a5a52"), "ombre": Color("3c322e"), "reflet": Color("9a887c")},
			"chapeau": {"clair": Color("7854a8"), "ombre": Color("50387c"), "reflet": Color("dcc2ff")},
			"pied": {"clair": Color("aaa298"), "ombre": Color("6a625a"), "reflet": Color("d8d0c4")},
			"feuillage": {"clair": Color("3f9a7e"), "ombre": Color("1f5e4e"), "reflet": Color("9ae8c8")},
			"pierre": {"clair": Color("6e7a86"), "ombre": Color("414c58"), "reflet": Color("9aaab6")},
			"fleur": Color("7ff0dc"), "fleur_coeur": Color("e8fffa"), "fleur_2": Color("c9a2ff"), "fruit": Color("e8a640"), "lueur": Color("8affea"),
			"air": Color("c8fff0"), "voile": Color("0e2228"), "particule": Color("a8fff0"),
		},
	},
}

## Couleur du sol en couches et du décor cuit : mpc("ronce", "lavis_vif_clair") (MONDE[région]["sol_couches"]).
static func mpc(region: String, key: String) -> Color:
	var r: Dictionary = MONDE.get(region, {}).get("sol_couches", {})
	if r.has(key):
		return r[key]
	push_error("Art.mpc : couleur du sol en couches inconnue « %s/%s »" % [region, key])
	return Color.MAGENTA



## Couleur du monde : mc("ronce", "fletri", "sol"), ou mc("commun", "", "seve"). Une clé absente d'un
## état « apaise » est cherchée dans « fletri » (le décor apaisé garde ses formes mortes).
static func mc(region: String, etat: String, cle: String):
	var r: Dictionary = MONDE.get(region, {})
	if etat == "":
		return r.get(cle, Color.MAGENTA)
	var e: Dictionary = r.get(etat, {})
	if e.has(cle):
		return e[cle]
	if etat == "apaise" and r.get("fletri", {}).has(cle):
		return r["fletri"][cle]
	push_error("Art.mc : couleur du monde inconnue « %s/%s/%s »" % [region, etat, cle])
	return Color.MAGENTA


## Couleur du bestiaire : bc("encre"), ou bc("ronce", "clair") pour la palette d'une région.
static func bc(nom: String, variante := "") -> Color:
	var v = BESTIAIRE.get(nom, null)
	if v is Color:
		return v
	if v is Dictionary and v.has(variante):
		return v[variante]
	push_error("Art.bc : couleur du bestiaire inconnue « %s/%s »" % [nom, variante])
	return Color.MAGENTA


# --- Traits, ombres, lumière ---

const TRAIT_FIN := 1.5     ## détails, motifs, icônes de petite taille
const TRAIT := 2.5         ## contour standard d'un acteur
const TRAIT_FORT := 4.0    ## acteur lourd, boss, contour d'annonce au moment du coup
## L'ombre portée est une ellipse aplatie sous l'acteur, décalée vers le bas (lumière zénithale, un peu de face).
const OMBRE_APLATI := 0.38
const OMBRE_DECALAGE := 0.55

## Ordre de dessin (z_index) : sol < décor bas < objets interactifs < acteurs < projectiles < effets < décor haut < interface.
const COUCHE := {
	"sol": -100, "decor_bas": -50, "interactif": -20, "acteurs": 0,
	"projectiles": 10, "effets": 20, "decor_haut": 40, "interface": 100,
}

## Polygone plein qui se dessine seulement si Godot sait le trianguler. Un polygone aplati ou minuscule
## (effets qui naissent ou s'éteignent : surface nulle) ne se verrait pas, et Godot écrit alors
## « Invalid polygon data, triangulation failed » à chaque image : la sortie du jeu reste propre.
static func safe_polygon(ci: CanvasItem, points: PackedVector2Array, col: Color) -> void:
	if not Geometry2D.triangulate_polygon(points).is_empty():
		ci.draw_colored_polygon(points, col)


## Contour fermé d'un polygone, au trait de la charte.
static func outline(ci: CanvasItem, points: PackedVector2Array, col := Color(0, 0, 0, 0), width := TRAIT) -> void:
	if points.size() < 2:
		return
	if col.a == 0.0:
		col = c("contour")
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, col, width, true)


## Ombre portée sous un acteur de rayon r posé en pos.
static func shadow(ci: CanvasItem, pos: Vector2, r: float) -> void:
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, r * OMBRE_DECALAGE), r * 1.05, r * OMBRE_APLATI * 1.05), c("ombre"))


## Lueur douce d'un élément : trois halos de plus en plus clairs, puis un cœur.
static func glow(ci: CanvasItem, pos: Vector2, r: float, element := "seve") -> void:
	var col := ec(element)
	var core := ec(element, "clair")
	ci.draw_circle(pos, r, Color(col, 0.08))
	ci.draw_circle(pos, r * 0.7, Color(col, 0.14))
	ci.draw_circle(pos, r * 0.42, Color(col, 0.3))
	ci.draw_circle(pos, r * 0.2, Color(core, 0.9))


## Remplit une forme avec du volume, lumière venant d'en haut à gauche : côté ombre, face éclairée,
## reflet. light règle la force du reflet (0 : mat). Pour les acteurs et les objets importants.
## ci : un CanvasItem, ou un lot de triangles (draw_batch.gd) qui a les mêmes draw_*.
static func volume(ci, pts: PackedVector2Array, col: Color, light := 1.0) -> void:
	var cen := Vector2.ZERO
	for q in pts:
		cen += q
	cen /= pts.size()
	var r := 0.0
	for q in pts:
		r = maxf(r, q.distance_to(cen))
	ci.draw_colored_polygon(pts, col.darkened(0.38))
	ci.draw_colored_polygon(_xform(pts, cen, 0.84, Vector2(-0.06, -0.09) * r), col)
	if light > 0.0:
		ci.draw_colored_polygon(_xform(pts, cen, 0.4, Vector2(-0.24, -0.3) * r), Color(col.lightened(0.3), 0.5 * light))


## Disque avec du volume (même lumière que volume()).
static func volume_circle(ci, pos: Vector2, r: float, col: Color, light := 1.0) -> void:
	ci.draw_circle(pos, r, col.darkened(0.38))
	ci.draw_circle(pos + Vector2(-0.07, -0.1) * r, r * 0.84, col)
	if light > 0.0:
		ci.draw_circle(pos + Vector2(-0.3, -0.34) * r, r * 0.34, Color(col.lightened(0.32), 0.55 * light))


static func _xform(pts: PackedVector2Array, cen: Vector2, k: float, off: Vector2) -> PackedVector2Array:
	# cen + (q - cen) * k + off pour chaque point, calculé par le moteur (chemin chaud des silhouettes).
	return Transform2D(0.0, Vector2(k, k), 0.0, cen - cen * k + off) * pts


## Polygone d'une ellipse (rayons rx, ry) : sert aux ombres et aux zones vues en perspective.
static func ellipse(pos: Vector2, rx: float, ry: float, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		pts.append(pos + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# --- Motifs des éléments ---

## Remplit un rectangle avec le motif d'un élément (échantillon de la planche, tuile d'état).
## t : temps en secondes, pour les motifs animés.
static func motif(ci: CanvasItem, element: String, rect: Rect2, t := 0.0) -> void:
	var e: Dictionary = ELEMENTS[element]
	ci.draw_rect(rect, Color(e["sombre"], 0.55))
	var step := 22.0
	var cols := int(rect.size.x / step)
	var rows := int(rect.size.y / step)
	var off := rect.position + (rect.size - Vector2(cols, rows) * step) / 2.0 + Vector2(step, step) / 2.0
	for j in rows:
		for i in cols:
			var p := off + Vector2(i * step + (step * 0.5 if j % 2 == 1 else 0.0), j * step)
			if p.x > rect.end.x - 4.0:
				continue
			_motif_unit(ci, element, p, step * 0.36, t + (i * 0.37 + j * 0.61))


## Marque d'état autour d'un acteur de rayon r : le motif de l'élément, animé par t.
## Pour les Flétris saignants, enracinés, empoisonnés, enflammés ; pour le héros sous un effet.
static func status(ci: CanvasItem, element: String, pos: Vector2, r: float, t := 0.0) -> void:
	var e: Dictionary = ELEMENTS[element]
	match element:
		"saignement":
			# Gouttes qui perlent sous le corps et tombent.
			for i in 3:
				var k := fposmod(t * 0.9 + i / 3.0, 1.0)
				var p := pos + Vector2((i - 1) * r * 0.55, r * (0.3 + 0.9 * k))
				_drop(ci, p, r * 0.22 * (1.0 - 0.4 * k), Color(e["clair"], 1.0 - k))
		"racine":
			# Racines noueuses qui enserrent le bas du corps.
			for i in 4:
				var a := PI * (0.15 + i * 0.23)
				var base := pos + Vector2.from_angle(a) * r * 1.25
				var tip := pos + Vector2.from_angle(a - 0.6) * r * 0.75
				ci.draw_polyline(PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(0, -r * 0.15), tip]), e["couleur"], TRAIT, true)
				ci.draw_circle(base.lerp(tip, 0.5) + Vector2(0, -r * 0.15), TRAIT * 0.9, e["clair"])
		"poison":
			# Bulles qui montent et éclatent.
			for i in 4:
				var k := fposmod(t * 0.7 + i * 0.27, 1.0)
				var p := pos + Vector2(sin(i * 2.1 + t * 2.0) * r * 0.7, -r * (0.2 + 1.2 * k))
				ci.draw_arc(p, r * (0.1 + 0.12 * k), 0.0, TAU, 12, Color(e["clair"], 1.0 - k), TRAIT_FIN, true)
		"cendre":
			# Braises qui s'envolent.
			for i in 4:
				var k := fposmod(t * 1.1 + i * 0.25, 1.0)
				var p := pos + Vector2(sin(i * 1.7 + t) * r * 0.8, -r * (0.3 + 1.3 * k))
				_ember(ci, p, r * 0.16 * (1.0 - 0.5 * k), Color(e["clair"], 1.0 - k))
		"epine":
			# Pointes qui hérissent le contour.
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0 + 0.2)
				_thorn(ci, pos + d * r * 1.02, d, r * 0.38, e["couleur"])
		"seve":
			# Halo vert qui respire.
			var b := 0.5 + 0.5 * sin(t * 3.0)
			ci.draw_arc(pos, r * (1.25 + 0.1 * b), 0.0, TAU, 32, Color(e["couleur"], 0.35 + 0.35 * b), TRAIT, true)
		"vent":
			# Rafales qui tournent autour du corps.
			for i in 3:
				var a := t * 2.4 + i * TAU / 3.0
				ci.draw_arc(pos, r * (1.2 + 0.12 * i), a, a + 1.1, 12, Color(e["clair"], 0.85 - 0.2 * i), TRAIT_FIN, true)
		"lumiere":
			# Ébloui : une étoile de rayons au-dessus de la tête, qui scintille.
			var b := 0.5 + 0.5 * sin(t * 6.0)
			var c := pos + Vector2(0, -r * 1.25)
			for i in 4:
				var d := Vector2.from_angle(i * TAU / 4.0 + t * 0.8)
				ci.draw_line(c - d * r * 0.42 * (0.7 + 0.3 * b), c + d * r * 0.42 * (0.7 + 0.3 * b), Color(e["clair"], 0.9), TRAIT_FIN, true)
			ci.draw_circle(c, r * 0.14, e["couleur"])
			ci.draw_arc(pos, r * 1.15, 0.0, TAU, 24, Color(e["couleur"], 0.25 + 0.3 * b), TRAIT_FIN, true)


static func _motif_unit(ci: CanvasItem, element: String, p: Vector2, s: float, t: float) -> void:
	var e: Dictionary = ELEMENTS[element]
	match e["motif"]:
		"pointes":
			_thorn(ci, p + Vector2(0, s * 0.6), Vector2.UP, s * 1.5, e["couleur"])
		"gouttes":
			_drop(ci, p, s * 0.7, e["clair"])
		"noeuds":
			ci.draw_line(p + Vector2(-s * 1.4, s * 0.4), p + Vector2(s * 1.4, -s * 0.4), e["couleur"], TRAIT)
			ci.draw_circle(p, s * 0.42, e["clair"])
		"bulles":
			ci.draw_arc(p + Vector2(-s * 0.3, s * 0.2), s * 0.55, 0.0, TAU, 14, e["clair"], TRAIT_FIN, true)
			ci.draw_arc(p + Vector2(s * 0.55, -s * 0.5), s * 0.3, 0.0, TAU, 10, e["couleur"], TRAIT_FIN, true)
		"braises":
			_ember(ci, p, s * 0.6, e["clair"])
			ci.draw_circle(p + Vector2(s * 0.8, s * 0.7), s * 0.18, e["couleur"])
		"lueur":
			ci.draw_circle(p, s * 0.9, Color(e["couleur"], 0.22))
			ci.draw_circle(p, s * 0.35, e["clair"])
		"rafales":
			_gust(ci, p + Vector2(-s * 0.2, -s * 0.35), s * 1.3, e["clair"], TRAIT_FIN)
			_gust(ci, p + Vector2(s * 0.2, s * 0.4), s * 0.9, e["couleur"], TRAIT_FIN)
		"rayons":
			# Petit soleil : un disque clair et six rayons courts.
			for i in 6:
				var d := Vector2.from_angle(i * TAU / 6.0)
				ci.draw_line(p + d * s * 0.55, p + d * s * 1.05, e["couleur"], TRAIT_FIN, true)
			ci.draw_circle(p, s * 0.38, e["clair"])


## En dessous de cette taille (px), un dessin d'effet qui s'éteint peut devenir un polygone dégénéré.
const SMALL_POLY := 1.0


## Une pointe d'épine : base large, pointe dans la direction d.
static func _thorn(ci: CanvasItem, base: Vector2, d: Vector2, len: float, col: Color) -> void:
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([base + n * len * 0.28, base + d * len, base - n * len * 0.28])
	if len < SMALL_POLY and Geometry2D.triangulate_polygon(pts).is_empty():
		return
	ci.draw_colored_polygon(pts, col)


## Une goutte : rond en bas, pointe en haut.
static func _drop(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(p, s, col)
	var pts := PackedVector2Array([p + Vector2(-s * 0.92, -s * 0.3), p + Vector2(0, -s * 2.1), p + Vector2(s * 0.92, -s * 0.3)])
	if s < SMALL_POLY and Geometry2D.triangulate_polygon(pts).is_empty():
		return
	ci.draw_colored_polygon(pts, col)


## Remplit un polygone sauf s'il est dégénéré (effet qui finit de s'effacer : points confondus ou
## qui se croisent). Godot ne dessinerait rien et écrirait « Invalid polygon data, triangulation
## failed » dans le journal : le rendu est le même, sans le message.
static func fill_safe(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	ci.draw_colored_polygon(pts, col)


## Une rafale : un trait qui file et s'enroule au bout (vers la droite).
static func _gust(ci: CanvasItem, p: Vector2, len: float, col: Color, width: float) -> void:
	var end := p + Vector2(len * 0.5, 0)
	ci.draw_line(p - Vector2(len * 0.5, 0), end, col, width, true)
	var r := len * 0.18
	ci.draw_arc(end + Vector2(0, -r), r, PI * 0.5, PI * 2.0, 10, col, width, true)


## Une braise : losange.
static func _ember(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.4), p + Vector2(s, 0), p + Vector2(0, s * 1.1), p + Vector2(-s, 0)]), col)


# --- Annonces de danger ---
#
# Une seule grammaire, pour les ennemis, les élites et le boss :
#   1. annonce (progression 0 → 1) : la forme apparaît en contour rouge, un voile la remplit
#      depuis l'origine de l'attaque ; dans le dernier quart, le contour clignote ;
#   2. frappe (frappe 0 → 1) : éclair blanc chaud sur toute la forme, puis il s'éteint.
# Formes (dictionnaires) :
#   {"type": "cercle", "centre": Vector2, "rayon": float}
#   {"type": "cone", "centre": Vector2, "direction": float (radians), "ouverture": float (radians), "rayon": float}
#   {"type": "ligne", "de": Vector2, "a": Vector2, "largeur": float}
const ANNONCE_CLIGNOTE := 0.75   ## à partir de cette progression, le contour clignote

## Dessine une attaque annoncée. progression : 0 → 1 pendant l'annonce. frappe : -1 tant que le coup
## n'est pas parti, puis 0 → 1 pendant l'éclair. t : temps (pour le clignotement).
static func telegraph(ci: CanvasItem, forme: Dictionary, progression: float, frappe := -1.0, t := 0.0) -> void:
	var danger := c("danger")
	if frappe >= 0.0:
		var k := clampf(frappe, 0.0, 1.0)
		var fl := c("danger_eclair").lerp(danger, k)
		ci.draw_colored_polygon(telegraph_polygon(forme, 1.0), Color(fl, 0.85 * (1.0 - k)))
		outline(ci, telegraph_polygon(forme, 1.0), Color(fl, 1.0 - k), TRAIT_FORT)
		return
	var p := clampf(progression, 0.0, 1.0)
	var full := telegraph_polygon(forme, 1.0)
	ci.draw_colored_polygon(full, Color(danger, 0.10))
	if p > 0.01:
		ci.draw_colored_polygon(telegraph_polygon(forme, p), c("danger_annonce"))
	if motifs:
		hatch(ci, telegraph_polygon(forme, 1.0), Color(danger, 0.35 + 0.4 * p))
	var a := 0.55 + 0.45 * p
	if p >= ANNONCE_CLIGNOTE:
		a = 0.6 + 0.4 * (0.5 + 0.5 * cos(t * TAU * 6.0))
	outline(ci, full, Color(danger, a), TRAIT)
	# Formes en plus de la couleur (daltonisme, foule) : un contour en tirets se resserre sur la
	# zone jusqu'au coup (le temps qui reste se lit à sa distance), et des chevrons montrent le sens.
	var marks := PackedVector2Array()
	_telegraph_marks(marks, forme, full, p, t)
	if not marks.is_empty():
		ci.draw_multiline(marks, Color(danger, 0.5 + 0.5 * a), TRAIT_FIN)


## Tirets qui se resserrent et chevrons d'une annonce, en segments (un seul appel de dessin).
static func _telegraph_marks(out: PackedVector2Array, forme: Dictionary, full: PackedVector2Array, p: float, t: float) -> void:
	var kind := str(forme.get("type", ""))
	var o: Vector2
	match kind:
		"cercle", "cone":
			o = forme["centre"]
		"ligne":
			o = forme["de"]
		_:
			return
	# Contour en tirets, agrandi de 35 % au début de l'annonce, posé sur la zone au moment du coup.
	var grow := 1.0 + 0.35 * (1.0 - p)
	var n := full.size()
	for i in n:
		var a := o + (full[i] - o) * grow
		var b := o + (full[(i + 1) % n] - o) * grow
		var len := a.distance_to(b)
		var steps := maxi(1, int(len / 14.0))
		for j in steps:
			if j % 2 == 0:
				out.append(a.lerp(b, float(j) / steps))
				out.append(a.lerp(b, float(j + 1) / steps))
	# Chevrons qui avancent dans le sens du coup.
	var dir: Vector2
	var reach: float
	var wing: float
	match kind:
		"cone":
			dir = Vector2.from_angle(forme["direction"])
			reach = forme["rayon"]
			wing = minf(18.0, reach * 0.12)
		"ligne":
			var v: Vector2 = forme["a"] - forme["de"]
			dir = v.normalized()
			reach = v.length()
			wing = minf(18.0, forme["largeur"] * 0.35)
		_:
			# Cercle : quatre chevrons sur le bord, tournés vers l'extérieur (la zone éclate).
			var r: float = forme["rayon"]
			wing = minf(14.0, r * 0.18)
			for i in 4:
				var d := Vector2.from_angle(TAU * i / 4.0 + PI / 4.0)
				_chevron(out, o + d * r * (0.62 + 0.18 * fposmod(t * 1.5, 1.0)), d, wing)
			return
	if reach <= 1.0:
		return
	for i in 3:
		var u := fposmod(t * 1.2 + i / 3.0, 1.0)
		_chevron(out, o + dir * reach * (0.15 + 0.75 * u), dir, wing)


static func _chevron(out: PackedVector2Array, tip: Vector2, d: Vector2, wing: float) -> void:
	var back := tip - d * wing * 0.8
	var n := d.orthogonal() * wing
	out.append_array([back + n, tip, tip, back - n])


## Hachures diagonales dans un polygone (zones de danger en mode daltonien ou contraste renforcé).
const HACHURE_PAS := 14.0
static func hatch(ci: CanvasItem, poly: PackedVector2Array, col: Color, pas := HACHURE_PAS) -> void:
	var segs := hatch_segments(poly, pas)
	if not segs.is_empty():
		ci.draw_multiline(segs, col, 1.5, true)


## Segments des hachures (paires de points), à 45°, découpés dans le polygone.
static func hatch_segments(poly: PackedVector2Array, pas := HACHURE_PAS) -> PackedVector2Array:
	var out := PackedVector2Array()
	if poly.size() < 3:
		return out
	var r := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		r = r.expand(q)
	var d := r.size.x + r.size.y
	var x := r.position.x - r.size.y
	while x < r.position.x + r.size.x:
		var line := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + d, r.end.y - d)])
		for seg in Geometry2D.intersect_polyline_with_polygon(line, poly):
			if seg.size() >= 2:
				out.append(seg[0])
				out.append(seg[seg.size() - 1])
		x += pas
	return out


## Polygone d'une forme d'annonce remplie à k (0 → 1) depuis l'origine de l'attaque.
static func telegraph_polygon(forme: Dictionary, k: float) -> PackedVector2Array:
	k = clampf(k, 0.0, 1.0)
	var pts := PackedVector2Array()
	match str(forme.get("type", "")):
		"cercle":
			return ellipse(forme["centre"], forme["rayon"] * k, forme["rayon"] * k, 32)
		"cone":
			var o: Vector2 = forme["centre"]
			var half: float = forme["ouverture"] / 2.0
			var r: float = forme["rayon"] * k
			pts.append(o)
			for i in 13:
				pts.append(o + Vector2.from_angle(forme["direction"] - half + i * 2.0 * half / 12.0) * r)
		"ligne":
			var a: Vector2 = forme["de"]
			var b: Vector2 = a.lerp(forme["a"], k)
			var n: Vector2 = (forme["a"] - a).normalized().orthogonal() * forme["largeur"] / 2.0
			pts.append_array([a + n, b + n, b - n, a - n])
		_:
			push_error("Art.telegraph : forme inconnue « %s »" % forme.get("type", ""))
	return pts


# --- Daltonisme ---
#
# Simulation de Machado, Oliveira et Fernandes (2009), sévérité maximale, en RGB linéaire.
# Sert à la planche (les éléments vus par un daltonien) et au test qui vérifie qu'ils restent distincts.
const DALTONISMES := {
	"protanopie": [Vector3(0.152286, 1.052583, -0.204868), Vector3(0.114503, 0.786281, 0.099216), Vector3(-0.003882, -0.048116, 1.051998)],
	"deuteranopie": [Vector3(0.367322, 0.860646, -0.227968), Vector3(0.280085, 0.672501, 0.047413), Vector3(-0.011820, 0.042940, 0.968881)],
	"tritanopie": [Vector3(1.255528, -0.076749, -0.178779), Vector3(-0.078411, 0.930809, 0.147602), Vector3(0.004733, 0.691367, 0.303900)],
}

## La couleur telle que la voit une personne atteinte de la forme de daltonisme donnée.
static func simulate(col: Color, kind: String) -> Color:
	var m: Array = DALTONISMES[kind]
	var l := Vector3(col.srgb_to_linear().r, col.srgb_to_linear().g, col.srgb_to_linear().b)
	var o := Color(clampf(m[0].dot(l), 0, 1), clampf(m[1].dot(l), 0, 1), clampf(m[2].dot(l), 0, 1), col.a)
	return o.linear_to_srgb()


## Coordonnées CIELAB (L, a, b) d'une couleur sRGB, illuminant D65.
static func lab(col: Color) -> Vector3:
	var l := col.srgb_to_linear()
	var x := (0.4124 * l.r + 0.3576 * l.g + 0.1805 * l.b) / 0.95047
	var y := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	var z := (0.0193 * l.r + 0.1192 * l.g + 0.9505 * l.b) / 1.08883
	var f := func(v: float) -> float: return pow(v, 1.0 / 3.0) if v > 0.008856 else 7.787 * v + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## Écart perçu entre deux couleurs (ΔE 1976). Au-dessus de 20, on les distingue d'un coup d'œil.
static func delta_e(a: Color, b: Color) -> float:
	return lab(a).distance_to(lab(b))


# --- Icônes ---
#
# Une icône par compétence, élément, famille de statistiques, objet du monde et greffe.
# La même partout : barre de compétences, arbre, infobulles, journal, ramassage.
# Silhouettes pleines, lisibles à 20 px ; un détail clair au plus.
const ICONES := {
	"elements": ["epine", "saignement", "racine", "poison", "cendre", "seve", "vent", "lumiere"],
	"competences": ["graine", "nova", "fouet", "racines", "volee", "saignee", "cloud", "bloom", "vesse", "essaim", "eclosion", "tornade", "ruee", "appel_air", "aurore", "prisme", "lance_aube", "liane", "fontaine", "cocon", "ecorce", "ancrage", "pieux"],
	"statistiques": ["degats", "attaque", "projectile", "critique", "vie", "regen", "armure", "vitesse", "esquive", "zone", "collecte", "competence"],
	"monde": ["sanctuaire", "autel", "coeur", "arene", "secret", "seve_perdue", "essence", "greffe"],
	# Formes de l'attaque de base (data/attack.json) et nœud qui la modifie : Art.icon("attaque_<forme>").
	"attaques": ["attaque_graine", "attaque_echarde", "attaque_fouet", "attaque_ronce_vive", "attaque_spore_lobee", "attaque_dard", "attaque_lame", "attaque_bourrasque", "attaque_rayon", "attaque_perle", "attaque_massue", "attaque_mod"],
}
## Nom affiché de chaque icône (planche de la charte seulement). # i18n: non (début)
const NOM_ICONE := {
	"graine": "Graines", "nova": "Couronne d'épines", "fouet": "Fouet de ronce", "racines": "Racines voraces",
	"volee": "Volée d'épines", "saignee": "Saignée", "cloud": "Nuage de spores", "bloom": "Floraison",
	"vesse": "Vesse-de-loup", "essaim": "Essaim", "eclosion": "Éclosion",
	"degats": "Dégâts", "attaque": "Vitesse d'attaque", "projectile": "Projectiles", "critique": "Critique",
	"vie": "Vie", "regen": "Régénération", "armure": "Armure", "vitesse": "Déplacement", "esquive": "Esquive",
	"zone": "Zones", "collecte": "Collecte", "competence": "Compétence",
	"sanctuaire": "Sanctuaire", "autel": "Autel", "coeur": "Cœur de flétrissure", "arene": "Arène",
	"secret": "Secret", "seve_perdue": "Sève perdue", "essence": "Essence de vie", "greffe": "Greffe",
	"attaque_graine": "Attaque : graines", "attaque_echarde": "Attaque : échardes", "attaque_fouet": "Attaque : fouet",
	"attaque_ronce_vive": "Attaque : ronces vives", "attaque_spore_lobee": "Attaque : spores lobées",
	"attaque_dard": "Attaque : dards fongiques", "attaque_mod": "Attaque modifiée",
	"tornade": "Tornade", "ruee": "Ruée", "appel_air": "Appel d'air",
	"attaque_lame": "Attaque : lames de vent", "attaque_bourrasque": "Attaque : bourrasque",
	"aurore": "Aurore", "prisme": "Prisme", "lance_aube": "Lance d'aube", "attaque_rayon": "Attaque : rayon d'aube",
	"liane": "Liane buveuse", "fontaine": "Fontaine de sève", "cocon": "Cocon de sève",
	"attaque_perle": "Attaque : perles de sève",
	"ecorce": "Bouclier d'écorce", "ancrage": "Ancrage", "pieux": "Pieux", "attaque_massue": "Attaque : massue de bois",
} # i18n: non (fin)
## Élément de chaque forme de l'attaque de base (le même que dans data/attack.json).
const ELEMENT_D_ATTAQUE := {
	"attaque_graine": "seve", "attaque_echarde": "epine", "attaque_fouet": "epine", "attaque_ronce_vive": "saignement",
	"attaque_spore_lobee": "poison", "attaque_dard": "poison",
	"attaque_lame": "vent", "attaque_bourrasque": "vent",
	"attaque_rayon": "lumiere",
	"attaque_perle": "seve",
	"attaque_massue": "racine",
}
## Couleur par défaut d'une icône qui n'est pas un élément.
const COULEUR_ICONE := {
	"degats": "texte", "attaque": "texte", "projectile": "texte", "critique": "or", "vie": "danger",
	"regen": "accent", "armure": "texte", "vitesse": "texte", "esquive": "texte", "zone": "texte",
	"collecte": "butin", "competence": "or",
	"sanctuaire": "interactif", "autel": "interactif", "coeur": "elite", "arene": "danger", "secret": "or",
	"seve_perdue": "joueur_accent", "essence": "joueur_accent", "greffe": "butin", "attaque_mod": "or",
}

## Couleur naturelle d'une icône (celle de son élément, sinon celle de son rôle).
static func icon_color(id: String) -> Color:
	if ELEMENTS.has(id):
		return ec(id)
	if ELEMENT_DE_COMPETENCE.has(id):
		return ec(ELEMENT_DE_COMPETENCE[id])
	if ELEMENT_D_ATTAQUE.has(id):
		return ec(ELEMENT_D_ATTAQUE[id])
	return c(COULEUR_ICONE.get(id, "texte"))


## Toutes les icônes connues, dans l'ordre de la planche.
static func icon_ids() -> Array:
	var out := []
	for g in ICONES:
		out.append_array(ICONES[g])
	return out


## Dessine l'icône id centrée dans rect (carré conseillé). col : couleur de l'icône, sa couleur
## naturelle par défaut. Le dessin tient dans le cercle inscrit, au trait de la charte.
## Au-dessus de 10 px de demi-côté, l'icône prend du relief : sa propre forme, assombrie et décalée
## vers le bas, lui fait une tranche (comme une pièce découpée et posée).
static func icon(ci: CanvasItem, id: String, rect: Rect2, col := Color(0, 0, 0, 0)) -> void:
	var p := rect.get_center()
	var s := minf(rect.size.x, rect.size.y) * 0.42
	if col.a == 0.0:
		col = icon_color(id)
	var lw := maxf(s * 0.14, 1.2)
	if s >= 10.0:
		var edge := col.darkened(0.62)
		_icon_body(ci, id, p + Vector2(0, s * 0.11), s, edge, edge, edge, lw)
	_icon_body(ci, id, p, s, col, col.lerp(Color.WHITE, 0.6), col.darkened(0.55), lw)


## Médaillon d'icône (barre de compétences, infobulles, journal) : disque sombre, anneau à la
## couleur de l'icône, reflet en haut, puis l'icône en relief.
static func icon_badge(ci: CanvasItem, id: String, rect: Rect2, col := Color(0, 0, 0, 0)) -> void:
	var p := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) / 2.0
	if col.a == 0.0:
		col = icon_color(id)
	ci.draw_circle(p + Vector2(0, r * 0.08), r, c("ombre"))
	ci.draw_circle(p, r, c("contour"))
	ci.draw_circle(p, r * 0.9, col.darkened(0.82))
	ci.draw_circle(p + Vector2(0, -r * 0.12), r * 0.74, Color(col.darkened(0.65), 0.6))
	ci.draw_arc(p, r * 0.93, 0.0, TAU, 40, col.darkened(0.25), maxf(r * 0.08, 1.2), true)
	ci.draw_arc(p, r * 0.8, PI * 1.12, PI * 1.88, 20, Color(1, 1, 1, 0.16), maxf(r * 0.07, 1.0), true)
	icon(ci, id, Rect2(p - Vector2(r, r) * 0.72, Vector2(r, r) * 1.44), col)


static func _icon_body(ci: CanvasItem, id: String, p: Vector2, s: float, col: Color, clair: Color, sombre: Color, lw: float) -> void:
	var P := func(x: float, y: float) -> Vector2: return p + Vector2(x, y) * s
	match id:
		# Éléments
		"epine":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.55, 0.95), P.call(0.05, -1.0), P.call(0.25, -0.1), P.call(0.55, 0.95)]), col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.05, -1.0), P.call(0.25, -0.1), P.call(-0.05, 0.1)]), clair)
		"saignement":
			_drop(ci, P.call(0, 0.35), s * 0.58, col)
			ci.draw_circle(P.call(-0.2, 0.25), s * 0.15, clair)
		"racine":
			ci.draw_polyline(PackedVector2Array([P.call(0, -1.0), P.call(0.05, -0.2), P.call(-0.45, 0.45), P.call(-0.8, 0.95)]), col, lw * 1.4, true)
			ci.draw_polyline(PackedVector2Array([P.call(0.05, -0.2), P.call(0.45, 0.35), P.call(0.55, 0.95)]), col, lw * 1.2, true)
			ci.draw_polyline(PackedVector2Array([P.call(-0.45, 0.45), P.call(-0.1, 0.9)]), col, lw, true)
			ci.draw_circle(P.call(0.05, -0.2), lw * 1.1, clair)
			ci.draw_circle(P.call(-0.45, 0.45), lw * 0.9, clair)
		"poison":
			ci.draw_circle(P.call(-0.25, 0.35), s * 0.5, col)
			ci.draw_circle(P.call(0.45, -0.25), s * 0.32, col)
			ci.draw_circle(P.call(-0.05, -0.7), s * 0.2, col)
			ci.draw_arc(P.call(-0.38, 0.2), s * 0.22, PI, PI * 1.6, 8, clair, lw * 0.8, true)
		"cendre":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -1.0), P.call(0.55, -0.1), P.call(0.6, 0.45), P.call(0, 0.95), P.call(-0.6, 0.45), P.call(-0.55, -0.1), P.call(-0.15, -0.35)]), col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -0.2), P.call(0.28, 0.4), P.call(0, 0.75), P.call(-0.28, 0.4)]), clair)
		"seve":
			ci.draw_circle(p, s * 0.95, Color(col, 0.25))
			_leaf(ci, p, s * 0.8, -PI / 4.0, col)
			ci.draw_line(P.call(-0.45, 0.45), P.call(0.35, -0.35), sombre, lw * 0.7, true)
		"vent":
			# Trois rafales qui s'enroulent, la plus longue au milieu.
			_gust(ci, P.call(-0.15, -0.45), s * 1.3, col, lw * 1.3)
			_gust(ci, P.call(0.05, 0.1), s * 1.6, col, lw * 1.5)
			_gust(ci, P.call(-0.25, 0.65), s * 1.0, clair if col != sombre else col, lw * 1.1)
		"lumiere":
			# Soleil levant : un demi-disque posé sur l'horizon, et ses rayons.
			var pts := PackedVector2Array()
			for i in 13:
				pts.append(P.call(0, 0.35) + Vector2.from_angle(PI + PI * i / 12.0) * s * 0.55)
			ci.draw_colored_polygon(pts, col)
			for i in 5:
				var d := Vector2.from_angle(PI + PI * (i + 0.5) / 5.0)
				ci.draw_line(P.call(0, 0.35) + d * s * 0.72, P.call(0, 0.35) + d * s * 1.0, col, lw, true)
			ci.draw_line(P.call(-0.95, 0.42), P.call(0.95, 0.42), sombre if col != sombre else col, lw, true)
			if col != sombre:
				ci.draw_circle(P.call(-0.12, 0.12), s * 0.14, clair)
		# Compétences et arme. Chacune garde une forme propre à 20 px ; les détails clairs ne
		# servent qu'en grand (barre, infobulles). relief : vrai pendant la passe de la tranche.
		"graine":
			var relief := col == sombre
			# Graine en amande, inclinée, avec sa pousse et un éclat de lumière.
			var body := PackedVector2Array()
			for i in 16:
				var a := i * TAU / 16.0
				body.append(p + Vector2(cos(a) * 0.62, sin(a) * 0.42).rotated(-PI / 4.0) * s + Vector2(-0.08, 0.12) * s)
			ci.draw_colored_polygon(body, col)
			_leaf(ci, P.call(0.42, -0.5), s * 0.34, -PI / 4.0 - 0.5, (sombre if relief else col.lightened(0.15)))
			ci.draw_line(P.call(0.22, -0.28), P.call(0.42, -0.5), sombre, lw * 0.8, true)
			if not relief:
				ci.draw_circle(P.call(-0.28, 0.0), s * 0.16, clair)
				ci.draw_arc(P.call(-0.08, 0.12), s * 0.9, PI * 0.55, PI * 1.05, 10, Color(clair, 0.6), lw * 0.7, true)
		"nova":
			var relief := col == sombre
			# Couronne d'épines : un anneau tressé hérissé de pointes, longues et courtes alternées.
			for i in 10:
				var d := Vector2.from_angle(i * TAU / 10.0 - PI / 2.0)
				var len := s * (0.48 if i % 2 == 0 else 0.3)
				var nn := d.orthogonal()
				var b := p + d * s * 0.5
				ci.draw_colored_polygon(PackedVector2Array([b + nn * len * 0.32, b + d * len, b - nn * len * 0.32]), col)
				if not relief and s >= 10.0:
					ci.draw_colored_polygon(PackedVector2Array([b, b + d * len, b - nn * len * 0.32]), col.darkened(0.25))
			ci.draw_arc(p, s * 0.5, 0.0, TAU, 28, col, lw * 1.6, true)
			if not relief:
				ci.draw_arc(p, s * 0.5, PI * 1.1, PI * 1.7, 10, clair, lw * 0.6, true)
				for i in 5:
					var a := i * TAU / 5.0 + 0.3
					ci.draw_line(p + Vector2.from_angle(a) * s * 0.42, p + Vector2.from_angle(a + 0.35) * s * 0.58, sombre, lw * 0.5, true)
		"fouet":
			var relief := col == sombre
			# Liane en S qui claque : épines alternées, pointe d'os et éclat au bout.
			var pts := PackedVector2Array()
			for i in 15:
				var k := i / 14.0
				pts.append(P.call(-0.85 + 1.55 * k, 0.75 - 1.45 * k + 0.5 * sin(k * PI * 1.7)))
			ci.draw_polyline(pts, col, lw * (1.5 if s < 10.0 else 1.8), true)
			for i: int in [3, 6, 9, 12]:
				var d: Vector2 = (pts[i + 1] - pts[i]).normalized().orthogonal() * (1.0 if i % 6 == 0 else -1.0)
				_thorn(ci, pts[i], d, s * 0.3, col)
			_thorn(ci, pts[14], (pts[14] - pts[13]).normalized(), s * 0.32, col)
			if not relief:
				for i in 3:
					var a := -PI / 3.0 + i * 0.6
					ci.draw_line(pts[14] + Vector2.from_angle(a) * s * 0.22, pts[14] + Vector2.from_angle(a) * s * 0.42, clair, lw * 0.6, true)
		"racines":
			var relief := col == sombre
			# Trois racines noueuses jaillissent du sol et se courbent vers le centre.
			for q: Vector3 in [Vector3(-0.55, 0.32, 0.55), Vector3(0.0, -0.95, 0.0), Vector3(0.55, 0.32, -0.55)]:
				var base: Vector2 = P.call(q.x, 0.85)
				var tip: Vector2 = P.call(q.x + q.z * 0.6, -0.5 + q.y * (0.4 if q.x == 0.0 else 0.0) + (0.0 if q.x == 0.0 else -0.25))
				var mid := base.lerp(tip, 0.5) + Vector2(-q.z * s * 0.25, 0)
				var w := s * (0.26 if q.x == 0.0 else 0.2)
				var side := (tip - base).normalized().orthogonal()
				ci.draw_colored_polygon(PackedVector2Array([base + side * w, mid + side * w * 0.6, tip, mid - side * w * 0.6, base - side * w]), col)
				if not relief:
					ci.draw_circle(mid, w * 0.38, sombre)
					ci.draw_circle(tip, maxf(w * 0.28, 1.0), Art.ec("racine", "clair"))
			ci.draw_line(P.call(-1.0, 0.88), P.call(1.0, 0.88), sombre, lw * 1.2, true)
			if not relief:
				for x: float in [-0.8, -0.25, 0.3, 0.8]:
					ci.draw_circle(P.call(x, 0.98), lw * 0.6, sombre.lightened(0.2))
		"volee":
			var relief := col == sombre
			# Éventail de trois épines qui partent d'un même point, avec leurs traînées.
			var o: Vector2 = P.call(-0.75, 0.75)
			for i in 3:
				var d := Vector2.from_angle(-PI / 4.0 + (i - 1) * 0.42)
				var b := o + d * s * 0.55
				if not relief:
					ci.draw_line(o + d * s * 0.1, b, Color(col, 0.45), lw * 0.8, true)
				var nn := d.orthogonal()
				var len := s * (0.95 if i == 1 else 0.8)
				ci.draw_colored_polygon(PackedVector2Array([b + nn * s * 0.17, b + d * len, b - nn * s * 0.17]), col)
				if not relief and s >= 10.0:
					ci.draw_colored_polygon(PackedVector2Array([b, b + d * len, b - nn * s * 0.17]), col.darkened(0.25))
				if not relief:
					ci.draw_circle(b, s * 0.07, Art.ec("saignement", "clair"))
		"saignee":
			var relief := col == sombre
			# Une grande goutte au centre ; quatre petites gouttes convergent vers elle.
			var clair_s := (sombre if relief else Art.ec("saignement", "clair"))
			_drop(ci, P.call(0, 0.25), s * 0.5, (sombre if relief else clair_s))
			for i in 4:
				var a := i * TAU / 4.0 + PI / 4.0
				var q := p + Vector2.from_angle(a) * s * 0.82 + Vector2(0, s * 0.1)
				_drop(ci, q, s * 0.13, col.lightened(0.15) if not relief else sombre)
				ci.draw_line(q - Vector2.from_angle(a) * s * 0.12, q - Vector2.from_angle(a) * s * 0.3, Color(col.lightened(0.15), 0.8) if not relief else sombre, lw * 0.6, true)
			if not relief:
				ci.draw_arc(P.call(0, 0.25), s * 0.5, PI * 0.15, PI * 0.85, 10, col.darkened(0.2), lw * 0.8, true)
				ci.draw_circle(P.call(-0.15, 0.12), s * 0.12, Color.WHITE.lerp(clair_s, 0.4))
		"cloud":
			var relief := col == sombre
			# Volutes de spores, et deux bulles qui montent.
			for q: Vector3 in [Vector3(-0.42, 0.3, 0.4), Vector3(0.08, -0.05, 0.5), Vector3(0.55, 0.32, 0.36), Vector3(0.0, 0.48, 0.38)]:
				ci.draw_circle(P.call(q.x, q.y), s * q.z, col)
			ci.draw_arc(P.call(-0.55, -0.62), s * 0.16, 0.0, TAU, 10, (sombre if relief else clair), lw * 0.8, true)
			ci.draw_arc(P.call(0.55, -0.72), s * 0.11, 0.0, TAU, 8, (sombre if relief else clair), lw * 0.7, true)
			if not relief:
				ci.draw_arc(P.call(0.05, -0.12), s * 0.26, PI, PI * 1.7, 8, clair, lw * 0.7, true)
				ci.draw_circle(P.call(-0.2, 0.3), s * 0.08, sombre)
				ci.draw_circle(P.call(0.3, 0.38), s * 0.06, sombre)
		"vesse":
			var relief := col == sombre
			# Champignon : chapeau rond tacheté sur un pied court, une spore qui s'échappe.
			ci.draw_rect(Rect2(P.call(-0.2, 0.0), Vector2(0.4, 0.85) * s), (sombre if relief else clair.lerp(col, 0.3)))
			var cap := PackedVector2Array()
			for i in 13:
				var a := PI + i * PI / 12.0
				cap.append(P.call(cos(a) * 0.85, 0.1 + sin(a) * 0.75))
			ci.draw_colored_polygon(cap, col)
			if not relief:
				ci.draw_circle(P.call(-0.35, -0.25), s * 0.13, clair)
				ci.draw_circle(P.call(0.3, -0.4), s * 0.11, clair)
				ci.draw_circle(P.call(0.05, -0.05), s * 0.09, clair)
			ci.draw_arc(P.call(0.6, -0.85), s * 0.12, 0.0, TAU, 8, (sombre if relief else clair), lw * 0.8, true)
		"essaim":
			var relief := col == sombre
			# Un filament qui serpente d'un point à l'autre, trois spores le long du fil.
			var pts := PackedVector2Array()
			for i in 9:
				var u := i / 8.0
				pts.append(P.call(-0.85 + 1.7 * u, 0.7 - 1.4 * u + 0.3 * sin(u * TAU)))
			ci.draw_polyline(pts, col, lw * 1.1, true)
			for j: int in [0, 4, 8]:
				ci.draw_circle(pts[j], s * (0.26 if j == 8 else 0.19), col)
				if not relief:
					ci.draw_circle(pts[j] + Vector2(-s * 0.06, -s * 0.06), s * 0.07, clair)
		"eclosion":
			var relief := col == sombre
			# Fleur de spores qui éclot : cinq pétales ronds autour d'un cœur clair, poussière autour.
			for i in 5:
				var d := Vector2.from_angle(i * TAU / 5.0 - PI / 2.0)
				ci.draw_circle(p + d * s * 0.42, s * 0.3, col)
			ci.draw_circle(p, s * 0.26, (sombre if relief else clair))
			for i in 5:
				var d := Vector2.from_angle(i * TAU / 5.0 - PI / 2.0 + PI / 5.0)
				ci.draw_circle(p + d * s * 0.88, s * 0.08, (sombre if relief else clair))
		"bloom":
			var relief := col == sombre
			# Fleur à cinq pétales sur deux feuilles, cœur doré.
			_leaf(ci, P.call(-0.5, 0.62), s * 0.32, PI * 0.85, (sombre if relief else col.darkened(0.3)))
			_leaf(ci, P.call(0.5, 0.62), s * 0.32, PI * 0.15, (sombre if relief else col.darkened(0.3)))
			for i in 5:
				var a := i * TAU / 5.0 - PI / 2.0
				_leaf(ci, p + Vector2.from_angle(a) * s * 0.45, s * 0.42, a, col)
				if not relief and s >= 10.0:
					ci.draw_line(p + Vector2.from_angle(a) * s * 0.25, p + Vector2.from_angle(a) * s * 0.65, col.darkened(0.3), lw * 0.5, true)
			ci.draw_circle(p, s * 0.24, (sombre if relief else Art.c("butin")))
			if not relief:
				ci.draw_circle(p + Vector2(-s * 0.06, -s * 0.06), s * 0.09, clair)
		# Statistiques
		"degats":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -1.0), P.call(0.28, 0.3), P.call(-0.28, 0.3)]), col)
			ci.draw_line(P.call(-0.6, 0.4), P.call(0.6, 0.4), col, lw, true)
			ci.draw_line(P.call(0, 0.4), P.call(0, 1.0), col, lw, true)
		"attaque":
			for dx in [-0.5, 0.2]:
				ci.draw_colored_polygon(PackedVector2Array([P.call(dx, -0.7), P.call(dx + 0.55, 0), P.call(dx, 0.7), P.call(dx + 0.2, 0)]), col)
		"projectile":
			ci.draw_circle(P.call(0.45, -0.35), s * 0.36, col)
			ci.draw_line(P.call(-0.85, 0.75), P.call(0.25, -0.15), Color(col, 0.6), lw * 1.2, true)
			ci.draw_line(P.call(-0.55, 0.85), P.call(0.15, 0.2), Color(col, 0.35), lw, true)
		"critique":
			var st := PackedVector2Array()
			for i in 8:
				st.append(p + Vector2.from_angle(i * TAU / 8.0 - PI / 2.0) * s * (1.0 if i % 2 == 0 else 0.32))
			ci.draw_colored_polygon(st, col)
		"vie":
			ci.draw_circle(P.call(-0.4, -0.25), s * 0.42, col)
			ci.draw_circle(P.call(0.4, -0.25), s * 0.42, col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.8, -0.12), P.call(0.8, -0.12), P.call(0, 0.85)]), col)
		"regen":
			ci.draw_circle(P.call(-0.4, -0.25), s * 0.42, col)
			ci.draw_circle(P.call(0.4, -0.25), s * 0.42, col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.8, -0.12), P.call(0.8, -0.12), P.call(0, 0.85)]), col)
			ci.draw_line(P.call(-0.3, 0), P.call(0.3, 0), sombre, lw, true)
			ci.draw_line(P.call(0, -0.3), P.call(0, 0.3), sombre, lw, true)
		"armure":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.75, -0.8), P.call(0.75, -0.8), P.call(0.7, 0.1), P.call(0, 1.0), P.call(-0.7, 0.1)]), col)
			ci.draw_line(P.call(0, -0.6), P.call(0, 0.7), sombre, lw * 0.8, true)
		"vitesse":
			ci.draw_circle(P.call(0.45, 0), s * 0.38, col)
			for k in 3:
				ci.draw_line(P.call(-0.95 + k * 0.12, -0.4 + k * 0.4), P.call(-0.05, -0.4 + k * 0.4), Color(col, 0.75 - k * 0.15), lw, true)
		"esquive":
			ci.draw_arc(p, s * 0.75, PI * 0.7, PI * 1.9, 20, col, lw * 1.2, true)
			_thorn(ci, p + Vector2.from_angle(PI * 1.9) * s * 0.75, Vector2.from_angle(PI * 1.9 + PI / 2.0), s * 0.45, col)
			_leaf(ci, P.call(-0.1, 0.1), s * 0.38, -PI / 4.0, clair)
		"zone":
			ci.draw_arc(p, s * 0.9, 0.0, TAU, 28, col, lw, true)
			ci.draw_arc(p, s * 0.55, 0.0, TAU, 20, Color(col, 0.7), lw, true)
			ci.draw_circle(p, s * 0.2, col)
		"collecte":
			ci.draw_arc(P.call(0, -0.1), s * 0.6, PI * 0.0, PI, 16, col, lw * 1.6, true)
			ci.draw_line(P.call(-0.6, -0.1), P.call(-0.6, -0.7), col, lw * 1.6, true)
			ci.draw_line(P.call(0.6, -0.1), P.call(0.6, -0.7), col, lw * 1.6, true)
			ci.draw_circle(P.call(0, 0.0), s * 0.18, clair)
		# Formes de l'attaque de base : toutes partent du bas à gauche (la main) vers le haut à droite.
		"attaque_graine":
			# Trois graines en éventail, la plus grande au centre.
			for i in 3:
				var a := -PI / 4.0 + (i - 1) * 0.55
				var c0: Vector2 = P.call(-0.55, 0.55) + Vector2.from_angle(a) * s * (1.05 if i == 1 else 0.85)
				var body := PackedVector2Array()
				for j in 12:
					var b := j * TAU / 12.0
					body.append(c0 + Vector2(cos(b) * 0.36, sin(b) * 0.24).rotated(a) * s * (1.0 if i == 1 else 0.8))
				ci.draw_colored_polygon(body, col)
				if col != sombre:
					ci.draw_circle(c0 + Vector2.from_angle(a + PI * 0.7) * s * 0.1, s * 0.08, clair)
			ci.draw_circle(P.call(-0.6, 0.6), s * 0.16, col)
		"attaque_echarde":
			# Trois échardes fines et parallèles, en rafale, la première devant.
			for i in 3:
				var base: Vector2 = P.call(-0.75 + i * 0.22, 0.45 + i * 0.12)
				var d := Vector2(1, -1).normalized()
				var n := d.orthogonal()
				var len := s * (1.3 - i * 0.22)
				var tip := base + d * len
				ci.draw_colored_polygon(PackedVector2Array([tip, base + n * s * 0.11, base - d * s * 0.08, base - n * s * 0.11]), col)
				if col != sombre:
					ci.draw_line(base + d * len * 0.2, tip, clair, lw * 0.5, true)
		"attaque_fouet":
			# Un croissant : le balayage du fouet, hérissé de trois épines vers l'extérieur.
			var c0: Vector2 = P.call(-0.45, 0.45)
			var pts := PackedVector2Array()
			for i in 13:
				pts.append(c0 + Vector2.from_angle(lerpf(-PI * 0.95, 0.1, i / 12.0)) * s * 1.2)
			for i in range(12, -1, -1):
				pts.append(c0 + Vector2.from_angle(lerpf(-PI * 0.85, 0.0, i / 12.0)) * s * 0.85)
			ci.draw_colored_polygon(pts, col)
			for i in 3:
				var a := lerpf(-PI * 0.8, -0.15, (i + 0.5) / 3.0)
				var q := c0 + Vector2.from_angle(a) * s * 1.18
				var d := Vector2.from_angle(a)
				var n := d.orthogonal()
				ci.draw_colored_polygon(PackedVector2Array([q + n * s * 0.12, q + d * s * 0.3, q - n * s * 0.12]), (col if col == sombre else clair))
			ci.draw_circle(c0, s * 0.16, col)
		"attaque_ronce_vive":
			# Une graine plantée, d'où sort un cercle de ronce griffue.
			ci.draw_arc(P.call(0, 0.1), s * 0.72, 0.0, TAU, 24, col, lw * 1.2, true)
			for i in 5:
				var a := -PI / 2.0 + i * TAU / 5.0
				var q: Vector2 = P.call(0, 0.1) + Vector2.from_angle(a) * s * 0.72
				var d := Vector2.from_angle(a + 0.9)
				var n := d.orthogonal()
				ci.draw_colored_polygon(PackedVector2Array([q + n * s * 0.1, q + d * s * 0.32, q - n * s * 0.1]), col)
			var seed := PackedVector2Array()
			for j in 12:
				var b := j * TAU / 12.0
				seed.append(P.call(0, 0.15) + Vector2(cos(b) * 0.24, sin(b) * 0.32) * s)
			ci.draw_colored_polygon(seed, (col if col == sombre else clair))
		"attaque_spore_lobee":
			# Une spore lancée en cloche : la courbe pointillée de son vol, la boule de spores au sommet
			# qui redescend, et l'éclat au sol.
			var relief := col == sombre
			for i in 5:
				var u := i / 4.0
				var q: Vector2 = P.call(-0.8 + 1.4 * u, 0.75 - 1.5 * sin(u * PI * 0.8))
				ci.draw_circle(q, s * 0.07, col)
			ci.draw_circle(P.call(0.35, -0.35), s * 0.36, col)
			if not relief:
				ci.draw_circle(P.call(0.25, -0.45), s * 0.1, clair)
				ci.draw_circle(P.call(0.47, -0.27), s * 0.08, clair)
			for i in 4:
				var a := -PI + i * PI / 3.0
				ci.draw_line(P.call(0.6, 0.85), P.call(0.6, 0.85) + Vector2.from_angle(a) * s * 0.32, col, lw, true)
		"attaque_dard":
			# Trois aiguilles fines en éventail, une goutte de poison à la base de chacune.
			var relief := col == sombre
			for i in 3:
				var d := Vector2.from_angle(-PI / 4.0 + (i - 1) * 0.38)
				var nn := d.orthogonal()
				var base: Vector2 = P.call(-0.6, 0.6) + d * s * 0.2
				var tip := base + d * s * (1.45 if i == 1 else 1.2)
				ci.draw_colored_polygon(PackedVector2Array([tip, base + nn * s * 0.09, base - nn * s * 0.09]), col)
				ci.draw_circle(base, s * 0.13, (col if relief else clair))
		"attaque_mod":
			# Un trait qui se divise : la fourche, signe d'une attaque transformée.
			ci.draw_line(P.call(-0.75, 0.75), P.call(-0.05, 0.05), col, lw * 1.5, true)
			ci.draw_line(P.call(-0.05, 0.05), P.call(0.7, -0.35), col, lw * 1.3, true)
			ci.draw_line(P.call(-0.05, 0.05), P.call(0.35, -0.75), col, lw * 1.3, true)
			ci.draw_circle(P.call(0.7, -0.35), s * 0.17, col)
			ci.draw_circle(P.call(0.35, -0.75), s * 0.17, col)
			ci.draw_circle(P.call(-0.05, 0.05), s * 0.14, (col if col == sombre else clair))
		"competence":
			ci.draw_circle(p, s * 0.38, col)
			for i in 6:
				var d := Vector2.from_angle(i * TAU / 6.0)
				ci.draw_line(p + d * s * 0.58, p + d * s, col, lw, true)
		# Monde
		"sanctuaire":
			ci.draw_arc(P.call(0, 0.35), s * 0.7, 0.0, TAU, 24, Color(col, 0.45), lw * 0.8, true)
			for i in 5:
				var q: Vector2 = P.call(0, 0.35) + Vector2.from_angle(PI + i * PI / 4.0) * s * 0.7
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-s * 0.12, s * 0.1), q + Vector2(-s * 0.1, -s * 0.35), q + Vector2(0, -s * 0.45), q + Vector2(s * 0.1, -s * 0.35), q + Vector2(s * 0.12, s * 0.1)]), col)
			ci.draw_circle(P.call(0, 0.35), s * 0.2, (sombre if col == sombre else Art.ec("seve")))
		"autel":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.8, 0.95), P.call(-0.55, 0.3), P.call(0.55, 0.3), P.call(0.8, 0.95)]), col)
			ci.draw_rect(Rect2(P.call(-0.7, 0.12), Vector2(1.4, 0.2) * s), col)
			_leaf(ci, P.call(0, -0.4), s * 0.42, -PI / 2.0, (sombre if col == sombre else Art.c("butin")))
		"coeur":
			var pts2 := PackedVector2Array()
			for i in 10:
				pts2.append(p + Vector2.from_angle(i * TAU / 10.0) * s * (0.9 if i % 2 == 0 else 0.55))
			ci.draw_colored_polygon(pts2, col)
			ci.draw_circle(p, s * 0.3, (sombre if col == sombre else Art.c("contour")))
			ci.draw_circle(p, s * 0.16, (sombre if col == sombre else Art.c("ennemi_oeil")))
		"arene":
			ci.draw_arc(p, s * 0.72, 0.0, TAU, 28, col, lw, true)
			for i in 10:
				var d := Vector2.from_angle(i * TAU / 10.0)
				_thorn(ci, p + d * s * 0.72, d, s * 0.3, col)
				_thorn(ci, p + d * s * 0.72, -d, s * 0.2, col)
		"secret":
			_eye(ci, p, s, col, sombre)
		"seve_perdue":
			_drop(ci, P.call(0, 0.35), s * 0.55, col)
			ci.draw_circle(P.call(-0.18, 0.25), s * 0.14, clair)
			ci.draw_arc(P.call(0, 0.35), s * 0.85, PI * 1.15, PI * 1.85, 14, Color(col, 0.5), lw * 0.8, true)
		"essence":
			ci.draw_circle(p, s * 0.8, Color(col, 0.2))
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -0.75), P.call(0.45, 0), P.call(0, 0.75), P.call(-0.45, 0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -0.4), P.call(0.18, 0), P.call(0, 0.4), P.call(-0.18, 0)]), clair)
		"greffe":
			_leaf(ci, P.call(0.1, -0.1), s * 0.85, -PI / 4.0, col)
			ci.draw_line(P.call(-0.45, 0.45), P.call(-0.85, 0.85), sombre.lightened(0.2), lw * 1.2, true)
			ci.draw_line(P.call(-0.5, 0.5), P.call(0.55, -0.55), sombre, lw * 0.7, true)
		_:
			# Icônes des branches Vent (vent_fx.gd), Aube (aube_fx.gd), Sève (seve_fx.gd) et Racine (racine_fx.gd).
			if not VentFx.icon(ci, id, p, s, col, clair, sombre, lw) and not AubeFx.icon(ci, id, p, s, col, clair, sombre, lw) and not SeveFx.icon(ci, id, p, s, col, clair, sombre, lw) \
					and not RacineFx.icon(ci, id, p, s, col, clair, sombre, lw):
				ci.draw_circle(p, s * 0.35, col)


## Feuille en amande, pointe dans la direction a, longueur l (de la base à la pointe : 2 × l).
static func _leaf(ci, p: Vector2, l: float, a: float, col: Color) -> void:
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		pts.append(p + d * l * (2.0 * k - 1.0) + n * l * 0.5 * sin(k * PI))
	for i in range(7, 0, -1):
		var k := i / 8.0
		pts.append(p + d * l * (2.0 * k - 1.0) - n * l * 0.5 * sin(k * PI))
	ci.draw_colored_polygon(pts, col)


static func _eye(ci: CanvasItem, p: Vector2, s: float, col: Color, pupil: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var k := i / 11.0
		pts.append(p + Vector2(-s + 2.0 * s * k, -s * 0.55 * sin(k * PI)))
	for i in range(10, 0, -1):
		var k := i / 11.0
		pts.append(p + Vector2(-s + 2.0 * s * k, s * 0.55 * sin(k * PI)))
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(p, s * 0.32, pupil)
	ci.draw_circle(p + Vector2(-s * 0.1, -s * 0.1), s * 0.1, col.lerp(Color.WHITE, 0.7))
