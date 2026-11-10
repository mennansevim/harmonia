// Media and Drive-connect handlers against the local database, with a disk
// Drive. Needs `supabase start`, then:
//   SUPABASE_URL=… SUPABASE_ANON_KEY=… SUPABASE_SERVICE_ROLE_KEY=… \
//     deno test -A supabase/functions/tests/
import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import { DiskDrive } from "../_shared/dev_drive.ts";
import { createMediaHandler, DriveContext } from "../_shared/media_core.ts";
import { createOAuthHandler, signState } from "../_shared/oauth_core.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(url, serviceKey, opts);
const run = crypto.randomUUID().slice(0, 8);
const dir = await Deno.makeTempDir();
const disk = new DiskDrive(dir, "http://local/upload");

async function person(name: string) {
  const email = `${name}.${run}@resonia.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: "local-test-only-pw",
    email_confirm: true,
  });
  if (error) throw error;
  const client = createClient(url, anonKey, opts);
  const { data } = await client.auth.signInWithPassword({
    email,
    password: "local-test-only-pw",
  });
  return { client, id: data.user!.id, token: data.session!.access_token };
}

async function rpc<T>(c: SupabaseClient, fn: string, args: Record<string, unknown>) {
  const { data, error } = await c.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.message}`);
  return data as T;
}

const driveFor = async (choirId: string): Promise<DriveContext | null> => {
  const { data } = await admin.rpc("_drive_token", { c: choirId });
  const row = (data ?? [])[0];
  return row
    ? {
      drive: disk,
      root: row.root,
      folders: { ...row.folders },
      saveFolders: async (f) => {
        await admin.rpc("_save_drive_folders", { c: choirId, f });
      },
    }
    : null;
};
const media = createMediaHandler({ supabaseUrl: url, anonKey, admin, driveFor });
const secret = "test-state-secret";
const oauth = createOAuthHandler({
  supabaseUrl: url,
  anonKey,
  admin,
  clientId: "cid",
  clientSecret: "cs",
  stateSecret: secret,
  redirectUri: "http://local/drive-oauth/callback",
  exchange: async (code) =>
    code === "good"
      ? { refresh: "refresh-1", access: "a", email: "koro@gmail.com" }
      : { refresh: "", access: "a", email: "x" },
  driveWith: () => disk,
  now: () => Date.now(),
});

