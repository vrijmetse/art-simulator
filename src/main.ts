import Phaser from 'phaser';
import { registerSW } from 'virtual:pwa-register';
import { MenuScene } from './game/MenuScene';
import { RoomScene } from './game/RoomScene';
import { PersonalRoomScene } from './game/PersonalRoomScene';

registerSW({ immediate: true });

const config: Phaser.Types.Core.GameConfig = {
  type: Phaser.CANVAS,
  parent: 'app',
  width: 450,
  height: 800,
  transparent: true,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  input: {
    activePointers: 2,
  },
  scene: [MenuScene, RoomScene, PersonalRoomScene],
};

new Phaser.Game(config);
