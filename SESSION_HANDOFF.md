# Session handoff

Updated: 2026-07-24 (Asia/Singapore)

## Current objective / latest user decision

Production lost the next-page control and Google stopped returning results.
Diagnose and fix; ship a rebuild.

## Root cause

- Live JSON showed `unresponsive=["google","暂停服务: 请求过于频繁"]` — Google
  CSE hit HTTP 429 and was suspended in-process.
- SearXNG only enables pagination when a successful engine has `paging=True`.
  Upstream Bing web has no paging; with Google suspended, `result_container.paging`
  stayed false, so the next-page UI disappeared. This was a consequence of the
  Google outage, not a separate theme/layout regression.

## What changed

- `python/Lib/site-packages/searx/engines/bing.py` — `paging = True` and
  `first` offset for `pageno > 1`.
- `python/Lib/site-packages/searx/engines/google_cse.py` — `page_size` 20 → 10
  to reduce CSE rate-limit pressure (zh-CN `hl`/`gl=cn` bias kept).
- `config/settings.yml` — shorter suspend windows:
  `SearxEngineTooManyRequests: 60`, `SearxEngineAccessDenied: 120`.
- `tools/build-portable.ps1` — reproducible Bing paging + CSE page_size patches.

## Validation

- Local `127.0.0.1:18894`: page HTML contains `pageno=2`; Google+Bing returned
  results; page 2 top result differed from page 1.
- Clean rebuild `.build/portable-paging-fix` contains the patches.
- Test listener on `18894` was stopped.

## Portable artifact

`dist/SearXNGforWindows-2026.07.22.zip` (Git-ignored)

- Size: 55,627,504 bytes
- SHA-256: `2770601ABCAE07528E6A7AB0CFC33BD9736DEAFA799B9FF050A8055B4FBB9E37`
- Built from `.build/portable-paging-fix`
- No packaged `.secret`

## Git state

- Branch: `codex/rebuild-2026`
- Parent before this delivery: `78bb3a3a21fe88c6fd97b5dd788902bdce4967ce`
- Tip after push: use `git rev-parse HEAD`
- Ignored only: `.build/`, `dist/`, `config/.secret`

## Remaining work / ops note

- Deploy the ZIP and **restart** SearXNG on the Windows Server. Restart clears
  the in-memory Google suspension immediately; waiting alone also works once
  the suspend timer expires.
- Public CSE can still 429 under heavy probing; smaller page size and shorter
  suspend mitigate but do not eliminate Google's rate limits.
- No other blockers for this paging/Google recovery fix.

## Next recommended action

Deploy `dist/SearXNGforWindows-2026.07.22.zip`, restart the service on
`127.0.0.1:3001`, then confirm Google results return and the next-page control
is visible on a general search.
