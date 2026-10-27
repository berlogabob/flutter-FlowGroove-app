(function () {
  const root = document.documentElement;
  const buttons = document.querySelectorAll('.theme-toggle');
  function syncTheme() {
    const dark = root.dataset.theme === 'dark';
    document.querySelector('meta[name="theme-color"]').content = dark ? '#0b0b0c' : '#f6f5f0';
    buttons.forEach(button => {
      button.setAttribute('aria-pressed', String(dark));
      button.querySelector('.theme-label').textContent = dark ? 'Dark' : 'Light';
    });
  }
  buttons.forEach(button => button.addEventListener('click', () => {
    root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
    try { localStorage.setItem('fg-theme', root.dataset.theme); } catch (e) {}
    syncTheme();
  }));
  syncTheme();
  window.addEventListener('storage', event => {
    if (event.key === 'fg-theme') {
      root.dataset.theme = event.newValue === 'dark' ? 'dark' : 'light';
      syncTheme();
    }
  });
  const toggle = document.querySelector('.mobile-toggle');
  const nav = document.querySelector('.nav');
  function setMenu(open) {
    nav.classList.toggle('open', open);
    toggle.setAttribute('aria-expanded', String(open));
    toggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
    toggle.textContent = open ? '×' : '☰';
  }
  toggle.addEventListener('click', () => setMenu(toggle.getAttribute('aria-expanded') !== 'true'));
  nav.querySelectorAll('a').forEach(link => link.addEventListener('click', () => setMenu(false)));
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
      setMenu(false);
      toggle.focus();
    }
  });
  const mobile = window.matchMedia('(max-width: 1000px)');
  function syncLayout() {
    setMenu(false);
    document.querySelectorAll('.wiki-nav details').forEach(details => { details.open = !window.matchMedia('(max-width: 680px)').matches; });
  }
  mobile.addEventListener('change', syncLayout);
  window.matchMedia('(max-width: 680px)').addEventListener('change', syncLayout);
  syncLayout();
  const header = document.querySelector('.topbar');
  const syncHeader = () => header.classList.toggle('is-scrolled', window.scrollY > 12);
  syncHeader();
  window.addEventListener('scroll', syncHeader, { passive: true });
  document.querySelectorAll('[data-ev]').forEach(link => link.addEventListener('click', () => {
    if (typeof window.gtag === 'function') window.gtag('event', link.dataset.ev, { event_category: 'engagement' });
  }));
  document.querySelectorAll('.faq-question').forEach(question => question.parentElement.addEventListener('toggle', () => {
    if (question.parentElement.open && typeof window.trackFAQClick === 'function') window.trackFAQClick(question.textContent.trim());
  }));
})();
