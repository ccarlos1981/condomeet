console.log("Hello from Magiclink Edge Function!");
import { createClient } from 'jsr:@supabase/supabase-js@2';
// Inicializa o cliente do Supabase com as variáveis de ambiente
const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
Deno.serve(async (req)=>{
  // Verifica se veio o header com a service_role_key
  const authHeader = req.headers.get("authorization");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (authHeader !== `Bearer ${serviceRole}`) {
    return new Response("Unauthorized", {
      status: 401
    });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405
    });
  }
  try {
    // Extrai o email do corpo da requisição
    const { email } = await req.json();
    if (!email) {
      return new Response("Email is required", {
        status: 400
      });
    }
    // Gera o magiclink usando a função generateLink com o tipo "magiclink"
    const { data, error } = await supabaseClient.auth.admin.generateLink({
      type: 'magiclink',
      email,
      options: {
        redirectTo: 'https://home.condomeet.app.br/reset_pw_sb'
      }
    });
    if (error) {
      console.error("Erro ao gerar magiclink:", error.message);
      return new Response(JSON.stringify({
        error: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    // Imprime o resultado do generateLink no console
    console.log("Resultado do generateLink:", data);
    // Retorna o resultado para facilitar os testes (remover em produção)
    return new Response(JSON.stringify({
      success: true,
      linkData: data
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Erro na função:", err.message);
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
});
