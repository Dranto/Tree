// État du jeu, économie, saisons (prestige) et sauvegarde.
(function (G) {
  const S = (G.Seve = G.Seve || {});

  const SAVE_KEY = 'seve-save-v1';
  const TYPE_COST = { small: 1, notable: 4, keystone: 12, root: 0 };
  const BASE_FRONTIER = 6;
  const FRONTIER_STEP = 3;
  const SEED_DIVISOR = 1e6;
  const OFFLINE_CAP = 8 * 3600;

  function newState() {
    return {
      sap: 0,
      seasonEarned: 0,
      totalEarned: 0,
      seeds: 0,
      winters: 0,
      owned: [0],
      last: Date.now(),
    };
  }

  class Game {
    constructor(tree) {
      this.tree = tree;
      this.state = newState();
      this.ownedSet = new Set(this.state.owned);
      this.listeners = [];
      this.autoAcc = 0;
      this.recompute();
    }

    on(fn) { this.listeners.push(fn); }
    emit(ev, data) { this.listeners.forEach((f) => f(ev, data)); }

    frontier() {
      return Math.min(this.tree.rings, BASE_FRONTIER + FRONTIER_STEP * this.state.winters);
    }

    has(id) { return this.ownedSet.has(id); }

    hasKey(key) { return this.keys.has(key); }

    recompute() {
      const st = { flat: 0, pct: 0, clickFlat: 0, clickPct: 0, costRed: 0, synergy: 0, seedPct: 0, offline: 0.25 };
      const perBranch = {};
      let notables = 0;
      let keystones = 0;
      this.keys = new Set();
      for (const id of this.ownedSet) {
        const n = this.tree.nodes[id];
        if (n.branch) perBranch[n.branch] = (perBranch[n.branch] || 0) + 1;
        if (n.type === 'notable') notables++;
        if (n.type === 'keystone') { keystones++; this.keys.add(n.keystone); }
        for (const k in n.effects) {
          if (k === 'costRed') st.costRed += Math.log(1 - n.effects[k]);
          else st[k] += n.effects[k];
        }
      }
      const owned = this.ownedSet.size;
      const K = (k) => this.keys.has(k);

      let flatMult = 1, prodMult = 1, pctMult = 1, synergyMult = 1, clickMult = 1, seedMult = 1, costMult = Math.exp(st.costRed);
      if (K('pivot')) flatMult *= 2;
      if (K('meres')) st.pct += 0.02 * (perBranch.racines || 0);
      if (K('tellurique')) { flatMult *= 5; clickMult = 0; }
      if (K('photo')) pctMult *= 1.5;
      if (K('canopee')) prodMult *= 1 + 0.15 * keystones;
      if (K('soleil')) prodMult *= 3;
      if (K('pollen')) st.clickPct += 0.1;
      if (K('nectar')) clickMult *= 10;
      if (K('liege')) costMult *= 0.75;
      if (K('petri')) { costMult *= 0.3; prodMult *= 0.8; }
      if (K('reseau')) synergyMult *= 2;
      if (K('symbiose')) prodMult *= 1 + 0.04 * notables;
      if (K('esprit')) prodMult *= 1 + owned / 100;
      if (K('verger')) seedMult *= 1.5;
      if (K('conserve')) st.offline = 1;
      const seedBonus = K('or') ? 0.25 : 0.1;

      const prod =
        (1 + st.flat) * flatMult *
        (1 + st.pct * pctMult + st.synergy * synergyMult * owned) *
        prodMult *
        (1 + seedBonus * this.state.seeds);

      const click = ((1 + st.clickFlat) * (1 + st.pct * pctMult * 0.5) + st.clickPct * prod) * clickMult;

      this.stats = {
        ...st,
        prod,
        click,
        costMult,
        seedMult: seedMult * (1 + st.seedPct),
        seedBonus,
        offline: Math.min(1, st.offline),
        autoClicks: K('floraison') ? 2 : 0,
        owned,
        perBranch,
        notables,
        keystones,
      };
    }

    cost(id) {
      const n = this.tree.nodes[id];
      let c = 10 * Math.pow(1.9, n.ring - 1) * TYPE_COST[n.type] * this.stats.costMult;
      if ((n.type === 'notable' || n.type === 'keystone') && this.hasKey('coeur')) c *= 0.5;
      // Légère inflation selon le nombre de nœuds déjà pris : l'ordre d'achat compte.
      c *= Math.pow(1.02, this.stats.owned);
      return Math.ceil(c);
    }

    status(id) {
      if (this.has(id)) return 'owned';
      const n = this.tree.nodes[id];
      if (n.ring > this.frontier()) return 'frozen';
      if (!n.neighbors.some((m) => this.ownedSet.has(m))) return 'locked';
      return this.state.sap >= this.cost(id) ? 'affordable' : 'available';
    }

    buy(id) {
      const s = this.status(id);
      if (s !== 'affordable') return false;
      this.state.sap -= this.cost(id);
      this.ownedSet.add(id);
      this.state.owned.push(id);
      this.recompute();
      this.emit('buy', id);
      return true;
    }

    earn(x) {
      this.state.sap += x;
      this.state.seasonEarned += x;
      this.state.totalEarned += x;
    }

    harvest() {
      const v = this.stats.click;
      this.earn(v);
      return v;
    }

    tick(dt) {
      this.earn(this.stats.prod * dt);
      if (this.stats.autoClicks) {
        this.autoAcc += dt * this.stats.autoClicks;
        while (this.autoAcc >= 1) { this.autoAcc -= 1; this.harvest(); }
      }
    }

    seedsOnWinter() {
      return Math.floor(Math.cbrt(this.state.seasonEarned / SEED_DIVISOR) * this.stats.seedMult);
    }

    canWinter() { return this.seedsOnWinter() >= 1; }

    winter() {
      const gain = this.seedsOnWinter();
      if (gain < 1) return 0;
      this.state.seeds += gain;
      this.state.winters += 1;
      this.state.sap = 0;
      this.state.seasonEarned = 0;
      this.state.owned = [0];
      this.ownedSet = new Set([0]);
      this.recompute();
      this.emit('winter', gain);
      return gain;
    }

    save() {
      this.state.last = Date.now();
      try { localStorage.setItem(SAVE_KEY, JSON.stringify(this.state)); } catch (e) { /* stockage indisponible */ }
    }

    load() {
      let raw = null;
      try { raw = localStorage.getItem(SAVE_KEY); } catch (e) { return 0; }
      if (!raw) return 0;
      try {
        const s = Object.assign(newState(), JSON.parse(raw));
        s.owned = s.owned.filter((id) => this.tree.nodes[id]);
        if (!s.owned.includes(0)) s.owned.unshift(0);
        this.state = s;
        this.ownedSet = new Set(s.owned);
        this.recompute();
        const away = Math.min(OFFLINE_CAP, Math.max(0, (Date.now() - s.last) / 1000));
        const gain = this.stats.prod * away * this.stats.offline;
        if (gain > 0) this.earn(gain);
        return gain;
      } catch (e) {
        return 0;
      }
    }

    reset() {
      try { localStorage.removeItem(SAVE_KEY); } catch (e) { /* ignore */ }
      this.state = newState();
      this.ownedSet = new Set([0]);
      this.recompute();
    }
  }

  S.Game = Game;
})(typeof window !== 'undefined' ? window : globalThis);