const call = (h: (r: Request) => Promise<Response>, token: string, method: string, path: string, body?: unknown) =>
  h(new Request(`http://local${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  }));

// The choir: conductor, soprano leader, soprano, alto. Another conductor.
const sef = await person("sef");
const lider = await person("lider");
const sop = await person("sop");
const alto = await person("alto");
const other = await person("baska");
const choirId = await rpc<string>(sef.client, "create_choir", { choir_name: "Deno Korosu", conductor_name: "Şef" });
const code = await rpc<string>(sef.client, "create_invite", { c: choirId });
for (const [p, part] of [[lider, "soprano"], [sop, "soprano"], [alto, "alto"]] as const) {
  const req = await rpc<string>(p.client, "request_join", { invite_code: code, name: "K", wanted: part });
  await rpc(sef.client, "decide_join", { request_id: req, approve: true });
}
await rpc(sef.client, "set_section_leader", { c: choirId, singer: lider.id, leads: true });
const otherChoir = await rpc<string>(other.client, "create_choir", { choir_name: "Başka", conductor_name: "B" });

async function uploadBytes(
  who: { token: string },
  choir: string,
  kind: string,
  bytes: Uint8Array,
  extra: Record<string, unknown> = { work: "Gloria", name: "Gloria 1–24 · deneme 1" },
) {
  const res = await call(media, who.token, "POST", "/media/upload", {
    choirId: choir, kind, ext: "wav", mime: "audio/wav", size: bytes.length, ...extra,
  });
  if (res.status !== 200) return { status: res.status };
  const { mediaId, uploadUrl } = await res.json();
  const driveId = uploadUrl.split("/").pop();
  const put = await disk.receive(driveId, new Request(uploadUrl, { method: "PUT", body: new Blob([bytes as BlobPart]) }));
  assertEquals(put.status, 200);
  return { status: 200, mediaId, driveId: (await put.json()).id as string };
}

Deno.test("drive connect: only the conductor, only with a valid state", async () => {
  const notAllowed = await call(oauth, sop.token, "POST", "/drive-oauth/start", { choirId });
  assertEquals(notAllowed.status, 403);
  await notAllowed.body?.cancel();

  const start = await call(oauth, sef.token, "POST", "/drive-oauth/start", { choirId });
  const { url: consent } = await start.json();
  const state = new URL(consent).searchParams.get("state")!;
  assert(consent.startsWith("https://accounts.google.com/"));
  assert(new URL(consent).searchParams.get("scope")!.includes("drive.file"));

  const tampered = await oauth(new Request(`http://local/drive-oauth/callback?code=good&state=${state}x`));
  assertEquals(tampered.status, 400);
  await tampered.body?.cancel();
  const expired = await signState(secret, { c: choirId, u: sef.id, exp: Date.now() - 1 });
  const late = await oauth(new Request(`http://local/drive-oauth/callback?code=good&state=${expired}`));
  assertEquals(late.status, 400);
  await late.body?.cancel();
  const forged = await signState(secret, { c: choirId, u: sop.id, exp: Date.now() + 60000 });
  const wrongUser = await oauth(new Request(`http://local/drive-oauth/callback?code=good&state=${forged}`));
  assertEquals(wrongUser.status, 403);
  await wrongUser.body?.cancel();

  const ok = await oauth(new Request(`http://local/drive-oauth/callback?code=good&state=${state}`));
  assertEquals(ok.status, 200);
  assert((await ok.text()).includes("koro@gmail.com"));
  const status = await rpc<Array<{ connected: boolean; google_email: string }>>(
    sef.client, "drive_status", { c: choirId },
  );
  assertEquals([status[0].connected, status[0].google_email], [true, "koro@gmail.com"]);
});

Deno.test("uploads: who may start, Drive must be connected", async () => {
  assertEquals((await uploadBytes(sop, choirId, "repertoire", new Uint8Array([1]))).status, 403);
  assertEquals((await uploadBytes(alto, otherChoir, "take", new Uint8Array([1]))).status, 403);
  assertEquals((await uploadBytes(other, otherChoir, "repertoire", new Uint8Array([1]))).status, 409);
  const tooBig = await call(media, sop.token, "POST", "/media/upload", {
    choirId, kind: "take", ext: "wav", mime: "audio/wav", size: 300 * 1024 * 1024,
  });
  assertEquals(tooBig.status, 400);
  await tooBig.body?.cancel();
});

