import type { AvatarId, LocalizedText } from './types';

export interface AvatarSpec {
  id: AvatarId;
  name: LocalizedText;
  modelName: string;
}

export const AVATARS: AvatarSpec[] = [
  {
    id: 'sari',
    name: { id: 'Sari', en: 'Sari' },
    modelName: 'character-female-a.glb',
  },
  {
    id: 'maya',
    name: { id: 'Maya', en: 'Maya' },
    modelName: 'character-female-b.glb',
  },
  {
    id: 'budi',
    name: { id: 'Budi', en: 'Budi' },
    modelName: 'character-male-a.glb',
  },
  {
    id: 'eko',
    name: { id: 'Pak Eko', en: 'Pak Eko' },
    modelName: 'character-worker.glb',
  },
];

const VALID_AVATAR_IDS = new Set<string>(AVATARS.map((a) => a.id));

export function isValidAvatarId(id: string): id is AvatarId {
  return VALID_AVATAR_IDS.has(id);
}

export function getAvatarSpec(id: AvatarId | string): AvatarSpec {
  return AVATARS.find((a) => a.id === id) ?? AVATARS[0];
}
