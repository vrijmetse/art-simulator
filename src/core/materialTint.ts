export interface ActorTintOptions {
  skinHex?: string;
  shirtHex?: string;
  hairHex?: string;
}

export function resolveActorMaterialColor(
  matName: string,
  shirtHex?: string,
  skinHex?: string,
  hairHex?: string,
): string | null {
  const key = matName.trim().toLowerCase();
  if (key === 'skin' && skinHex) return skinHex;
  if (key === 'shirt' && shirtHex) return shirtHex;
  if (key === 'hair' && hairHex) return hairHex;
  return null;
}
