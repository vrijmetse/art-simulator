import Phaser from 'phaser';
import type { ClutterItemSpec, JobSpec } from '../core/types';
import { getJobById, JOBS } from '../core/jobs';
import { applyJobResult, getToolStats } from '../core/economy';
import { formatMoney, pickText, t } from '../core/i18n';
import { asmrSynth } from '../audio/asmrSynth';
import { getState, updateState } from './stateStore';
import { Room3DView } from './Room3DView';

function getClientCoords(
  pointer: Phaser.Input.Pointer,
  canvas: HTMLCanvasElement,
): { x: number; y: number } {
  const ev = pointer.event as MouseEvent | TouchEvent | undefined;
  if (ev && 'clientX' in ev && typeof ev.clientX === 'number') {
    return { x: ev.clientX, y: ev.clientY };
  }
  if (ev && 'changedTouches' in ev && ev.changedTouches && ev.changedTouches.length > 0) {
    const touch = ev.changedTouches[0];
    return { x: touch.clientX, y: touch.clientY };
  }
  const rect = canvas.getBoundingClientRect();
  return {
    x: rect.left + (pointer.x / 450) * rect.width,
    y: rect.top + (pointer.y / 800) * rect.height,
  };
}

export class RoomScene extends Phaser.Scene {
  private job!: JobSpec;
  private view3d: Room3DView | null = null;
  private activePointerId: number | null = null;
  private startMs = 0;
  private finished = false;

  private progressText!: Phaser.GameObjects.Text;
  private timerText!: Phaser.GameObjects.Text;
  private toastText!: Phaser.GameObjects.Text;

  constructor() {
    super('RoomScene');
  }

  init(data: { jobId?: string }): void {
    this.job = getJobById(data.jobId || '') ?? JOBS[0];
    this.activePointerId = null;
    this.finished = false;
    this.view3d = null;
  }

  create(): void {
    const state = getState();
    const loc = state.locale;
    const stats = getToolStats(state.upgrades);
    const canvas = this.sys.game.canvas;

    // Mount Three.js 3D Room behind transparent Phaser UI layer
    this.view3d = new Room3DView(
      canvas,
      this.job,
      stats.brushRadius3D,
      stats.snapRadius3D,
      {
        onProgress: (pct) => {
          this.progressText?.setText(`${t(getState().locale, 'tidyProgress')}: ${pct}%`);
        },
        onStainCleared: () => {
          asmrSynth.playPop();
        },
        onScrubStroke: () => {
          asmrSynth.playScrub();
        },
        onClutterSnapped: (item: ClutterItemSpec) => {
          asmrSynth.playSnap();
          this.toastText?.setText(pickText(item.note, getState().locale));
        },
        onComplete: () => {
          this.handleWin();
        },
      },
    );

    // Top HUD
    this.add.rectangle(225, 48, 450, 96, 0x3d405b, 0.94).setDepth(10);

    const backRect = this.add
      .rectangle(46, 34, 72, 32, 0xf2cc8f)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(46, 34, `← ${t(loc, 'backBtn')}`, {
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
      .text(225, 26, pickText(this.job.title, loc), {
        fontSize: '16px',
        fontStyle: 'bold',
        color: '#FDF6EC',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.progressText = this.add
      .text(120, 68, `${t(loc, 'tidyProgress')}: 0%`, {
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#81B29A',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.timerText = this.add
      .text(335, 68, `0s / ${this.job.parTimeSec}s`, {
        fontSize: '13px',
        color: '#F2CC8F',
      })
      .setOrigin(0.5)
      .setDepth(12);

    // Mute button top right
    const muteRect = this.add
      .rectangle(410, 34, 52, 32, state.muted ? 0x9ca3af : 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    const muteLabel = this.add
      .text(410, 34, state.muted ? '🔇' : '🔊', { fontSize: '14px' })
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

    // Bottom HUD bar with 3D orbit controls + hint + optional Dust Radar
    this.add.rectangle(225, 738, 450, 124, 0x3d405b, 0.94).setDepth(10);
    this.toastText = this.add
      .text(225, 702, t(loc, 'scrubHint'), {
        fontSize: '12px',
        color: '#FDF6EC',
        align: 'center',
        wordWrap: { width: 410 },
      })
      .setOrigin(0.5)
      .setDepth(12);

    const rotLeft = this.add
      .rectangle(68, 756, 98, 34, 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(68, 756, `↺ ${t(loc, 'rotateBtn')}`, {
        fontSize: '11px',
        fontStyle: 'bold',
        color: '#FFFFFF',
      })
      .setOrigin(0.5)
      .setDepth(12);
    rotLeft.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.view3d?.rotateStep(-0.28);
    });

    const rotRight = this.add
      .rectangle(382, 756, 98, 34, 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(382, 756, `${t(loc, 'rotateBtn')} ↻`, {
        fontSize: '11px',
        fontStyle: 'bold',
        color: '#FFFFFF',
      })
      .setOrigin(0.5)
      .setDepth(12);
    rotRight.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.view3d?.rotateStep(0.28);
    });

    if (stats.hasRadar) {
      const radarRect = this.add
        .rectangle(225, 756, 174, 34, 0xf2cc8f)
        .setDepth(11)
        .setInteractive({ useHandCursor: true });
      this.add
        .text(225, 756, `✨ ${t(loc, 'radarBtn')}`, {
          fontSize: '12px',
          fontStyle: 'bold',
          color: '#3D405B',
        })
        .setOrigin(0.5)
        .setDepth(12);
      radarRect.on('pointerdown', () => {
        asmrSynth.unlock();
        asmrSynth.playPop();
        this.view3d?.pulseRemaining();
      });
    }

    // Forward 3D playfield pointer interaction
    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      asmrSynth.unlock();
      if (this.finished) return;
      if (pointer.y < 96 || pointer.y > 676) return;
      if (this.activePointerId !== null) return;
      this.activePointerId = pointer.id;
      const pt = getClientCoords(pointer, canvas);
      this.view3d?.onPointerDown(pt.x, pt.y);
    });

    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      if (this.finished || !pointer.isDown) return;
      if (this.activePointerId !== pointer.id) return;
      const pt = getClientCoords(pointer, canvas);
      this.view3d?.onPointerMove(pt.x, pt.y);
    });

    const releasePointer = (pointer?: Phaser.Input.Pointer) => {
      if (pointer && this.activePointerId !== null && pointer.id !== this.activePointerId) return;
      this.activePointerId = null;
      this.view3d?.onPointerUp();
    };

    this.input.on('pointerup', releasePointer);
    this.input.on('pointerupoutside', releasePointer);

    const onBlur = () => releasePointer();
    const onResize = () => this.view3d?.syncCanvasBounds();
    this.game.events.on('blur', onBlur);
    this.scale.on('resize', onResize);

    this.events.once('shutdown', () => {
      this.game.events.off('blur', onBlur);
      this.scale.off('resize', onResize);
      this.view3d?.destroy();
      this.view3d = null;
    });

    this.startMs = Date.now();
  }

  update(): void {
    if (this.finished) return;
    const elapsed = Math.max(0, Math.floor((Date.now() - this.startMs) / 1000));
    this.timerText.setText(`${elapsed}s / ${this.job.parTimeSec}s`);
  }

  private handleWin(): void {
    if (this.finished) return;
    this.finished = true;
    const elapsedSec = Math.max(1, Math.round((Date.now() - this.startMs) / 1000));
    const res = applyJobResult(getState(), { jobId: this.job.id, elapsedSec });
    updateState(res.state);
    asmrSynth.playCash();
    this.showCompletionModal(res.entry);
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
