// Google Drive as the choir's file store (ADR-041). Only these calls are used,
// all with the drive.file scope: the app sees only files it created.

export interface DriveFile {
  id: string;
  size: number;
  appProperties: Record<string, string>;
  parents: string[];
}

export interface DriveApi {
  createFolder(
    name: string,
    parent?: string,
    appProperties?: Record<string, string>,
  ): Promise<string>;
  /** A folder this app made earlier with [name] under [parent] (or the
   * Drive root), if it is still there and not in the bin. With [tag], the
   * folder is found by that app property instead of its name. */
  findFolder(
    name: string,
    parent?: string,
    tag?: [string, string],
  ): Promise<string | null>;
  /** Starts a resumable upload; the returned URL takes the bytes (PUT). */
  startUpload(opts: {
    name: string;
    mime: string;
    size: number;
    parent: string;
    appProperties: Record<string, string>;
  }): Promise<string>;
  getFile(id: string): Promise<DriveFile | null>;
  download(id: string): Promise<Response>;
}

const API = "https://www.googleapis.com/drive/v3";
const UPLOAD = "https://www.googleapis.com/upload/drive/v3";
const FOLDER = "application/vnd.google-apps.folder";

export class GoogleDrive implements DriveApi {
  constructor(private token: string) {}

  private headers(extra: Record<string, string> = {}) {
    return { authorization: `Bearer ${this.token}`, ...extra };
  }

  async createFolder(
    name: string,
    parent?: string,
    appProperties?: Record<string, string>,
  ): Promise<string> {
    const res = await fetch(`${API}/files?fields=id`, {
      method: "POST",
      headers: this.headers({ "content-type": "application/json" }),
      body: JSON.stringify({
        name,
        mimeType: FOLDER,
        ...(parent ? { parents: [parent] } : {}),
        ...(appProperties ? { appProperties } : {}),
      }),
    });
    if (!res.ok) throw new Error(`drive folder ${res.status}`);
    return (await res.json()).id;
  }

  async findFolder(
    name: string,
    parent?: string,
    tag?: [string, string],
  ): Promise<string | null> {
    const quote = (t: string) => t.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
    const q = [
      `mimeType = '${FOLDER}'`,
      tag
        ? `appProperties has { key='${quote(tag[0])}' and value='${quote(tag[1])}' }`
        : `name = '${quote(name)}'`,
      `'${parent ?? "root"}' in parents`,
      "trashed = false",
    ].join(" and ");
    const res = await fetch(
      `${API}/files?${new URLSearchParams({ q, fields: "files(id)", pageSize: "1" })}`,
      { headers: this.headers() },
    );
    if (!res.ok) throw new Error(`drive find ${res.status}`);
    return (await res.json()).files?.[0]?.id ?? null;
  }

  async startUpload(o: {
    name: string;
    mime: string;
    size: number;
    parent: string;
    appProperties: Record<string, string>;
  }): Promise<string> {
    const res = await fetch(`${UPLOAD}/files?uploadType=resumable&fields=id`, {
      method: "POST",
      headers: this.headers({
        "content-type": "application/json; charset=UTF-8",
        "x-upload-content-type": o.mime,
        "x-upload-content-length": String(o.size),
      }),
      body: JSON.stringify({
        name: o.name,
        parents: [o.parent],
        appProperties: o.appProperties,
      }),
    });
    const url = res.headers.get("location");
    await res.body?.cancel();
    if (!res.ok || !url) throw new Error(`drive upload ${res.status}`);
    return url;
  }

  async getFile(id: string): Promise<DriveFile | null> {
    const res = await fetch(
      `${API}/files/${encodeURIComponent(id)}?fields=id,size,appProperties,parents`,
      { headers: this.headers() },
    );
    if (res.status === 404) {
      await res.body?.cancel();
      return null;
    }
    if (!res.ok) throw new Error(`drive get ${res.status}`);
    const f = await res.json();
    return {
      id: f.id,
      size: Number(f.size ?? 0),
      appProperties: f.appProperties ?? {},
      parents: f.parents ?? [],
    };
  }

  async download(id: string): Promise<Response> {
    const res = await fetch(`${API}/files/${encodeURIComponent(id)}?alt=media`, {
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`drive download ${res.status}`);
    return res;
  }
}

/** Google OAuth (web client) endpoints. */
export const google = {
  authUrl: "https://accounts.google.com/o/oauth2/v2/auth",
  tokenUrl: "https://oauth2.googleapis.com/token",
  userInfoUrl: "https://openidconnect.googleapis.com/v1/userinfo",
  scope: "openid email https://www.googleapis.com/auth/drive.file",
};

export async function accessTokenFrom(
  refresh: string,
  clientId: string,
  clientSecret: string,
): Promise<string> {
  const res = await fetch(google.tokenUrl, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refresh,
      grant_type: "refresh_token",
    }),
  });
  if (!res.ok) throw new Error(`google token ${res.status}`);
  return (await res.json()).access_token;
}
