# FlowGroove Landing Page

**URL:** https://flowgroove.app  
**Framework:** Hugo (Static Site Generator)  
**Theme:** PaperMod  
**Status:** Pre-Launch (Target: May 1, 2026 on TinyLaunch)

---

## 📁 Project Structure

```
site/
├── archetypes/           # Content templates
├── assets/
│   └── css/
│       └── custom.css   # Custom styles (dark theme)
├── content/              # Markdown content
│   ├── _index.md        # Landing page (homepage)
│   ├── about.md         # About page (The Story)
│   ├── faq.md           # FAQ page
│   ├── privacy.md       # Privacy policy (Sounding Doubts)
│   ├── terms.md         # Terms of service
│   ├── tinylaunch.md    # TinyLaunch launch page
│   ├── 404.md           # Custom 404 page
│   ├── blog/            # Blog posts
│   │   ├── _index.md
│   │   ├── post-001-why-i-built-flowgroove.md
│   │   └── post-002-5-problems-cover-bands-face.md
│   └── songs/           # Programmatic SEO (future)
│       └── _index.md
├── data/
│   ├── social.yml       # Social links configuration
│   └── launch-boost.yml # TinyLaunch launch tracking
├── layouts/
│   ├── partials/
│   │   ├── seo.html     # SEO meta tags (OpenGraph, Schema.org)
│   │   └── analytics.html # GA4 + Microsoft Clarity
│   └── shortcodes/      # Custom Hugo shortcodes
│       ├── hero.html
│       ├── hero-title.html
│       ├── hero-subtitle.html
│       ├── hero-cta-primary.html
│       ├── hero-cta-secondary.html
│       ├── section.html
│       ├── section-title.html
│       ├── section-subtitle.html
│       ├── feature-card.html
│       ├── video-embed.html
│       ├── faq-item.html
│       ├── kofi-button.html
│       └── tinylaunch-badge.html
├── static/
│   ├── images/          # Images (OG cards, logos, etc.)
│   ├── videos/          # Video files (if self-hosted)
│   └── robots.txt       # SEO robots configuration
├── themes/              # Hugo themes (PaperMod submodule)
└── hugo.toml            # Hugo configuration file
```

---

## 🚀 Quick Start

### Prerequisites

