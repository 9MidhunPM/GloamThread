import {
  AdditiveBlending, AmbientLight, BoxGeometry, CanvasTexture, Color, DirectionalLight, DoubleSide, Group,
  InstancedMesh, Mesh, MeshBasicMaterial, MeshLambertMaterial,
  NearestFilter, Object3D, OrthographicCamera, PlaneGeometry, PointLight,
  Quaternion, Scene, Sprite, SpriteMaterial, SRGBColorSpace, TextureLoader, Vector3, WebGLRenderer,
} from 'three';
import foxAtlas from '../../assets/arena/builtin/kiln-fox-ai/character.png';
import thistleAtlas from '../../assets/arena/builtin/thistlepaw/character.png';

// The website miniature is original deterministic scenery, separate from combat.
const PALETTE = {
  stone: [0x24343d, 0x30464c, 0x3e5458, 0x526166, 0x1a2c36, 0x34424a],
  earth: [0x665141, 0x79604a, 0x8a6b4d, 0x4f4339],
  moss: [0x326264, 0x407b75, 0x538e7f, 0x638e75, 0x284f53],
  leaves: [0x1d444c, 0x275d65, 0x33747a, 0x438b8b, 0x588d84, 0x22515b],
  wood: [0x624a38, 0x805d3f, 0x9d7650, 0xb18b60, 0x4b3c30],
};

function randomSource(seed) {
  return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
}

