## Matière du sol de la région « seve » (Vallée), refonte du monde vague 2 (ground_layers.gd › SOL_REGION).
##
## Chaque fonction dessine un élément du calque d'un carré de sol à la place de la matière provisoire
## commune, et rend true ; elle rend false pour garder le dessin commun, **sans avoir tiré e** (les
## tirages suivants doivent rester les mêmes). L : le calque (ground_layers.gd › TileLayer), dont on
## appelle les primitives : L._tri, L._fan, L._oval, L._line, L._polyline, L._blade, L._leaf,
## L._pebble, L._tuft, L._flower ; L._p : palette de la région (fletri, apaise, ravive) ; e : le tirage
## de l'élément (RandomNumberGenerator), le même à chaque construction du carré.
## La géométrie ne dépend pas de la vie : le shader du calque choisit quoi montrer (mort, ravivé, front).
## Couleurs depuis Art.MONDE (palette de la région) ou pal ; aucune collision, aucun texte.
extends RefCounted


## Terre morte, matière (couche 2) en p ; i : 0 ou 1 (deux tirages par case), sd : graine de e.
static func dead_matter(_L, _p: Vector2, _i: int, _sd: int, _e: RandomNumberGenerator) -> bool:
	return false


## Terre ravivée, matière vivante (couche 2) en p.
static func alive_matter(_L, _p: Vector2, _e: RandomNumberGenerator) -> bool:
	return false


## Un objet d'une grappe de la terre morte (couche 3) ; big : 1 pour le plus grand, 0,45-0,8 sinon ;
## kind : 0 touffes, 1 cailloux, 2 cendre (choisi une fois par grappe) ; pal : L._p["fletri"].
static func dead_item(_L, _p: Vector2, _big: float, _kind: int, _pal: Dictionary, _e: RandomNumberGenerator) -> bool:
	return false


## Un objet d'une grappe de la terre ravivée (couche 3) ; k dans [0, 1) : < 0,55 touffe, < 0,85 fleur,
## sinon caillou ou baie ; pal : L._p["ravive"].
static func alive_item(_L, _p: Vector2, _big: float, _k: float, _pal: Dictionary, _e: RandomNumberGenerator) -> bool:
	return false


## Une fleur du bord de vie, juste derrière le front, en p (rayon r) ; pal : L._p.
static func flower(_L, _p: Vector2, _r: float, _pal: Dictionary, _e: RandomNumberGenerator) -> bool:
	return false
