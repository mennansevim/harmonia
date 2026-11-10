// Connecting the choir's Google account to Drive (ADR-041), in the browser:
//
//   POST /drive-oauth/start {choirId}  (conductor, signed in)
//        → {url}  Google's consent page; the app opens it in the browser
//   GET  /drive-oauth/callback?code&state
//        → exchanges the code, keeps the refresh token in Vault, makes the
//          choir's folders, and shows "connected, return to the app".
//
// state is signed (HMAC-SHA256) and lasts 10 minutes, so a callback can only
// finish a start made by that choir's conductor.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import { DriveApi, google } from "./drive.ts";
import { choirRoot } from "./layout.ts";

export interface OAuthDeps {
  supabaseUrl: string;
  anonKey: string;
  admin: SupabaseClient;
  clientId: string;
  clientSecret: string;
  stateSecret: string;
  /** Public URL of /drive-oauth/callback, as registered in Google Cloud. */
  redirectUri: string;
  /** Code → tokens; replaced in tests. */
  exchange(code: string): Promise<{ refresh: string; access: string; email: string }>;
  driveWith(accessToken: string): DriveApi;
  now(): number;
  /** Local stack: skip Google and go straight to the callback. */
  devConsent?: boolean;
}

const enc = new TextEncoder();
const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_")
    .replace(/=+$/, "");

async function hmac(secret: string, text: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return b64url(new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(text))));
}

export async function signState(
  secret: string,
  body: { c: string; u: string; exp: number },
): Promise<string> {
  const payload = b64url(enc.encode(JSON.stringify(body)));
  return `${payload}.${await hmac(secret, payload)}`;
}

export async function readState(
  secret: string,
  state: string,
  now: number,
): Promise<{ c: string; u: string } | null> {
  const [payload, sig] = state.split(".");
  if (!payload || !sig || (await hmac(secret, payload)) !== sig) return null;
  try {
    const body = JSON.parse(
      atob(payload.replace(/-/g, "+").replace(/_/g, "/")),
    );
    return typeof body.exp === "number" && body.exp > now ? body : null;
  } catch {
    return null;
  }
}

const page = (title: string, body: string, status = 200) =>
  new Response(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><body style="font-family:system-ui;padding:32px;max-width:520px;margin:auto"><h2>${title}</h2><p>${body}</p></body>`,
    { status, headers: { "content-type": "text/html; charset=utf-8" } },
  );

export function createOAuthHandler(deps: OAuthDeps) {
  async function start(req: Request) {
    const auth = req.headers.get("authorization") ?? "";
    const client = createClient(deps.supabaseUrl, deps.anonKey, {
      global: { headers: { authorization: auth } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const verifier = createClient(deps.supabaseUrl, deps.anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data } = await verifier.auth.getUser(
      (req.headers.get("authorization") ?? "").replace(/^Bearer /i, ""),
    );
    if (!data.user) return Response.json({ error: "not signed in" }, { status: 401 });
    const b = await req.json().catch(() => null);
    const { data: conducts } = await client.rpc("is_conductor", { c: b?.choirId });
    if (conducts !== true) return Response.json({ error: "not allowed" }, { status: 403 });
    const state = await signState(deps.stateSecret, {
      c: b.choirId,
      u: data.user.id,
      exp: deps.now() + 10 * 60 * 1000,
    });
    if (deps.devConsent) {
      return Response.json({
        url: `${deps.redirectUri}?${new URLSearchParams({ code: "dev", state })}`,
      });
    }
    const url = `${google.authUrl}?${new URLSearchParams({
      client_id: deps.clientId,
      redirect_uri: deps.redirectUri,
      response_type: "code",
      scope: google.scope,
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: "true",
      state,
    })}`;
    return Response.json({ url });
  }

  async function callback(url: URL) {
    const state = await readState(
      deps.stateSecret,
      url.searchParams.get("state") ?? "",
      deps.now(),
    );
    const code = url.searchParams.get("code");
    if (!state || !code) {
      return page("Bağlantı kurulamadı", "Bağlantının süresi dolmuş. Uygulamadan yeniden deneyin.", 400);
    }
    const { data: m } = await deps.admin.from("members").select("role")
      .eq("choir_id", state.c).eq("user_id", state.u).maybeSingle();
    const { data: choir } = await deps.admin.from("choirs").select("name")
      .eq("id", state.c).maybeSingle();
    if (m?.role !== "conductor" || !choir) {
      return page("Bağlantı kurulamadı", "Bu koroya Drive bağlama yetkiniz yok.", 403);
    }
    const tokens = await deps.exchange(code);
    if (!tokens.refresh) {
      return page("Bağlantı kurulamadı", "Google uzun süreli izin vermedi. Yeniden deneyin.", 400);
    }
    const drive = deps.driveWith(tokens.access);
    // Vocalart/<Choir>; subfolders are made on first use (layout.ts).
    const root = await choirRoot(drive, state.c, choir.name);
    const folders = {};
    const { error } = await deps.admin.rpc("_store_drive", {
      c: state.c,
      email: tokens.email,
      refresh: tokens.refresh,
      root,
      f: folders,
      by_user: state.u,
    });
    if (error) throw error;
    return page(
      "Drive bağlandı",
      `${choir.name} korosunun dosyaları ${tokens.email} hesabının Drive'ında “Vocalart / ${choir.name}” klasöründe tutulacak: eserler, partilere göre kayıtlar ve kaynaklar. Uygulamaya dönebilirsiniz.`,
    );
  }

  return async (req: Request): Promise<Response> => {
    const url = new URL(req.url);
    const path = url.pathname.replace(/^.*\/drive-oauth/, "");
    try {
      if (req.method === "POST" && path === "/start") return await start(req);
      if (req.method === "GET" && path === "/callback") return await callback(url);
      return Response.json({ error: "not found" }, { status: 404 });
    } catch (e) {
      console.error(e);
      return page("Bağlantı kurulamadı", "Google'a ulaşılamadı. Yeniden deneyin.", 502);
    }
  };
}

/** Real code exchange against Google. */
export function googleExchange(clientId: string, clientSecret: string, redirectUri: string) {
  return async (code: string) => {
    const res = await fetch(google.tokenUrl, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code,
        grant_type: "authorization_code",
        redirect_uri: redirectUri,
      }),
    });
    if (!res.ok) throw new Error(`google code ${res.status}`);
    const t = await res.json();
    const info = await fetch(google.userInfoUrl, {
      headers: { authorization: `Bearer ${t.access_token}` },
    }).then((r) => r.json());
    return { refresh: t.refresh_token ?? "", access: t.access_token, email: info.email ?? "" };
  };
}
