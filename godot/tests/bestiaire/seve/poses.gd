## Poses de référence des Flétris de Sève (R4) pour les aperçus, la planche et le GIF : ce que leur
## comportement (enemy_behaviors/) fait vivre au dessin.
extends RefCounted

## Sortes de la région, dans l'ordre de la planche : [id, nom, rôle, rayon de collision, comportement].
const CAST := [
	["sangsue_vase", "Sangsue de vase", "chargeur", 13.0, "leech"],
	["crapaud", "Crapaud des sources", "bondisseur", 16.0, "hopper"],
	["libellule", "Libellule de cendre", "piqueur", 11.0, "diver"],
	["souche", "Souche gorgée", "soutien", 23.0, "healer"],
]


## Largeur du dessin (unités locales) pour cadrer l'aperçu, et décalage horizontal du centre.
static func span(kind: String) -> float:
	return {"sangsue_vase": 125.0, "crapaud": 110.0, "libellule": 125.0, "souche": 115.0}.get(kind, 110.0)


static func span_x(kind: String) -> float:
	return {"sangsue_vase": 0.0, "crapaud": -4.0, "libellule": -8.0, "souche": 0.0}.get(kind, 0.0)


## Toutes les poses d'une sorte (aperçu).
static func gallery(kind: String) -> Array:
	var common := [
		{"t": 0.4, "look": 0.2},
		{"t": 0.6, "walk": 1.0, "moving": 1.0, "look": 0.2},
		{"t": 0.8, "walk": 2.6, "moving": 1.0, "look": 0.2},
		{"t": 0.3, "state": "windup", "k": 0.5, "look": 0.3},
		{"t": 0.3, "state": "windup", "k": 1.0, "look": 0.3},
		{"t": 0.4, "hit": 1.0, "look": 0.2},
		{"t": 0.4, "look": PI - 0.3},
		{"t": 0.4, "look": -0.7},
		{"t": 0.4, "look": 0.2, "elite": true},
		{"t": 0.4, "look": 0.2, "mono": true},
	]
	match kind:
		"sangsue_vase":
			common.append_array([{"t": 0.3, "state": "charge", "look": 0.2}, {"t": 0.3, "state": "recover", "look": 0.2}, {"t": 0.3, "gorged": 1.0, "look": 0.2}, {"t": 0.3, "strike": 0.2, "look": 0.2}])
		"crapaud":
			common.append_array([{"t": 0.3, "state": "leap", "lift": 0.5, "look": 0.2}, {"t": 0.3, "state": "leap", "lift": 1.0, "look": 0.2}, {"t": 0.3, "state": "recover", "strike": 0.1, "look": 0.2}, {"t": 0.3, "strike": 0.5, "look": 0.2}])
		"libellule":
			common.append_array([{"t": 0.3, "state": "charge", "look": 0.2}, {"t": 0.3, "state": "recover", "look": 0.2}, {"t": 0.55, "look": 0.2}, {"t": 0.3, "state": "charge", "look": PI - 0.4}])
		"souche":
			common.append_array([{"t": 0.3, "strike": 0.2, "look": 0.2}, {"t": 0.3, "strike": 0.7, "look": 0.2}, {"t": 1.3, "look": 0.2}, {"t": 0.3, "state": "windup", "k": 1.0, "elite": true, "look": 0.2}])
	return common


## Pose de l'image f d'un cycle de GIF (24 i/s) : marche, annonce, attaque, repos, coup reçu, repos.
## Renvoie [phase, pose].
static func cycle(kind: String, f: int, look := 0.2) -> Array:
	var t := f / 24.0
	var o := {"t": t, "look": look}
	var ph := "repos"
	if f < 24:
		ph = "marche"
		o["walk"] = f / 24.0 * TAU * 2.0
		o["moving"] = 1.0
	elif f < 44:
		ph = "annonce"
		o["state"] = "windup"
		o["k"] = (f - 24) / 20.0
	elif f < 58:
		ph = "attaque"
		var u := (f - 44) / 14.0
		match kind:
			"sangsue_vase", "libellule":
				o["state"] = "charge" if u < 0.6 else "recover"
				if u >= 0.6:
					o["strike"] = (u - 0.6) / 0.4
			"crapaud":
				if u < 0.65:
					o["state"] = "leap"
					o["lift"] = sin(PI * u / 0.65)
				else:
					o["state"] = "recover"
					o["strike"] = (u - 0.65) / 0.35
			"souche":
				o["strike"] = u
	elif f < 62:
		ph = "repos"
	elif f < 78:
		ph = "coup reçu"
		o["hit"] = 1.0 - (f - 62) / 16.0
	return [ph, o]
