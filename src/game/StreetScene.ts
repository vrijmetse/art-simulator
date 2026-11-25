import Phaser from 'phaser';
import { getTodayDateKey } from '../core/attendance';
import { canClaimNpcChat, claimNpcChatReward, type NeighborSpec } from '../core/neighborhood';
import { formatBalance, formatMoney, pickText, t } from '../core/i18n';
import { asmrSynth } from '../audio/asmrSynth';
import { getState, updateState } from './stateStore';
import { renderNeighborPortraitCanvas } from './portraits';
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
    const today = getTodayDateKey();
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
        const curState = getState();
        const curLoc = curState.locale;
        for (const b of badges) {
          const canGreet = canClaimNpcChat(curState, b.id, today);
          const tag = canGreet
            ? `❗ ${pickText(b.spec.name, curLoc)}`
            : pickText(b.spec.name, curLoc);
          let label = this.badgeTexts.get(b.id);
          if (!label) {
            label = this.add
              .text(b.x, b.y, tag, {
                fontSize: '10px',
                fontStyle: 'bold',
                color: '#FFFFFF',
                backgroundColor: '#1E293B',
                padding: { x: 6, y: 3 },
              })
              .setOrigin(0.5)
              .setDepth(8);
            this.badgeTexts.set(b.id, label);
          } else {
            label.setText(tag);
          }
          const inPlayfield = b.y > 82 && b.y < 692 && b.x > 30 && b.x < 420;
          label.setVisible(inPlayfield);
          if (inPlayfield) {
            label.setPosition(b.x, b.y);
          }
        }
      },
    });

    // Translucent dark-glass Top HUD (Warung-Life style)
    this.add.rectangle(225, 36, 450, 72, 0x1e293b, 0.84).setDepth(10);
    const backBtn = this.add
      .rectangle(52, 36, 82, 34, 0xf2cc8f)
      .setDepth(11)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(52, 36, '📱 HP', {
        fontSize: '12px',
        fontStyle: 'bold',
        color: '#1E293B',
      })
      .setOrigin(0.5)
      .setDepth(12);
    backBtn.on('pointerdown', () => {
      asmrSynth.unlock();
      asmrSynth.playPop();
      this.scene.start('MenuScene');
    });

    this.add
      .text(245, 22, `${t(loc, 'streetHeader')} • ${t(loc, 'dayLabel')} ${state.day}`, {
        fontSize: '14px',
        fontStyle: 'bold',
        color: '#FDF6EC',
      })
      .setOrigin(0.5)
      .setDepth(12);

    const totalStars = Object.values(state.bestStars).reduce((a, b) => a + b, 0);
    this.balanceText = this.add
      .text(
        245,
        48,
        `${formatBalance(state.balanceRp, loc)}  •  ★ ${totalStars}/15  •  ${state.xp} ${t(loc, 'xpLabel')}`,
        {
          fontSize: '12px',
          fontStyle: 'bold',
          color: '#81B29A',
        },
      )
      .setOrigin(0.5)
      .setDepth(12);

    // Bottom HUD (708..800)
    this.add.rectangle(225, 754, 450, 92, 0x1e293b, 0.86).setDepth(10);
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
      for (const key of this.textures.getTextureKeys()) {
        if (key.startsWith('portrait_')) {
          this.textures.remove(key);
        }
      }
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

    // Warung-Life style translucent Bottom Story Bar (y = 636, h = 126 -> clears 708..800 Bottom HUD!)
    const bar = this.add
      .rectangle(225, 636, 428, 126, 0x1e293b, 0.94)
      .setStrokeStyle(2, 0xf2cc8f)
      .setDepth(21);

    // 2D Bust Portrait at (58, 612), 68x68 -> y=578..646 strictly above greetBtn (y=655..689)
    const pKey = `portrait_${spec.id}`;
    if (!this.textures.exists(pKey)) {
      this.textures.addCanvas(pKey, renderNeighborPortraitCanvas(spec));
    }
    const portraitImg = this.add.image(58, 612, pKey).setDisplaySize(68, 68).setDepth(22);

    const nameTxt = this.add
      .text(104, 582, `${pickText(spec.name, loc)} • ${pickText(spec.role, loc)}`, {
        fontSize: '12px',
        fontStyle: 'bold',
        color: '#F2CC8F',
      })
      .setDepth(22);

    const msgTxt = this.add
      .text(104, 604, `"${pickText(spec.greeting, loc)}"`, {
        fontSize: '11px',
        color: '#FDF6EC',
        wordWrap: { width: 318 },
      })
      .setDepth(22);

    this.modalObjects.push(bar, portraitImg, nameTxt, msgTxt);

    const greetBtn = this.add
      .rectangle(154, 672, 240, 34, canClaim ? 0x2a9d8f : 0x475569)
      .setDepth(22)
      .setInteractive({ useHandCursor: canClaim });
    const greetTxt = this.add
      .text(
        154,
        672,
        canClaim
          ? `💬 ${t(loc, 'greetBtn')} (+${formatMoney(spec.tipRp, loc)})`
          : `✓ ${t(loc, 'greetedLabel')}`,
        {
          fontSize: '11px',
          fontStyle: 'bold',
          color: canClaim ? '#FFFFFF' : '#CBD5E1',
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
          const stars = Object.values(res.state.bestStars).reduce((a, b) => a + b, 0);
          this.balanceText.setText(
            `${formatBalance(res.state.balanceRp, loc)}  •  ★ ${stars}/15  •  ${res.state.xp} ${t(loc, 'xpLabel')}`,
          );
          greetBtn.setFillStyle(0x475569);
          greetTxt.setText(`✓ ${t(loc, 'greetedLabel')}`).setColor('#CBD5E1');
        }
      });
    }

    const closeBtn = this.add
      .rectangle(356, 672, 128, 34, 0xe07a5f)
      .setDepth(22)
      .setInteractive({ useHandCursor: true });
    const closeTxt = this.add
      .text(356, 672, t(loc, 'backBtn'), {
        fontSize: '12px',
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
