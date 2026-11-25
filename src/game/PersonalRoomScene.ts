import Phaser from 'phaser';
import type { JobSpec } from '../core/types';
import { buildPersonalKosFurniture, DECOR_ITEMS } from '../core/decor';
import { t } from '../core/i18n';
import { asmrSynth } from '../audio/asmrSynth';
import { getState, updateState } from './stateStore';
import { Room3DView } from './Room3DView';

export class PersonalRoomScene extends Phaser.Scene {
  private view3d: Room3DView | null = null;

  constructor() {
    super('PersonalRoomScene');
  }

  create(): void {
    const state = getState();
    const loc = state.locale;
    const canvas = this.sys.game.canvas;

    const kosSpec: JobSpec = {
      id: 'personal-kos',
      level: 1,
      title: { id: 'Kamar Kos Pribadi', en: 'My Personal Kos Room' },
      clientName: 'Saya',
      briefing: { id: '', en: '' },
      storyNote: { id: '', en: '' },
      baseWageRp: 0,
      parTimeSec: 60,
      palette: { wall: '#F8EDE3', floor: '#DFD3C3', accent: '#E07A5F', trim: '#8D6E63' },
      furnitureLayout: buildPersonalKosFurniture(state.placedDecor),
      stains: [],
      clutter: [],
    };

    this.view3d = new Room3DView(
      canvas,
      kosSpec,
      24,
      0.55,
      {
        onProgress: () => {},
        onStainCleared: () => {},
        onScrubStroke: () => {},
        onClutterSnapped: () => {},
        onComplete: () => {},
      },
      true,
    );

    // Top HUD
    this.add.rectangle(225, 36, 450, 72, 0x3d405b, 0.92).setDepth(10);
    const backBtn = this.add
      .rectangle(46, 36, 70, 36, 0xf2cc8f)
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
    backBtn.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.scene.start('MenuScene', { tab: 'kos' });
    });

    this.add
      .text(235, 24, t(loc, 'kosHeader'), {
        fontSize: '15px',
        fontStyle: 'bold',
        color: '#FDF6EC',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.add
      .text(235, 48, `${state.placedDecor.length}/${DECOR_ITEMS.length} ${t(loc, 'decorSubTab')}`, {
        fontSize: '12px',
        color: '#81B29A',
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

    // Bottom HUD with 3D orbit controls
    this.add.rectangle(225, 754, 450, 92, 0x3d405b, 0.92).setDepth(10);
    this.add
      .text(225, 724, t(loc, 'kosHint'), {
        fontSize: '11px',
        color: '#FDF6EC',
        align: 'center',
        wordWrap: { width: 410 },
      })
      .setOrigin(0.5)
      .setDepth(12);

    const rotLeft = this.add
      .rectangle(80, 766, 112, 36, 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(80, 766, `↺ ${t(loc, 'rotateBtn')}`, {
        fontSize: '12px',
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
      .rectangle(370, 766, 112, 36, 0x81b29a)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(370, 766, `${t(loc, 'rotateBtn')} ↻`, {
        fontSize: '12px',
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

    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      asmrSynth.unlock();
      if (pointer.y < 72 || pointer.y > 708) return;
      const ev = pointer.event as MouseEvent | TouchEvent | undefined;
      let cx = 0;
      let cy = 0;
      if (ev && 'clientX' in ev && typeof ev.clientX === 'number') {
        cx = ev.clientX;
        cy = ev.clientY;
      } else if (ev && 'changedTouches' in ev && ev.changedTouches && ev.changedTouches.length > 0) {
        cx = ev.changedTouches[0].clientX;
        cy = ev.changedTouches[0].clientY;
      } else {
        const rect = canvas.getBoundingClientRect();
        cx = rect.left + (pointer.x / 450) * rect.width;
        cy = rect.top + (pointer.y / 800) * rect.height;
      }
      this.view3d?.onFloorTap(cx, cy);
    });

    const onResize = () => this.view3d?.syncCanvasBounds();
    this.scale.on('resize', onResize);

    this.events.once('shutdown', () => {
      this.scale.off('resize', onResize);
      this.view3d?.destroy();
      this.view3d = null;
    });
  }
}
