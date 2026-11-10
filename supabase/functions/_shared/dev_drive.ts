// A Drive stand-in on local disk, for the local stack and tests only. It is
// switched on by RESONIA_DEV_DRIVE=1 and refuses to run unless the
// Supabase URL is a local one (see devDriveAllowed).

import type { DriveApi, DriveFile } from "./drive.ts";

interface Meta {
  id: string;
  name: string;
  mime: string;
  size: number;
  parents: string[];
  appProperties: Record<string, string>;
  folder?: boolean;
  complete?: boolean;
}

export function devDriveAllowed(supabaseUrl: string): boolean {
  const host = new URL(supabaseUrl).hostname;
  return ["127.0.0.1", "localhost", "kong", "host.docker.internal"].includes(host);
}

export class DiskDrive implements DriveApi {
  /** [uploadBase]/<id> is where the app PUTs the bytes. */
  constructor(private dir: string, private uploadBase: string) {}

  private path(id: string) {
    if (!/^[a-z0-9-]{8,64}$/.test(id)) throw new Error("bad dev id");
    return `${this.dir}/${id}`;
  }

  private async readMeta(id: string): Promise<Meta | null> {
    try {
      return JSON.parse(await Deno.readTextFile(`${this.path(id)}.json`));
    } catch {
      return null;
    }
  }

  private async writeMeta(meta: Meta) {
    await Deno.mkdir(this.dir, { recursive: true });
    await Deno.writeTextFile(`${this.path(meta.id)}.json`, JSON.stringify(meta));
  }

  async createFolder(
    name: string,
    parent?: string,
    appProperties: Record<string, string> = {},
  ): Promise<string> {
    const id = `f-${crypto.randomUUID()}`;
    await this.writeMeta({
      id,
      name,
      mime: "folder",
      size: 0,
      parents: parent ? [parent] : [],
      appProperties,
      folder: true,
    });
    return id;
  }

  async findFolder(
    name: string,
    parent?: string,
    tag?: [string, string],
  ): Promise<string | null> {
    try {
      for await (const e of Deno.readDir(this.dir)) {
        if (!e.name.endsWith(".json")) continue;
        const m: Meta = JSON.parse(await Deno.readTextFile(`${this.dir}/${e.name}`));
        const named = tag ? m.appProperties[tag[0]] === tag[1] : m.name === name;
        if (m.folder && named && (m.parents[0] ?? undefined) === parent) {
          return m.id;
        }
      }
    } catch {
      // No folder yet.
    }
    return null;
  }

  async startUpload(o: {
    name: string;
    mime: string;
    size: number;
    parent: string;
    appProperties: Record<string, string>;
  }): Promise<string> {
    const id = `d-${crypto.randomUUID()}`;
    await this.writeMeta({
      id,
      name: o.name,
      mime: o.mime,
      size: o.size,
      parents: [o.parent],
      appProperties: o.appProperties,
    });
    return `${this.uploadBase}/${id}`;
  }

  /** The PUT a resumable session URL receives. Answers like Drive: {id}. */
  async receive(id: string, req: Request): Promise<Response> {
    const meta = await this.readMeta(id);
    if (!meta || meta.folder || meta.complete) {
      return new Response("no session", { status: 404 });
    }
    const bytes = new Uint8Array(await req.arrayBuffer());
    if (bytes.length !== meta.size) {
      return new Response("size mismatch", { status: 400 });
    }
    await Deno.writeFile(this.path(id), bytes);
    await this.writeMeta({ ...meta, complete: true });
    return Response.json({ id });
  }

  async getFile(id: string): Promise<DriveFile | null> {
    const meta = await this.readMeta(id);
    if (!meta || !meta.complete) return null;
    return {
      id,
      size: meta.size,
      appProperties: meta.appProperties,
      parents: meta.parents,
    };
  }

  async download(id: string): Promise<Response> {
    return new Response(await Deno.readFile(this.path(id)));
  }

  /** For tests: the folder a file went to, and its name. */
  async describe(id: string) {
    return await this.readMeta(id);
  }

  /** For tests: "Vocalart/Koro/Eserler/…/name" of a file. */
  async pathOf(id: string): Promise<string> {
    const parts: string[] = [];
    let meta = await this.readMeta(id);
    while (meta) {
      parts.unshift(meta.name);
      meta = meta.parents[0] ? await this.readMeta(meta.parents[0]) : null;
    }
    return parts.join("/");
  }
}
