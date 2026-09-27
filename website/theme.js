(function () {
  const root = document.documentElement;
  const btn = document.getElementById('theme-toggle');

  function current() {
    return root.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
  }

  function apply(theme) {
    root.setAttribute('data-theme', theme);
    try {
      localStorage.setItem('cleanmac-site-theme', theme);
    } catch (_) {}
    if (btn) {
      btn.setAttribute(
        'aria-label',
        theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'
      );
    }
  }

  if (btn) {
    btn.addEventListener('click', () => {
      apply(current() === 'dark' ? 'light' : 'dark');
    });
    apply(current());
  }
})();
