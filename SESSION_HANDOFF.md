# Session handoff

Updated: 2026-07-24 (Asia/Singapore)

## Current objective / latest user decision

Fix general-search relevance skew versus Google/Bing for queries such as
`南京领域翻译`. Implement the agreed plan: `auto → all`, soften Google CSE
locale params, default Bing market when locale is unset, lower Bing weight,
then rebuild, package, commit, and push.

## What changed

- `python/Lib/site-packages/searx/webadapter.py` — `auto` now maps to neutral
  `all` (UI `selected_locale` remains `auto`).
- `python/Lib/site-packages/searx/engines/google_cse.py` — keep `hl` only;
  do not send `lr` / `cr` / `gl` to the public CSE endpoint.
- `python/Lib/site-packages/searx/engines/bing.py` — when region is empty,
  default `engine_region` to `zh-CN`.
- `config/settings.yml` — `bing` `weight: 0.6`.
- `tools/build-portable.ps1` — reproducible patches for the three code
  changes above.
- `README.md` — document neutral automatic language behavior.

## Validation

- `py_compile` for `webadapter.py`, `google_cse.py`, `bing.py` passed.
- PowerShell AST parse for `tools/build-portable.ps1` passed.
- Local Granian on `127.0.0.1:18892` with `Accept-Language: zh-CN`:
  - `language=auto` for `南京领域翻译`: `wow=True`, top Google hit
    `沃领域翻译官方网站|南京翻译公司| 南京领域翻译有限公司`, `jpNoise=False`.
  - `language=zh-CN`: also `wow=True` with the same official-site lead
    (CSE softening).
  - Preferences POST returned `302 Location: /`.
  - Homepage HTTP 200.
- Clean rebuild:
  `.\tools\build-portable.ps1 -OutputDirectory .\.build\portable-relevance-fix`
  confirmed the three patches and `weight: 0.6` in the output tree.
- Test listener on `18892` was stopped after validation (Windows may briefly
  keep a stale Listen row for the dead PID).

## Portable artifact

Local ignored ZIP:
`dist/SearXNGforWindows-2026.07.22.zip`

- Size: 55,630,020 bytes
- SHA-256: `24090392D0485828AE7C81CF67506B2D4526F3BFE72C94A0A1046962CC82986A`
- Source: `.build/portable-relevance-fix` via `tools/package-portable.ps1`
- No packaged `.secret`

## Git state

- Branch: `codex/rebuild-2026`
- Feature commit: `abb23764b71dc9ae7d5c5d98b1f367c711c45f49`
- Remote: `origin/codex/rebuild-2026` matches that feature commit after push
- This handoff commit follows immediately; use `git rev-parse HEAD` for the
  exact tip after the handoff commit
- Working tree clean aside from ignored `.build/`, `dist/`, `config/.secret`

## Remaining work

- Deploy the new ZIP to the Windows Server for `search.wowtran.com` and
  restart SearXNG. Git push does not update production by itself.
- Bing via proxy can still return off-topic rows; they should no longer outrank
  Google CSE exact-match leads for this class of query.
- No other blockers for this relevance fix.

## Next recommended action

Deploy `dist/SearXNGforWindows-2026.07.22.zip` to production, restart the
service on `127.0.0.1:3001`, and confirm `南京领域翻译` on the live site with a
normal Chinese browser profile.
