# 🚀 FLOWGROOVE HUGO SITE - QUICK START GUIDE

## What You Have

✅ Complete Hugo landing page for flowgroove.app  
✅ 8 content pages (home, about, FAQ, legal, blog, TinyLaunch)  
✅ 2 launch-ready blog posts  
✅ SEO optimization (meta tags, OpenGraph, Schema.org)  
✅ Analytics integration (GA4: G-T6YBX0M53W, Clarity: w8h5eswdua)  
✅ Custom dark theme for musicians  
✅ Deployment pipeline (FTP for production)  
✅ TinyLaunch launch tracking  

---

## 📋 PROJECT ARCHITECTURE

**This repo contains:**
1. **Flutter App** (`lib/`, `android/`, `web/`) → The actual FlowGroove app
2. **Hugo Landing Page** (`site/`) → Marketing site on GitHub Pages

**Deployment:**
- **GitHub Pages** (`make deploy-test`) → Flutter app for testing
- **GitHub Pages** (`make -f Makefile.hugo deploy`) → Hugo landing page (staging)
- **Android APK** (`make release`) → Mobile app

---

## 📋 IMMEDIATE NEXT STEPS (Do These First)

### Step 1: Install Hugo (5 minutes)

**macOS:**
```bash
brew install hugo
```

**Verify:**
```bash
hugo version
# Should show: hugo v0.120+ extended
```

### Step 2: Add PaperMod Theme (2 minutes)

```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app/site
git submodule add https://github.com/adityatelange/hugo-PaperMod themes/PaperMod
```

### Step 3: Test Local Build (1 minute)

```bash
cd site
hugo server -D
```

Open: http://localhost:1313

**Expected:** Dark-themed landing page with all sections visible

### Step 4: Add Images (15 minutes)

Create these images in `site/static/images/`:

| File | Size | Purpose |
|------|------|---------|
| `og-cover.webp` | 1200x630px | OpenGraph share image |
| `logo.webp` | 200x50px | Site header logo |
| `favicon.ico` | 32x32px | Browser favicon |
| `blog-001-cover.webp` | 1200x630px | Blog post 1 cover |
| `blog-002-cover.webp` | 1200x630px | Blog post 2 cover |
| `tinylaunch-badge.svg` | 200x60px | TinyLaunch badge |

**Tools:**
- Convert to WebP: https://convertio.co/png-webp/
- Create OG image: Canva template
- Favicon: https://favicon.io/

### Step 5: Update Analytics IDs (2 minutes)

Edit `site/hugo.toml`:

```toml
[params.analytics]
  ga4_id = "G-XXXXXXXXXX"  # Replace with your GA4 ID
  clarity_id = "XXXXXXXXXX"  # Replace with your Clarity ID
```

**Get IDs:**
- GA4: https://analytics.google.com/
- Clarity: https://clarity.microsoft.com/

### Step 6: Update Ko-fi Username (1 minute)

Edit `site/layouts/shortcodes/kofi-button.html`:

Replace `'flowgroove'` with your actual Ko-fi username.

---

## 🎥 RECORD DEMO VIDEO (Critical)

**What to Record:**
1. Open FlowGroove app on phone
2. Change a song in setlist
3. Show it updating on tablet/laptop in real-time
4. Highlight <500ms sync time

**Format:**
- Length: 15 seconds
- Resolution: 1080p
- Format: MP4

**Upload Options:**
1. **YouTube** (recommended for Hugo embed)
   - Upload as unlisted
   - Get embed URL
2. **Self-host** (add to `site/static/videos/`)

**Update Video Embed:**
Edit `site/content/_index.md`:

```markdown
{{< video-embed src="https://www.youtube.com/embed/YOUR_VIDEO_ID" caption="..." >}}
```

---

## 🚢 DEPLOY TO PRODUCTION

### Deploy Hugo Landing Page to GitHub Pages

**Using Makefile:**
```bash
# Build
make -f Makefile.hugo build

# Deploy to GitHub Pages (auto-triggers workflow)
make -f Makefile.hugo deploy
```

**Manual Deploy:**
```bash
cd site && hugo --minify
git add site/public/
git commit -m "chore: rebuild hugo landing page"
git push
# GitHub Actions workflow auto-deploys to Pages
```

