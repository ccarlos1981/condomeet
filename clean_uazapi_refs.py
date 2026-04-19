import re
from pathlib import Path
import os

functions_dir = Path("supabase/functions")

# Rename the shared module
shared_dir = functions_dir / "_shared"
old_shared = shared_dir / "uazapi.ts"
new_shared = shared_dir / "botconversa.ts"

if old_shared.exists():
    os.rename(old_shared, new_shared)

# Fix signature in botconversa.ts
content = new_shared.read_text()
content = re.sub(
    r'export async function sendTextMessage\([\s\S]*?phone: string,\s*message: string,?\s*\)',
    'export async function sendTextMessage(\n  phone: string,\n  message: string,\n)',
    content
)
content = re.sub(
    r'export async function sendImageMessage\([\s\S]*?phone: string,\s*imageUrl: string,?(?:\s*caption\?: string,?)?\s*\)',
    'export async function sendImageMessage(\n  phone: string,\n  imageUrl: string,\n  caption?: string,\n)',
    content
)
new_shared.write_text(content)

for filepath in functions_dir.rglob("*.ts"):
    if filepath.name == "botconversa.ts":
        continue

    text = filepath.read_text()

    if "uazapi" not in text.lower() and "uazapi" not in filepath.parts and "sendTextMessage" not in text and "sendImageMessage" not in text:
        continue

    # Update import
    text = text.replace("_shared/uazapi.ts", "_shared/botconversa.ts")

    # Remove Deno.env assignments for UAZAPI
    text = re.sub(r'^\s*const\s+UAZAPI_URL(?:.*?)$', '', text, flags=re.MULTILINE)
    text = re.sub(r'^\s*const\s+UAZAPI_TOKEN(?:.*?)$', '', text, flags=re.MULTILINE)

    # Remove basic `if (!UAZAPI_URL || !UAZAPI_TOKEN) { ... }` simple structures up to closing brace
    # Assuming basic formatting and no nested braces inside
    text = re.sub(r'\s*if\s*\(!UAZAPI_URL.*?\)\s*\{[^{}]*\}', '', text, flags=re.DOTALL)
    
    # Same thing for single line if statements
    text = re.sub(r'\s*if\s*\(!UAZAPI_URL.*?\)\s*return.*', '', text)

    # Remove UAZAPI_URL and UAZAPI_TOKEN from function arguments
    text = re.sub(r'sendTextMessage\([^,]*UAZAPI_URL[^,]*,[^,]*UAZAPI_TOKEN[^,]*,', 'sendTextMessage(', text)
    text = re.sub(r'sendImageMessage\([^,]*UAZAPI_URL[^,]*,[^,]*UAZAPI_TOKEN[^,]*,', 'sendImageMessage(', text)

    # Fix the ternary issue I saw earlier
    text = re.sub(r'\(\s*(?:UAZAPI_URL\s*&&)?\s*UAZAPI_TOKEN\s*\)\s*\?\s*await\s+sendTextMessage\(\s*.*?\s*,\s*.*?\s*,\s*(.*?),\s*(.*?)\)\s*:\s*false', r'await sendTextMessage(\1, \2)', text)

    filepath.write_text(text)

print("done")
