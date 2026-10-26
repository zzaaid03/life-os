// Package sentences for the daily brief. Pure: the caller loads the rows.

export interface BriefPackage {
  merchant: string | null;
  item: string | null;
  status: string;
  expected_date: string | null; // "YYYY-MM-DD"
  delivered_at: string | null; // ISO
}

const DAY_MS = 86400000;
const MAX_NAMED = 3;

function labelOf(p: BriefPackage): string | null {
  const merchant = p.merchant?.trim();
  if (merchant) return merchant;
  const item = p.item?.trim();
  return item ? item : null;
}

function joinNames(names: string[]): string {
  if (names.length === 1) return names[0];
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}

// One sentence for a group, or null when it is empty.
function sentence(
  group: BriefPackage[],
  single: string,
  plural: string,
): string | null {
  if (group.length === 0) return null;
  const labels = group.map(labelOf).filter((l): l is string => l !== null);
  if (group.length === 1) {
    return labels.length === 1
      ? `Your ${labels[0]} package ${single}.`
      : `A package ${single}.`;
  }
  const head = `${group.length} packages ${plural}`;
  if (labels.length === 0) return `${head}.`;
  const named = labels.slice(0, MAX_NAMED);
  const rest = group.length - named.length;
  const list = rest > 0
    ? `${named.join(", ")} and ${rest} more`
    : joinNames(named);
  return `${head}: ${list}.`;
}

export function packageSentences(args: {
  packages: BriefPackage[];
  now: Date;
  tzOffsetMinutes: number;
}): string[] {
  const offsetMs = args.tzOffsetMinutes * 60000;
  const localNow = args.now.getTime() + offsetMs;
  const today = new Date(localNow).toISOString().slice(0, 10);
  const dayStart = Math.floor(localNow / DAY_MS) * DAY_MS - offsetMs;
  const dayEnd = dayStart + DAY_MS;

  const out = args.packages.filter((p) => p.status === "out_for_delivery");
  const expected = args.packages.filter((p) =>
    (p.status === "ordered" || p.status === "shipped") &&
    p.expected_date === today
  );
  const delivered = args.packages.filter((p) => {
    if (p.status !== "delivered" || !p.delivered_at) return false;
    const t = new Date(p.delivered_at).getTime();
    return t >= dayStart && t < dayEnd;
  });

  return [
    sentence(out, "is out for delivery", "are out for delivery"),
    sentence(expected, "is expected today", "are expected today"),
    sentence(delivered, "was delivered today", "were delivered today"),
  ].filter((s): s is string => s !== null);
}
