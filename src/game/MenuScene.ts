import Phaser from 'phaser';
import { JOBS } from '../core/jobs';
import { UPGRADES, purchaseUpgrade } from '../core/economy';
import { formatMoney, pickText, t } from '../core/i18n';
import { asmrSynth } from '../audio/asmrSynth';
import { getState, updateState, resetGameState } from './stateStore';

type ActiveTab = 'map' | 'shop' | 'cashbook';

export class MenuScene extends Phaser.Scene {
  private activeTab: ActiveTab = 'map';
  private confirmReset = false;

  constructor() {
    super('MenuScene');
  }

  create(): void {
    const state = getState();
    asmrSynth.setMuted(state.muted);

    this.input.on('pointerdown', () => {
      asmrSynth.unlock();
    });

    this.renderUI();
  }

  private renderUI(): void {
    this.children.removeAll(true);
    const state = getState();
    const loc = state.locale;

    // Warm background
    this.add.rectangle(225, 400, 450, 800, 0xfdf6ec);

    // Header card
    this.add.rectangle(225, 62, 450, 124, 0x3d405b);
    this.add.text(20, 22, t(loc, 'appTitle'), {
      fontSize: '23px',
      fontStyle: 'bold',
      color: '#FDF6EC',
    });
    this.add.text(20, 50, t(loc, 'appSubtitle'), {
      fontSize: '12px',
      color: '#F2CC8F',
    });

    // Wallet & Day pills
    const totalStars = Object.values(state.bestStars).reduce((a, b) => a + b, 0);
    this.add.text(
      20,
      82,
      `${t(loc, 'dayLabel')} ${state.day}  •  ${formatMoney(state.balanceRp, loc)}  •  ★ ${totalStars}/15`,
      {
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#81B29A',
      },
    );

    // Language toggle button (top right)
    this.makePillButton(346, 36, 44, 30, t(loc, 'langSwitch'), 0x81b29a, '#1F2937', () => {
      asmrSynth.playPop();
      updateState({ ...getState(), locale: loc === 'id' ? 'en' : 'id' });
      this.confirmReset = false;
      this.renderUI();
    });

    // Sound toggle button
    this.makePillButton(
      408,
      36,
      54,
      30,
      state.muted ? '🔇' : '🔊',
      state.muted ? 0x9ca3af : 0xf2cc8f,
      '#1F2937',
      () => {
        const nextMuted = !getState().muted;
        asmrSynth.setMuted(nextMuted);
        updateState({ ...getState(), muted: nextMuted });
        if (!nextMuted) asmrSynth.playPop();
        this.renderUI();
      },
    );

    // Tab switcher
    const tabs: Array<{ id: ActiveTab; label: string; x: number }> = [
      { id: 'map', label: t(loc, 'mapTab'), x: 80 },
      { id: 'shop', label: t(loc, 'shopTab'), x: 225 },
      { id: 'cashbook', label: t(loc, 'cashbookTab'), x: 370 },
    ];
    for (const tab of tabs) {
      const selected = this.activeTab === tab.id;
      this.makePillButton(
        tab.x,
        148,
        134,
        36,
        tab.label,
        selected ? 0xe07a5f : 0xede0d4,
        selected ? '#FFFFFF' : '#3D405B',
        () => {
          asmrSynth.playPop();
          this.activeTab = tab.id;
          this.confirmReset = false;
          this.renderUI();
        },
      );
    }

    if (this.activeTab === 'map') {
      this.renderHousesTab();
    } else if (this.activeTab === 'shop') {
      this.renderShopTab();
    } else {
      this.renderCashbookTab();
    }
  }

  private renderHousesTab(): void {
    const state = getState();
    const loc = state.locale;

    JOBS.forEach((job, idx) => {
      const y = 232 + idx * 106;
      const unlocked = job.level <= state.unlockedLevel;
      const best = state.bestStars[job.id] ?? 0;

      const card = this.add
        .rectangle(225, y, 412, 92, unlocked ? 0xffffff : 0xefe7dc)
        .setStrokeStyle(2, unlocked ? 0x81b29a : 0xd6ccc2);

      // Level badge
      this.add.circle(48, y, 22, unlocked ? 0xe07a5f : 0xbdbdbd);
      this.add
        .text(48, y, String(job.level), {
          fontSize: '18px',
          fontStyle: 'bold',
          color: '#FFFFFF',
        })
        .setOrigin(0.5);

      // House info
      this.add.text(84, y - 30, pickText(job.title, loc), {
        fontSize: '15px',
        fontStyle: 'bold',
        color: unlocked ? '#3D405B' : '#7D7D7D',
      });

      this.add.text(84, y - 8, pickText(job.briefing, loc), {
        fontSize: '11px',
        color: '#6B7280',
        wordWrap: { width: 225 },
      });

      const starsStr = best > 0 ? '★'.repeat(best) + '☆'.repeat(3 - best) : '☆☆☆';
      this.add.text(84, y + 22, `${formatMoney(job.baseWageRp, loc)}  •  ${starsStr}`, {
        fontSize: '12px',
        fontStyle: 'bold',
        color: unlocked ? '#2A9D8F' : '#9CA3AF',
      });

      if (unlocked) {
        this.makePillButton(
          372,
          y,
          92,
          36,
          best > 0 ? t(loc, 'replayJob') : t(loc, 'startJob'),
          0x81b29a,
          '#FFFFFF',
          () => {
            asmrSynth.playSnap();
            this.scene.start('RoomScene', { jobId: job.id });
          },
        );
        card.setInteractive({ useHandCursor: true }).on('pointerdown', () => {
          asmrSynth.playSnap();
          this.scene.start('RoomScene', { jobId: job.id });
        });
      } else {
        this.add
          .text(372, y, `🔒 ${t(loc, 'lockedLabel')}`, {
            fontSize: '11px',
            color: '#9CA3AF',
          })
          .setOrigin(0.5);
      }
    });
  }

