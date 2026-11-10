// Wiring for the deployed functions. Secrets come from the function env:
// GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, DRIVE_STATE_SECRET,
// FUNCTIONS_PUBLIC_URL (e.g. https://<ref>.supabase.co/functions/v1).
// RESONIA_DEV_DRIVE=1 swaps Google for a disk folder on a local stack only.

import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { accessTokenFrom, DriveApi, GoogleDrive } from "./drive.ts";
import { DiskDrive, devDriveAllowed } from "./dev_drive.ts";
import type { DriveContext } from "./media_core.ts";

const env = (k: string) => Deno.env.get(k) ?? "";

export const supabaseUrl = env("SUPABASE_URL");
export const anonKey = env("SUPABASE_ANON_KEY");
export const admin = createClient(supabaseUrl, env("SUPABASE_SERVICE_ROLE_KEY"), {
  auth: { persistSession: false, autoRefreshToken: false },
});
export const publicUrl = env("FUNCTIONS_PUBLIC_URL").replace(/\/$/, "");
export const clientId = env("GOOGLE_CLIENT_ID");
export const clientSecret = env("GOOGLE_CLIENT_SECRET");
export const stateSecret = env("DRIVE_STATE_SECRET");

export const devDrive = env("RESONIA_DEV_DRIVE") === "1" && devDriveAllowed(supabaseUrl)
  ? new DiskDrive("/tmp/resonia-dev-drive", `${publicUrl}/media/dev-upload`)
  : null;

const tokens = new Map<string, { token: string; until: number }>();

export function driveWith(access: string): DriveApi {
  return devDrive ?? new GoogleDrive(access);
}

export async function driveFor(choirId: string): Promise<DriveContext | null> {
  const { data, error } = await admin.rpc("_drive_token", { c: choirId });
  if (error) throw error;
  const row = (data as Array<{ refresh: string; root: string; folders: Record<string, string> }>)[0];
  if (!row) return null;
  let drive: DriveApi;
  if (devDrive) {
    drive = devDrive;
  } else {
    const cached = tokens.get(choirId);
    let token = cached && cached.until > Date.now() ? cached.token : "";
    if (!token) {
      token = await accessTokenFrom(row.refresh, clientId, clientSecret);
      tokens.set(choirId, { token, until: Date.now() + 45 * 60 * 1000 });
    }
    drive = new GoogleDrive(token);
  }
  return {
    drive,
    root: row.root,
    folders: { ...row.folders },
    saveFolders: async (f) => {
      await admin.rpc("_save_drive_folders", { c: choirId, f });
    },
  };
}
