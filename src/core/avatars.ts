import type { AvatarId, LocalizedText } from './types';

export interface AvatarSpec {
  id: AvatarId;
  name: LocalizedText;
  modelName: string;
  scale3D: number;
}

export const AVATARS: AvatarSpec[] = [
  {
    id: 'sari',
    name: { id: 'Sari', en: 'Sari' },
    modelName: 'casual-female.glb',
    scale3D: 0.56,
  },
  {
    id: 'maya',
    name: { id: 'Maya', en: 'Maya' },
    modelName: 'casual-2-female.glb',
    scale3D: 0.56,
  },
  {
    id: 'budi',
    name: { id: 'Budi', en: 'Budi' },
    modelName: 'casual-male.glb',
    scale3D: 0.56,
  },
  {
    id: 'eko',
    name: { id: 'Pak Eko', en: 'Pak Eko' },
    modelName: 'casual-2-male.glb',
    scale3D: 0.56,
  },
];

const VALID_AVATAR_IDS = new Set<string>(AVATARS.map((a) => a.id));

export function isValidAvatarId(id: string): id is AvatarId {
  return VALID_AVATAR_IDS.has(id);
}

export function getAvatarSpec(id: AvatarId | string): AvatarSpec {
  return AVATARS.find((a) => a.id === id) ?? AVATARS[0];
}
