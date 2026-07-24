# Session handoff

Updated: 2026-07-24 (Asia/Singapore)

## Latest session: current upstream, Bing + Google categories, and scroll fix

The repository remains pinned to official SearXNG commit
`ef8f6470e0473a1548f175217aaa7b9346ce6973` (`2026.07.22+ef8f6470`), which was
also the current upstream `master` during the audit on 2026-07-24.

Implemented:

- Default engines now include Google and Bing for general, news, and images.
- Google images uses `google_cse` image mode. Google news uses the Google CSE
  compatibility path because the dedicated Google News endpoint suspends
  datacenter/proxy IPs with CAPTCHA responses.
- Bing News now uses `/news/search` instead of the retired empty
  `infinitescrollajax` payload. Bing Images uses `/images/search` instead of
  the stale `async=1` payload. The affected `zh-CN` Bing news/image traits use
  the parseable `en-US` market while preserving the Chinese query.
- Bing autocomplete is enabled with a two-character threshold, and image proxy
  is enabled.
- Upstream automatic-language behavior is restored: `auto` follows the browser
  locale; the removed local `auto -> all` divergence is no longer rebuilt.
- Granian 2.7.9 and server requirements are included. The BAT launcher prefers
  Granian on `127.0.0.1:3001` and falls back to Flask if Granian cannot load.
- The compact result-page SVG logo follows `--wow-accent`.
- The layered page background now scrolls normally and does not use
  `background-attachment: fixed`, avoiding the Chrome compositor seam/flicker.
- Theme cache key is `20260724-9`.

Validation:

- Clean rebuild passed at `.build/portable-final-audit-2`.
- Granian reports `2.7.9`; server header is `granian`.
- General search returned 30 result cards from Google and Bing.
- News returned 28 cards: Bing News 8 and Google News 20, with no engine error.
- Images returned 25 cards: Bing Images 5 and Google Images 20. The Chinese
  query `南京城市` returned relevant Chinese/Nanjing images from both sources.
- Browser UI showed `综合 / 图片 / 新闻`, `自动检测 (zh-CN)`, themed logo stroke
  `rgb(199, 106, 46)`, and a continuous background at a 1190 px scroll offset.
- Source and clean-build theme CSS SHA-256 matched:
  `52C071C1256B41B1B843061BCF809B2C1F2E46F2E045DB6C09FF9562C15151D7`.
- The `/autocompleter?q=OpenA` endpoint returned 12 Bing suggestions. A browser
  preference cookie can override the configured provider with an empty value;
  a fresh/default profile uses the configured Bing provider.
- Final package: `dist/SearXNGforWindows-2026.07.22.zip`, 56,092,771 bytes,
  SHA-256
  `EB31CDCC62B3EB95C8D825F677E72FF30CA25691F9F71A7E88DF0FF16DB4D969`;
  `.secret` count is zero.
- Packaging correction: the earlier `Compress-Archive -Path <root>\*` artifact
  omitted files located directly at the portable root. The replacement
  `tools/package-portable.ps1` uses `ZipFile.CreateFromDirectory` and fails if
  BAT, README, LICENSE, or BUILD-INFO is absent. The corrected ZIP was extracted
  and all required root files, `config/settings.yml`, and `python/python.exe`
  were verified.

Environment note:

- Granian test listeners on ports `18897` through `18905` continued responding
  after their owning PIDs disappeared from `Get-Process`, `tasklist`, and WMI;
  Windows still reports the stale listener PIDs. This appears specific to
  detached Granian processes in the Codex execution environment. No production
  port (including 3001) was touched. If the ports matter later, restart the
  Codex host/session or Windows before reusing them.

## Current state

The requested preferences, multilingual search, responsive-title, and
theme-icon fixes are complete and validated. This handoff is included in the
final commit on branch `codex/rebuild-2026`; use `git rev-parse HEAD` for the
exact commit containing it. The branch is intended to be pushed to
`origin/codex/rebuild-2026` before the session closes.

Repository: `D:\AI\SSL\SearXNGforWindows`

Remote: `https://github.com/DOVEGUO/SearXNGforWindows.git`

Parent commit before this delivery:
`815b3143fa3f87c57f3e128b877ff2cc5638d15b`

## Changes delivered

### Preferences save

The public reverse proxy did not forward a usable host for Flask's external
URL generation. Saving `/preferences` therefore returned
`Location: http:///`. Both preferences redirects in
`python/Lib/site-packages/searx/webapp.py` now use a relative index URL, so
the response is `302 Location: /`. The portable builder applies the same
scoped patch.

### Automatic search language

Pinned upstream SearXNG interpreted `auto` as the browser
`Accept-Language`, which caused a query written in another language to inherit
the UI language. `python/Lib/site-packages/searx/webadapter.py` now maps
`auto` to the neutral `all` locale, allowing Google and Bing to infer the
language from the query. The result-page selector displays only
`自动检测`, without the misleading implementation label `(all)`. README and
the portable builder reproduce and explain this behavior.

### Theme and responsive UI

- The homepage SearXNG mark uses the upstream PNG as a CSS mask filled by
  `--wow-accent`, so it changes with automatic/light/dark themes.
- Homepage and result-page search icons use the same theme accent, with a
  coordinated hover/focus state.
- The small-screen thumbnail-link float override remains in place, preventing
  multi-line result titles from being indented beside an invisible float.
- Theme asset cache key is `20260724-7`.
- `custom/theme.css` and the checked-in runtime mirror are byte-identical.

### Repository workflow

`AGENTS.md` is initialized. Every future development task must finish by
updating this handoff after validation and before reporting completion.

## Validation evidence

- Python compilation passed for patched `webapp.py` and `webadapter.py`.
- PowerShell AST parsing passed for `tools/build-portable.ps1`.
- `node --check custom/theme.js` and `git diff --check` passed.
- Clean portable rebuild completed at `.build/portable-final-check`.
- Clean-build HTTP tests:
  - homepage: HTTP 200;
  - preferences POST: HTTP 302 with `Location: /`;
  - `今日新闻`, `OpenAI news`, and `actualités France`: HTTP 200 with relevant
    Chinese, English, and French content despite forced `Accept-Language:
    en-US`;
  - Google and Bing both returned content with no unresponsive-engine marker.
- Browser validation:
  - light logo and search icon: `#c76a2e`;
  - dark logo and search icon: `#e08a44`;
  - result-page selector: `自动检测`;
  - first result for `今日新闻`: `中国新闻_央视网 (cctv.com)`, labeled by both
    Bing and Google.
- Test server on port `18894` was stopped and the port was released. Existing
  port `3001` processes were not touched.

## Portable artifact

Local ignored artifact:
`dist/SearXNGforWindows-2026.07.22.zip`

SHA-256:
`EB31CDCC62B3EB95C8D825F677E72FF30CA25691F9F71A7E88DF0FF16DB4D969`

The corrected ZIP contains 6,959 entries. Its root contains
`SearXNG for Windows.bat`, `README.md`, `LICENSE`, and `BUILD-INFO.txt`; it
contains no runtime `.secret`. `.build/`, `dist/`, and runtime secrets remain
intentionally ignored by Git.

## Deployment note

Pushing the repository does not update `https://search.wowtran.com/` by
itself. Deploy the rebuilt portable package to the Windows Server and restart
that SearXNG process to make these changes public. Keep the service on
`127.0.0.1:3001` and the application-only search proxy on
`127.0.0.1:7897`.
