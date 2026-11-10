// Where things go in the choir's Drive (user decision 2026-11-10):
//
//   Vocalart/
//     <Choir>/                         (found by its choirId app property)
//       Eserler/<Work>/MIDI ve nota/   repertoire added with a piece
//       Eserler/<Work>/Kayıtlar/<Part>/ takes, and voice notes beside them
//       Kaynaklar/Notalar | Prova kayıtları | Diğer
//
// Work first: the repertoire is per work, the conductor sees all parts of
// a work together, and a section leader opens only their part's folder.
// Folder ids are cached in choir_drive.folders by path, so a folder is
// looked up once.

import type { DriveApi } from "./drive.ts";

export const ROOT = "Vocalart";

export const PART_TITLES: Record<string, string> = {
  soprano: "Soprano",
  alto: "Alto",
  tenor: "Tenor",
  bass: "Bas",
};

export const SHELVES: Record<string, string> = {
  score: "Notalar",
  rehearsal: "Prova kayıtları",
  other: "Diğer",
};

/** Safe for a Drive name: no slashes or control characters, short. */
export function clean(text: unknown, fallback: string): string {
  const t = String(text ?? "").replace(/[\\/:*?"<>|\u0000-\u001f]/g, " ")
    .replace(/\s+/g, " ").trim().slice(0, 80);
  return t || fallback;
}

/** "Gloria", "gloria " and "GLORIA" share one folder. */
export function keyOf(segments: string[]): string {
  return segments.map((s) => s.toLocaleLowerCase("tr")).join("/");
}

/** The Vocalart folder, then this choir's folder inside it. */
export async function choirRoot(
  drive: DriveApi,
  choirId: string,
  choirName: string,
): Promise<string> {
  const root = (await drive.findFolder(ROOT)) ?? (await drive.createFolder(ROOT));
  return (await drive.findFolder("", root, ["choirId", choirId])) ??
    (await drive.createFolder(clean(choirName, "Koro"), root, { choirId }));
}

/** Finds or makes [segments] under the choir folder; caches the ids. */
export async function ensurePath(
  ctx: {
    drive: DriveApi;
    root: string;
    folders: Record<string, string>;
    saveFolders(f: Record<string, string>): Promise<void>;
  },
  segments: string[],
): Promise<string> {
  let parent = ctx.root;
  let changed = false;
  for (let i = 0; i < segments.length; i++) {
    const key = `p:${keyOf(segments.slice(0, i + 1))}`;
    let id = ctx.folders[key];
    if (!id) {
      id = (await ctx.drive.findFolder(segments[i], parent)) ??
        (await ctx.drive.createFolder(segments[i], parent));
      ctx.folders[key] = id;
      changed = true;
    }
    parent = id;
  }
  if (changed) await ctx.saveFolders(ctx.folders);
  return parent;
}

/** Today in Istanbul, as 2026-11-10. */
export function today(now = new Date()): string {
  return now.toLocaleDateString("sv-SE", { timeZone: "Europe/Istanbul" });
}
