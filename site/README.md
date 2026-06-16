# FlowGroove Hugo Site

**Last Updated:** April 24, 2026

This directory contains the Hugo landing-page source for FlowGroove.

## Purpose

- marketing landing page
- FAQ, privacy, and terms pages
- blog content
- GitHub Pages preview root
- production root site for FTP deployment

## Structure

```text
site/
├── content/      # pages, blog posts, FAQ, legal pages
├── layouts/      # templates, partials, shortcodes
├── static/       # static assets
├── assets/       # site CSS assets
├── data/         # structured site data
├── themes/       # PaperMod theme
└── hugo.toml     # Hugo configuration
```

## Local Development

Recommended:

```bash
make -f Makefile.hugo serve
```

Direct Hugo usage also works:

```bash
cd site
hugo server -D
```

## GitHub Pages Preview

Safe dual deploy:

```bash
make -f Makefile.hugo deploy-all
```

Result:

- `docs/` root -> Hugo landing page
- `docs/app/` -> Flutter web app

## Production Deploy

Production deploy is driven from the repo root:

```bash
make deploy-stable
```

Result:

- `site/public/` -> `flowgroove.app/`
- `build/web/` -> `flowgroove.app/app/`

## Important Note

Do not treat `make deploy-test` as the normal site deploy path. That command performs a Flutter-only publish and overwrites `docs/` root output.

## Related Docs

- [README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/README.md)
- [ARCHITECTURE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/ARCHITECTURE.md)
- [DEPLOYMENT_GUIDE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/DEPLOYMENT_GUIDE.md)
- [docs/project-audit-2026-04-24.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/project-audit-2026-04-24.md)
