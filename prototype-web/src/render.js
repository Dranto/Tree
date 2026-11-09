// Rendu Canvas de l'arbre : caméra (déplacement / zoom), arêtes, nœuds, givre.
(function (G) {
  const S = (G.Seve = G.Seve || {});

  const RADIUS = { root: 26, small: 9, notable: 15, keystone: 22 };

  function hexToRgb(hex) {
    const n = parseInt(hex.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  class Renderer {
    constructor(canvas, game) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.game = game;
      this.tree = game.tree;
      this.cam = { x: 0, y: 0, zoom: 1 };
      this.hover = null;
      this.flashes = [];
      this.rgb = {};
      S.BRANCHES.forEach((b) => (this.rgb[b.id] = hexToRgb(b.color)));
      this.resize();
      window.addEventListener('resize', () => this.resize());
    }

    resize() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.dpr = dpr;
      this.w = window.innerWidth;
      this.h = window.innerHeight;
      this.canvas.width = this.w * dpr;
      this.canvas.height = this.h * dpr;
    }

    toScreen(x, y) {
      return [(x - this.cam.x) * this.cam.zoom + this.w / 2, (y - this.cam.y) * this.cam.zoom + this.h / 2];
    }

    toWorld(sx, sy) {
      return [(sx - this.w / 2) / this.cam.zoom + this.cam.x, (sy - this.h / 2) / this.cam.zoom + this.cam.y];
    }

    zoomAt(sx, sy, factor) {
      const [wx, wy] = this.toWorld(sx, sy);
      const z = Math.max(0.12, Math.min(3, this.cam.zoom * factor));
      this.cam.zoom = z;
      this.cam.x = wx - (sx - this.w / 2) / z;
      this.cam.y = wy - (sy - this.h / 2) / z;
    }

    pan(dx, dy) {
      this.cam.x -= dx / this.cam.zoom;
      this.cam.y -= dy / this.cam.zoom;
    }

    radiusOf(n) {
      return RADIUS[n.type];
    }

    pick(sx, sy) {
      const [wx, wy] = this.toWorld(sx, sy);
      const slack = 6 / this.cam.zoom;
      let best = null;
      let bd = Infinity;
      for (const n of this.tree.nodes) {
        const r = this.radiusOf(n) + slack;
        const d = (n.x - wx) ** 2 + (n.y - wy) ** 2;
        if (d < r * r && d < bd) { bd = d; best = n; }
      }
      return best;
    }

    flash(id) {
      this.flashes.push({ id, t: performance.now() });
    }

    draw(now) {
      const { ctx, game, tree, cam } = this;
      const z = cam.zoom;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);

      // Fond
      const bg = ctx.createRadialGradient(this.w / 2, this.h / 2, 0, this.w / 2, this.h / 2, Math.max(this.w, this.h));
      bg.addColorStop(0, '#111a15');
      bg.addColorStop(1, '#070a08');
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, this.w, this.h);

      ctx.setTransform(this.dpr * z, 0, 0, this.dpr * z, this.dpr * (this.w / 2 - cam.x * z), this.dpr * (this.h / 2 - cam.y * z));

      // Vue courante en coordonnées monde (pour ignorer ce qui est hors écran)
      const [x0, y0] = this.toWorld(-40, -40);
      const [x1, y1] = this.toWorld(this.w + 40, this.h + 40);
      const visible = (n) => n.x > x0 && n.x < x1 && n.y > y0 && n.y < y1;

      // Anneaux guides
      ctx.lineWidth = 1 / z;
      ctx.strokeStyle = 'rgba(140,180,150,0.05)';
      for (let r = 1; r <= tree.rings; r++) {
        ctx.beginPath();
        ctx.arc(0, 0, r * tree.ringGap, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Givre
      const frontier = game.frontier();
      if (frontier < tree.rings) {
        const fr = (frontier + 0.5) * tree.ringGap;
        ctx.save();
        ctx.strokeStyle = 'rgba(159,216,255,0.55)';
        ctx.lineWidth = 3 / z;
        ctx.setLineDash([14 / z, 10 / z]);
        ctx.lineDashOffset = -now / 80 / z;
        ctx.beginPath();
        ctx.arc(0, 0, fr, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
        ctx.fillStyle = 'rgba(120,170,210,0.05)';
        ctx.beginPath();
        ctx.arc(0, 0, (tree.rings + 1) * tree.ringGap, 0, Math.PI * 2);
        ctx.arc(0, 0, fr, 0, Math.PI * 2, true);
        ctx.fill();
      }

      // Statuts calculés une fois par image
      const status = new Array(tree.nodes.length);
      for (const n of tree.nodes) status[n.id] = game.status(n.id);

      // Arêtes groupées par style
      const dim = new Path2D();
      const half = new Path2D();
      const lit = {};
      for (const [a, b] of tree.edges) {
        const na = tree.nodes[a];
        const nb = tree.nodes[b];
        if (!visible(na) && !visible(nb)) continue;
        const oa = status[a] === 'owned';
        const ob = status[b] === 'owned';
        let p;
        if (oa && ob) {
          const br = nb.branch || na.branch;
          p = lit[br] || (lit[br] = new Path2D());
        } else if (oa || ob) p = half;
        else p = dim;
        p.moveTo(na.x, na.y);
        p.lineTo(nb.x, nb.y);
      }
      ctx.lineCap = 'round';
      ctx.lineWidth = Math.max(1.2, 1.5 / z);
      ctx.strokeStyle = 'rgba(120,140,130,0.18)';
      ctx.stroke(dim);
      ctx.lineWidth = Math.max(1.5, 2 / z);
      ctx.strokeStyle = 'rgba(200,220,205,0.4)';
      ctx.stroke(half);
      ctx.lineWidth = Math.max(3, 3 / z);
      for (const br in lit) {
        const [r, g, b] = this.rgb[br];
        ctx.strokeStyle = `rgba(${r},${g},${b},0.85)`;
        ctx.stroke(lit[br]);
      }

      // Nœuds
      const pulse = 0.5 + 0.5 * Math.sin(now / 350);
      const detail = z > 0.35;
      for (const n of tree.nodes) {
        if (!visible(n)) continue;
        const st = status[n.id];
        const rad = this.radiusOf(n);
        const [r, g, b] = n.branch ? this.rgb[n.branch] : [240, 230, 180];

        if (st === 'owned') {
          ctx.fillStyle = `rgba(${r},${g},${b},0.18)`;
          ctx.beginPath();
          ctx.arc(n.x, n.y, rad * 1.9, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = `rgb(${r},${g},${b})`;
        } else if (st === 'affordable' || st === 'available') {
          ctx.fillStyle = '#16201b';
        } else if (st === 'frozen') {
          ctx.fillStyle = '#121a20';
        } else {
          ctx.fillStyle = '#121714';
        }

        ctx.beginPath();
        if (n.type === 'keystone') this.diamond(ctx, n.x, n.y, rad);
        else ctx.arc(n.x, n.y, rad, 0, Math.PI * 2);
        ctx.fill();

        let stroke;
        let lw = 2;
        if (st === 'owned') { stroke = 'rgba(255,255,255,0.65)'; lw = 1.5; }
        else if (st === 'affordable') { stroke = `rgba(${r},${g},${b},${0.55 + 0.45 * pulse})`; lw = 3; }
        else if (st === 'available') { stroke = `rgba(${r},${g},${b},0.45)`; lw = 2; }
        else if (st === 'frozen') { stroke = 'rgba(159,216,255,0.22)'; lw = 1.5; }
        else { stroke = `rgba(${r},${g},${b},0.16)`; lw = 1.5; }
        if (n.type !== 'small') lw += 1;
        ctx.strokeStyle = stroke;
        ctx.lineWidth = lw;
        ctx.stroke();

        if (n.type === 'notable' && detail) {
          ctx.beginPath();
          ctx.arc(n.x, n.y, rad * 0.45, 0, Math.PI * 2);
          ctx.fillStyle = st === 'owned' ? 'rgba(255,255,255,0.7)' : `rgba(${r},${g},${b},0.35)`;
          ctx.fill();
        }

        if ((n.type === 'keystone' || n.type === 'root') && z > 0.25) {
          ctx.fillStyle = st === 'owned' ? 'rgba(255,255,255,0.9)' : 'rgba(220,230,220,0.55)';
          ctx.font = `600 ${Math.max(11, 12 / z)}px system-ui, sans-serif`;
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillText(n.name, n.x, n.y + rad + 6);
        }
      }

      // Survol
      if (this.hover) {
        const n = this.hover;
        ctx.beginPath();
        ctx.arc(n.x, n.y, this.radiusOf(n) + 6, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(255,255,255,0.8)';
        ctx.lineWidth = 2 / z;
        ctx.stroke();
      }

      // Éclats d'achat
      this.flashes = this.flashes.filter((f) => now - f.t < 600);
      for (const f of this.flashes) {
        const n = tree.nodes[f.id];
        const k = (now - f.t) / 600;
        const [r, g, b] = n.branch ? this.rgb[n.branch] : [255, 255, 255];
        ctx.beginPath();
        ctx.arc(n.x, n.y, this.radiusOf(n) * (1 + k * 3), 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(${r},${g},${b},${1 - k})`;
        ctx.lineWidth = 3;
        ctx.stroke();
      }

      // Noms des branches en vue d'ensemble
      if (z < 0.5) {
        ctx.font = `700 ${18 / z}px system-ui, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        S.BRANCHES.forEach((b, i) => {
          const a = (i + 0.5) * (Math.PI * 2 / S.BRANCHES.length) - Math.PI / 2;
          const R = (tree.rings + 1.6) * tree.ringGap;
          const [r, g, bb] = this.rgb[b.id];
          ctx.fillStyle = `rgba(${r},${g},${bb},0.8)`;
          ctx.fillText(b.name, Math.cos(a) * R, Math.sin(a) * R);
        });
      }
    }

    diamond(ctx, x, y, r) {
      ctx.moveTo(x, y - r * 1.15);
      ctx.lineTo(x + r, y);
      ctx.lineTo(x, y + r * 1.15);
      ctx.lineTo(x - r, y);
      ctx.closePath();
    }
  }

  S.Renderer = Renderer;
})(typeof window !== 'undefined' ? window : globalThis);
