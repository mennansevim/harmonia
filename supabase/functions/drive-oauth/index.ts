import { createOAuthHandler, googleExchange } from "../_shared/oauth_core.ts";
import {
  admin, anonKey, clientId, clientSecret, devDrive, driveWith, publicUrl,
  stateSecret, supabaseUrl,
} from "../_shared/env.ts";

const redirectUri = `${publicUrl}/drive-oauth/callback`;

const handle = createOAuthHandler({
  supabaseUrl,
  anonKey,
  admin,
  clientId: devDrive ? "dev" : clientId,
  clientSecret,
  stateSecret,
  redirectUri,
  exchange: devDrive
    ? async () => ({ refresh: "dev", access: "dev", email: "yerel-drive@dev.local" })
    : googleExchange(clientId, clientSecret, redirectUri),
  driveWith,
  now: () => Date.now(),
  devConsent: !!devDrive,
});

Deno.serve(handle);