function makeMiniature(world) {
  const random = randomSource(18427);
  const boxes = [], glow = [], dark = [];
  const pick = (palette) => palette[Math.floor(random() * palette.length)];
  const add = (x, y, z, sx, sy, sz, color, rotation = null, collection = boxes) => {
    collection.push({ x, y, z, sx, sy, sz, color, rotation });
  };
  const beam = (a, b, width, color, collection = boxes) => {
    const start = new Vector3(...a), end = new Vector3(...b);
    const direction = end.clone().sub(start);
    const center = start.add(end).multiplyScalar(0.5);
    add(center.x, center.y, center.z, width, direction.length(), width, color,
      new Quaternion().setFromUnitVectors(new Vector3(0, 1, 0), direction.normalize()), collection);
  };
  const ledge = (cx, cz, width, depth, top, seedOffset = 0) => {
    const unit = 0.42;
    for (let x = -width / 2; x < width / 2; x += unit) {
      for (let z = -depth / 2; z < depth / 2; z += unit) {
        const edge = Math.max(Math.abs(x / (width / 2)), Math.abs(z / (depth / 2)));
        if (edge > 0.86 && random() < 0.18) continue;
        const bottom = -2.7 + edge * 1.05 + random() * 0.65 + seedOffset;
        const columnTop = top + (random() - 0.5) * 0.08;
        for (let y = bottom; y < columnTop; y += 0.38) {
          const height = Math.min(0.38, columnTop - y);
          add(cx + x + (random() - 0.5) * 0.055, y + height / 2, cz + z + (random() - 0.5) * 0.055,
            unit + random() * 0.055, height + 0.012, unit + random() * 0.055, pick(PALETTE.stone));
        }
        add(cx + x, columnTop + 0.045, cz + z, unit + 0.025, 0.14, unit + 0.025, pick(PALETTE.earth));
        if (random() > 0.12) add(cx + x, columnTop + 0.13, cz + z,
          unit * (0.7 + random() * 0.4), 0.08, unit * (0.7 + random() * 0.4), pick(PALETTE.moss));
        if (edge > 0.73 && random() < 0.36) {
          for (let k = 0; k < 3 + random() * 5; k++) {
            add(cx + x, top - k * 0.27, cz + z, 0.08, 0.25, 0.08, pick(PALETTE.moss));
          }
        }
      }
    }
  };
  ledge(-2.2, -0.2, 5.7, 4.4, 0.65);
  ledge(3.6, 0.8, 3.45, 3.2, 0.15, 0.35);
  ledge(0.4, -1.7, 2.4, 2.2, 1.15);

  // Raised tree terrace, worn paving and an open lower cave.
  for (let x = -4.0; x < 0.7; x += 0.45) {
    for (let z = -1.9; z < 0.4; z += 0.45) {
      add(x, 1.02, z, 0.43, 0.55, 0.43, pick(PALETTE.stone));
      add(x, 1.33, z, 0.44, 0.1, 0.44, random() < 0.67 ? pick(PALETTE.moss) : pick(PALETTE.earth));
      if (random() < 0.25) {
        add(x + 0.08, 1.392, z, 0.013, 0.008, 0.27, 0x34483d);
        add(x, 1.392, z + 0.03, 0.18, 0.008, 0.013, 0x34483d);
      }
    }
  }
  add(-2.7, -0.15, 2.03, 1.65, 1.45, 0.05, 0x081a22, null, dark);
  for (const x of [-3.64, -1.77]) {
    for (let y = -0.7; y < 0.85; y += 0.4) add(x, y, 2.1, 0.4, 0.37, 0.4, pick(PALETTE.stone));
  }
  for (let x = -3.7; x < -1.6; x += 0.4) add(x, 0.72, 2.1, 0.4, 0.4, 0.4, pick(PALETTE.stone));
  for (let n = 0; n < 16; n++) add(-3.5 + random() * 1.9, -0.85, 2.27 + random() * 0.4, 0.18, 0.1, 0.18, pick(PALETTE.earth));

  // A broad deck and fine plank stairs draw the eye through the miniature.
  const deck = (x, y, z, width, depth) => {
    for (let dx = -width / 2; dx < width / 2; dx += 0.22) {
      add(x + dx, y, z, 0.2, 0.13, depth, pick(PALETTE.wood));
    }
    for (const dx of [-width / 2 + 0.1, width / 2 - 0.1]) {
      beam([x + dx, y - 0.1, z - depth / 2 + 0.15], [x + dx, y - 1.5, z - depth / 2 + 0.15], 0.13, 0x493e32);
      beam([x + dx, y - 0.1, z + depth / 2 - 0.15], [x + dx, y - 1.4, z + depth / 2 - 0.15], 0.13, 0x493e32);
    }
  };
  deck(-2.4, 1.0, 1.22, 3.6, 1.38);
  deck(-1.65, 3.05, -1.35, 2.4, 1.2);
  for (let n = 0; n < 8; n++) {
    add(-0.1 - n * 0.23, 1.43 + n * 0.21, -0.53, 0.32, 0.13, 0.72, pick(PALETTE.wood));
    beam([-0.1 - n * 0.23, 1.35 + n * 0.21, -0.85], [-0.1 - n * 0.23, 0.65, -0.85], 0.1, 0x5c4835);
  }

  // A suspended bridge with individual planks and segmented rope handrails.
  const bridgePoint = (t, z) => [-0.75 + t * 3.7, 0.95 - t * 0.62 - Math.sin(t * Math.PI) * 0.35, z];
  for (let n = 0; n < 19; n++) {
    const t = n / 18;
    const [x, y] = bridgePoint(t, 1.1);
    add(x, y, 1.1, 0.18, 0.12, 0.93, pick(PALETTE.wood));
    if (n % 6 === 0) for (const z of [0.61, 1.59]) beam([x, y - 0.2, z], [x, y + 0.9, z], 0.09, 0x947044);
    if (n > 0) for (const z of [0.61, 1.59]) {
      const a = bridgePoint((n - 1) / 18, z), b = bridgePoint(t, z);
      beam([a[0], a[1] + 0.73, z], [b[0], b[1] + 0.73, z], 0.035, 0xb69a69);
      beam([a[0], a[1] - 0.05, z], [b[0], b[1] - 0.05, z], 0.055, 0x755738);
    }
  }

  // The canopy uses hand-shaped bough volumes, filled with seeded voxel leaves.
  const trunk = [-1.7, 1.3, -1.1];
  const branches = [
    [[-1.7, 1.3, -1.1], [-1.55, 4.55, -1.2], 0.64],
    [[-1.55, 3.2, -1.2], [-3.4, 5.1, -0.8], 0.4],
    [[-1.55, 3.75, -1.2], [0.3, 5.5, -1.1], 0.38],
    [[-1.5, 4.1, -1.2], [-2.05, 6.2, -1.9], 0.38],
    [[-3.4, 5.1, -0.8], [-4.0, 5.3, 0.0], 0.2],
    [[0.3, 5.5, -1.1], [1.3, 5.4, -0.25], 0.2],
    [[-1.55, 4.2, -1.2], [-0.6, 5.1, 0.35], 0.25],
    [[-1.7, 2.8, -1.1], [-0.25, 4.05, 0.05], 0.29],
    [[-1.65, 3.25, -1.1], [-3.3, 4.25, 0.1], 0.3],
  ];
  for (const [branchIndex, [a, b, width]] of branches.entries()) {
    if (branchIndex === 0) {
      for (let step = 0; step < 11; step++) {
        const t = step / 10;
        const x = a[0] + (b[0] - a[0]) * t + Math.sin(t * 5.7) * 0.17;
        const y = a[1] + (b[1] - a[1]) * t;
        const z = a[2] + (b[2] - a[2]) * t + Math.cos(t * 4) * 0.07;
        add(x, y, z, width * (1.18 - t * 0.29), 0.4, width * (1.14 - t * 0.24), pick([0x5e4431, 0x6d4c34, 0x755138]));
        add(x + width * 0.2, y + 0.05, z + width / 2, 0.08, 0.3, 0.04, 0x44372d);
        add(x - width * 0.2, y - 0.08, z + width / 2, 0.07, 0.18, 0.04, 0x99714b);
      }
    } else beam(a, b, width, 0x6d4d35);
    const direction = new Vector3(...b).sub(new Vector3(...a));
    for (let n = 0; n < 14; n++) {
      const t = random(), center = new Vector3(...a).addScaledVector(direction, t);
      add(center.x + (random() - 0.5) * width, center.y, center.z + width / 2,
        width * 0.3, 0.13 + random() * 0.35, 0.08, pick(PALETTE.wood));
    }
  }
  for (let n = 0; n < 10; n++) {
    const angle = n / 10 * Math.PI * 2;
    beam(trunk, [-1.7 + Math.cos(angle) * (0.7 + random() * 0.7), 1.36, -1.1 + Math.sin(angle) * 0.8], 0.23, 0x6d5039);
  }
  for (let n = 0; n < 8; n++) {
    const angle = n * 0.7;
    const end = [-1.7 + Math.cos(angle) * 1.55, 1.4, -1.1 + Math.sin(angle) * 1.1];
    beam([-1.7 + Math.cos(angle) * 0.35, 1.65, -1.1 + Math.sin(angle) * 0.35], end, 0.13, 0x735638);
    beam(end, [end[0] + Math.cos(angle) * 0.4, 1.42, end[2] + Math.sin(angle) * 0.3], 0.065, 0x624932);
  }
  const crowns = [
    [-3.65, 5.1, -0.65, 1.55, 0.64, 1.2], [-2.7, 6.05, -1.9, 1.6, 0.85, 1.3],
    [-1.3, 6.35, -1.6, 1.7, 0.88, 1.4], [0.25, 5.8, -1.25, 1.5, 0.7, 1.25],
    [1.05, 5.15, -0.05, 1.25, 0.55, 1.1], [-1.0, 5.0, 0.25, 1.28, 0.57, 1.0],
    [-3.35, 4.7, 0.5, 1.25, 0.53, 0.95],
  ];
  for (const [cx, cy, cz, rx, ry, rz] of crowns) {
    for (let n = 0; n < 480; n++) {
      const x = (random() * 2 - 1), y = (random() * 2 - 1), z = (random() * 2 - 1);
      if (x * x + y * y + z * z > 1) continue;
      const size = 0.09 + random() * 0.15;
      add(cx + x * rx, cy + y * ry, cz + z * rz, size * 1.35, size * 0.65, size,
        pick(PALETTE.leaves));
    }
  }

  const lanterns = [];
  const lantern = (x, y, z, hanging = 0) => {
    if (hanging) beam([x, y + 0.23, z], [x, y + hanging, z], 0.027, 0x9a7951);
    add(x, y, z, 0.2, 0.31, 0.2, 0xffd586, null, glow);
    add(x, y + 0.19, z, 0.29, 0.08, 0.29, 0x5d4833);
    add(x, y - 0.19, z, 0.27, 0.08, 0.27, 0x735539);
    for (const dx of [-0.1, 0.1]) for (const dz of [-0.1, 0.1]) add(x + dx, y, z + dz, 0.035, 0.34, 0.035, 0x7b5b39);
    lanterns.push([x, y, z]);
  };
  for (const position of [[-4.0, 4.2, 0.0, 1], [-2.9, 4.5, 0.15, 1], [-0.45, 4.4, 0.15, 0.9], [0.95, 4.45, -0.5, 0.6], [-2.3, 5.05, -1.2, 0.9]]) lantern(...position);
  for (const [x, y, z] of [[-3.4, 1.5, 1.6], [4.7, 0.85, 1.8], [2.3, 0.85, -0.1], [-2.9, -0.15, 2.25]]) {
    lantern(x, y, z);
    if (y > 0) beam([x, y - 0.3, z], [x, y - 0.9, z], 0.09, 0x6e523b);
  }

  // Water descends as luminous pixel ribbons, with stepped splash pools.
  for (let n = 0; n < 13; n++) {
    const x = 0.58 + random() * 0.65;
    add(x, -0.67 + random() * 0.15, -0.38 + random() * 0.48, 0.07 + random() * 0.1, 3.4 + random() * 0.6, 0.07, n % 3 ? 0x53b3bd : 0x93d4ce, null, glow);
  }
  for (let n = 0; n < 22; n++) add(0.3 + random() * 1.4, -2.4 + random() * 0.1, -0.7 + random() * 1.2, 0.2, 0.07, 0.2, 0x68c5ce, null, glow);

  // Sparse flowers, hanging roots and broken little satellite islands.
  for (let n = 0; n < 115; n++) {
    const right = n > 80, x = right ? 2.2 + random() * 2.7 : -4.7 + random() * 4.2;
    const z = right ? -0.35 + random() * 2.5 : 0.55 + random() * 1.2;
    const y = right ? 0.35 : 0.9;
    if (random() < 0.4) {
      add(x, y + 0.1, z, 0.035, 0.22, 0.035, 0x6c9475);
      add(x, y + 0.23, z, 0.1, 0.08, 0.1, random() < 0.5 ? 0xd6d0a6 : 0x9bbd8b);
    } else add(x, y, z, 0.1 + random() * 0.15, 0.12, 0.1, pick(PALETTE.moss));
  }
  for (let n = 0; n < 100; n++) {
    const right = n > 65;
    const x = right ? 2.35 + random() * 2.35 : -4.1 + random() * 3.75;
    const z = right ? -0.45 + random() * 0.45 : -1.75 + random() * 0.45;
    const y = right ? 0.34 : 1.43;
    for (let blade = 0; blade < 3; blade++) add(x + blade * 0.035, y + 0.09, z + blade * 0.025,
      0.025, 0.12 + random() * 0.13, 0.025, pick(PALETTE.moss));
    if (n % 4 === 0) {
      add(x, y + 0.22, z, 0.035, 0.26, 0.035, 0x638969);
      add(x, y + 0.36, z, 0.13, 0.06, 0.06, 0xd8d7ac);
      add(x, y + 0.36, z, 0.06, 0.06, 0.13, 0xd8d7ac);
      add(x, y + 0.4, z, 0.045, 0.03, 0.045, 0xe8b674);
    }
  }
  // Little hand-built supplies: an orchard crate and a thread spool.
  add(-3.45, 1.69, -0.75, 0.55, 0.55, 0.5, 0x5c4935);
  for (const dx of [-0.24, 0, 0.24]) add(-3.45 + dx, 1.69, -0.48, 0.055, 0.55, 0.045, 0x997447);
  for (const dy of [-0.24, 0.24]) add(-3.45, 1.69 + dy, -0.47, 0.55, 0.055, 0.05, 0xac8551);
  add(3.45, 0.55, -0.2, 0.25, 0.44, 0.25, 0xc6aa71);
  for (let n = 0; n < 8; n++) {
    const angle = n * Math.PI / 4;
    for (const y of [0.33, 0.77]) beam([3.45, y, -0.2], [3.45 + Math.cos(angle) * 0.27, y, -0.2 + Math.sin(angle) * 0.27], 0.09, 0x8e7049);
  }
  for (const [x, y, z] of [[-5.2, 0.4, 1.2], [5.2, 2.1, -1.7], [4.2, 3.0, -2.2], [-4.4, -2.1, 3.0]]) {
    add(x, y, z, 0.52, 0.7, 0.5, pick(PALETTE.stone));
    add(x, y + 0.4, z, 0.58, 0.1, 0.55, pick(PALETTE.moss));
    for (let k = 0; k < 4; k++) add(x, y - k * 0.2, z + 0.22, 0.04, 0.19, 0.04, 0x508174);
  }

  // A small woven banner evokes the game's shared thread without external art.
  for (const [x, y, z] of [[4.7, 0.3, 0.05], [-3.5, 3.1, -1.2]]) {
    beam([x, y, z], [x, y + 1.45, z], 0.065, 0x9c794d);
    add(x + 0.24, y + 1.02, z, 0.46, 0.7, 0.03, 0x2d6067);
    add(x + 0.24, y + 1.04, z + 0.025, 0.055, 0.4, 0.025, 0xe0b66d);
    add(x + 0.24, y + 1.04, z + 0.025, 0.28, 0.055, 0.025, 0xe0b66d);
  }

  const geometry = new BoxGeometry(1, 1, 1);
  const buildBatch = (items, material) => {
    const mesh = new InstancedMesh(geometry, material, items.length);
    const dummy = new Object3D(), color = new Color();
    items.forEach((item, i) => {
      dummy.position.set(item.x, item.y, item.z);
      dummy.scale.set(item.sx, item.sy, item.sz);
      dummy.quaternion.copy(item.rotation || new Quaternion());
      dummy.updateMatrix();
      mesh.setMatrixAt(i, dummy.matrix);
      mesh.setColorAt(i, color.setHex(item.color));
    });
    mesh.instanceMatrix.needsUpdate = true;
    mesh.instanceColor.needsUpdate = true;
    mesh.frustumCulled = false;
    world.add(mesh);
    return mesh;
  };
  buildBatch(boxes, new MeshLambertMaterial());
  buildBatch(glow, new MeshBasicMaterial());
  buildBatch(dark, new MeshBasicMaterial());
  for (const [x, y, z] of [lanterns[0], lanterns[2], lanterns[5], lanterns[8]]) {
    const light = new PointLight(0xffbe6b, 7, 4.0, 2);
    light.position.set(x, y + 0.1, z + 0.25);
    world.add(light);
  }

  const haloCanvas = document.createElement('canvas');
  haloCanvas.width = 64; haloCanvas.height = 64;
  const haloContext = haloCanvas.getContext('2d');
  const haloGradient = haloContext.createRadialGradient(32, 32, 0, 32, 32, 32);
  haloGradient.addColorStop(0, 'rgba(255,201,117,0.65)');
  haloGradient.addColorStop(0.18, 'rgba(255,185,83,0.22)');
  haloGradient.addColorStop(0.55, 'rgba(255,164,62,0.06)');
  haloGradient.addColorStop(1, 'rgba(255,164,62,0)');
  haloContext.fillStyle = haloGradient; haloContext.fillRect(0, 0, 64, 64);
  const haloTexture = new CanvasTexture(haloCanvas);
  const haloMaterial = new SpriteMaterial({map: haloTexture, transparent: true, opacity: 0.65, depthWrite: false, blending: AdditiveBlending});
  for (const [x, y, z] of lanterns) {
    const halo = new Sprite(haloMaterial);
    halo.position.set(x, y, z + 0.08); halo.scale.setScalar(1.2);
    world.add(halo);
  }

  const threadPieces = [];
  const threadMaterial = new MeshBasicMaterial({color: 0xffd38a});
  const thread = new InstancedMesh(geometry, threadMaterial, 72);
  thread.frustumCulled = false;
  for (let n = 0; n < 72; n++) {
    const t = n / 71;
    const mesh = new Object3D();
    mesh.position.set(-2.4 + t * 6.0, 1.6 + Math.cos(t * Math.PI * 2) * 0.25, 1.52);
    mesh.scale.set(0.09, 0.032, 0.032);
    mesh.updateMatrix(); thread.setMatrixAt(n, mesh.matrix); threadPieces.push(mesh);
  }
  world.add(thread);

  const particleMaterial = new MeshBasicMaterial({color: 0xffd17c, transparent: true, opacity: 0.8});
  const particles = new InstancedMesh(geometry, particleMaterial, 24);
  particles.frustumCulled = false;
  const particleSeeds = [];
  for (let n = 0; n < 24; n++) {
    const mesh = new Object3D();
    mesh.position.set(-5.1 + random() * 10.6, -2 + random() * 8.7, -1.5 + random() * 5);
    mesh.scale.setScalar(0.035 + random() * 0.025);
    mesh.updateMatrix(); particles.setMatrixAt(n, mesh.matrix);
    particleSeeds.push({mesh, y: mesh.position.y, phase: random() * 6.28});
  }
  world.add(particles);
  return {thread, threadPieces, particles, particleSeeds, particleMaterial};
}

