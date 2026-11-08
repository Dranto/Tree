// Boucle de jeu, interface et contrôles.
(function () {
  const S = window.Seve;
  const tree = S.buildTree();
  const game = new S.Game(tree);
  const canvas = document.getElementById('tree');
  const view = new S.Renderer(canvas, game);
  S.game = game; // accès console pour le débogage
  const $ = (id) => document.getElementById(id);

  const SUFFIX = ['', 'k', 'M', 'Md', 'Bn', 'Bd', 'Tn', 'Td', 'Qn', 'Qd'];
  function fmt(x) {
    if (!isFinite(x)) return '∞';
    if (x < 1000) return x < 10 && x % 1 ? x.toFixed(1) : Math.floor(x).toString();
    const e = Math.floor(Math.log10(x) / 3);
    if (e < SUFFIX.length) return (x / Math.pow(1000, e)).toFixed(2) + ' ' + SUFFIX[e];
    return x.toExponential(2).replace('+', '');
  }
  const pct = (x) => '+' + (Math.round(x * 1000) / 10).toLocaleString('fr-FR') + ' %';

  function describe(n) {
    const e = n.effects;
    const out = [];
    if (e.flat) out.push(`+${fmt(e.flat)} sève/s de base`);
    if (e.pct) out.push(`${pct(e.pct)} de production`);
    if (e.clickFlat) out.push(`+${fmt(e.clickFlat)} par récolte`);
    if (e.clickPct) out.push(`Récolte : ${pct(e.clickPct)} de la production/s`);
    if (e.costRed) out.push(`Coûts −${Math.round(e.costRed * 1000) / 10} %`);
    if (e.synergy) out.push(`${pct(e.synergy)} de production par nœud possédé`);
    if (e.seedPct) out.push(`${pct(e.seedPct)} de graines à l'hiver`);
    if (e.offline) out.push(`${pct(e.offline)} de gains hors ligne`);
    if (n.desc) out.push(n.desc);
    return out;
  }

  const KIND = { root: 'Origine', small: 'Nœud', notable: 'Nœud notable', keystone: 'Nœud clé' };

  function showTooltip(n, sx, sy) {
    const tip = $('tooltip');
    if (!n) { tip.hidden = true; return; }
    const st = game.status(n.id);
    const b = n.branch ? S.BRANCH_BY_ID[n.branch] : null;
    let html = `<h3 style="color:${b ? b.color : '#f0e6b4'}">${n.name}</h3>`;
    html += `<div class="kind">${KIND[n.type]}${b ? ' · ' + b.name : ''} · anneau ${n.ring}</div>`;
    const fx = describe(n);
    if (n.type === 'root') fx.push('Le cœur de l\'arbre. Tout part d\'ici.');
    html += `<ul class="fx">${fx.map((f) => `<li>${f}</li>`).join('')}</ul>`;
    if (st === 'owned') html += `<div class="note">Acquis</div>`;
    else {
      const c = game.cost(n.id);
      html += `<div class="cost ${game.state.sap >= c ? 'yes' : 'no'}">Coût : ${fmt(c)} sève</div>`;
      if (st === 'frozen') html += `<div class="note">Pris dans le givre : déclenche un hiver pour l'atteindre.</div>`;
      else if (st === 'locked') html += `<div class="note">Achète d'abord un nœud voisin.</div>`;
    }
    tip.innerHTML = html;
    tip.hidden = false;
    const pad = 16;
    const r = tip.getBoundingClientRect();
    let x = sx + pad;
    let y = sy + pad;
    if (x + r.width > window.innerWidth - 8) x = sx - r.width - pad;
    if (y + r.height > window.innerHeight - 8) y = sy - r.height - pad;
    tip.style.left = Math.max(8, x) + 'px';
    tip.style.top = Math.max(8, y) + 'px';
  }

  let toastTimer = null;
  function toast(msg) {
    const t = $('toast');
    t.textContent = msg;
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (t.hidden = true), 3500);
  }

  // --- Contrôles : déplacement, zoom, pincement, clic ---
  const pointers = new Map();
  let drag = null;
  let pinch = null;
  let lastTip = null;

  canvas.addEventListener('pointerdown', (e) => {
    canvas.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) drag = { x: e.clientX, y: e.clientY, moved: 0, type: e.pointerType };
    if (pointers.size === 2) {
      const [a, b] = [...pointers.values()];
      pinch = { d: Math.hypot(a.x - b.x, a.y - b.y) };
      drag = null;
    }
  });

  canvas.addEventListener('pointermove', (e) => {
    const p = pointers.get(e.pointerId);
    if (p) {
      const dx = e.clientX - p.x;
      const dy = e.clientY - p.y;
      p.x = e.clientX;
      p.y = e.clientY;
      if (pinch && pointers.size === 2) {
        const [a, b] = [...pointers.values()];
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        view.zoomAt((a.x + b.x) / 2, (a.y + b.y) / 2, d / pinch.d);
        pinch.d = d;
        return;
      }
      if (drag) {
        drag.moved += Math.abs(dx) + Math.abs(dy);
        if (drag.moved > 6) {
          canvas.classList.add('dragging');
          view.pan(dx, dy);
          view.hover = null;
          showTooltip(null);
          return;
        }
      }
    }
    if (e.pointerType === 'mouse') {
      const n = view.pick(e.clientX, e.clientY);
      view.hover = n;
      canvas.classList.toggle('pointing', !!n);
      lastTip = n ? [e.clientX, e.clientY] : null;
      showTooltip(n, e.clientX, e.clientY);
    }
  });

  function endPointer(e) {
    const wasDrag = drag;
    pointers.delete(e.pointerId);
    canvas.classList.remove('dragging');
    if (pointers.size < 2) pinch = null;
    if (wasDrag && wasDrag.moved <= 6 && e.type === 'pointerup') {
      const n = view.pick(e.clientX, e.clientY);
      if (n) {
        if (game.buy(n.id)) view.flash(n.id);
        // Sur écran tactile, un appui affiche aussi la fiche du nœud.
        view.hover = n;
        lastTip = [e.clientX, e.clientY];
        showTooltip(n, e.clientX, e.clientY);
      } else if (wasDrag.type !== 'mouse') {
        view.hover = null;
        showTooltip(null);
      }
    }
    drag = null;
  }
  canvas.addEventListener('pointerup', endPointer);
  canvas.addEventListener('pointercancel', endPointer);
  canvas.addEventListener('pointerleave', (e) => {
    if (e.pointerType === 'mouse' && !drag) { view.hover = null; showTooltip(null); }
  });

  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    view.zoomAt(e.clientX, e.clientY, Math.exp(-e.deltaY * 0.0015));
  }, { passive: false });

  // --- Boutons ---
  function harvest() {
    const v = game.harvest();
    const btn = $('harvest');
    btn.animate([{ transform: 'scale(0.96)' }, { transform: 'scale(1)' }], { duration: 120 });
    return v;
  }
  $('harvest').addEventListener('click', harvest);
  window.addEventListener('keydown', (e) => {
    if (e.code === 'Space' && !$('helpDialog').open) { e.preventDefault(); harvest(); }
  });

  $('winter').addEventListener('click', () => {
    const g = game.seedsOnWinter();
    if (g < 1) return;
    const msg = `Déclencher l'hiver ?\n\nL'arbre et la sève repartent de zéro.\nTu gagnes ${fmt(g)} graine(s) et le givre recule jusqu'à l'anneau ${Math.min(tree.rings, game.frontier() + 3)}.`;
    if (!confirm(msg)) return;
    game.winter();
    game.save();
    toast(`Hiver n°${game.state.winters} : +${fmt(g)} graines. Le printemps revient.`);
  });

  $('center').addEventListener('click', () => {
    view.cam.x = 0;
    view.cam.y = 0;
    view.cam.zoom = Math.min(window.innerWidth, window.innerHeight) / (2 * (tree.rings + 1.2) * tree.ringGap);
  });

  const help = $('helpDialog');
  $('branchList').innerHTML = S.BRANCHES.map((b) => `<span><i style="background:${b.color}"></i><b>${b.name}</b> : ${b.blurb}</span>`).join('<br>');
  $('help').addEventListener('click', () => help.showModal());
  $('closeHelp').addEventListener('click', () => help.close());
  $('resetBtn').addEventListener('click', () => {
    if (!confirm('Effacer définitivement la partie ?')) return;
    game.reset();
    help.close();
    toast('Nouvelle partie.');
  });

  // --- Démarrage ---
  const offline = game.load();
  if (offline > 0) toast(`Pendant ton absence, l'arbre a produit ${fmt(offline)} sève.`);
  if (game.state.owned.length <= 1 && game.state.winters === 0 && game.state.totalEarned < 1) help.showModal();
  $('total').textContent = tree.nodes.length.toLocaleString('fr-FR');
  view.cam.zoom = Math.min(1, Math.min(window.innerWidth, window.innerHeight) / 700);

  game.on((ev, data) => {
    if (ev === 'buy' && tree.nodes[data].type === 'keystone') toast(`Nœud clé débloqué : ${tree.nodes[data].name}`);
  });

  let last = performance.now();
  let hudAcc = 0;
  let saveAcc = 0;
  function frame(now) {
    const dt = Math.min(8 * 3600, Math.max(0, (now - last) / 1000));
    last = now;
    game.tick(dt);
    view.draw(now);

    hudAcc += dt;
    if (hudAcc > 0.1) {
      hudAcc = 0;
      $('sap').textContent = fmt(game.state.sap);
      $('rate').textContent = fmt(game.stats.prod);
      $('seeds').textContent = fmt(game.state.seeds);
      $('seedBonus').textContent = game.state.seeds ? `(×${fmt(1 + game.stats.seedBonus * game.state.seeds)})` : '';
      $('frontier').textContent = game.frontier() >= tree.rings ? '— (aucun)' : game.frontier();
      $('winters').textContent = game.state.winters;
      $('owned').textContent = game.stats.owned.toLocaleString('fr-FR');
      $('clickVal').textContent = '+' + fmt(game.stats.click);
      const g = game.seedsOnWinter();
      $('winter').disabled = g < 1;
      $('winterGain').textContent = g >= 1 ? '+' + fmt(g) + ' graines' : '';
      if (view.hover && lastTip) showTooltip(view.hover, lastTip[0], lastTip[1]);
    }
    saveAcc += dt;
    if (saveAcc > 10) { saveAcc = 0; game.save(); }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  window.addEventListener('beforeunload', () => game.save());
  document.addEventListener('visibilitychange', () => { if (document.hidden) game.save(); });
})();
