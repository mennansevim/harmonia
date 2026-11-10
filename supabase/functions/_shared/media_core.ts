// Media endpoints (ADR-041), written against injected dependencies so tests
// can run them with a memory Drive and the local database.
//
//   POST /media/upload    {choirId, kind, ext, mime, size, name?}
//        → {mediaId, uploadUrl}     (caller PUTs the bytes to uploadUrl)
//   POST /media/finalize  {mediaId, driveFileId} → {mediaId, ext}
//   GET  /media/<mediaId>            → the bytes, after can_read_media()
//
// The Drive file id never reaches the client; finalize accepts a Drive file
// only if it carries this media id in its appProperties.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import type { DriveApi } from "./drive.ts";
import { clean, ensurePath, PART_TITLES, SHELVES, today } from "./layout.ts";

export interface DriveContext {
  drive: DriveApi;
  root: string;
  folders: Record<string, string>;
  saveFolders(folders: Record<string, string>): Promise<void>;
}

export interface MediaDeps {
  supabaseUrl: string;
  anonKey: string;
  admin: SupabaseClient;
  driveFor(choirId: string): Promise<DriveContext | null>;
}

const KINDS = ["repertoire", "take", "voice_note"] as const;
type Kind = typeof KINDS[number];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const MAX = 200 * 1024 * 1024;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
const fail = (status: number, error: string) => json({ error }, status);


export function createMediaHandler(deps: MediaDeps) {
  const userClient = (req: Request) => {
    const auth = req.headers.get("authorization") ?? "";
    return createClient(deps.supabaseUrl, deps.anonKey, {
      global: { headers: { authorization: auth } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
  };

  // Checks the caller's token; a client with no global auth header, since
  // two Authorization headers make the auth server refuse the call.
  const verifier = createClient(deps.supabaseUrl, deps.anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  async function who(req: Request) {
    const client = userClient(req);
    const { data } = await verifier.auth.getUser(
      (req.headers.get("authorization") ?? "").replace(/^Bearer /i, ""),
    );
    return data.user ? { client, userId: data.user.id } : null;
  }

  async function memberOf(choirId: string, userId: string) {
    const { data } = await deps.admin
      .from("members").select("part, display_name")
      .eq("choir_id", choirId).eq("user_id", userId).maybeSingle();
    return { part: data?.part as string | null, name: data?.display_name ?? "" };
  }

  /** Folder and file name for an upload (see layout.ts). */
  async function placeOf(
    b: Record<string, unknown>,
    kind: Kind,
    ext: string,
    userId: string,
  ): Promise<{ folder: string[]; name: string }> {
    const label = clean(b.name, "");
    const work = clean(b.work, "Adsız eser");
    if (kind === "repertoire") {
      const folder = b.work
        ? ["Eserler", work, "MIDI ve nota"]
        : ["Kaynaklar", SHELVES[String(b.shelf)] ?? SHELVES.other];
      const base = label.replace(new RegExp(`\\.${ext}$`, "i"), "");
      return { folder, name: `${base || today()}.${ext}` };
    }
    const me = await memberOf(String(b.choirId), userId);
    const part = kind === "take" ? me.part : String(b.part ?? "");
    const partFolder = PART_TITLES[part ?? ""] ?? "Partisiz";
    const who = kind === "take" ? me.name : `${me.name} notu`;
    return {
      folder: ["Eserler", work, "Kayıtlar", partFolder],
      name: [today(), clean(who, "Koro"), label].filter(Boolean).join(" · ") +
        `.${ext}`,
    };
  }

  async function upload(req: Request) {
    const me = await who(req);
    if (!me) return fail(401, "not signed in");
    const b = await req.json().catch(() => null);
    const kind = b?.kind as Kind;
    const ext = String(b?.ext ?? "").toLowerCase();
    const size = Number(b?.size);
    if (
      !UUID.test(b?.choirId ?? "") || !KINDS.includes(kind) ||
      !/^[a-z0-9]{1,5}$/.test(ext) || !Number.isInteger(size) ||
      size <= 0 || size > MAX || typeof b?.mime !== "string"
    ) {
      return fail(400, "bad request");
    }
    const { data: allowed } = await me.client.rpc("can_upload_media", {
      c: b.choirId,
      k: kind,
    });
    if (allowed !== true) return fail(403, "not allowed");
    const ctx = await deps.driveFor(b.choirId);
    if (!ctx) return fail(409, "drive not connected");

    const { data: row, error } = await deps.admin.from("media").insert({
      choir_id: b.choirId,
      kind,
      owner_id: me.userId,
      ext,
      mime: b.mime,
      size_bytes: size,
    }).select("id").single();
    if (error || !row) return fail(500, "could not start");
    const place = await placeOf(b, kind, ext, me.userId);
    const parent = await ensurePath(ctx, place.folder);
    const uploadUrl = await ctx.drive.startUpload({
      name: place.name,
      mime: b.mime,
      size,
      parent,
      appProperties: { mediaId: row.id, choirId: b.choirId },
    });
    return json({ mediaId: row.id, uploadUrl });
  }

  async function finalize(req: Request) {
    const me = await who(req);
    if (!me) return fail(401, "not signed in");
    const b = await req.json().catch(() => null);
    if (!UUID.test(b?.mediaId ?? "") || typeof b?.driveFileId !== "string") {
      return fail(400, "bad request");
    }
    const { data: m } = await deps.admin.from("media").select("*")
      .eq("id", b.mediaId).maybeSingle();
    if (!m || m.owner_id !== me.userId) return fail(404, "no such file");
    if (m.status === "ready") return json({ mediaId: m.id, ext: m.ext });
    const ctx = await deps.driveFor(m.choir_id);
    if (!ctx) return fail(409, "drive not connected");
    const file = await ctx.drive.getFile(b.driveFileId);
    if (
      !file || file.appProperties.mediaId !== m.id ||
      file.appProperties.choirId !== m.choir_id || file.size !== m.size_bytes
    ) {
      return fail(409, "upload does not match");
    }
    const { error } = await deps.admin.from("media")
      .update({ status: "ready", drive_file_id: file.id })
      .eq("id", m.id).eq("status", "pending");
    if (error) return fail(500, "could not finish");
    return json({ mediaId: m.id, ext: m.ext });
  }

  async function serve(req: Request, mediaId: string) {
    const me = await who(req);
    if (!me) return fail(401, "not signed in");
    if (!UUID.test(mediaId)) return fail(400, "bad request");
    const { data: ok } = await me.client.rpc("can_read_media", { m: mediaId });
    if (ok !== true) return fail(404, "no such file");
    const { data: m } = await deps.admin.from("media")
      .select("choir_id, drive_file_id, mime, size_bytes")
      .eq("id", mediaId).single();
    const ctx = await deps.driveFor(m!.choir_id);
    if (!ctx) return fail(409, "drive not connected");
    const res = await ctx.drive.download(m!.drive_file_id);
    return new Response(res.body, {
      headers: {
        "content-type": m!.mime,
        "content-length": String(m!.size_bytes),
        "cache-control": "private, no-store",
      },
    });
  }

  return async (req: Request): Promise<Response> => {
    const path = new URL(req.url).pathname.replace(/^.*\/media/, "");
    try {
      if (req.method === "POST" && path === "/upload") return await upload(req);
      if (req.method === "POST" && path === "/finalize") return await finalize(req);
      if (req.method === "GET" && /^\/[0-9a-f-]{36}$/.test(path)) {
        return await serve(req, path.slice(1));
      }
      return fail(404, "not found");
    } catch (e) {
      console.error(e);
      return fail(502, "drive unavailable");
    }
  };
}
