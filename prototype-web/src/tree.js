// Génération procédurale (déterministe) de l'arbre géant.
// Six branches thématiques partent de la graine centrale et se ramifient
// sur 18 anneaux concentriques : environ 1 600 nœuds au total.
(function (G) {
  const S = (G.Seve = G.Seve || {});

  function mulberry32(seed) {
    return function () {
      seed |= 0;
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  const RINGS = 18;
  const RING_GAP = 95;

  const BRANCHES = [
    { id: 'racines', name: 'Racines', color: '#8bd17c', blurb: 'Production de sève brute' },
    { id: 'feuilles', name: 'Feuilles', color: '#d4e157', blurb: 'Multiplicateurs de production' },
    { id: 'fleurs', name: 'Fleurs', color: '#f48fb1', blurb: 'Puissance de récolte manuelle' },
    { id: 'ecorce', name: 'Écorce', color: '#c9a27e', blurb: 'Réduction des coûts' },
    { id: 'mycelium', name: 'Mycélium', color: '#b39ddb', blurb: 'Synergie : chaque nœud renforce les autres' },
    { id: 'fruits', name: 'Fruits', color: '#ffb74d', blurb: 'Graines, saisons et gains hors ligne' },
  ];

  // Nœuds clés : effets uniques, placés aux anneaux 5, 10 et 15 de chaque branche.
  const KEYSTONES = {
    racines: [
      { key: 'pivot', name: 'Pivot ancestral', desc: 'Production de base ×2' },
      { key: 'meres', name: 'Racines-mères', desc: '+2 % de production par nœud Racines possédé' },
      { key: 'tellurique', name: 'Cœur tellurique', desc: 'Production de base ×5, mais la récolte manuelle ne rapporte plus rien' },
    ],
    feuilles: [
      { key: 'photo', name: 'Photosynthèse', desc: 'Bonus en % des Feuilles ×1,5' },
      { key: 'canopee', name: 'Canopée', desc: 'Production ×(1 + 0,15 par nœud clé possédé)' },
      { key: 'soleil', name: 'Soleil captif', desc: 'Production ×3' },
    ],
    fleurs: [
      { key: 'pollen', name: 'Pollinisation', desc: 'Chaque récolte rapporte 10 % de plus de la production par seconde' },
      { key: 'floraison', name: 'Floraison', desc: 'Récolte automatique 2 fois par seconde' },
      { key: 'nectar', name: 'Nectar éternel', desc: 'Récolte manuelle ×10' },
    ],
    ecorce: [
      { key: 'liege', name: 'Liège', desc: 'Tous les coûts ×0,75' },
      { key: 'coeur', name: 'Bois de cœur', desc: 'Les nœuds notables et clés coûtent moitié moins' },
      { key: 'petri', name: 'Pétrification', desc: 'Coûts ×0,3, mais production −20 %' },
    ],
    mycelium: [
      { key: 'reseau', name: 'Réseau souterrain', desc: 'Synergie ×2' },
      { key: 'symbiose', name: 'Symbiose', desc: 'Production ×(1 + 0,04 par nœud notable possédé)' },
      { key: 'esprit', name: 'Esprit de la forêt', desc: 'Production ×(1 + nœuds possédés / 100)' },
    ],
    fruits: [
      { key: 'verger', name: 'Verger', desc: 'Graines gagnées à l\'hiver ×1,5' },
      { key: 'conserve', name: 'Conserves', desc: 'Gains hors ligne portés à 100 %' },
      { key: 'or', name: 'Fruit d\'or', desc: 'Chaque graine donne +25 % au lieu de +10 %' },
    ],
  };

  const NOTABLE_WORDS = {
    racines: [['Radicelle', 'Pivot', 'Rhizome', 'Tubercule', 'Souche', 'Bulbe'], ['profond', 'noueux', 'ancien', 'tenace', 'gorgé', 'secret']],
    feuilles: [['Limbe', 'Frondaison', 'Ramure', 'Feuillage', 'Bourgeon', 'Stomate'], ['doré', 'vibrant', 'immense', 'lumineux', 'tendre', 'vernal']],
    fleurs: [['Pétale', 'Corolle', 'Pistil', 'Étamine', 'Calice', 'Bouton'], ['éclatant', 'parfumé', 'carmin', 'nacré', 'sauvage', 'précoce']],
    ecorce: [['Liber', 'Aubier', 'Cambium', 'Nœud', 'Cerne', 'Lenticelle'], ['dur', 'épais', 'rugueux', 'patient', 'scellé', 'vieilli']],
    mycelium: [['Hyphe', 'Spore', 'Lichen', 'Filament', 'Sporée', 'Trame'], ['partagé', 'tissé', 'muet', 'fertile', 'sombre', 'lié']],
    fruits: [['Drupe', 'Baie', 'Pépin', 'Noyau', 'Akène', 'Gousse'], ['mûr', 'sucré', 'lourd', 'juteux', 'tardif', 'gorgé']],
  };

  // Effets des nœuds ordinaires et notables selon la branche et l'anneau.
  function nodeEffects(branch, r, notable) {
    const g = Math.pow(1.4, r - 1);
    const m = notable ? 5 : 1;
    switch (branch) {
      case 'racines': return { flat: 1.5 * g * m };
      case 'feuilles': return { pct: notable ? 0.3 + 0.05 * r : 0.05 + 0.01 * r };
      case 'fleurs': return notable ? { clickPct: 0.05, clickFlat: 10 * g } : { clickFlat: 3 * g, clickPct: 0.01 };
      case 'ecorce': return { costRed: notable ? 0.05 : 0.012 };
      case 'mycelium': return { synergy: notable ? 0.0015 : 0.0003 };
      case 'fruits': return notable ? { seedPct: 0.25, offline: 0.05 } : { flat: 0.6 * g, seedPct: 0.03 };
    }
    return {};
  }

  function build() {
    const rand = mulberry32(20261108);
    const nodes = [];
    const edges = [];
    const edgeSet = new Set();
    const link = (a, b) => {
      if (a === b) return;
      const k = a < b ? a + ':' + b : b + ':' + a;
      if (edgeSet.has(k)) return;
      edgeSet.add(k);
      edges.push([a, b]);
      nodes[a].neighbors.push(b);
      nodes[b].neighbors.push(a);
    };

    nodes.push({ id: 0, ring: 0, branch: null, type: 'root', x: 0, y: 0, angle: 0, name: 'Graine originelle', effects: {}, neighbors: [] });

    const sector = (Math.PI * 2) / BRANCHES.length;
    const ringsByBranch = BRANCHES.map(() => [[0]]);
    const nameIdx = {};

    for (let r = 1; r <= RINGS; r++) {
      const count = Math.ceil(1.5 * r);
      BRANCHES.forEach((b, bi) => {
        const row = [];
        const start = bi * sector - Math.PI / 2;
        const mid = Math.floor((count - 1) / 2);
        for (let i = 0; i < count; i++) {
          const t = (i + 0.5) / count;
          const jitterA = (rand() - 0.5) * (sector / count) * 0.35;
          const angle = start + t * sector + jitterA;
          const radius = r * RING_GAP + (rand() - 0.5) * RING_GAP * 0.3;
          let type = 'small';
          let ks = null;
          if (i === mid && (r === 5 || r === 10 || r === 15)) {
            type = 'keystone';
            ks = KEYSTONES[b.id][r / 5 - 1];
          } else if (r % 3 === 0 && (i === 0 || i === count - 1 ? false : (i + r) % 4 === 0)) {
            type = 'notable';
          } else if (r >= 2 && rand() < 0.04) {
            type = 'notable';
          }
          const id = nodes.length;
          let name;
          if (type === 'keystone') name = ks.name;
          else if (type === 'notable') {
            const w = NOTABLE_WORDS[b.id];
            nameIdx[b.id] = (nameIdx[b.id] || 0) + 1;
            const n = nameIdx[b.id];
            name = w[0][n % w[0].length] + ' ' + w[1][Math.floor(n / w[0].length) % w[1].length];
          } else name = b.name;
          nodes.push({
            id, ring: r, branch: b.id, type, angle, radius,
            x: Math.cos(angle) * radius,
            y: Math.sin(angle) * radius,
            name,
            keystone: ks ? ks.key : null,
            desc: ks ? ks.desc : null,
            effects: type === 'keystone' ? {} : nodeEffects(b.id, r, type === 'notable'),
            neighbors: [],
          });
          row.push(id);
        }
        ringsByBranch[bi].push(row);

        // Liens vers l'anneau précédent : parent le plus proche, parfois un second.
        const prev = ringsByBranch[bi][r - 1];
        row.forEach((id) => {
          const n = nodes[id];
          const sorted = prev
            .map((p) => [p, (nodes[p].x - n.x) ** 2 + (nodes[p].y - n.y) ** 2])
            .sort((a, b2) => a[1] - b2[1]);
          link(id, sorted[0][0]);
          if (sorted.length > 1 && rand() < 0.22) link(id, sorted[1][0]);
        });
        // Liens latéraux dans le même anneau.
        for (let i = 0; i < row.length - 1; i++) {
          if (rand() < 0.2) link(row[i], row[i + 1]);
        }
      });
      // Ponts entre branches voisines, tous les 4 anneaux.
      if (r % 4 === 2) {
        BRANCHES.forEach((b, bi) => {
          const a = ringsByBranch[bi][r];
          const c = ringsByBranch[(bi + 1) % BRANCHES.length][r];
          link(a[a.length - 1], c[0]);
        });
      }
    }

    // Garantir que chaque parent connecté au centre existe (le graphe est connexe par construction).
    return { nodes, edges, rings: RINGS, ringGap: RING_GAP };
  }

  S.BRANCHES = BRANCHES;
  S.BRANCH_BY_ID = Object.fromEntries(BRANCHES.map((b) => [b.id, b]));
  S.buildTree = build;
})(typeof window !== 'undefined' ? window : globalThis);
