import Phaser from 'phaser';
import { getTodayDateKey } from '../core/attendance';
import { canClaimNpcChat, claimNpcChatReward, type NeighborSpec } from '../core/neighborhood';
import { formatMoney, pickText, t } from '../core/i18n';
import { asmrSynth } from '../audio/asmrSynth';
import { getState, updateState } from './stateStore';
import { Street3DView } from './Street3DView';

export class StreetScene extends Phaser.Scene {
  private view3d: Street3DView | null = null;
  private isModalOpen = false;
  private activeNpcId: string | null = null;
  private modalObjects: Phaser.GameObjects.GameObject[] = [];
  private badgeTexts = new Map<string, Phaser.GameObjects.Text>();
  private balanceText!: Phaser.GameObjects.Text;

  constructor() {
    super('StreetScene');
  }

  create(): void {
    const state = getState();
    const loc = state.locale;
    const canvas = this.sys.game.canvas;
    this.isModalOpen = false;
    this.activeNpcId = null;
    this.modalObjects = [];
    this.badgeTexts.clear();

    this.view3d = new Street3DView(canvas, state.avatarId, {
      onSelectNeighbor: (spec) => {
        asmrSynth.playPop();
        this.openDialogueModal(spec);
      },
      onBadgesUpdated: (badges) => {
        if (this.isModalOpen) {
          for (const txt of this.badgeTexts.values()) txt.setVisible(false);
          return;
        }
        for (const b of badges) {
          let label = this.badgeTexts.get(b.id);
          if (!label) {
            label = this.add
              .text(b.x, b.y, pickText(b.spec.name, getState().locale), {
                fontSize: '10px',
                fontStyle: 'bold',
                color: '#3D405B',
                backgroundColor: '#FDF6EC',
                padding: { x: 5, y: 2 },
              })
              .setOrigin(0.5)
              .setDepth(8);
            this.badgeTexts.set(b.id, label);
          }
          const inPlayfield = b.y > 78 && b.y < 698 && b.x > 25 && b.x < 425;
          label.setVisible(inPlayfield);
          if (inPlayfield) {
            label.setPosition(b.x, b.y);
          }
        }
      },
    });

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
      this.scene.start('MenuScene');
    });

    this.add
      .text(225, 23, t(loc, 'streetHeader'), {
        fontSize: '15px',
        fontStyle: 'bold',
        color: '#FDF6EC',
      })
      .setOrigin(0.5)
      .setDepth(12);

    this.balanceText = this.add
      .text(225, 48, `${formatMoney(state.balanceRp, loc)}  •  ${state.xp} ${t(loc, 'xpLabel')}`, {
        fontSize: '12px',
        fontStyle: 'bold',
        color: '#81B29A',
      })
      .setOrigin(0.5)
      .setDepth(12);

    // Bottom HUD
    this.add.rectangle(225, 754, 450, 92, 0x3d405b, 0.92).setDepth(10);
    this.add
      .text(225, 724, t(loc, 'streetHint'), {
        fontSize: '11px',
        color: '#FDF6EC',
        align: 'center',
        wordWrap: { width: 410 },
      })
      .setOrigin(0.5)
      .setDepth(12);

    const rotL = this.add
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
    rotL.on('pointerdown', () => {
      asmrSynth.playPop();
      this.view3d?.rotateStep(-0.22);
    });

    const rotR = this.add
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
    rotR.on('pointerdown', () => {
      asmrSynth.playPop();
      this.view3d?.rotateStep(0.22);
    });

    // Street pointer input (gated by playfield bounds AND modal state!)
    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      asmrSynth.unlock();
      if (this.isModalOpen) return;
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
      this.view3d?.handleTap(cx, cy);
    });

    const onResize = () => this.view3d?.syncCanvasBounds();
    this.scale.on('resize', onResize);

    this.events.once('shutdown', () => {
      this.scale.off('resize', onResize);
      this.view3d?.destroy();
      this.view3d = null;
    });
  }

  private closeDialogueModal(): void {
    for (const obj of this.modalObjects) {
      obj.destroy();
    }
    this.modalObjects = [];
    this.isModalOpen = false;
    this.view3d?.resumeNpc(this.activeNpcId);
    this.activeNpcId = null;
  }

  private openDialogueModal(spec: NeighborSpec): void {
    this.closeDialogueModal();
    this.isModalOpen = true;
    this.activeNpcId = spec.id;

    const state = getState();
    const loc = state.locale;
    const today = getTodayDateKey();
    const canClaim = canClaimNpcChat(state, spec.id, today);

    const backdrop = this.add.rectangle(225, 400, 450, 800, 0x000000, 0.5).setDepth(20);
    const panel = this.add
      .rectangle(225, 410, 384, 320, 0xfdf6ec)
      .setStrokeStyle(3, 0x81b29a)
      .setDepth(21);

    const nameTxt = this.add
      .text(225, 290, pickText(spec.name, loc), {
        fontSize: '20px',
        fontStyle: 'bold',
        color: '#3D405B',
      })
      .setOrigin(0.5)
      .setDepth(22);

    const roleTxt = this.add
      .text(225, 316, pickText(spec.role, loc), {
        fontSize: '12px',
        fontStyle: 'bold',
        color: '#E07A5F',
      })
      .setOrigin(0.5)
      .setDepth(22);

    const bubble = this.add
      .rectangle(225, 382, 336, 92, 0xffffff)
      .setStrokeStyle(1, 0xe5d9c8)
      .setDepth(22);
    const msgTxt = this.add
      .text(225, 382, `"${pickText(spec.greeting, loc)}"`, {
        fontSize: '12px',
        color: '#3D405B',
        align: 'center',
        wordWrap: { width: 310 },
      })
      .setOrigin(0.5)
      .setDepth(23);

    this.modalObjects.push(backdrop, panel, nameTxt, roleTxt, bubble, msgTxt);

    // Claim daily tip button
    const greetBtn = this.add
      .rectangle(225, 464, 280, 40, canClaim ? 0x2a9d8f : 0xd1d5db)
      .setDepth(22)
      .setInteractive({ useHandCursor: canClaim });
    const greetTxt = this.add
      .text(
        225,
        464,
        canClaim
          ? `💬 ${t(loc, 'greetBtn')} (+${formatMoney(spec.tipRp, loc)})`
          : `✓ ${t(loc, 'greetedLabel')}`,
        {
          fontSize: '13px',
          fontStyle: 'bold',
          color: canClaim ? '#FFFFFF' : '#6B7280',
        },
      )
      .setOrigin(0.5)
      .setDepth(23);
    this.modalObjects.push(greetBtn, greetTxt);

    if (canClaim) {
      greetBtn.on('pointerdown', () => {
        const res = claimNpcChatReward(getState(), spec.id, today);
        if (res.claimed) {
          asmrSynth.playCash();
          updateState(res.state);
          this.balanceText.setText(
            `${formatMoney(res.state.balanceRp, loc)}  •  ${res.state.xp} ${t(loc, 'xpLabel')}`,
          );
          greetBtn.setFillStyle(0xd1d5db);
          greetTxt.setText(`✓ ${t(loc, 'greetedLabel')}`).setColor('#6B7280');
        }
      });
    }

    // Close button
    const closeBtn = this.add
      .rectangle(225, 520, 160, 36, 0xe07a5f)
      .setDepth(22)
      .setInteractive({ useHandCursor: true });
    const closeTxt = this.add
      .text(225, 520, t(loc, 'backBtn'), {
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#FFFFFF',
      })
      .setOrigin(0.5)
      .setDepth(23);
    this.modalObjects.push(closeBtn, closeTxt);

    closeBtn.on('pointerdown', () => {
      asmrSynth.playPop();
      this.closeDialogueModal();
    });
  }
}
