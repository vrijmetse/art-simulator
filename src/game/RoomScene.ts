import Phaser from 'phaser';
import type { ClutterItemSpec, JobSpec, StainSpotSpec } from '../core/types';
import { getJobById, JOBS } from '../core/jobs';
import { applyJobResult, getToolStats } from '../core/economy';
import { CoverageGrid } from '../core/coverage';
import { formatMoney, pickText, t } from '../core/i18n';
import { asmrSynth } from '../audio/asmrSynth';
import {
  ensureBrushTexture,
  ensureClutterTexture,
  ensureSparkleTexture,
  ensureStainTexture,
} from './textures';
import { getState, updateState } from './stateStore';

interface StainTracker {
  spec: StainSpotSpec;
  grid: CoverageGrid;
  rt: Phaser.GameObjects.RenderTexture;
  done: boolean;
}

interface ClutterTracker {
  spec: ClutterItemSpec;
  sprite: Phaser.GameObjects.Image;
  targetRing: Phaser.GameObjects.Rectangle;
  done: boolean;
}

export class RoomScene extends Phaser.Scene {
  private job!: JobSpec;
  private stains: StainTracker[] = [];
  private clutter: ClutterTracker[] = [];
  private activePointerId: number | null = null;
  private draggedClutter: ClutterTracker | null = null;
  private lastPointerPos: { x: number; y: number } | null = null;
  private startMs = 0;
  private finished = false;
  private brushKey = 'brush_24';
  private brushRadius = 24;
  private snapRadius = 42;

  private progressText!: Phaser.GameObjects.Text;
  private timerText!: Phaser.GameObjects.Text;
  private toastText!: Phaser.GameObjects.Text;
  private sparkles!: Phaser.GameObjects.Particles.ParticleEmitter;

  constructor() {
    super('RoomScene');
  }

  init(data: { jobId?: string }): void {
    this.job = getJobById(data.jobId || '') ?? JOBS[0];
    this.stains = [];
    this.clutter = [];
    this.activePointerId = null;
    this.draggedClutter = null;
    this.lastPointerPos = null;
    this.finished = false;
  }

