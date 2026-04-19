from pathlib import Path

functions_dir = Path("supabase/functions")

for filepath in functions_dir.rglob("*.ts"):
    text = filepath.read_text()
    
    if "UAZAPI_URL" in text or "UAZAPI_TOKEN" in text:
        text = text.replace("Deno.env.get('UAZAPI_URL')", '"IGNORED"')
        text = text.replace('Deno.env.get("UAZAPI_URL")', '"IGNORED"')
        text = text.replace("Deno.env.get('UAZAPI_TOKEN')", '"IGNORED"')
        text = text.replace('Deno.env.get("UAZAPI_TOKEN")', '"IGNORED"')
        
        # Sometimes there's a fallback e.g. Deno.env.get('UAZAPI_URL') || ''
        # No, replacing Deno.env.get(...) safely handles it:
        # const UAZAPI_URL = "IGNORED" || ''  <- still evaluates to "IGNORED", safe.
        
        filepath.write_text(text)