/** Owns one optional website renderer; disposal is mandatory before game boot. */
export function createDiorama(host, {motion = true, onReady = () => {}, onError = () => {}} = {}) {
  let renderer;
  try {
    renderer = new WebGLRenderer({alpha: true, antialias: false, powerPreference: 'low-power'});
  } catch (error) {
    onError(error);
    return {setMode() {}, setMotion() {}, dispose() {}};
  }
  let disposed = false, visible = true, frame = 0, ready = false;
  let mode = 'arena', modeMix = 0, lastTime = 0, elapsed = 0;
  const pointer = {x: 0, y: 0, down: false, startX: 0, yaw: 0, startYaw: 0};
  const canvas = renderer.domElement;
  canvas.className = 'diorama-canvas';
  canvas.setAttribute('aria-hidden', 'true');
  canvas.style.cssText = 'display:block;width:100%;height:100%;touch-action:pan-y;';
  host.append(canvas);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
  renderer.setClearColor(0x101a24, 0);
  renderer.outputColorSpace = SRGBColorSpace;
  const scene = new Scene();
  const world = new Group();
  scene.add(world);
  const camera = new OrthographicCamera(-7, 7, 6, -6, 0.1, 100);
  scene.add(new AmbientLight(0xa2c9c9, 1.2));
  const key = new DirectionalLight(0xffe4b0, 2.4);
  const arenaLight = new Color(0xffe4b0), storyLight = new Color(0xffd79a);
  key.position.set(-4, 10, 7); scene.add(key);
  const fill = new DirectionalLight(0x578d9e, 0.9);
  fill.position.set(7, 5, -6); scene.add(fill);
  const {thread, threadPieces, particles, particleSeeds, particleMaterial} = makeMiniature(world);
  const sprites = [];
  const textures = new Set();

  const render = () => {
    if (disposed) return;
    const story = modeMix;
    world.rotation.y = -0.15 + pointer.yaw + (motion ? pointer.x * 0.035 : 0) + story * 0.16;
    camera.position.set(11.8, 8.8 + (motion ? pointer.y * 0.4 : 0) + story * 0.7, 16.5);
    camera.lookAt(0, 2.05 + story * 0.12, 0);
    for (const sprite of sprites) sprite.quaternion.copy(camera.quaternion);
    key.color.copy(arenaLight).lerp(storyLight, story);
    fill.intensity = 0.9 + story * 0.45;
    renderer.render(scene, camera);
    if (!ready && loaded === 2) { ready = true; onReady(); }
  };
  const resize = () => {
    if (disposed) return;
    const width = Math.max(1, host.clientWidth), height = Math.max(1, host.clientHeight);
    const aspect = width / height;
    const halfHeight = Math.max(6.2, 6.7 / aspect);
    camera.left = -halfHeight * aspect; camera.right = halfHeight * aspect;
    camera.top = halfHeight; camera.bottom = -halfHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height, false);
    render();
  };

  const tick = (time) => {
    frame = 0;
    if (disposed || !motion || !visible || document.hidden) {lastTime = 0; return;}
    const delta = lastTime ? Math.min((time - lastTime) / 1000, 0.05) : 0;
    lastTime = time; elapsed += delta;
    modeMix += ((mode === 'story' ? 1 : 0) - modeMix) * Math.min(1, delta * 3.4);
    world.position.y = Math.sin(elapsed * 0.55) * 0.035;
    particleMaterial.opacity = 0.65 + Math.sin(elapsed * 1.2) * 0.15;
    for (const [index, {mesh, y, phase}] of particleSeeds.entries()) {
      mesh.position.y = y + Math.sin(elapsed * 0.5 + phase) * 0.16;
      mesh.updateMatrix(); particles.setMatrixAt(index, mesh.matrix);
    }
    particles.instanceMatrix.needsUpdate = true;
    for (let n = 0; n < threadPieces.length; n++) {
      const t = n / (threadPieces.length - 1);
      threadPieces[n].position.y = 1.6 + Math.cos(t * Math.PI * 2 + elapsed * 0.8) * 0.2;
      threadPieces[n].updateMatrix(); thread.setMatrixAt(n, threadPieces[n].matrix);
    }
    thread.instanceMatrix.needsUpdate = true;
    for (const texture of textures) {
      const cell = Math.floor(elapsed * 6) % 4;
      texture.offset.x = (cell * 68 + (texture.userData.flipped ? 66 : 2)) / 544;
    }
    render();
    frame = requestAnimationFrame(tick);
  };
  const refreshLoop = () => {
    if (frame) cancelAnimationFrame(frame);
    frame = 0; lastTime = 0;
    if (!disposed && motion && visible && !document.hidden) frame = requestAnimationFrame(tick);
  };
  const loader = new TextureLoader();
  let loaded = 0;
  const loadFighter = (url, position, scale, flip = false) => {
    loader.load(url, (texture) => {
      if (disposed) {texture.dispose(); return;}
      texture.colorSpace = SRGBColorSpace;
      texture.magFilter = NearestFilter; texture.minFilter = NearestFilter;
      texture.generateMipmaps = false;
      texture.userData.flipped = flip;
      texture.repeat.set((flip ? -1 : 1) * 64 / 544, 64 / 272);
      texture.offset.set((flip ? 66 : 2) / 544, 1 - 66 / 272);
      textures.add(texture);
      const sprite = new Mesh(new PlaneGeometry(scale, scale), new MeshBasicMaterial({map: texture, transparent: true, alphaTest: 0.2, side: DoubleSide}));
      sprite.position.set(...position); world.add(sprite); sprites.push(sprite);
      loaded++;
      resize();
    }, undefined, (error) => {
      if (!disposed) {dispose(); onError(error);}
    });
  };
  loadFighter(foxAtlas, [-2.4, 1.65, 1.45], 1.55);
  loadFighter(thistleAtlas, [3.6, 0.92, 1.45], 1.6, true);

  const move = (event) => {
    const bounds = canvas.getBoundingClientRect();
    pointer.x = (event.clientX - bounds.left) / bounds.width - 0.5;
    pointer.y = (event.clientY - bounds.top) / bounds.height - 0.5;
    if (pointer.down) pointer.yaw = Math.max(-0.3, Math.min(0.3, pointer.startYaw + (event.clientX - pointer.startX) * 0.004));
    if (!motion) render();
  };
  const down = (event) => {
    if (event.pointerType === 'touch') return;
    pointer.down = true; pointer.startX = event.clientX; pointer.startYaw = pointer.yaw;
    canvas.setPointerCapture(event.pointerId);
  };
  const up = () => {pointer.down = false;};
  const leave = () => {pointer.x = 0; pointer.y = 0;};
  const lost = (event) => {
    event.preventDefault();
    if (!disposed) {dispose(); onError(new Error('The website scene lost its graphics context.'));}
  };
  canvas.addEventListener('pointermove', move);
  canvas.addEventListener('pointerdown', down);
  canvas.addEventListener('pointerup', up);
  canvas.addEventListener('pointercancel', up);
  canvas.addEventListener('pointerleave', leave);
  canvas.addEventListener('webglcontextlost', lost);
  document.addEventListener('visibilitychange', refreshLoop);
  const resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(host);
  const intersection = new IntersectionObserver(([entry]) => {visible = entry.isIntersecting; refreshLoop();}, {threshold: 0.05});
  intersection.observe(host);
  resize(); refreshLoop();

  function dispose() {
    if (disposed) return;
    disposed = true;
    cancelAnimationFrame(frame); frame = 0;
    resizeObserver.disconnect(); intersection.disconnect();
    document.removeEventListener('visibilitychange', refreshLoop);
    canvas.removeEventListener('pointermove', move);
    canvas.removeEventListener('pointerdown', down);
    canvas.removeEventListener('pointerup', up);
    canvas.removeEventListener('pointercancel', up);
    canvas.removeEventListener('pointerleave', leave);
    canvas.removeEventListener('webglcontextlost', lost);
    const geometries = new Set(), materials = new Set();
    scene.traverse((object) => {
      if (object.geometry) geometries.add(object.geometry);
      if (object.material) for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
        materials.add(material);
        if (material.map) textures.add(material.map);
      }
    });
    for (const geometry of geometries) geometry.dispose();
    for (const material of materials) material.dispose();
    for (const texture of textures) texture.dispose();
    renderer.dispose(); renderer.forceContextLoss(); canvas.remove();
  }
  return {
    setMode(value) {mode = value === 'story' ? 'story' : 'arena'; if (!motion) {modeMix = mode === 'story' ? 1 : 0; render();}},
    setMotion(value) {motion = Boolean(value); if (!motion) {world.position.y = 0; modeMix = mode === 'story' ? 1 : 0; render();} refreshLoop();},
    dispose,
  };
}
