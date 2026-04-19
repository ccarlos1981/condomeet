from pathlib import Path

filepath = Path("supabase/functions/whatsapp-chatbot/index.ts")
text = filepath.read_text()
text = text.replace('"IGNORED" ?? ""', '"IGNORED"')
filepath.write_text(text)
