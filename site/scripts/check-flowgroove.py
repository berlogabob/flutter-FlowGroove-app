#!/usr/bin/env python3
"""Check a Hugo build without a browser; report pre-existing draft links separately."""
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit

root = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/theme-public')
base = sys.argv[2] if len(sys.argv) > 2 else 'https://flowgroove.app/'
base_url = urlsplit(base)
site = Path(__file__).resolve().parents[1]

class Document(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.elements = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        self.elements.append((tag, dict(attrs)))

missing = {}
errors = []
for file in root.rglob('*.html'):
    text = file.read_text()
    document = Document(text)
    relative = file.relative_to(root).as_posix()
    url = urljoin(base, relative)
    assert 'fonts.googleapis' not in text, file
    for tag, attrs in document.elements:
        for key in ('href', 'src'):
            if key not in attrs:
                continue
            reference = attrs[key]
            target = urlsplit(urljoin(url, reference))
            if target.scheme not in ('http', 'https') or target.netloc != base_url.netloc:
                continue
            target_path = target.path or '/'
            if not target_path.startswith(base_url.path):
                errors.append(f'{relative}: escaped base path: {reference}')
                continue
            path = root / unquote(target_path[len(base_url.path):])
            if not (path.is_file() or (path / 'index.html').is_file()):
                missing.setdefault(target.path, set()).add(relative)
            if reference.startswith('/') and (key == 'src' or tag == 'link' and attrs.get('rel') in ('stylesheet', 'icon', 'apple-touch-icon')):
                errors.append(f'{relative}: root-absolute asset: {reference}')

# Check full theme pages, excluding deliberate alias redirects and in-app embeds.
full_pages = []
for name in ('', 'privacy/', 'terms/', 'blog/', 'wiki/', 'faq/', 'about/', 'roadmap/', 'support/', 'delete-account/'):
    full_pages.append(root / name / 'index.html')
full_pages.append(root / '404.html')
if (root / 'tinylaunch/index.html').exists():
    full_pages.append(root / 'tinylaunch/index.html')
full_pages.extend(root.glob('blog/*/index.html'))
full_pages.extend(root.glob('wiki/*/index.html'))
for file in full_pages:
    text = file.read_text()
    elements = Document(text).elements
    assert any(t == 'header' and 'topbar' in a.get('class', '') for t, a in elements), file
    assert any(t == 'footer' and 'footer' in a.get('class', '') for t, a in elements), file
    assert any(t == 'link' and a.get('rel') == 'canonical' for t, a in elements), file
    assert any(t == 'meta' and a.get('name') == 'color-scheme' and a.get('content') == 'light dark' for t, a in elements), file
    assert 'G-T6YBX0M53W' in text and 'w8h5eswdua' in text, file
    assert 'fg-theme' in text and text.index('fg-theme') < text.index('rel=stylesheet'), file
    assert any(t == 'button' and a.get('aria-label') == 'Dark mode' for t, a in elements), file
    assert any(t == 'html' and a.get('data-theme') == 'light' for t, a in elements), file

assert (root / 'blog/index.html').read_text().count('class=post-card') <= 6
assert (root / 'wiki/page/2/index.html').exists(), 'Pagination not built'
assert '404' in (root / '404.html').read_text(), 'Missing error document body'
for file in root.rglob('*.css'):
    css = file.read_text()
    assert 'fonts.googleapis' not in css, file
    for font in re.findall(r'url\([\'"]?([^\)\'\"]+\.woff2)[\'"]?\)', css):
        target = urlsplit(urljoin(urljoin(base, file.relative_to(root).as_posix()), font))
        assert target.netloc == base_url.netloc, font
        assert (root / target.path[len(base_url.path):]).is_file(), font

# Every known missing production link must point to an explicitly unpublished post.
drafts = set()
for file in (site / 'content/blog').glob('*.md'):
    source = file.read_text()
    if re.search(r'^draft:\s*true\s*$', source, re.M):
        slug = re.search(r'^slug:\s*[\'"]?([^\n\'\"]+)', source, re.M)
        drafts.add(base_url.path + 'blog/' + (slug.group(1).strip() if slug else file.stem) + '/')
for target, sources in sorted(missing.items()):
    if target not in drafts:
        errors.append(f'{target}: unresolved link from {", ".join(sorted(sources))}')
if missing:
    print(f'OPEN ISSUE: {len(missing)} existing draft-post URLs are linked from published content.')
    for target in sorted(missing):
        print(' ', target)
for issue in errors:
    print('ERROR:', issue)
assert not errors, f'{len(errors)} link/asset errors'
print(f'PASS: {len(full_pages)} full pages, theme head/chrome/analytics, local fonts, asset URLs, pagination; all non-draft links resolve.')

# The light and dark text palette must satisfy AA, including code and hardware buttons.
def luminance(hex_color):
    values = [int(hex_color[i:i+2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values]
    return sum(v * w for v, w in zip(linear, (.2126, .7152, .0722)))

source_css = (site / 'themes/flowgroove/assets/css/fg.css').read_text()
def variables(selector):
    blocks = re.findall(re.escape(selector) + r'\{([^}]+)\}', source_css)
    return dict(re.findall(r'(--[a-z-]+):([^;]+)', ';'.join(blocks)))
light = variables(':root')
dark = light | variables('html[data-theme=dark]')
palettes = [(name, [palette[key] for key in ('--paper', '--screen')],
             [palette[key] for key in ('--ink', '--muted', '--link')])
            for name, palette in (('light', light), ('dark', dark))]
ratios = []
for theme, backgrounds, foregrounds in palettes:
    for bg in backgrounds:
        for fg in foregrounds:
            values = sorted((luminance(bg), luminance(fg)))
            ratio = (values[1] + .05) / (values[0] + .05)
            assert ratio >= 4.5, (theme, bg, fg, ratio)
            ratios.append(ratio)
for fg, bg in (('#1e1e1c', '#ceccc2'), ('#f0eee6', '#40403b'), ('#0a0a09', '#df461c')):
    values = sorted((luminance(bg), luminance(fg)))
    ratio = (values[1] + .05) / (values[0] + .05)
    assert ratio >= 4.5, (bg, fg, ratio)
    ratios.append(ratio)
print(f'PASS: palette contrast, minimum {min(ratios):.2f}:1.')
