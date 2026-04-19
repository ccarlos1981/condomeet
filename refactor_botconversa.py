import os
import re
from pathlib import Path

functions_dir = Path("supabase/functions")
shared_dir = functions_dir / "_shared"
old_shared_file = shared_dir / "uazapi.ts"
new_shared_file = shared_dir / "botconversa.ts"

if old_shared_file.exists():
    os.rename(old_shared_file, new_shared_file)

# Modify the new botconversa.ts to remove baseUrl and token args
content = new_shared_file.read_text()
content = re.sub(
    r'export async function sendTextMessage\(\s*baseUrl: string,\s*//.*?\s*token: string,\s*//.*?\s*phone: string,\s*message: string,?\s*\)',
    r'export async function sendTextMessage(\n  phone: string,\n  message: string,\n)',
    content, flags=re.MULTILINE
)
content = re.sub(
    r'export async function sendImageMessage\(\s*baseUrl: string,\s*//.*?\s*token: string,\s*//.*?\s*phone: string,\s*imageUrl: string,?\s*caption\?: string,?\s*\)',
    r'export async function sendImageMessage(\n  phone: string,\n  imageUrl: string,\n  caption?: string,\n)',
    content, flags=re.MULTILINE
)
new_shared_file.write_text(content)

# Update all TypeScript files in functions
for filepath in functions_dir.rglob("*.ts"):
    if filepath == new_shared_file:
        continue
    
    content = filepath.read_text()
    
    # 1. Replace imports
    content = content.replace('_shared/uazapi.ts', '_shared/botconversa.ts')
    
    # 2. Remove UAZAPI_URL and UAZAPI_TOKEN environment variable fetches
    content = re.sub(r'const\s+UAZAPI_URL\s*=\s*(?:Deno\.env\.get|process\.env)\([\'"]UAZAPI_URL[\'"]\)(?: as string|!)?;?[\r\n]*', '', content)
    content = re.sub(r'const\s+UAZAPI_TOKEN\s*=\s*(?:Deno\.env\.get|process\.env)\([\'"]UAZAPI_TOKEN[\'"]\)(?: as string|!)?;?[\r\n]*', '', content)

    # Remove Deno.env.get without ! 
    content = re.sub(r'const\s+UAZAPI_URL\s*=\s*Deno\.env\.get\([\'"]UAZAPI_URL[\'"]\)(?: \|\| [\'"].*[\'"])?;?[\r\n]*', '', content)
    content = re.sub(r'const\s+UAZAPI_TOKEN\s*=\s*Deno\.env\.get\([\'"]UAZAPI_TOKEN[\'"]\)(?: \|\| [\'"].*[\'"])?;?[\r\n]*', '', content)
    
    # 3. Handle specific if condition checks like if (UAZAPI_URL && ...)
    # Sometimes it's `(UAZAPI_URL && UAZAPI_TOKEN) ? await ... : false`
    content = re.sub(r'\s*\(\s*UAZAPI_URL\s*&&\s*UAZAPI_TOKEN\s*\)\s*\?\s*await\s+sendTextMessage\(\s*UAZAPI_URL\s*,\s*UAZAPI_TOKEN\s*,\s*', ' await sendTextMessage(', content)
    content = re.sub(r'\s*\(\s*UAZAPI_URL\s*&&\s*UAZAPI_TOKEN\s*\)\s*\?\s*await\s+sendImageMessage\(\s*UAZAPI_URL\s*,\s*UAZAPI_TOKEN\s*,\s*', ' await sendImageMessage(', content)
    # Remove the `: false` fallback for the ternary condition above
    # Wait, the regex above matches the start of the ternary. If we matched `? await ... : false`, we need to remove over the line.
    
    # For safety, just replace the function call signatures.
    content = re.sub(r'sendTextMessage\(\s*UAZAPI_URL\s*,\s*UAZAPI_TOKEN\s*,', 'sendTextMessage(', content)
    content = re.sub(r'sendImageMessage\(\s*UAZAPI_URL\s*,\s*UAZAPI_TOKEN\s*,', 'sendImageMessage(', content)

    filepath.write_text(content)

print("Refactor completed")
