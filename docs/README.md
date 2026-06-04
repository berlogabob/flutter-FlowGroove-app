# docs/

This directory is both:

- the generated GitHub Pages output root
- a storage area for project reports and audit notes

## Safe Commands

### Safe GitHub Pages Preview

```bash
make -f Makefile.hugo deploy-all
```

This keeps the Hugo landing page at `docs/` root and the Flutter app at `docs/app/`.

### Flutter-Only Publish

```bash
make deploy-test
```

This overwrites `docs/` root with a Flutter-only build.

## Useful Documents

- [README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/README.md)
- [ARCHITECTURE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/ARCHITECTURE.md)
- [DEPLOYMENT_GUIDE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/DEPLOYMENT_GUIDE.md)
- [project-audit-2026-04-24.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/project-audit-2026-04-24.md)
- [canonical-library-migration-runbook.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/canonical-library-migration-runbook.md)
