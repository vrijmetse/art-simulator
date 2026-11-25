import Phaser from 'phaser';
import type { ClutterKind, StainKind } from '../core/types';

function createCanvas(scene: Phaser.Scene, key: string, w: number, h: number, draw: (ctx: CanvasRenderingContext2D) => void): void {
  if (scene.textures.exists(key)) return;
  const tex = scene.textures.createCanvas(key, w, h);
  if (!tex) return;
  const ctx = tex.getContext();
  ctx.clearRect(0, 0, w, h);
  draw(ctx);
  tex.refresh();
}

export function ensureBrushTexture(scene: Phaser.Scene, key: string, radius: number): void {
  if (scene.textures.exists(key)) return;
  const d = radius * 2;
  createCanvas(scene, key, d, d, (ctx) => {
    const grad = ctx.createRadialGradient(radius, radius, radius * 0.25, radius, radius, radius);
    grad.addColorStop(0, 'rgba(255,255,255,1)');
    grad.addColorStop(0.8, 'rgba(255,255,255,0.95)');
    grad.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(radius, radius, radius, 0, Math.PI * 2);
    ctx.fill();
  });
}

export function ensureStainTexture(
  scene: Phaser.Scene,
  key: string,
  kind: StainKind,
  w: number,
  h: number,
): void {
  createCanvas(scene, key, w, h, (ctx) => {
    const colors: Record<StainKind, [string, string]> = {
      dust: ['rgba(155, 145, 135, 0.72)', 'rgba(195, 185, 175, 0.45)'],
      spill: ['rgba(111, 78, 55, 0.78)', 'rgba(156, 102, 68, 0.52)'],
      grease: ['rgba(202, 138, 4, 0.76)', 'rgba(234, 179, 8, 0.48)'],
      crayon: ['rgba(224, 122, 95, 0.75)', 'rgba(129, 178, 154, 0.6)'],
      mud: ['rgba(92, 64, 51, 0.82)', 'rgba(128, 91, 68, 0.55)'],
    };
    const [c1, c2] = colors[kind];

    // Organic overlapping blobs for cozy illustrated grime
    const blobs = [
      [0.28, 0.35, 0.26],
      [0.54, 0.46, 0.31],
      [0.72, 0.38, 0.24],
      [0.42, 0.65, 0.25],
      [0.64, 0.64, 0.22],
    ];
    blobs.forEach(([bx, by, br], idx) => {
      ctx.fillStyle = idx % 2 === 0 ? c1 : c2;
      ctx.beginPath();
      ctx.ellipse(
        w * bx,
        h * by,
        w * br,
        h * (br * 0.9),
        (idx * 0.4) % Math.PI,
        0,
        Math.PI * 2,
      );
      ctx.fill();
    });

    if (kind === 'crayon') {
      ctx.strokeStyle = '#3D405B';
      ctx.lineWidth = 4;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(w * 0.2, h * 0.35);
      ctx.quadraticCurveTo(w * 0.5, h * 0.15, w * 0.8, h * 0.55);
      ctx.quadraticCurveTo(w * 0.55, h * 0.82, w * 0.25, h * 0.65);
      ctx.stroke();
    } else if (kind === 'dust') {
      ctx.fillStyle = 'rgba(255,255,255,0.45)';
      for (let i = 0; i < 10; i++) {
        const px = ((i * 37) % 80 + 10) * 0.01 * w;
        const py = ((i * 53) % 70 + 15) * 0.01 * h;
        ctx.beginPath();
        ctx.arc(px, py, 2.5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  });
}

export function ensureSparkleTexture(scene: Phaser.Scene): void {
  createCanvas(scene, 'fx_sparkle', 24, 24, (ctx) => {
    ctx.fillStyle = '#F2CC8F';
    ctx.beginPath();
    ctx.moveTo(12, 1);
    ctx.lineTo(15, 9);
    ctx.lineTo(23, 12);
    ctx.lineTo(15, 15);
    ctx.lineTo(12, 23);
    ctx.lineTo(9, 15);
    ctx.lineTo(1, 12);
    ctx.lineTo(9, 9);
    ctx.closePath();
    ctx.fill();
  });
}

export function ensureClutterTexture(scene: Phaser.Scene, kind: ClutterKind, size = 56): void {
  const key = `clutter_${kind}`;
  createCanvas(scene, key, size, size, (ctx) => {
    const s = size;
    const c = s / 2;

    // Soft drop shadow base
    ctx.fillStyle = 'rgba(61, 64, 91, 0.16)';
    ctx.beginPath();
    ctx.ellipse(c, s - 6, s * 0.34, 5, 0, 0, Math.PI * 2);
    ctx.fill();

    switch (kind) {
      case 'book': {
        ctx.fillStyle = '#E07A5F';
        roundRect(ctx, 11, 12, s - 22, s - 20, 5);
        ctx.fill();
        ctx.fillStyle = '#FDF6EC';
        roundRect(ctx, 15, 16, s - 30, 8, 2);
        ctx.fill();
        ctx.fillStyle = '#3D405B';
        ctx.fillRect(11, 12, 6, s - 20);
        break;
      }
      case 'headphones': {
        ctx.strokeStyle = '#3D405B';
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.arc(c, c + 2, 15, Math.PI, 0);
        ctx.stroke();
        ctx.fillStyle = '#81B29A';
        roundRect(ctx, 9, c, 9, 16, 4);
        ctx.fill();
        roundRect(ctx, s - 18, c, 9, 16, 4);
        ctx.fill();
        break;
      }
      case 'slippers': {
        ctx.fillStyle = '#F2CC8F';
        ctx.beginPath();
        ctx.ellipse(c - 8, c, 8, 15, -0.15, 0, Math.PI * 2);
        ctx.ellipse(c + 9, c + 2, 8, 15, 0.15, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#E07A5F';
        ctx.fillRect(c - 15, c - 4, 14, 7);
        ctx.fillRect(c + 2, c - 2, 14, 7);
        break;
      }
      case 'remote': {
        ctx.fillStyle = '#3D405B';
        roundRect(ctx, c - 9, 8, 18, s - 18, 5);
        ctx.fill();
        ctx.fillStyle = '#E07A5F';
        ctx.beginPath();
        ctx.arc(c, 15, 3, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#F4F1DE';
        for (let r = 0; r < 3; r++) {
          ctx.fillRect(c - 5, 22 + r * 6, 4, 3);
          ctx.fillRect(c + 1, 22 + r * 6, 4, 3);
        }
        break;
      }
      case 'teacup': {
        ctx.strokeStyle = '#81B29A';
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.arc(c + 11, c + 2, 6, -Math.PI / 2, Math.PI / 2);
        ctx.stroke();
        ctx.fillStyle = '#FDF6EC';
        ctx.strokeStyle = '#3D405B';
        ctx.lineWidth = 2;
        roundRect(ctx, 13, 18, 24, 22, 6);
        ctx.fill();
        ctx.stroke();
        ctx.fillStyle = '#C97B42';
        ctx.fillRect(16, 20, 18, 5);
        break;
      }
      case 'photo': {
        ctx.fillStyle = '#8D6E63';
        roundRect(ctx, 10, 10, s - 20, s - 22, 4);
        ctx.fill();
        ctx.fillStyle = '#81B29A';
        ctx.fillRect(15, 15, s - 30, s - 32);
        ctx.fillStyle = '#F2CC8F';
        ctx.beginPath();
        ctx.arc(c - 5, 24, 4, 0, Math.PI * 2);
        ctx.arc(c + 6, 26, 4, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case 'pan': {
        ctx.fillStyle = '#3D405B';
        ctx.beginPath();
        ctx.arc(c - 4, c, 15, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#5C6B73';
        ctx.beginPath();
        ctx.arc(c - 4, c, 11, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#E07A5F';
        roundRect(ctx, c + 9, c - 3, 15, 6, 3);
        ctx.fill();
        break;
      }
      case 'spice': {
        ctx.fillStyle = '#F4F1DE';
        ctx.strokeStyle = '#8D6E63';
        ctx.lineWidth = 2;
        roundRect(ctx, 15, 16, s - 30, s - 26, 5);
        ctx.fill();
        ctx.stroke();
        ctx.fillStyle = '#E07A5F';
        roundRect(ctx, 17, 10, s - 34, 7, 2);
        ctx.fill();
        ctx.fillStyle = '#81B29A';
        ctx.fillRect(19, 25, s - 38, 10);
        break;
      }
      case 'ladle': {
        ctx.strokeStyle = '#5C6B73';
        ctx.lineWidth = 5;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(14, 12);
        ctx.lineTo(35, 36);
        ctx.stroke();
        ctx.fillStyle = '#3D405B';
        ctx.beginPath();
        ctx.arc(38, 39, 9, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case 'suitcase': {
        ctx.fillStyle = '#2A9D8F';
        roundRect(ctx, 10, 16, s - 20, s - 26, 6);
        ctx.fill();
        ctx.strokeStyle = '#264653';
        ctx.lineWidth = 3;
        ctx.strokeRect(20, 10, s - 40, 8);
        ctx.fillStyle = '#E9C46A';
        ctx.fillRect(16, 16, 4, s - 26);
        ctx.fillRect(s - 20, 16, 4, s - 26);
        break;
      }
      case 'sunglasses': {
        ctx.fillStyle = '#264653';
        roundRect(ctx, 9, 21, 16, 12, 4);
        ctx.fill();
        roundRect(ctx, s - 25, 21, 16, 12, 4);
        ctx.fill();
        ctx.fillRect(24, 24, 8, 3);
        ctx.fillStyle = '#E9C46A';
        ctx.fillRect(11, 23, 4, 2);
        ctx.fillRect(s - 23, 23, 4, 2);
        break;
      }
      case 'towel': {
        ctx.fillStyle = '#FFFFFF';
        roundRect(ctx, 10, 18, s - 20, 20, 9);
        ctx.fill();
        ctx.fillStyle = '#2A9D8F';
        ctx.fillRect(16, 18, 7, 20);
        ctx.fillRect(s - 23, 18, 7, 20);
        break;
      }
      case 'chalice': {
        ctx.fillStyle = '#CFD8DC';
        ctx.beginPath();
        ctx.moveTo(16, 12);
        ctx.lineTo(s - 16, 12);
        ctx.lineTo(c + 4, 32);
        ctx.lineTo(c - 4, 32);
        ctx.closePath();
        ctx.fill();
        ctx.fillRect(c - 3, 30, 6, 12);
        roundRect(ctx, c - 10, 41, 20, 5, 2);
        ctx.fill();
        break;
      }
      case 'scroll': {
        ctx.fillStyle = '#F2CC8F';
        roundRect(ctx, 12, 16, s - 24, 24, 5);
        ctx.fill();
        ctx.fillStyle = '#E07A5F';
        ctx.fillRect(c - 3, 16, 6, 24);
        ctx.fillStyle = '#8D6E63';
        ctx.fillRect(10, 14, 5, 28);
        ctx.fillRect(s - 15, 14, 5, 28);
        break;
      }
      case 'crown': {
        ctx.fillStyle = '#F2CC8F';
        ctx.beginPath();
        ctx.moveTo(11, 40);
        ctx.lineTo(13, 18);
        ctx.lineTo(22, 28);
        ctx.lineTo(c, 13);
        ctx.lineTo(s - 22, 28);
        ctx.lineTo(s - 13, 18);
        ctx.lineTo(s - 11, 40);
        ctx.closePath();
        ctx.fill();
        ctx.fillStyle = '#7E57C2';
        ctx.beginPath();
        ctx.arc(c, 32, 4, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case 'trophy':
      default: {
        ctx.fillStyle = '#E9C46A';
        roundRect(ctx, 16, 12, s - 32, 20, 6);
        ctx.fill();
        ctx.fillRect(c - 3, 31, 6, 9);
        ctx.fillStyle = '#5C6B73';
        roundRect(ctx, c - 10, 39, 20, 6, 2);
        ctx.fill();
        break;
      }
    }
  });
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}