  private renderShopTab(): void {
    const state = getState();
    const loc = state.locale;

    UPGRADES.forEach((up, idx) => {
      const y = 232 + idx * 106;
      const owned = state.upgrades.includes(up.id);
      const canBuy = !owned && state.balanceRp >= up.costRp;

      this.add
        .rectangle(225, y, 412, 92, owned ? 0xeaf4f4 : 0xffffff)
        .setStrokeStyle(2, owned ? 0x2a9d8f : 0xe5d9c8);

      this.add.text(34, y - 28, pickText(up.name, loc), {
        fontSize: '15px',
        fontStyle: 'bold',
        color: '#3D405B',
      });

      this.add.text(34, y - 5, pickText(up.description, loc), {
        fontSize: '12px',
        color: '#6B7280',
        wordWrap: { width: 265 },
      });

      this.add.text(34, y + 20, formatMoney(up.costRp, loc), {
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#E07A5F',
      });

      if (owned) {
        this.add
          .text(368, y, `✓ ${t(loc, 'ownedLabel')}`, {
            fontSize: '12px',
            fontStyle: 'bold',
            color: '#2A9D8F',
          })
          .setOrigin(0.5);
      } else {
        this.makePillButton(
          368,
          y,
          104,
          36,
          canBuy ? t(loc, 'buyBtn') : t(loc, 'notEnoughFunds'),
          canBuy ? 0xe07a5f : 0xd1d5db,
          canBuy ? '#FFFFFF' : '#6B7280',
          () => {
            const res = purchaseUpgrade(getState(), up.id);
            if (res.purchased) {
              asmrSynth.playCash();
              updateState(res.state);
              this.renderUI();
            }
          },
        );
      }
    });
  }

  private renderCashbookTab(): void {
    const state = getState();
    const loc = state.locale;

    if (state.cashbook.length === 0) {
      this.add
        .text(225, 360, t(loc, 'cashbookEmpty'), {
          fontSize: '14px',
          color: '#6B7280',
          align: 'center',
          wordWrap: { width: 320 },
        })
        .setOrigin(0.5);
    } else {
      state.cashbook.slice(0, 7).forEach((entry, idx) => {
        const y = 218 + idx * 70;
        const job = JOBS.find((j) => j.id === entry.jobId);
        const title = job ? pickText(job.title, loc) : entry.jobId;
        this.add.rectangle(225, y, 412, 58, 0xffffff).setStrokeStyle(1, 0xe5d9c8);

        this.add.text(32, y - 16, `${t(loc, 'dayLabel')} ${entry.day} — ${title}`, {
          fontSize: '13px',
          fontStyle: 'bold',
          color: '#3D405B',
        });
        this.add.text(32, y + 6, `${'★'.repeat(entry.stars)}  (${entry.elapsedSec}s)`, {
          fontSize: '12px',
          color: '#E07A5F',
        });
        this.add
          .text(414, y, `+${formatMoney(entry.totalRp, loc)}`, {
            fontSize: '14px',
            fontStyle: 'bold',
            color: '#2A9D8F',
          })
          .setOrigin(1, 0.5);
      });
    }

    // Safe two-tap reset at bottom
    this.makePillButton(
      225,
      748,
      200,
      38,
      this.confirmReset ? t(loc, 'resetConfirm') : t(loc, 'resetBtn'),
      this.confirmReset ? 0xdc2626 : 0xe5d9c8,
      this.confirmReset ? '#FFFFFF' : '#3D405B',
      () => {
        if (!this.confirmReset) {
          this.confirmReset = true;
          this.renderUI();
        } else {
          this.confirmReset = false;
          resetGameState();
          asmrSynth.playPop();
          this.renderUI();
        }
      },
    );
  }

  private makePillButton(
    x: number,
    y: number,
    w: number,
    h: number,
    label: string,
    bgColor: number,
    textColor: string,
    onClick: () => void,
  ): void {
    const rect = this.add
      .rectangle(x, y, w, h, bgColor)
      .setStrokeStyle(1, 0x000000, 0.08)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(x, y, label, {
        fontSize: label.length > 14 ? '10px' : '12px',
        fontStyle: 'bold',
        color: textColor,
      })
      .setOrigin(0.5);
    rect.on('pointerdown', onClick);
  }
}
