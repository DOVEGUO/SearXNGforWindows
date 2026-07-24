# Session handoff

Updated: 2026-07-24 (Asia/Singapore)

## Current objective / latest user decision

Matching still wrong for queries like `广域市` (user saw Japanese / unrelated
noise). Fix relevance when Google is down or Bing returns proxy junk.

## Root cause

- Through the Clash egress IP, Bing often returns Cloudflare Turnstile or a
  soft-block SERP (English headphones / calculators / overseas pages) that
  shares no CJK with the Chinese query.
- When Google CSE is 429-suspended, those junk Bing rows dominate ranking.
- Only Google+Bing were enabled; no Chinese-friendly fallback remained.

## What changed

- `python/Lib/site-packages/searx/engines/bing.py`
  - Prefer `setlang=zh-Hans` + market cookies
  - Raise captcha on Turnstile / `请解决以下难题`
  - Soft-block Chinese queries whose top Bing titles share almost no CJK with
    the query (reject junk SERPs instead of ranking them)
- `config/settings.yml`
  - Enable `baidu` in `keep_only` (weight 1.1) as CN fallback
  - Lower Bing weight to 0.4; `paging: true`
- `tools/build-portable.ps1` — mirror Bing captcha/soft-block + setlang patches
- `README.md` — document Baidu fallback

## Validation

- Local `127.0.0.1:18897` for `广域市`:
  - `unresponsive=["bing","验证码"]`
  - Top hits from baidu+google: 百度百科 / 维基百科「广域市」(韩国行政区划)
- `南京领域翻译`: baidu+google return 南京领域翻译有限公司 / 沃领域翻译
- Leftover probe script removed; stop test listener when packaging finishes.

## Portable artifact

`dist/SearXNGforWindows-2026.07.22.zip` (Git-ignored)

- Size: 55,625,472 bytes
- SHA-256: `DD79960F5E008BFC539E698F8C60E0325730E8942E86E5D50314E3BF9DBFEC9C`
- Built from `.build/portable-match-fix`
- No packaged `.secret`

## Git state

- Branch: `codex/rebuild-2026`
- Ignored only: `.build/`, `dist/`, `config/.secret`

## Remaining work / ops note

- Deploy the new ZIP and **restart** SearXNG on the Windows Server
  (`127.0.0.1:3001`). Restart clears in-memory engine suspensions.
- Free Google CSE can still 429; Baidu now covers Chinese queries in that gap.
- Bing via proxy may stay captcha-blocked; that is intentional once detected
  (better empty Bing than junk SERPs).

## Next recommended action

Deploy the new ZIP, restart, then re-check `广域市` and `南京领域翻译` on
production.