- Hugo Extended (v0.120+) — [Install Guide](https://gohugo.io/installation/)
- Git (for theme submodule)

### Local Development

```bash
# 1. Clone the repository
cd /path/to/flutter_repsync_app

# 2. Initialize Hugo site (if not already done)
cd site
hugo mod init github.com/berloga/flowgroove-site

# 3. Add PaperMod theme
git submodule add https://github.com/adityatelange/hugo-PaperMod themes/PaperMod

# 4. Start local server
hugo server -D

# 5. Open in browser
# http://localhost:1313
```

### Production Build

```bash
# Build for production
hugo --minify

# Output directory: site/public/
```

---

## 🎨 Customization

### Update Analytics IDs

Edit `site/hugo.toml`:

```toml
[params.analytics]
  ga4_id = "G-XXXXXXXXXX"  # Replace with real ID
  clarity_id = "XXXXXXXXXX"  # Replace with real ID
```

### Update Social Links

Edit `site/hugo.toml`:

```toml
[[params.socialIcons]]
  name = "github"
  url = "https://github.com/YOUR_REPO"

[[params.socialIcons]]
  name = "kofi"
  url = "https://ko-fi.com/YOUR_PROFILE"
```

### Add Images

Place images in `site/static/images/`:

- `og-cover.webp` — OpenGraph share image (1200x630px)
- `logo.webp` — Site logo
- `favicon.ico` — Favicon
- `tinylaunch-badge.svg` — TinyLaunch badge

### Update Ko-fi Widget

Edit `site/layouts/shortcodes/kofi-button.html`:

```javascript
kofiWidgetOverlay.draw('YOUR_KOFI_USERNAME', {
  // ... configuration
});
```

---

## 📝 Content Management

### Create New Blog Post

```bash
hugo new content/blog/post-title.md
```

Edit the frontmatter:

```yaml
---
title: "Post Title"
date: 2026-04-08T10:00:00+01:00
draft: false
tags: ["tag1", "tag2"]
categories: ["category"]
summary: "Short description for listings"
featuredImage: "images/blog-cover.webp"
---
```

### Create New Song Page (Programmatic SEO)

```bash
hugo new content/songs/wonderwall-bpm-key.md
```

Example frontmatter:

```yaml
---
title: "Wonderwall - BPM & Key"
date: 2026-04-08
draft: false
tags: ["bpm", "key", "wonderwall", "oasis"]
categories: ["songs"]
summary: "Auto-detect BPM (87) and musical key (F#m) for Wonderwall by Oasis"
bpm: "87"
key: "F#m"
artist: "Oasis"
---
```

---

## 🔍 SEO Configuration

### Meta Tags

All pages include:
- Primary meta tags (title, description, keywords)
- OpenGraph tags (for Facebook, LinkedIn)
- Twitter Cards
- Schema.org structured data (JSON-LD)

### Sitemap

Automatically generated at `/sitemap.xml`

### Robots.txt

Located at `site/static/robots.txt`

### Custom URLs

All URLs are relative and use `baseURL` from `hugo.toml`.

---

## 📊 Analytics

### Google Analytics 4

Tracks:
- Page views
- User behavior
- Conversion events (Ko-fi clicks, demo trials)

Custom events:
- `kofi_click` — Ko-fi button clicked
- `demo_trial` — Demo trial started
- `faq_expand` — FAQ question expanded

### Microsoft Clarity

Provides:
- Heatmaps
- Session recordings
- User behavior insights

---

## 🚢 Deployment

### Option 1: Cloudflare Pages (Recommended)

```bash
# 1. Connect GitHub repository to Cloudflare Pages
# 2. Set build command: hugo --minify
# 3. Set publish directory: site/public
# 4. Configure custom domain: flowgroove.app
# 5. SSL enabled automatically
```

### Option 2: GitHub Pages

```bash
# 1. Enable GitHub Pages in repository settings
# 2. Set source to GitHub Actions
# 3. Create .github/workflows/hugo.yml

# Example workflow:
name: Deploy Hugo site to Pages

on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: '0.120.0'
          extended: true
      - name: Build
        run: hugo --minify
        working-directory: ./site
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v2
        with:
          path: ./site/public
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v3
```

### Option 3: Firebase Hosting

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Initialize Firebase
firebase init hosting

# 3. Configure firebase.json
{
  "hosting": {
    "public": "site/public",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
  }
}

# 4. Deploy
firebase deploy --only hosting
```

---

## ✅ Pre-Launch Checklist

### Technical
- [ ] Hugo site builds without errors
- [ ] All links working
- [ ] Mobile responsive tested
- [ ] Video embed tested (YouTube/Vimeo)
- [ ] Ko-fi widget integrated
- [ ] GA4 tracking code added
- [ ] Clarity script added
- [ ] robots.txt configured
- [ ] Sitemap.xml generated
- [ ] Custom 404 page tested

### Content
- [ ] Landing page copy finalized
- [ ] About page written
- [ ] FAQ page complete
- [ ] Privacy policy (Sounding Doubts) added
- [ ] Terms of service added
- [ ] 2 blog posts written
- [ ] TinyLaunch page created

### SEO
- [ ] Meta titles unique per page
- [ ] Meta descriptions (150-160 chars)
- [ ] OpenGraph complete
- [ ] Schema.org structured data
- [ ] Canonical URLs set
- [ ] Images have alt text
- [ ] Images optimized (WebP)

### Launch Prep
- [ ] TinyLaunch profile completed
- [ ] Premium launch ($39) configured
- [ ] Launch post for X/Twitter drafted
- [ ] Reddit post drafted
- [ ] Email announcement template
- [ ] Friend boost list (15 people) ready
- [ ] Social media graphics ready

---

## 📈 Post-Launch Metrics to Track

| Metric | Target | Tool |
|--------|--------|------|
| Lighthouse Score | 95+ | Lighthouse |
| Page Load Time | <1.5s | WebPageTest |
| Organic Traffic | 1000+/mo | GA4 |
| Bounce Rate | <40% | GA4 |
| Ko-fi Conversions | 2%+ | Ko-fi + GA4 |
| TinyLaunch Upvotes | 15+ | TinyLaunch |

---

## 🛠️ Troubleshooting

### Hugo Build Fails

```bash
# Check Hugo version
hugo version

# Should be: hugo v0.120+ (extended)

# Clear cache
hugo --gc --minify
```

### Theme Not Loading

```bash
# Update submodule
git submodule update --remote --merge

# Or reinstall theme
rm -rf themes/PaperMod
git submodule add https://github.com/adityatelange/hugo-PaperMod themes/PaperMod
```

### Images Not Showing

- Check paths are relative to `static/`
- Use `/images/filename.webp` in content
- Verify files exist in `site/static/images/`

---

## 📞 Support

For issues or questions:

- **GitHub Issues:** https://github.com/berloga/flutter_repsync_app/issues
- **Email:** hello@flowgroove.app

---

## 📜 License

FlowGroove landing page is part of the FlowGroove project.

**© 2026 Sounding Doubts - Unipessoal Lda. Amadora, Portugal. NIF: 518200736.**

---

**Built with ❤️ for musicians and cover bands**
