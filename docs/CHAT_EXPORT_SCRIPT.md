# Chat Export Auto-Move Script

**Created:** March 15, 2026  
**Purpose:** Automatically move chat exports to `docs/archive/`

---

## Usage

### Option 1: Run Script Directly

```bash
./scripts/move-chat-exports.sh
```

### Option 2: Use Make Command

```bash
make clean-exports
```

---

## What It Does

1. Finds all chat export files in root:
   - `chat-export-*.json`
   - `*-export-*.json`
   - `qwen-code-export-*.md`
   - `console-export-*.log`

2. Moves them to `docs/archive/`

3. Shows confirmation list

---

## Example Output

```bash
$ make clean-exports

╔═══════════════════════════════════════════════════════════╗
║         Moving Chat Exports to Archive                    ║
╚═══════════════════════════════════════════════════════════╝

📦 Moving chat exports to docs/archive/...
  ✅ Moved: chat-export-1771543079730.json
  ✅ Moved: console-export-2026-2-26_3-26-41.log
  ✅ Moved: qwen-code-export-2026-03-15T16-01-03-398Z.md
✅ Chat exports moved to docs/archive/

📁 Archive contents:
  chat-export-1771543079730.json
  console-export-2026-2-26-41.log
  qwen-code-export-2026-03-15T16-01-03-398Z.md
```

---

## Automatic Execution (Optional)

### Add to Git Hook

To automatically move exports after each session:

```bash
# .git/hooks/post-checkout
#!/bin/sh
make clean-exports 2>/dev/null || true
```

### Add to .gitignore

Prevent exports from being tracked in root:

```gitignore
# Chat exports (moved to docs/archive/)
chat-export-*.json
console-export-*.log
qwen-code-export-*.md
*-export-*.json
```

---

## Manual Move

If you prefer manual control:

```bash
# Move single file
mv chat-export-1234567890.json docs/archive/

# Move all exports
mv *export* docs/archive/
```

---

## Archive Location

All exports are stored in: `docs/archive/`

View contents:
```bash
ls -1 docs/archive/ | grep export
```

---

## Benefits

✅ **Clean root directory** - No scattered export files  
✅ **Organized archive** - All exports in one place  
✅ **Easy to find** - Consistent location  
✅ **Git-friendly** - Cleaner commit history  

---

**Tip:** Run `make clean-exports` after each chat export session!
