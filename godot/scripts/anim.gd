## Petites animations de la charte : courbes d'accélération, écrasement, éclair, apparition,
## et les durées types. Fonctions pures (aucun état), à appeler depuis _process ou _draw :
## elles ne changent jamais le jeu, seulement son apparence.
##
## Règle d'une action : anticipation (on la voit venir), impact (court, marqué), retour (souple).
class_name Anim
extends RefCounted

## Durées types, en secondes.
const DUREE := {
	"anticipation": 0.14,   ## l'acteur se ramasse avant d'agir
	"impact": 0.06,         ## le coup lui-même : très court
	"retour": 0.2,          ## retour au repos
	"eclair": 0.1,          ## flash blanc d'un coup reçu ou d'une frappe
	"apparition": 0.25,     ## un objet, une icône ou un texte qui apparaît (pop)
	"disparition": 0.35,    ## dissolution, fondu de sortie
	"annonce_min": 0.5,     ## une attaque ennemie est annoncée au moins aussi longtemps
	"respiration": 2.4,     ## période du repos qui respire
}


# --- Courbes d'accélération (t de 0 à 1, renvoient 0 → 1) ---

static func ease_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t


static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func ease_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


## Dépasse un peu la cible avant de s'y poser (apparitions, rebonds).
static func ease_out_back(t: float, s := 1.70158) -> float:
	t = clampf(t, 0.0, 1.0)
	var u := t - 1.0
	return 1.0 + (s + 1.0) * u * u * u + s * u * u


# --- Effets ---

## Écrasement d'une action sur sa durée (t de 0 à 1) : échelle (x, y) à appliquer au dessin.
## Anticipation (écrasé), impact (étiré dans le sens de l'action), retour (amorti) ; garde à peu près l'aire.
const SQUASH_ANTICIPATION := 0.4   ## part de la durée passée à se ramasser
const SQUASH_IMPACT := 0.55        ## fin de l'impact

static func squash(t: float, force := 1.0) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var k := 0.0   # > 0 : écrasé, < 0 : étiré
	if t < SQUASH_ANTICIPATION:
		k = 0.18 * ease_out(t / SQUASH_ANTICIPATION)
	elif t < SQUASH_IMPACT:
		var u := (t - SQUASH_ANTICIPATION) / (SQUASH_IMPACT - SQUASH_ANTICIPATION)
		k = lerpf(0.18, -0.22, ease_out(u))
	else:
		var u := (t - SQUASH_IMPACT) / (1.0 - SQUASH_IMPACT)
		# Retour amorti : une petite oscillation qui s'éteint.
		k = -0.22 * (1.0 - u) * cos(u * PI * 1.5)
	k *= force
	return Vector2(1.0 + k, 1.0 - k)


## Éclair (coup reçu, frappe) : 1 au début, s'éteint vite. À mélanger vers blanc : col.lerp(blanc, flash(t)).
static func flash(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - ease_out(t)


## Apparition : échelle de 0 à 1 en dépassant un peu (≈ 1,1) avant de se poser.
static func pop(t: float) -> float:
	return ease_out_back(t)


## Respiration du repos : un léger gonflement périodique (1 ± amplitude), temps en secondes.
static func breathe(time: float, amplitude := 0.03) -> float:
	return 1.0 + amplitude * sin(time * TAU / DUREE["respiration"])


## Clignotement (alerte) : 0 ou 1, à la fréquence donnée.
static func blink(time: float, hz := 4.0) -> float:
	return 1.0 if fposmod(time * hz, 1.0) < 0.5 else 0.0


## Phase d'une action découpée en anticipation, impact et retour (durées en secondes).
## Renvoie {"phase": "anticipation" | "impact" | "retour" | "fin", "k": avancement dans la phase (0 → 1)}.
static func phase(time: float, anticipation := -1.0, impact := -1.0, retour := -1.0) -> Dictionary:
	if anticipation < 0.0:
		anticipation = DUREE["anticipation"]
	if impact < 0.0:
		impact = DUREE["impact"]
	if retour < 0.0:
		retour = DUREE["retour"]
	if time < anticipation:
		return {"phase": "anticipation", "k": time / anticipation if anticipation > 0.0 else 1.0}
	time -= anticipation
	if time < impact:
		return {"phase": "impact", "k": time / impact if impact > 0.0 else 1.0}
	time -= impact
	if time < retour:
		return {"phase": "retour", "k": time / retour if retour > 0.0 else 1.0}
	return {"phase": "fin", "k": 1.0}
