# Session handoff

Updated: 2026-07-24 (Asia/Singapore)

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
`ECFD620B496E63CCD161052328E23A80E3D5D91CFCF7D136FEEEF9313B10B603`

The ZIP contains 6,884 entries and no `config/.secret`. `.build/`, `dist/`,
and runtime secrets remain intentionally ignored by Git.

## Deployment note

Pushing the repository does not update `https://search.wowtran.com/` by
itself. Deploy the rebuilt portable package to the Windows Server and restart
that SearXNG process to make these changes public. Keep the service on
`127.0.0.1:3001` and the application-only search proxy on
`127.0.0.1:7897`.
