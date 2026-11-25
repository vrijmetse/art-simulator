import Phaser from 'phaser';
import type { ClutterItemSpec, JobSpec, ToolMode } from '../core/types';
import { getJobById, JOBS } from '../core/jobs';
import { generateDailyJob } from '../core/daily';
import { applyJobResult, getToolStats } from '../core/economy';
import { getCareerRank } from '../core/career';
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
  private sceneShutdown = false;
  private toolMode: ToolMode = 'lap';

  private progressText!: Phaser.GameObjects.Text;
  private timerText!: Phaser.GameObjects.Text;
  private toastText!: Phaser.GameObjects.Text;

  constructor() {
    super('RoomScene');
  }

  init(data: { jobId?: string; dailyDateKey?: string }): void {
    if (data.dailyDateKey) {
      this.job = generateDailyJob(data.dailyDateKey, getState().unlockedLevel);
    } else {
      this.job = getJobById(data.jobId || '') ?? JOBS[0];
    }
    this.activePointerId = null;
    this.finished = false;
    this.sceneShutdown = false;
    this.view3d = null;
    this.toolMode = 'lap';
  }

  create(): void {
    const state = getState();
    const loc = state.locale;
    const stats = getToolStats(state.upgrades);
    const canvas = this.sys.game.canvas;

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
        onClutterSelected: (item: ClutterItemSpec) => {
          asmrSynth.playPop();
          this.toastText?.setText(`${pickText(item.label, getState().locale)} → ${t(getState().locale, 'toolDrag')}`);
        },
        onToolFeedback: (kind, expectedTool) => {
          const curLoc = getState().locale;
          if (kind === 'match') {
            this.toastText?.setText(t(curLoc, 'matchBonusToast'));
          } else {
            this.toastText?.setText(
              t(curLoc, expectedTool === 'pel' ? 'mismatchHintPel' : 'mismatchHintLap'),
            );
          }
        },
        onComplete: () => {
          this.handleWin();
        },
      },
      false,
      state.avatarId,
    );

    // Sleek Compact Top HUD (72px)
    this.add.rectangle(225, 36, 450, 72, 0x3d405b, 0.92).setDepth(10);

    const backRect = this.add
      .rectangle(42, 36, 66, 36, 0xf2cc8f)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(42, 36, '←', { fontSize: '18px', fontStyle: 'bold', color: '#3D405B' })
      .setOrigin(0.5)
      .setDepth(12);
    backRect.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.scene.start('MenuScene');
    });

    this.add
      .text(225, 22, pickText(this.job.title, loc), {
        fontSize: '14px',
        fontStyle: 'bold',
        color: '#FDF6EC',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.progressText = this.add
      .text(148, 50, `${t(loc, 'tidyProgress')}: 0%`, {
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#81B29A',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.timerText = this.add
      .text(308, 50, `0s / ${this.job.parTimeSec}s`, {
        fontSize: '12px',
        color: '#F2CC8F',
      })
      .setOrigin(0.5)
      .setDepth(12);

    const muteRect = this.add
      .rectangle(412, 36, 50, 36, state.muted ? 0x9ca3af : 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    const muteLabel = this.add
      .text(412, 36, state.muted ? '🔇' : '🔊', { fontSize: '15px' })
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

    // Sleek Compact Bottom HUD (92px)
    this.add.rectangle(225, 754, 450, 92, 0x3d405b, 0.92).setDepth(10);
    this.toastText = this.add
      .text(225, 722, t(loc, 'scrubHint'), {
        fontSize: '11px',
        color: '#FDF6EC',
        align: 'center',
        wordWrap: { width: 420 },
      })
      .setOrigin(0.5)
      .setDepth(12);

    const rotLeft = this.add
      .rectangle(42, 766, 56, 36, 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(42, 766, '↺', { fontSize: '18px', fontStyle: 'bold', color: '#FFFFFF' })
      .setOrigin(0.5)
      .setDepth(12);
    rotLeft.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.view3d?.rotateStep(-0.28);
    });

    const lapBtn = this.add
      .rectangle(136, 766, 76, 36, 0xe07a5f)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(136, 766, t(loc, 'toolLap'), { fontSize: '12px', fontStyle: 'bold', color: '#FFFFFF' })
      .setOrigin(0.5)
      .setDepth(12);

    const pelBtn = this.add
      .rectangle(220, 766, 76, 36, 0x5c6b73)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(220, 766, t(loc, 'toolPel'), { fontSize: '12px', fontStyle: 'bold', color: '#FFFFFF' })
      .setOrigin(0.5)
      .setDepth(12);

    const updateToolVisual = () => {
      lapBtn.setFillStyle(this.toolMode === 'lap' ? 0xe07a5f : 0x5c6b73);
      pelBtn.setFillStyle(this.toolMode === 'pel' ? 0xe07a5f : 0x5c6b73);
    };
    lapBtn.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.toolMode = 'lap';
      this.view3d?.setToolMode('lap');
      updateToolVisual();
    });
    pelBtn.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.toolMode = 'pel';
      this.view3d?.setToolMode('pel');
      updateToolVisual();
    });

    if (stats.hasRadar) {
      const radarRect = this.add
        .rectangle(318, 766, 94, 36, 0xf2cc8f)
        .setDepth(11)
        .setInteractive({ useHandCursor: true });
      this.add
        .text(318, 766, `✨ ${t(loc, 'radarBtn')}`, {
          fontSize: '11px',
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

    const rotRight = this.add
      .rectangle(408, 766, 56, 36, 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(408, 766, '↻', { fontSize: '18px', fontStyle: 'bold', color: '#FFFFFF' })
      .setOrigin(0.5)
      .setDepth(12);
    rotRight.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.view3d?.rotateStep(0.28);
    });

    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      asmrSynth.unlock();
      if (this.finished) return;
      if (pointer.y < 72 || pointer.y > 708) return;
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
      if (pointer) {
        const pt = getClientCoords(pointer, canvas);
        this.view3d?.onPointerUp(pt.x, pt.y);
      } else {
        this.view3d?.onPointerUp();
      }
    };

    this.input.on('pointerup', releasePointer);
    this.input.on('pointerupoutside', releasePointer);

    const onBlur = () => releasePointer();
    const onResize = () => this.view3d?.syncCanvasBounds();
    this.game.events.on('blur', onBlur);
    this.scale.on('resize', onResize);

    this.events.once('shutdown', () => {
      this.sceneShutdown = true;
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
    const res = applyJobResult(getState(), {
      jobId: this.job.id,
      elapsedSec,
      jobOverride: this.job.isDaily ? this.job : undefined,
    });
    updateState(res.state);
    asmrSynth.playCash();
    this.showCompletionModal(res.entry, res.xpGained, res.state.xp);
  }

  private loadSnapshotAsync(key: string, dataUrl: string | null, x: number, y: number): void {
    if (!dataUrl) return;
    if (this.textures.exists(key)) {
      this.textures.remove(key);
    }
    const img = new Image();
    img.onload = () => {
      if (this.sceneShutdown || !this.scene.isActive('RoomScene')) return;
      if (this.textures.exists(key)) this.textures.remove(key);
      this.textures.addImage(key, img);
      this.add.image(x, y, key).setDisplaySize(90, 144).setDepth(24);
    };
    img.src = dataUrl;
  }

  private showCompletionModal(
    entry: {
      stars: 1 | 2 | 3;
      baseWageRp: number;
      speedBonusRp: number;
      tipRp: number;
      totalRp: number;
    },
    xpGained: number,
    totalXp: number,
  ): void {
    const loc = getState().locale;
    const snaps = this.view3d?.getSnapshots() ?? { before: null, after: null };
    const rank = getCareerRank(totalXp);

    this.add.rectangle(225, 400, 450, 800, 0x000000, 0.58).setDepth(20);
    this.add.rectangle(225, 400, 404, 620, 0xfdf6ec).setStrokeStyle(3, 0x81b29a).setDepth(21);

    this.add
      .text(225, 118, t(loc, 'completeTitle'), {
        fontSize: '22px',
        fontStyle: 'bold',
        color: '#3D405B',
      })
      .setOrigin(0.5)
      .setDepth(22);

    this.add
      .text(225, 152, '★'.repeat(entry.stars) + '☆'.repeat(3 - entry.stars), {
        fontSize: '26px',
        color: '#E07A5F',
      })
      .setOrigin(0.5)
      .setDepth(22);

    if (snaps.before || snaps.after) {
      this.add.rectangle(160, 264, 96, 152, 0xe5d9c8).setDepth(22);
      this.add.rectangle(290, 264, 96, 152, 0xe5d9c8).setDepth(22);
      this.add
        .text(160, 184, t(loc, 'beforeLabel'), { fontSize: '10px', fontStyle: 'bold', color: '#5C6B73' })
        .setOrigin(0.5)
        .setDepth(25);
      this.add
        .text(290, 184, t(loc, 'afterLabel'), { fontSize: '10px', fontStyle: 'bold', color: '#2A9D8F' })
        .setOrigin(0.5)
        .setDepth(25);
      this.loadSnapshotAsync('snap_before', snaps.before, 160, 268);
      this.loadSnapshotAsync('snap_after', snaps.after, 290, 268);
    }

    this.add.rectangle(225, 392, 360, 86, 0xffffff).setStrokeStyle(1, 0xe5d9c8).setDepth(22);
    this.add
      .text(225, 360, `💌 ${t(loc, 'storyHeader')}`, {
        fontSize: '11px',
        fontStyle: 'bold',
        color: '#81B29A',
      })
      .setOrigin(0.5)
      .setDepth(23);
    this.add
      .text(225, 398, pickText(this.job.storyNote, loc), {
        fontSize: '11px',
        color: '#3D405B',
        align: 'center',
        wordWrap: { width: 335 },
      })
      .setOrigin(0.5)
      .setDepth(23);

    const lines = [
      `${t(loc, 'baseWage')}: ${formatMoney(entry.baseWageRp, loc)}  •  ${t(loc, 'speedBonus')}: ${formatMoney(entry.speedBonusRp, loc)}`,
      `${t(loc, 'tipBonus')}: ${formatMoney(entry.tipRp, loc)}  •  +${xpGained} ${t(loc, 'xpLabel')} (${pickText(rank.title, loc)})`,
    ];
    this.add
      .text(225, 466, lines.join('\n'), {
        fontSize: '11px',
        color: '#5C6B73',
        align: 'center',
        lineSpacing: 6,
      })
      .setOrigin(0.5)
      .setDepth(22);

    this.add
      .text(225, 514, `${t(loc, 'totalEarned')}: +${formatMoney(entry.totalRp, loc)}`, {
        fontSize: '16px',
        fontStyle: 'bold',
        color: '#2A9D8F',
      })
      .setOrigin(0.5)
      .setDepth(22);

    const nextJob = !this.job.isDaily ? JOBS.find((j) => j.level === this.job.level + 1) : undefined;
    if (nextJob) {
      const nextBtn = this.add
        .rectangle(225, 568, 240, 40, 0x81b29a)
        .setDepth(22)
        .setInteractive({ useHandCursor: true });
      this.add
        .text(225, 568, t(loc, 'nextHouse'), {
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
      .rectangle(225, nextJob ? 620 : 576, 240, 38, 0xe07a5f)
      .setDepth(22)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(225, nextJob ? 620 : 576, t(loc, 'backToMap'), {
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
