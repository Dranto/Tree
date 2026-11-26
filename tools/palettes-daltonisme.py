#!/usr/bin/env python3
# Teintes du mode daltonien du bestiaire (Art.BESTIAIRE_DALTONIEN) : pour chaque daltonisme, cherche des
# teintes « clair » proches de la palette normale telles que, vues par ce daltonien (simulation de Machado
# et al. 2009, comme Art.simulate), les régions restent distinctes deux à deux (ΔE ≥ PAIR), de la braise
# (ΔE ≥ 22) et du sol mort de leur région (ΔE ≥ SOL). Recherche aléatoire, sans dépendance.
#   python3 tools/palettes-daltonisme.py [PAIR=30] [SOL=22]
# Recopier NORMAL depuis Art.BESTIAIRE › clair et SOLS depuis tests/bestiaire/commun.gd › ground_colors().
# Les teintes trouvées sont un point de départ : bestiaire_test.gd et paysages_test.gd tranchent (le banc
# des paysages a demandé deux retouches à la main : racine en protanopie, ronce en deutéranopie).
import sys
import math, itertools
M = {
 "protanopie": [(0.152286, 1.052583, -0.204868), (0.114503, 0.786281, 0.099216), (-0.003882, -0.048116, 1.051998)],
 "deuteranopie": [(0.367322, 0.860646, -0.227968), (0.280085, 0.672501, 0.047413), (-0.011820, 0.042940, 0.968881)],
 "tritanopie": [(1.255528, -0.076749, -0.178779), (-0.078411, 0.930809, 0.147602), (0.004733, 0.691367, 0.303900)],
}
def h2c(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
def c2h(c): return ''.join('%02x'%round(max(0,min(1,v))*255) for v in c)
def s2l(v): return v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4
def l2s(v): return 12.92*v if v<=0.0031308 else 1.055*v**(1/2.4)-0.055
def sim(c,k):
    if not k: return c
    l=[s2l(v) for v in c]; m=M[k]
    return tuple(l2s(max(0,min(1,sum(a*b for a,b in zip(row,l))))) for row in m)
def lab(c):
    l=[s2l(v) for v in c]
    x=(0.4124*l[0]+0.3576*l[1]+0.1805*l[2])/0.95047
    y=0.2126*l[0]+0.7152*l[1]+0.0722*l[2]
    z=(0.0193*l[0]+0.1192*l[1]+0.9505*l[2])/1.08883
    f=lambda v: v**(1/3) if v>0.008856 else 7.787*v+16/116
    return (116*f(y)-16, 500*(f(x)-f(y)), 200*(f(y)-f(z)))
def lab2rgb(L,a,b):
    fy=(L+16)/116; fx=fy+a/500; fz=fy-b/200
    fi=lambda t: t**3 if t>0.206893 else (t-16/116)/7.787
    x,y,z=fi(fx)*0.95047,fi(fy),fi(fz)*1.08883
    r= 3.2406*x-1.5372*y-0.4986*z; g=-0.9689*x+1.8758*y+0.0415*z; bb=0.0557*x-0.2040*y+1.0570*z
    return tuple(l2s(max(0,min(1,v))) for v in (r,g,bb))
def de(a,b): return math.dist(lab(a),lab(b))
SOLS={"aube":["524d44","736d62"],"racine":["312b21","4e473f"],"ronce":["3b241a","4e3226"],"seve":["302a21","373d31"],"spore":["2f2339","393445"],"vent":["2c333a","414950"]}
BRAISE="ff8a2a"
KINDS=["","protanopie","deuteranopie","tritanopie"]
import random, json, sys
NORMAL={"ronce":"c8324a","spore":"b45aec","vent":"4f9fe6","seve":"58c45e","aube":"fccd46","racine":"b97b4e","commun":"dcd6d2"}
ALLSOL=sum(SOLS.values(),[])
PAIR = float(sys.argv[1]) if len(sys.argv) > 1 else 30.0
GS = float(sys.argv[2]) if len(sys.argv) > 2 else 22.0
BR = 22.0
def inside(L,a,b):
    fy=(L+16)/116; fx=fy+a/500; fz=fy-b/200
    fi=lambda t: t**3 if t>0.206893 else (t-16/116)/7.787
    x,y,z=fi(fx)*0.95047,fi(fy),fi(fz)*1.08883
    r= 3.2406*x-1.5372*y-0.4986*z; g=-0.9689*x+1.8758*y+0.0415*z; bb=0.0557*x-0.2040*y+1.0570*z
    return all(-0.001<=v<=1.001 for v in (r,g,bb))
def score(labs,k):
    cols={r:lab2rgb(*labs[r]) for r in labs}
    s={r:lab(sim(cols[r],k)) for r in cols}
    pen=0; disp=0
    for a,b in itertools.combinations(cols,2):
        d=math.dist(s[a],s[b]); pen+=max(0,PAIR-d)**2
    sb=lab(sim(h2c(BRAISE),k))
    for r in cols:
        pen+=max(0,BR-math.dist(sb,s[r]))**2
        for g in SOLS.get(r,ALLSOL): pen+=max(0,GS-math.dist(s[r],lab(sim(h2c(g),k))))**2
        if not inside(*labs[r]): pen+=100
        disp+=math.dist(labs[r],lab(h2c(NORMAL[r])))
    return pen*50+disp
res={}
for k in KINDS[1:]:
    best=None
    for rs in range(4):
        random.seed(rs)
        cur={r:list(lab(h2c(NORMAL[r]))) for r in NORMAL}
        sc=score(cur,k); T=30
        for it in range(6000):
            r=random.choice(list(cur)); c=cur[r][:]; i=random.randrange(3); c[i]+=random.gauss(0,T*0.3)
            c[0]=max(5,min(97,c[0]))
            cand=dict(cur); cand[r]=c; s2=score(cand,k)
            if s2<sc: cur,sc=cand,s2
            T=max(1,T*0.9995)
        if best is None or sc<best[0]: best=(sc,cur)
    res[k]={r:c2h(lab2rgb(*best[1][r])) for r in NORMAL}
    print(k, round(best[0],1), res[k])

for k in res:
    p=res[k]
    # report only for that mode
    ws=sorted((de(sim(h2c(p[a]),k),sim(h2c(p[b]),k)),a,b) for a,b in itertools.combinations(p,2))
    br=min(de(sim(h2c(BRAISE),k),sim(h2c(p[r]),k)) for r in p)
    sol=min(min(de(sim(h2c(p[r]),k),sim(h2c(s),k)) for s in SOLS.get(r,ALLSOL)) for r in p)
    print(f" {k}: pire {ws[0][0]:.1f} {ws[0][1]}/{ws[0][2]}, braise {br:.1f}, sol {sol:.1f}")