Deno.test("take: upload, finalize, part-only listening, forward to conductor", async () => {
  const bytes = new Uint8Array([82, 73, 70, 70, 1, 2, 3, 4]);
  const up = await uploadBytes(sop, choirId, "take", bytes);
  assertEquals(up.status, 200);
  const path = await disk.pathOf(up.driveId!);
  const day = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Istanbul" });
  assertEquals(
    path,
    `Vocalart/Deno Korosu/Eserler/Gloria/Kayıtlar/Soprano/${day} · K · Gloria 1–24 · deneme 1.wav`,
  );

  // Someone else cannot finalize it, nor bind another Drive file to it.
  const stranger = await call(media, alto.token, "POST", "/media/finalize", { mediaId: up.mediaId, driveFileId: up.driveId });
  assertEquals(stranger.status, 404);
  await stranger.body?.cancel();
  const altoUp = await uploadBytes(alto, choirId, "take", new Uint8Array([9, 9]));
  const swapped = await call(media, sop.token, "POST", "/media/finalize", { mediaId: up.mediaId, driveFileId: altoUp.driveId });
  assertEquals(swapped.status, 409);
  await swapped.body?.cancel();

  const fin = await call(media, sop.token, "POST", "/media/finalize", { mediaId: up.mediaId, driveFileId: up.driveId });
  assertEquals(await fin.json(), { mediaId: up.mediaId, ext: "wav" });

  // Not yet sent: only the owner hears it.
  const leaderEarly = await call(media, lider.token, "GET", `/media/${up.mediaId}`);
  assertEquals(leaderEarly.status, 404);
  await leaderEarly.body?.cancel();
  const own = await call(media, sop.token, "GET", `/media/${up.mediaId}`);
  assertEquals(new Uint8Array(await own.arrayBuffer()), bytes);

  await rpc(sef.client, "put_item", {
    c: choirId, k: "assignment", item_id: "a1",
    item: { id: "a1", choirId, pieces: [] },
  });
  const sub = await rpc<string>(sop.client, "submit_take", {
    c: choirId, assignment: "a1", piece: "p1", file_id: up.mediaId, duration: 1000, sung: "unaccompanied",
  });

  const heard = await call(media, lider.token, "GET", `/media/${up.mediaId}`);
  assertEquals(new Uint8Array(await heard.arrayBuffer()), bytes);
  for (const [who, why] of [[alto, "another part"], [sef, "conductor before forwarding"], [other, "another choir"]] as const) {
    const res = await call(media, who.token, "GET", `/media/${up.mediaId}`);
    assertEquals(res.status, 404, why);
    await res.body?.cancel();
  }

  await rpc(lider.client, "leader_decide", { sub_id: sub, forward: true, body: "Temiz" });
  const conductor = await call(media, sef.token, "GET", `/media/${up.mediaId}`);
  assertEquals(conductor.status, 200);
  await conductor.body?.cancel();
});

Deno.test("layout: works, parts, library shelves; folders reused", async () => {
  const midi = await uploadBytes(sef, choirId, "repertoire", new Uint8Array([1]), {
    work: "gloria ", name: "gloria-satb.wav",
  });
  const day = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Istanbul" });
  assertEquals(await disk.pathOf(midi.driveId!), "Vocalart/Deno Korosu/Eserler/Gloria/MIDI ve nota/gloria-satb.wav");
  const score = await uploadBytes(sef, choirId, "repertoire", new Uint8Array([1]), {
    shelf: "score", name: "Gloria nota",
  });
  assertEquals(await disk.pathOf(score.driveId!), "Vocalart/Deno Korosu/Kaynaklar/Notalar/Gloria nota.wav");
  const altoTake = await uploadBytes(alto, choirId, "take", new Uint8Array([1]), { work: "Gloria", name: "x" });
  assertEquals(await disk.pathOf(altoTake.driveId!), `Vocalart/Deno Korosu/Eserler/Gloria/Kayıtlar/Alto/${day} · K · x.wav`);
  const note = await uploadBytes(lider, choirId, "voice_note", new Uint8Array([1]), {
    work: "Gloria", part: "soprano", name: "K",
  });
  assertEquals(await disk.pathOf(note.driveId!), `Vocalart/Deno Korosu/Eserler/Gloria/Kayıtlar/Soprano/${day} · K notu · K.wav`);
  // One Vocalart folder, one choir folder, one "Gloria" folder.
  const metas: Array<{ folder?: boolean; name: string }> = [];
  for await (const e of Deno.readDir(dir)) {
    if (e.name.endsWith(".json")) metas.push(JSON.parse(await Deno.readTextFile(`${dir}/${e.name}`)));
  }
  const folders = (n: string) => metas.filter((m) => m.folder && m.name === n).length;
  assertEquals([folders("Vocalart"), folders("Deno Korosu"), folders("Gloria")], [1, 1, 1]);
});



Deno.test({
  name: "cleanup",
  fn: async () => {
    await Deno.remove(dir, { recursive: true });
  },
  sanitizeResources: false,
});
