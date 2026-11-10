import { createMediaHandler } from "../_shared/media_core.ts";
import { admin, anonKey, devDrive, driveFor, supabaseUrl } from "../_shared/env.ts";

const handle = createMediaHandler({ supabaseUrl, anonKey, admin, driveFor });

Deno.serve((req) => {
  // Local stack only: the disk Drive's stand-in for a resumable upload URL.
  const dev = new URL(req.url).pathname.match(/\/media\/dev-upload\/([a-z0-9-]+)$/);
  if (dev && devDrive && req.method === "PUT") return devDrive.receive(dev[1], req);
  return handle(req);
});