### Deploy Flutter App (Existing Workflow)

**Test on GitHub Pages:**
```bash
make deploy-test
# URL: https://berlogabob.github.io/flutter-FlowGroove-app/
```

**Android Release:**
```bash
make release
# Builds APK + AAB + GitHub Release
```

---

## ✅ PRE-LAUNCH CHECKLIST

### Final Testing (Do Before Launch)

- [ ] Local build works (`hugo server -D`)
- [ ] All links working (test every page)
- [ ] Mobile responsive (test on phone)
- [ ] Video plays (if embedded)
- [ ] Ko-fi button shows
- [ ] FAQ accordion works
- [ ] Blog pages load
- [ ] 404 page works (visit `/nonexistent`)
- [ ] Lighthouse score 95+ (Chrome DevTools)

### Launch Day (May 1, 2026)

- [ ] Deploy to production
- [ ] Test live URL (flowgroove.app)
- [ ] Post on X/Twitter
- [ ] Post on Reddit (r/FlutterDev, r/SomebodyMakeThis)
- [ ] Contact 15 friends for TinyLaunch upvotes
- [ ] Monitor Ko-fi donations
- [ ] Respond to all comments (24h)

### Post-Launch (Week After)

- [ ] Check GA4 for traffic
- [ ] Review Clarity heatmaps
- [ ] Install TinyLaunch badge on homepage
- [ ] Thank boost list participants
- [ ] Document lessons learned

---

## 🔧 COMMON TASKS

### Add New Blog Post

```bash
cd site
hugo new content/blog/my-new-post.md
```

Edit the file, then commit.

### Update Content

Edit any `.md` file in `site/content/`, then commit.

### Test Production Build

```bash
cd site
hugo --minify
# Output in site/public/
```

### View Analytics

- GA4: https://analytics.google.com/
- Clarity: https://clarity.microsoft.com/

---

## 🆘 TROUBLESHOOTING

### Hugo Build Fails

**Error: "theme not found"**
```bash
cd site
git submodule update --init --recursive
```

**Error: "failed to extract shortcode"**
- Check shortcode name matches file in `site/layouts/shortcodes/`
- File name must match exactly (case-sensitive)

### Page Looks Wrong

- Clear browser cache (Cmd+Shift+R)
- Check `hugo.toml` baseURL is correct
- Verify CSS file is loaded (DevTools → Network tab)

### Video Doesn't Play

- Check YouTube URL is embed format: `https://www.youtube.com/embed/VIDEO_ID`
- Verify video is not private
- Test URL in browser first

---

## 📚 RESOURCES

### Hugo Documentation
- Official docs: https://gohugo.io/documentation/
- Shortcodes: https://gohugo.io/content-management/shortcodes/
- PaperMod theme: https://github.com/adityatelange/hugo-PaperMod

### SEO Tools
- Lighthouse: Chrome DevTools → Lighthouse tab
- Google Search Console: https://search.google.com/search-console
- Bing Webmaster: https://www.bing.com/webmasters

### Analytics
- GA4: https://analytics.google.com/
- Microsoft Clarity: https://clarity.microsoft.com/

---

## 📞 SUPPORT

**Issues:**
- GitHub: https://github.com/berloga/flutter_repsync_app/issues
- Email: hello@flowgroove.app

**Agent System:**
- Sequential workflow: `.codex/rules/sequential-workflow.md`
- Agent directory: `.codex/agents/`

---

## 🎯 SUCCESS METRICS

### Week 1 Targets
| Metric | Target |
|--------|--------|
| TinyLaunch Upvotes | 15+ |
| Website Visits | 500+ |
| Ko-fi Donations | 5+ |
| App Downloads | 100+ |

### 6-Month Targets
| Metric | Target |
|--------|--------|
| Organic Traffic | 1,000+/month |
| Keyword Rankings (Top 10) | 50+ |
| Monthly Ko-fi Donations | $100+ |
| Active Users | 500+ |

---

**Last Updated:** April 8, 2026  
**Next Review:** After first local build test

**Built with ❤️ for musicians and cover bands**  
**© 2026 Sounding Doubts - Unipessoal Lda. Amadora, Portugal. NIF: 518200736.**
