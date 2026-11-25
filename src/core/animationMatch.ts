export function resolveClipName(availableNames: string[], preferredTokens: string[]): string | null {
  if (availableNames.length === 0) return null;
  for (const token of preferredTokens) {
    const exact = availableNames.find((n) => n === token);
    if (exact) return exact;
    const lower = token.toLowerCase();
    const suffix = availableNames.find((n) => {
      const nLower = n.toLowerCase();
      return nLower === lower || nLower.endsWith(`|${lower}`) || nLower.includes(lower);
    });
    if (suffix) return suffix;
  }
  return null;
}
