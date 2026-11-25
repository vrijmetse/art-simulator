import Phaser from 'phaser';
import { JOBS } from '../core/jobs';
import { UPGRADES, purchaseUpgrade } from '../core/economy';
import { AVATARS } from '../core/avatars';
import { DECOR_ITEMS, purchaseDecor, toggleDecorPlacement } from '../core/decor';
import { getCareerRank, getNextCareerRank } from '../core/career';
import { canClaimAttendance, claimAttendance, getTodayDateKey } from '../core/attendance';
import { generateDailyJob } from '../core/daily';
import { formatBalance, formatMoney, pickText, t } from '../core/i18n';
import { asmrSynth } from '../audio/asmrSynth';
import { getState, updateState, resetGameState } from './stateStore';

type ActiveTab = 'map' | 'kos' | 'shop' | 'cashbook';
type ShopSubTab = 'tools' | 'decor';

export class MenuScene extends Phaser.Scene {
  private activeTab: ActiveTab = 'map';
  private shopSubTab: ShopSubTab = 'tools';
  private confirmReset = false;

  constructor() {
    super('MenuScene');
  }

  init(data?: { tab?: ActiveTab }): void {
    if (data?.tab) {
      this.activeTab = data.tab;
    }
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
    const rank = getCareerRank(state.xp);

    // Warm background
    this.add.rectangle(225, 400, 450, 800, 0xfdf6ec);

    // Header card
    this.add.rectangle(225, 58, 450, 116, 0x3d405b);
    this.add.text(18, 16, t(loc, 'appTitle'), {
      fontSize: '21px',
      fontStyle: 'bold',
      color: '#FDF6EC',
    });
    this.add.text(18, 42, `${pickText(rank.title, loc)} • ${state.xp} ${t(loc, 'xpLabel')}`, {
      fontSize: '12px',
      color: '#F2CC8F',
    });

    const totalStars = Object.values(state.bestStars).reduce((a, b) => a + b, 0);
    this.add.text(
      18,
      78,
      `${t(loc, 'dayLabel')} ${state.day}  •  ${formatBalance(state.balanceRp, loc)}  •  ★ ${totalStars}/15  •  🔥 ${state.dailyStreak}`,
      {
        fontSize: '12px',
        fontStyle: 'bold',
        color: '#81B29A',
      },
    );

    this.makePillButton(346, 32, 44, 30, t(loc, 'langSwitch'), 0x81b29a, '#1F2937', () => {
      asmrSynth.playPop();
      updateState({ ...getState(), locale: loc === 'id' ? 'en' : 'id' });
      this.confirmReset = false;
      this.renderUI();
    });

    this.makePillButton(
      408,
      32,
      52,
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

    const tabs: Array<{ id: ActiveTab; label: string; x: number }> = [
      { id: 'map', label: t(loc, 'mapTab'), x: 63 },
      { id: 'kos', label: t(loc, 'kosTab'), x: 171 },
      { id: 'shop', label: t(loc, 'shopTab'), x: 279 },
      { id: 'cashbook', label: t(loc, 'cashbookTab'), x: 387 },
    ];
    for (const tab of tabs) {
      const selected = this.activeTab === tab.id;
      this.makePillButton(
        tab.x,
        142,
        100,
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
        '11px',
      );
    }

    if (this.activeTab === 'map') {
      this.renderHousesTab();
    } else if (this.activeTab === 'kos') {
      this.renderKosTab();
    } else if (this.activeTab === 'shop') {
      this.renderShopTab();
    } else {
      this.renderCashbookTab();
    }
  }

  private renderHousesTab(): void {
    const state = getState();
    const loc = state.locale;
    const today = getTodayDateKey();

    const canClaim = canClaimAttendance(state, today);
    this.makePillButton(
      142,
      194,
      246,
      36,
      canClaim
        ? `🎁 ${t(loc, 'claimDailyBtn')}`
        : `✓ ${t(loc, 'claimedDailyLabel')} (${state.attendanceDay}/30)`,
      canClaim ? 0x2a9d8f : 0xe5d9c8,
      canClaim ? '#FFFFFF' : '#5C6B73',
      () => {
        if (!canClaimAttendance(getState(), today)) return;
        const res = claimAttendance(getState(), today);
        if (res.claimed) {
          asmrSynth.playCash();
          updateState(res.state);
          this.renderUI();
        }
      },
      '11px',
    );

    this.makePillButton(
      352,
      194,
      158,
      36,
      `🏘️ ${t(loc, 'streetBtn')}`,
      0x3d405b,
      '#F2CC8F',
      () => {
        asmrSynth.playSnap();
        this.scene.start('StreetScene');
      },
      '11px',
    );

    const dailyDone = state.dailyCompletedDates.includes(today);
    const dailyJob = generateDailyJob(today, state.unlockedLevel);
    const dailyCard = this.add
      .rectangle(225, 260, 412, 74, dailyDone ? 0xeaf4f4 : 0xfff8e7)
      .setStrokeStyle(2, dailyDone ? 0x2a9d8f : 0xe07a5f);
    this.add.text(32, 234, `🔥 ${pickText(dailyJob.title, loc)}`, {
      fontSize: '13px',
      fontStyle: 'bold',
      color: '#3D405B',
    });
    this.add.text(
      32,
      254,
      dailyDone
        ? `${t(loc, 'dailyDone')} • ${t(loc, 'streakLabel')}: ${state.dailyStreak}`
        : `${formatMoney(dailyJob.baseWageRp, loc)} (+50%) • ${t(loc, 'streakLabel')}: ${state.dailyStreak}`,
      { fontSize: '11px', color: '#5C6B73' },
    );
    this.makePillButton(
      372,
      260,
      92,
      34,
      dailyDone ? t(loc, 'replayJob') : t(loc, 'startJob'),
      dailyDone ? 0x81b29a : 0xe07a5f,
      '#FFFFFF',
      () => {
        asmrSynth.playSnap();
        this.scene.start('RoomScene', { dailyDateKey: today });
      },
    );
    dailyCard.setInteractive({ useHandCursor: true }).on('pointerdown', () => {
      asmrSynth.playSnap();
      this.scene.start('RoomScene', { dailyDateKey: today });
    });

    JOBS.forEach((job, idx) => {
      const y = 352 + idx * 88;
      const unlocked = job.level <= state.unlockedLevel;
      const best = state.bestStars[job.id] ?? 0;

      const card = this.add
        .rectangle(225, y, 412, 78, unlocked ? 0xffffff : 0xefe7dc)
        .setStrokeStyle(2, unlocked ? 0x81b29a : 0xd6ccc2);

      this.add.circle(46, y, 20, unlocked ? 0xe07a5f : 0xbdbdbd);
      this.add
        .text(46, y, String(job.level), {
          fontSize: '16px',
          fontStyle: 'bold',
          color: '#FFFFFF',
        })
        .setOrigin(0.5);

      this.add.text(78, y - 24, pickText(job.title, loc), {
        fontSize: '14px',
        fontStyle: 'bold',
        color: unlocked ? '#3D405B' : '#7D7D7D',
      });

      this.add.text(78, y - 4, pickText(job.briefing, loc), {
        fontSize: '10px',
        color: '#6B7280',
        wordWrap: { width: 235 },
      });

      const starsStr = best > 0 ? '★'.repeat(best) + '☆'.repeat(3 - best) : '☆☆☆';
      this.add.text(78, y + 18, `${formatMoney(job.baseWageRp, loc)}  •  ${starsStr}`, {
        fontSize: '11px',
        fontStyle: 'bold',
        color: unlocked ? '#2A9D8F' : '#9CA3AF',
      });

      if (unlocked) {
        this.makePillButton(
          372,
          y,
          92,
          34,
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

  private renderKosTab(): void {
    const state = getState();
    const loc = state.locale;

    this.makePillButton(
      225,
      192,
      412,
      40,
      `🏠 ${t(loc, 'kosHeader')} (3D)`,
      0x2a9d8f,
      '#FFFFFF',
      () => {
        asmrSynth.playSnap();
        this.scene.start('PersonalRoomScene');
      },
      '13px',
    );

    this.add
      .text(28, 218, `${t(loc, 'avatarLabel')}:`, {
        fontSize: '11px',
        fontStyle: 'bold',
        color: '#3D405B',
      });

    AVATARS.forEach((av, idx) => {
      const selected = state.avatarId === av.id;
      const ax = 68 + idx * 104;
      this.makePillButton(
        ax,
        252,
        96,
        30,
        pickText(av.name, loc),
        selected ? 0xe07a5f : 0xede0d4,
        selected ? '#FFFFFF' : '#3D405B',
        () => {
          asmrSynth.playPop();
          updateState({ ...getState(), avatarId: av.id });
          this.renderUI();
        },
        '11px',
      );
    });

    DECOR_ITEMS.forEach((item, idx) => {
      const y = 306 + idx * 58;
      const owned = state.ownedDecor.includes(item.id);
      const placed = state.placedDecor.includes(item.id);

      this.add
        .rectangle(225, y, 412, 50, owned ? 0xffffff : 0xf4eee6)
        .setStrokeStyle(1, owned ? 0x81b29a : 0xe5d9c8);

      this.add.text(32, y - 16, pickText(item.name, loc), {
        fontSize: '13px',
        fontStyle: 'bold',
        color: owned ? '#3D405B' : '#9CA3AF',
      });
      this.add.text(32, y + 4, pickText(item.description, loc), {
        fontSize: '10px',
        color: '#6B7280',
      });

      if (owned) {
        this.makePillButton(
          372,
          y,
          92,
          34,
          placed ? t(loc, 'removeBtn') : t(loc, 'placeBtn'),
          placed ? 0xe07a5f : 0x81b29a,
          '#FFFFFF',
          () => {
            asmrSynth.playPop();
            updateState(toggleDecorPlacement(getState(), item.id));
            this.renderUI();
          },
        );
      } else {
        this.add
          .text(372, y, formatMoney(item.costRp, loc), {
            fontSize: '11px',
            fontStyle: 'bold',
            color: '#9CA3AF',
          })
          .setOrigin(0.5);
      }
    });
  }

  private renderShopTab(): void {
    const state = getState();
    const loc = state.locale;

    this.makePillButton(
      120,
      194,
      196,
      34,
      t(loc, 'toolsSubTab'),
      this.shopSubTab === 'tools' ? 0x3d405b : 0xede0d4,
      this.shopSubTab === 'tools' ? '#FFFFFF' : '#3D405B',
      () => {
        asmrSynth.playPop();
        this.shopSubTab = 'tools';
        this.renderUI();
      },
      '12px',
    );
    this.makePillButton(
      330,
      194,
      196,
      34,
      t(loc, 'decorSubTab'),
      this.shopSubTab === 'decor' ? 0x3d405b : 0xede0d4,
      this.shopSubTab === 'decor' ? '#FFFFFF' : '#3D405B',
      () => {
        asmrSynth.playPop();
        this.shopSubTab = 'decor';
        this.renderUI();
      },
      '12px',
    );

    if (this.shopSubTab === 'tools') {
      UPGRADES.forEach((up, idx) => {
        const y = 266 + idx * 102;
        const owned = state.upgrades.includes(up.id);
        const canBuy = !owned && state.balanceRp >= up.costRp;

        this.add
          .rectangle(225, y, 412, 90, owned ? 0xeaf4f4 : 0xffffff)
          .setStrokeStyle(2, owned ? 0x2a9d8f : 0xe5d9c8);

        this.add.text(34, y - 26, pickText(up.name, loc), {
          fontSize: '15px',
          fontStyle: 'bold',
          color: '#3D405B',
        });

        this.add.text(34, y - 4, pickText(up.description, loc), {
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
    } else {
      DECOR_ITEMS.forEach((item, idx) => {
        const col = idx % 2;
        const row = Math.floor(idx / 2);
        const cx = col === 0 ? 120 : 330;
        const cy = 282 + row * 124;
        const owned = state.ownedDecor.includes(item.id);
        const canBuy = !owned && state.balanceRp >= item.costRp;

        this.add
          .rectangle(cx, cy, 198, 112, owned ? 0xeaf4f4 : 0xffffff)
          .setStrokeStyle(2, owned ? 0x2a9d8f : 0xe5d9c8);

        this.add
          .text(cx, cy - 36, pickText(item.name, loc), {
            fontSize: '12px',
            fontStyle: 'bold',
            color: '#3D405B',
            align: 'center',
            wordWrap: { width: 180 },
          })
          .setOrigin(0.5);

        this.add
          .text(cx, cy - 6, formatMoney(item.costRp, loc), {
            fontSize: '12px',
            fontStyle: 'bold',
            color: '#E07A5F',
          })
          .setOrigin(0.5);

        if (owned) {
          this.add
            .text(cx, cy + 30, `✓ ${t(loc, 'ownedLabel')}`, {
              fontSize: '11px',
              fontStyle: 'bold',
              color: '#2A9D8F',
            })
            .setOrigin(0.5);
        } else {
          this.makePillButton(
            cx,
            cy + 30,
            150,
            34,
            canBuy ? t(loc, 'buyBtn') : t(loc, 'notEnoughFunds'),
            canBuy ? 0xe07a5f : 0xd1d5db,
            canBuy ? '#FFFFFF' : '#6B7280',
            () => {
              const res = purchaseDecor(getState(), item.id);
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
  }

  private renderCashbookTab(): void {
    const state = getState();
    const loc = state.locale;
    const rank = getCareerRank(state.xp);
    const nextRank = getNextCareerRank(state.xp);

    this.add.rectangle(225, 204, 412, 54, 0xffffff).setStrokeStyle(2, 0x81b29a);
    this.add.text(32, 186, `${pickText(rank.title, loc)} (+${rank.wageBonusPct}%)`, {
      fontSize: '14px',
      fontStyle: 'bold',
      color: '#3D405B',
    });
    this.add.text(
      32,
      208,
      nextRank
        ? `${state.xp} / ${nextRank.minXp} ${t(loc, 'xpLabel')} → ${pickText(nextRank.title, loc)}`
        : `${state.xp} ${t(loc, 'xpLabel')} (MAX)`,
      { fontSize: '11px', color: '#2A9D8F' },
    );

    if (state.cashbook.length === 0) {
      this.add
        .text(225, 380, t(loc, 'cashbookEmpty'), {
          fontSize: '14px',
          color: '#6B7280',
          align: 'center',
          wordWrap: { width: 320 },
        })
        .setOrigin(0.5);
    } else {
      state.cashbook.slice(0, 6).forEach((entry, idx) => {
        const y = 274 + idx * 68;
        const job = JOBS.find((j) => j.id === entry.jobId);
        const title = job
          ? pickText(job.title, loc)
          : entry.jobId.startsWith('daily-')
            ? `${t(loc, 'dailyTitle')} (${entry.jobId.slice(6)})`
            : entry.jobId;

        this.add.rectangle(225, y, 412, 56, 0xffffff).setStrokeStyle(1, 0xe5d9c8);

        this.add.text(32, y - 16, `${t(loc, 'dayLabel')} ${entry.day} — ${title}`, {
          fontSize: '12px',
          fontStyle: 'bold',
          color: '#3D405B',
        });
        this.add.text(32, y + 6, `${'★'.repeat(entry.stars)}  (${entry.elapsedSec}s)`, {
          fontSize: '11px',
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
    fontSizeOverride?: string,
  ): void {
    const rect = this.add
      .rectangle(x, y, w, h, bgColor)
      .setStrokeStyle(1, 0x000000, 0.08)
      .setInteractive({ useHandCursor: true });
    this.add
      .text(x, y, label, {
        fontSize: fontSizeOverride ?? (label.length > 14 ? '10px' : '12px'),
        fontStyle: 'bold',
        color: textColor,
      })
      .setOrigin(0.5);
    rect.on('pointerdown', onClick);
  }
}