  create(): void {
    const state = getState();
    const loc = state.locale;
    const stats = getToolStats(state.upgrades);
    this.brushRadius = Math.round(stats.brushRadius * stats.scrubPower);
    this.snapRadius = stats.snapRadius;
    this.brushKey = `brush_${this.brushRadius}`;
    ensureBrushTexture(this, this.brushKey, this.brushRadius);
    ensureSparkleTexture(this);

    // Draw cozy room background
    this.drawRoomBackdrop();

    // Top HUD
    this.add.rectangle(225, 50, 450, 100, 0x3d405b).setDepth(10);
    const backRect = this.add
      .rectangle(46, 36, 72, 32, 0xf2cc8f)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(46, 36, `← ${t(loc, 'backBtn')}`, {
        fontSize: '12px',
        fontStyle: 'bold',
        color: '#3D405B',
      })
      .setOrigin(0.5)
      .setDepth(12);
    backRect.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.scene.start('MenuScene');
    });

    this.add
      .text(225, 28, pickText(this.job.title, loc), {
        fontSize: '16px',
        fontStyle: 'bold',
        color: '#FDF6EC',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.progressText = this.add
      .text(120, 70, `${t(loc, 'tidyProgress')}: 0%`, {
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#81B29A',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.timerText = this.add
      .text(335, 70, `0s / ${this.job.parTimeSec}s`, {
        fontSize: '13px',
        color: '#F2CC8F',
      })
      .setOrigin(0.5)
      .setDepth(12);

    // Mute button top right
    const muteRect = this.add
      .rectangle(410, 36, 52, 32, state.muted ? 0x9ca3af : 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    const muteLabel = this.add
      .text(410, 36, state.muted ? '🔇' : '🔊', { fontSize: '14px' })
      .setOrigin(0.5)
      .setDepth(12);
    muteRect.on('pointerdown', () => {
      asmrSynth.unlock();
      const next = !getState().muted;
      asmrSynth.setMuted(next);
      updateState({ ...getState(), muted: next });
      muteRect.setFillStyle(next ? 0x9ca3af : 0x81b29a);
      muteLabel.setText(next ? '🔇' : '🔊');
    });

    // Bottom hint bar + optional radar button
    this.add.rectangle(225, 735, 450, 130, 0x3d405b).setDepth(10);
    this.toastText = this.add
      .text(225, 702, t(loc, 'scrubHint'), {
        fontSize: '12px',
        color: '#FDF6EC',
        align: 'center',
        wordWrap: { width: 400 },
      })
      .setOrigin(0.5)
      .setDepth(12);

    if (stats.hasRadar) {
      const radarRect = this.add
        .rectangle(225, 756, 180, 36, 0xf2cc8f)
        .setDepth(11)
        .setInteractive({ useHandCursor: true });
      this.add
        .text(225, 756, `✨ ${t(loc, 'radarBtn')}`, {
          fontSize: '13px',
          fontStyle: 'bold',
          color: '#3D405B',
        })
        .setOrigin(0.5)
        .setDepth(12);
      radarRect.on('pointerdown', () => {
        asmrSynth.unlock();
        asmrSynth.playPop();
        this.pulseRemainingTargets();
      });
    }

    // Create stains (RenderTexture aligned top-left with CoverageGrid local coordinates)
    for (const spot of this.job.stains) {
      const texKey = `stain_${spot.kind}_${spot.id}`;
      ensureStainTexture(this, texKey, spot.kind, spot.width, spot.height);

      // Subtle clean surface glow underneath
      this.add
        .rectangle(spot.x + spot.width / 2, spot.y + spot.height / 2, spot.width, spot.height, 0xffffff, 0.25)
        .setStrokeStyle(1, 0xffffff, 0.4)
        .setDepth(1);

      const rt = this.add
        .renderTexture(spot.x, spot.y, spot.width, spot.height)
        .setOrigin(0, 0)
        .setDepth(3);
      rt.draw(texKey, 0, 0);

      const cols = Math.max(8, Math.round(spot.width / 10));
      const grid = new CoverageGrid(spot.width, spot.height, cols, 0.85);
      this.stains.push({ spec: spot, grid, rt, done: false });
    }

    // Create clutter items & glowing target outlines
    for (const item of this.job.clutter) {
      ensureClutterTexture(this, item.kind, 56);

      const ring = this.add
        .rectangle(item.targetX, item.targetY, item.size, item.size, 0x81b29a, 0.14)
        .setStrokeStyle(2, 0x2a9d8f, 0.65)
        .setDepth(2);

      const sprite = this.add
        .image(item.startX, item.startY, `clutter_${item.kind}`)
        .setDisplaySize(item.size, item.size)
        .setDepth(5)
        .setInteractive({ useHandCursor: true });

      const tracker: ClutterTracker = { spec: item, sprite, targetRing: ring, done: false };
      this.clutter.push(tracker);

      sprite.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
        asmrSynth.unlock();
        if (this.finished || tracker.done) return;
        if (this.activePointerId !== null && this.activePointerId !== pointer.id) return;
        this.activePointerId = pointer.id;
        this.draggedClutter = tracker;
        sprite.setDepth(8).setScale(1.12);
        ring.setFillStyle(0xf2cc8f, 0.35);
      });
    }

    // Particle sparkles
    this.sparkles = this.add.particles(0, 0, 'fx_sparkle', {
      speed: { min: 40, max: 110 },
      scale: { start: 0.9, end: 0 },
      lifespan: 450,
      emitting: false,
    });
    this.sparkles.setDepth(9);

    // Unified pointer handling with activePointerId lock & stuck-drag cleanup
    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      asmrSynth.unlock();
      if (this.finished) return;
      if (this.activePointerId === null) {
        this.activePointerId = pointer.id;
        this.lastPointerPos = { x: pointer.x, y: pointer.y };
        if (!this.draggedClutter) {
          this.handleScrub(pointer.x, pointer.y, pointer.x, pointer.y);
        }
      }
    });

    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      if (this.finished || !pointer.isDown) return;
      if (this.activePointerId !== pointer.id) return;

      if (this.draggedClutter) {
        const clampedX = Phaser.Math.Clamp(pointer.x, 28, 422);
        const clampedY = Phaser.Math.Clamp(pointer.y, 118, 650);
        this.draggedClutter.sprite.setPosition(clampedX, clampedY);
        return;
      }

      const prev = this.lastPointerPos ?? { x: pointer.x, y: pointer.y };
      this.handleScrub(prev.x, prev.y, pointer.x, pointer.y);
      this.lastPointerPos = { x: pointer.x, y: pointer.y };
    });

    const releasePointer = (pointer?: Phaser.Input.Pointer) => {
      if (pointer && this.activePointerId !== null && pointer.id !== this.activePointerId) return;
      this.finishActiveDrag();
      this.activePointerId = null;
      this.lastPointerPos = null;
    };

    this.input.on('pointerup', releasePointer);
    this.input.on('pointerupoutside', releasePointer);
    const onBlur = () => releasePointer();
    this.game.events.on('blur', onBlur);
    this.events.once('shutdown', () => {
      this.game.events.off('blur', onBlur);
    });

    this.startMs = Date.now();
    this.updateProgressUI();
  }

  update(): void {
    if (this.finished) return;
    const elapsed = Math.max(0, Math.floor((Date.now() - this.startMs) / 1000));
    this.timerText.setText(`${elapsed}s / ${this.job.parTimeSec}s`);
  }

  private drawRoomBackdrop(): void {
    const wall = Phaser.Display.Color.HexStringToColor(this.job.palette.wall).color;
    const floor = Phaser.Display.Color.HexStringToColor(this.job.palette.floor).color;
    const trim = Phaser.Display.Color.HexStringToColor(this.job.palette.trim).color;

    // Wall (top) & floor (bottom)
    this.add.rectangle(225, 225, 450, 260, wall).setDepth(0);
    this.add.rectangle(225, 510, 450, 320, floor).setDepth(0);
    this.add.rectangle(225, 355, 450, 10, trim, 0.35).setDepth(0);

    // Decorative cozy shelves/window cues
    this.add.rectangle(270, 175, 230, 88, 0xffffff, 0.35).setStrokeStyle(3, trim, 0.35).setDepth(0);
    this.add.rectangle(225, 445, 360, 140, trim, 0.08).setStrokeStyle(2, trim, 0.16).setDepth(0);
  }

  private handleScrub(prevX: number, prevY: number, currX: number, currY: number): void {
    // Never scrub while dragging a clutter item
    if (this.draggedClutter !== null) return;

    let scrubbedAny = false;
    const radius = this.brushRadius;

    for (const st of this.stains) {
      if (st.done) continue;
      const { x, y, width, height } = st.spec;
      const segMinX = Math.min(prevX, currX);
      const segMaxX = Math.max(prevX, currX);
      const segMinY = Math.min(prevY, currY);
      const segMaxY = Math.max(prevY, currY);
      const overlapsSegmentAabb =
        segMaxX >= x - radius &&
        segMinX <= x + width + radius &&
        segMaxY >= y - radius &&
        segMinY <= y + height + radius;

      if (!overlapsSegmentAabb) continue;

      const lx1 = prevX - x;
      const ly1 = prevY - y;
      const lx2 = currX - x;
      const ly2 = currY - y;

      const dist = Math.hypot(lx2 - lx1, ly2 - ly1);
      const step = Math.max(4, radius * 0.4);
      const steps = Math.max(1, Math.ceil(dist / step));

      for (let i = 0; i <= steps; i++) {
        const frac = i / steps;
        const ix = lx1 + (lx2 - lx1) * frac;
        const iy = ly1 + (ly2 - ly1) * frac;
        st.rt.erase(this.brushKey, ix - radius, iy - radius);
        st.grid.scrubCircle(ix, iy, radius);
      }

      scrubbedAny = true;

      if (st.grid.isComplete) {
        st.done = true;
        st.grid.markComplete();
        asmrSynth.playPop();
        this.sparkles.emitParticleAt(x + width / 2, y + height / 2, 12);
        this.tweens.add({
          targets: st.rt,
          alpha: 0,
          duration: 180,
          onComplete: () => st.rt.setVisible(false),
        });
      }
    }

    if (scrubbedAny) {
      asmrSynth.playScrub();
      this.updateProgressUI();
      this.checkWin();
    }
  }

  private finishActiveDrag(): void {
    const tracker = this.draggedClutter;
    if (!tracker) return;
    this.draggedClutter = null;

    tracker.sprite.setDepth(5).setScale(1);
    tracker.targetRing.setFillStyle(0x81b29a, 0.14);

    const dist = Phaser.Math.Distance.Between(
      tracker.sprite.x,
      tracker.sprite.y,
      tracker.spec.targetX,
      tracker.spec.targetY,
    );

    if (dist <= this.snapRadius) {
      tracker.done = true;
      tracker.sprite.disableInteractive();
      tracker.targetRing.setVisible(false);
      this.tweens.add({
        targets: tracker.sprite,
        x: tracker.spec.targetX,
        y: tracker.spec.targetY,
        duration: 140,
        ease: 'Back.easeOut',
      });
      asmrSynth.playSnap();
      this.sparkles.emitParticleAt(tracker.spec.targetX, tracker.spec.targetY, 10);
      this.toastText.setText(pickText(tracker.spec.note, getState().locale));
      this.updateProgressUI();
      this.checkWin();
    } else {
      this.tweens.add({
        targets: tracker.sprite,
        x: tracker.spec.startX,
        y: tracker.spec.startY,
        duration: 180,
        ease: 'Quad.easeOut',
      });
    }
  }

  private pulseRemainingTargets(): void {
    for (const st of this.stains) {
      if (!st.done) {
        this.sparkles.emitParticleAt(
          st.spec.x + st.spec.width / 2,
          st.spec.y + st.spec.height / 2,
          6,
        );
      }
    }
    for (const cl of this.clutter) {
      if (!cl.done) {
        this.tweens.add({
          targets: cl.targetRing,
          scale: 1.2,
          duration: 220,
          yoyo: true,
        });
      }
    }
  }

  private updateProgressUI(): void {
    const totalTasks = this.stains.length + this.clutter.length;
    const stainProgress = this.stains.reduce((sum, s) => sum + (s.done ? 1 : s.grid.ratio), 0);
    const clutterDone = this.clutter.filter((c) => c.done).length;
    const pct = Math.min(100, Math.round(((stainProgress + clutterDone) / totalTasks) * 100));
    this.progressText.setText(`${t(getState().locale, 'tidyProgress')}: ${pct}%`);
  }

  private checkWin(): void {
    if (this.finished) return;
    if (this.stains.every((s) => s.done) && this.clutter.every((c) => c.done)) {
      this.finished = true;
      const elapsedSec = Math.max(1, Math.round((Date.now() - this.startMs) / 1000));
      const res = applyJobResult(getState(), { jobId: this.job.id, elapsedSec });
      updateState(res.state);
      asmrSynth.playCash();
      this.showCompletionModal(res.entry);
    }
  }

  private showCompletionModal(entry: {
    stars: 1 | 2 | 3;
    baseWageRp: number;
    speedBonusRp: number;
    tipRp: number;
    totalRp: number;
  }): void {
    const loc = getState().locale;
    this.add.rectangle(225, 400, 450, 800, 0x000000, 0.55).setDepth(20);
    this.add.rectangle(225, 400, 396, 470, 0xfdf6ec).setStrokeStyle(3, 0x81b29a).setDepth(21);

    this.add
      .text(225, 200, t(loc, 'completeTitle'), {
        fontSize: '24px',
        fontStyle: 'bold',
        color: '#3D405B',
      })
      .setOrigin(0.5)
      .setDepth(22);

    this.add
      .text(225, 238, '★'.repeat(entry.stars) + '☆'.repeat(3 - entry.stars), {
        fontSize: '28px',
        color: '#E07A5F',
      })
      .setOrigin(0.5)
      .setDepth(22);

    // Homeowner story note card
    this.add.rectangle(225, 318, 352, 108, 0xffffff).setStrokeStyle(1, 0xe5d9c8).setDepth(22);
    this.add
      .text(225, 276, `💌 ${t(loc, 'storyHeader')}`, {
        fontSize: '12px',
        fontStyle: 'bold',
        color: '#81B29A',
      })
      .setOrigin(0.5)
      .setDepth(23);
    this.add
      .text(225, 326, pickText(this.job.storyNote, loc), {
        fontSize: '12px',
        color: '#3D405B',
        align: 'center',
        wordWrap: { width: 325 },
      })
      .setOrigin(0.5)
      .setDepth(23);

    // Itemized payout
    const lines = [
      `${t(loc, 'baseWage')}: ${formatMoney(entry.baseWageRp, loc)}`,
      `${t(loc, 'speedBonus')}: ${formatMoney(entry.speedBonusRp, loc)}`,
      `${t(loc, 'tipBonus')}: ${formatMoney(entry.tipRp, loc)}`,
    ];
    this.add
      .text(225, 424, lines.join('\n'), {
        fontSize: '13px',
        color: '#5C6B73',
        align: 'center',
        lineSpacing: 6,
      })
      .setOrigin(0.5)
      .setDepth(22);

    this.add
      .text(225, 482, `${t(loc, 'totalEarned')}: +${formatMoney(entry.totalRp, loc)}`, {
        fontSize: '16px',
        fontStyle: 'bold',
        color: '#2A9D8F',
      })
      .setOrigin(0.5)
      .setDepth(22);

    const nextJob = JOBS.find((j) => j.level === this.job.level + 1);
    if (nextJob) {
      const nextBtn = this.add
        .rectangle(225, 540, 240, 42, 0x81b29a)
        .setDepth(22)
        .setInteractive({ useHandCursor: true });
      this.add
        .text(225, 540, t(loc, 'nextHouse'), {
          fontSize: '14px',
          fontStyle: 'bold',
          color: '#FFFFFF',
        })
        .setOrigin(0.5)
        .setDepth(23);
      nextBtn.on('pointerdown', () => {
        asmrSynth.playSnap();
        this.scene.start('RoomScene', { jobId: nextJob.id });
      });
    }

    const mapBtn = this.add
      .rectangle(225, nextJob ? 595 : 550, 240, 38, 0xe07a5f)
      .setDepth(22)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(225, nextJob ? 595 : 550, t(loc, 'backToMap'), {
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#FFFFFF',
      })
      .setOrigin(0.5)
      .setDepth(23);
    mapBtn.on('pointerdown', () => {
      asmrSynth.playPop();
      this.scene.start('MenuScene');
    });
  }
}
