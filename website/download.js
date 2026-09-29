(function () {
  const REPO = 'Hasninemamud/CleanMac';
  // Stable alias on latest release; API still upgrades to browser_download_url.
  const FALLBACK =
    'https://github.com/' + REPO + '/releases/latest/download/CleanMac-arm64.dmg';

  function apply(url, label) {
    document.querySelectorAll('[data-dmg]').forEach(function (a) {
      a.setAttribute('href', url);
      // Force download navigation (GitHub serves Content-Disposition: attachment).
      a.setAttribute('download', '');
      if (a.hasAttribute('data-dmg-label') && label) {
        a.textContent = label;
      }
    });
  }

  apply(FALLBACK, null);

  fetch('https://api.github.com/repos/' + REPO + '/releases/latest')
    .then(function (r) {
      if (!r.ok) throw new Error('release fetch failed');
      return r.json();
    })
    .then(function (rel) {
      var assets = rel.assets || [];
      var dmg =
        assets.find(function (a) {
          return a.name === 'CleanMac-arm64.dmg';
        }) ||
        assets.find(function (a) {
          return /-arm64\.dmg$/i.test(a.name);
        }) ||
        assets.find(function (a) {
          return /\.dmg$/i.test(a.name);
        });
      if (!dmg || !dmg.browser_download_url) return;
      var ver = (rel.tag_name || '').replace(/^v/, '') || 'latest';
      apply(dmg.browser_download_url, 'Download CleanMac ' + ver);
      document.querySelectorAll('[data-dmg-version]').forEach(function (el) {
        el.textContent = 'Latest GitHub release: CleanMac ' + ver;
      });
    })
    .catch(function () {
      /* keep fallback href */
    });
})();
