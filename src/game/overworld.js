// Tiny top-down grid overworld: renders a scene, moves the player one tile
// at a time and reports interactions/step triggers to the caller.
const TILE = 32;
const SOLID = new Set(['#', 'C', 'T', 'X', 'B', '~', 'W', 'P', 'S', 'K']);

export function createOverworld({ canvas, hud }) {
  const ctx = canvas.getContext('2d');
  let scene = null, grid = [], player = { x: 1, y: 1, facing: 'down' };
  let npcs = {}; // char -> {x,y}
  let hudText = '';

  function load(sceneDef, startOverride = null) {
    scene = sceneDef;
    grid = sceneDef.map.map((row) => row.split(''));
    npcs = {};
    for (let y = 0; y < grid.length; y++) for (let x = 0; x < grid[y].length; x++) {
      const ch = grid[y][x];
      if (ch === '@') { player = { x, y, facing: 'up' }; grid[y][x] = sceneDef.map[y][x - 1] === '#' ? '.' : (sceneDef.map[y][x - 1] || '.'); }
      if ('SKH'.includes(ch)) npcs[ch] = { x, y };
    }
    if (startOverride) player = { ...player, ...startOverride };
    draw();
  }

  function setTile(x, y, ch) { grid[y][x] = ch; draw(); }
  function tileAt(x, y) { return grid[y]?.[x] ?? '#'; }
  function setHud(t) { hudText = t; hud.textContent = t; }

  function draw() {
    if (!scene) return;
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    const offX = Math.floor((canvas.width - grid[0].length * TILE) / 2);
    const offY = Math.floor((canvas.height - grid.length * TILE) / 2);
    for (let y = 0; y < grid.length; y++) for (let x = 0; x < grid[y].length; x++) {
      const ch = grid[y][x];
      const base = scene.palette[ch] ?? scene.palette['.'] ?? '#444';
      ctx.fillStyle = base;
      ctx.fillRect(offX + x * TILE, offY + y * TILE, TILE, TILE);
      const px = offX + x * TILE, py = offY + y * TILE;
      ctx.font = '20px serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      const glyph = { P: '📺', D: '🚪', C: '🚗', X: '🌀', S: '🕷️', K: '🥷', T: '🪵', B: '🪨', H: '🏯', G: '🌉', W: '🪟', E: '🌾' }[ch];
      if (ch === '~') { ctx.fillStyle = 'rgba(255,255,255,.15)'; ctx.fillRect(px + 4, py + 14, 24, 3); }
      if (ch === 'E') { ctx.fillStyle = 'rgba(0,0,0,.12)'; ctx.fillRect(px, py, TILE, TILE); }
      if (glyph) ctx.fillText(glyph, px + TILE / 2, py + TILE / 2 + 1);
      if (ch === 'X') { ctx.fillStyle = 'rgba(176,108,255,.35)'; ctx.beginPath(); ctx.arc(px + 16, py + 16, 22, 0, Math.PI * 2); ctx.fill(); }
    }
    // player
    const px = offX + player.x * TILE, py = offY + player.y * TILE;
    ctx.fillStyle = '#ffe45c';
    ctx.fillRect(px + 8, py + 6, 16, 20);
    ctx.fillStyle = '#000';
    const eye = { up: [14, 6], down: [14, 12], left: [8, 10], right: [20, 10] }[player.facing];
    ctx.fillRect(px + eye[0], py + eye[1], 4, 4);
    ctx.fillStyle = 'rgba(255,255,255,.85)'; ctx.font = '12px sans-serif'; ctx.textAlign = 'left'; ctx.textBaseline = 'top';
    ctx.fillText(scene.name, 8, canvas.height - 18);
    hud.textContent = hudText;
  }

  function facingTile() {
    const d = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }[player.facing];
    return { x: player.x + d[0], y: player.y + d[1], ch: tileAt(player.x + d[0], player.y + d[1]) };
  }

  /** Try to move; returns { moved, tile, blockedBy } */
  function move(dir) {
    const d = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }[dir];
    player.facing = dir;
    const nx = player.x + d[0], ny = player.y + d[1];
    const ch = tileAt(nx, ny);
    if (SOLID.has(ch) || ch === 'G') { draw(); return { moved: false, tile: ch, x: nx, y: ny }; }
    player.x = nx; player.y = ny;
    draw();
    return { moved: true, tile: ch, x: nx, y: ny };
  }

  return { load, draw, move, facingTile, setTile, tileAt, setHud, get player() { return player; }, TILE };
}
