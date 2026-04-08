# ⚠️ WARNING: DO NOT RUN `make deploy-test` HERE!

This directory contains the Hugo landing page + Flutter app.

**Wrong command:** `make deploy-test` (from repo root) → Destroys Hugo output
**Right command:** `make -f Makefile.hugo deploy-all` → Builds both safely

See ARCHITECTURE.md for full deployment guide.
