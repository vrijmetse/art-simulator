import type { NeighborSpec } from '../core/neighborhood';

export function renderNeighborPortraitCanvas(spec: NeighborSpec): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = 136;
  c.height = 136;
  const ctx = c.getContext('2d')!;
  const p = spec.portrait;

  // Rounded backdrop
  ctx.fillStyle = p.bg;
  ctx.beginPath();
  ctx.roundRect(4, 4, 128, 128, 22);
  ctx.fill();

  ctx.strokeStyle = '#F2CC8F';
  ctx.lineWidth = 4;
  ctx.stroke();

  if (spec.kind === 'pet') {
    // Pet ears
    ctx.fillStyle = p.hair;
    if (spec.id === 'mochi_cat') {
      ctx.beginPath();
      ctx.moveTo(36, 56);
      ctx.lineTo(44, 24);
      ctx.lineTo(62, 46);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(100, 56);
      ctx.lineTo(92, 24);
      ctx.lineTo(74, 46);
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.ellipse(34, 62, 12, 22, 0.25, 0, Math.PI * 2);
      ctx.ellipse(102, 62, 12, 22, -0.25, 0, Math.PI * 2);
      ctx.fill();
    }

    // Pet head & collar
    ctx.fillStyle = p.accent;
    ctx.beginPath();
    ctx.roundRect(38, 98, 60, 22, 10);
    ctx.fill();

    ctx.fillStyle = p.skin;
    ctx.beginPath();
    ctx.arc(68, 68, 34, 0, Math.PI * 2);
    ctx.fill();

    // Eyes & snout
    ctx.fillStyle = '#1E293B';
    ctx.beginPath();
    ctx.arc(54, 62, 4.5, 0, Math.PI * 2);
    ctx.arc(82, 62, 4.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#FFF7ED';
    ctx.beginPath();
    ctx.ellipse(68, 76, 13, 9, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#2B2D42';
    ctx.beginPath();
    ctx.arc(68, 73, 4.5, 0, Math.PI * 2);
    ctx.fill();
    return c;
  }

  // Shoulders / outfit
  ctx.fillStyle = p.accent;
  ctx.beginPath();
  ctx.ellipse(68, 126, 42, 28, 0, Math.PI, 0);
  ctx.fill();

  // Neck
  ctx.fillStyle = p.skin;
  ctx.fillRect(58, 86, 20, 18);

  // Back hair
  ctx.fillStyle = p.hair;
  ctx.beginPath();
  ctx.arc(68, 56, 33, 0, Math.PI * 2);
  ctx.fill();

  // Head
  ctx.fillStyle = p.skin;
  ctx.beginPath();
  ctx.arc(68, 60, 27, 0, Math.PI * 2);
  ctx.fill();

  // Hair bang / hijab accent
  ctx.fillStyle = p.hair;
  ctx.beginPath();
  ctx.arc(68, 49, 28, Math.PI * 1.05, Math.PI * 1.95);
  ctx.fill();

  // Soft cheeks
  ctx.fillStyle = 'rgba(224, 122, 95, 0.35)';
  ctx.beginPath();
  ctx.arc(49, 66, 5, 0, Math.PI * 2);
  ctx.arc(87, 66, 5, 0, Math.PI * 2);
  ctx.fill();

  // Friendly eyes & warm smile
  ctx.fillStyle = '#1E293B';
  ctx.beginPath();
  ctx.arc(57, 60, 3.6, 0, Math.PI * 2);
  ctx.arc(79, 60, 3.6, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#6D3B2E';
  ctx.lineWidth = 2.6;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.arc(68, 67, 8, 0.2, Math.PI - 0.2);
  ctx.stroke();

  return c;
}
