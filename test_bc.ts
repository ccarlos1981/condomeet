import 'https://deno.land/x/dotenv/load.ts';
import { sendTextMessage } from "./supabase/functions/_shared/uazapi.ts"

async function test() {
  const result = await sendTextMessage("url", "token", "5531992707070", "Teste manual do Antigravity (Deploy)");
  console.log(result);
}

test();
