import { normalizePhone } from "./functions/_shared/botconversa.ts";

const API_KEY = Deno.env.get("BOTCONVERSA_API_KEY") || "b6cb1e97-ce74-4b53-b09e-7360fb7f827d";

async function run() {
  const phone = normalizePhone("5531992707070");
  console.log("Resolving phone:", phone);

  // POST /subscriber/ to get the ID
  const subRes = await fetch(`https://backend.botconversa.com.br/api/v1/webhook/subscriber/`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "API-KEY": API_KEY,
    },
    body: JSON.stringify({ phone, first_name: "Test", last_name: "." }),
  });

  const subData = await subRes.json();
  console.log("Subscriber Data:", subData);
  
  if (subData.id) {
    // Try to get full subscriber info to see if last message is there
    const getRes = await fetch(`https://backend.botconversa.com.br/api/v1/webhook/subscriber/${subData.id}/`, {
      headers: { "API-KEY": API_KEY }
    });
    console.log("GET Subscriber:", await getRes.json());
  }
}

run();
