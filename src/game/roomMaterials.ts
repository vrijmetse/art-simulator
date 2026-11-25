import * as THREE from 'three';

export function createRichFloorTexture(hexColor: string, style: 'wood' | 'tile'): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 256;
  const ctx = c.getContext('2d')!;

  if (style === 'tile') {
    const n = 4;
    const s = 256 / n;
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        ctx.fillStyle = hexColor;
        ctx.fillRect(i * s, j * s, s, s);
        const shade = (i + j) % 2 === 0 ? 'rgba(255,255,255,0.12)' : 'rgba(61,64,91,0.06)';
        ctx.fillStyle = shade;
        ctx.fillRect(i * s, j * s, s, s);

        const grd = ctx.createLinearGradient(i * s, j * s, (i + 1) * s, (j + 1) * s);
        grd.addColorStop(0, 'rgba(255,255,255,0.1)');
        grd.addColorStop(1, 'rgba(0,0,0,0.05)');
        ctx.fillStyle = grd;
        ctx.fillRect(i * s + 2, j * s + 2, s - 4, s - 4);
      }
    }
    ctx.strokeStyle = 'rgba(61, 64, 91, 0.16)';
    ctx.lineWidth = 2;
    for (let k = 0; k <= n; k++) {
      ctx.beginPath();
      ctx.moveTo(k * s, 0);
      ctx.lineTo(k * s, 256);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, k * s);
      ctx.lineTo(256, k * s);
      ctx.stroke();
    }
  } else {
    ctx.fillStyle = hexColor;
    ctx.fillRect(0, 0, 256, 256);
    const plankH = 32;
    for (let row = 0; row < 8; row++) {
      const y = row * plankH;
      if (row % 2 === 1) {
        ctx.fillStyle = 'rgba(61, 45, 30, 0.05)';
        ctx.fillRect(0, y, 256, plankH);
      }
      // Subtle wood grain waves
      for (let g = 0; g < 4; g++) {
        const gy = y + 6 + g * 6;
        ctx.strokeStyle = 'rgba(95, 68, 42, 0.08)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, gy);
        for (let x = 0; x <= 256; x += 32) {
          ctx.lineTo(x, gy + Math.sin(x * 0.05 + row + g) * 1.6);
        }
        ctx.stroke();
      }
      ctx.strokeStyle = 'rgba(61, 45, 30, 0.16)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(256, y);
      ctx.stroke();
      const jointX = row % 2 === 0 ? 96 : 192;
      ctx.beginPath();
      ctx.moveTo(jointX, y);
      ctx.lineTo(jointX, y + plankH);
      ctx.stroke();
    }
  }

  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(3, 3);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export function createWallPaperTexture(hexColor: string, accentHex: string): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 256;
  const ctx = c.getContext('2d')!;
  ctx.fillStyle = hexColor;
  ctx.fillRect(0, 0, 256, 256);

  // Soft vertical wallpaper stripes
  ctx.fillStyle = 'rgba(255, 255, 255, 0.18)';
  for (let x = 0; x < 256; x += 32) {
    ctx.fillRect(x, 0, 12, 256);
  }
  // Subtle wainscoting panel lower third
  ctx.fillStyle = 'rgba(61, 64, 91, 0.06)';
  ctx.fillRect(0, 176, 256, 80);
  ctx.fillStyle = accentHex;
  ctx.globalAlpha = 0.28;
  ctx.fillRect(0, 172, 256, 5);
  ctx.globalAlpha = 1;

  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export function createWindowSkyTexture(): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 128;
  c.height = 128;
  const ctx = c.getContext('2d')!;
  const grd = ctx.createLinearGradient(0, 0, 0, 128);
  grd.addColorStop(0, '#9ECAE1');
  grd.addColorStop(0.55, '#FDE2B8');
  grd.addColorStop(1, '#FFF3D6');
  ctx.fillStyle = grd;
  ctx.fillRect(0, 0, 128, 128);

  ctx.fillStyle = 'rgba(255, 255, 255, 0.72)';
  ctx.beginPath();
  ctx.arc(38, 42, 14, 0, Math.PI * 2);
  ctx.arc(54, 40, 18, 0, Math.PI * 2);
  ctx.arc(70, 44, 12, 0, Math.PI * 2);
  ctx.fill();

  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export function createWallArtTexture(accentHex: string): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 128;
  c.height = 128;
  const ctx = c.getContext('2d')!;
  ctx.fillStyle = '#FDF6EC';
  ctx.fillRect(0, 0, 128, 128);
  ctx.fillStyle = accentHex;
  ctx.beginPath();
  ctx.arc(64, 54, 28, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#81B29A';
  ctx.beginPath();
  ctx.moveTo(16, 112);
  ctx.lineTo(54, 68);
  ctx.lineTo(94, 112);
  ctx.closePath();
  ctx.fill();
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export function createContactShadowTexture(): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 64;
  c.height = 64;
  const ctx = c.getContext('2d')!;
  const grd = ctx.createRadialGradient(32, 32, 3, 32, 32, 32);
  grd.addColorStop(0, 'rgba(30, 24, 18, 0.44)');
  grd.addColorStop(0.55, 'rgba(30, 24, 18, 0.18)');
  grd.addColorStop(1, 'rgba(30, 24, 18, 0)');
  ctx.fillStyle = grd;
  ctx.fillRect(0, 0, 64, 64);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export function createTerracottaRoofTexture(baseHex = '#B85D3B'): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 256;
  const ctx = c.getContext('2d')!;
  ctx.fillStyle = baseHex;
  ctx.fillRect(0, 0, 256, 256);

  for (let row = 0; row < 8; row++) {
    const y = row * 32;
    ctx.fillStyle = row % 2 === 0 ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.05)';
    ctx.fillRect(0, y, 256, 30);
    ctx.fillStyle = 'rgba(45, 20, 10, 0.22)';
    ctx.fillRect(0, y + 29, 256, 3);
    for (let col = 0; col < 8; col++) {
      const x = col * 32 + (row % 2 === 0 ? 0 : 16);
      ctx.fillStyle = 'rgba(45, 20, 10, 0.16)';
      ctx.fillRect(x % 256, y, 2, 32);
    }
  }

  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(2, 2);
  return tex;
}
