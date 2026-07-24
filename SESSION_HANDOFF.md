# Session handoff

Updated: 2026-07-24 (Asia/Singapore)

## Current objective / latest user decision

Results were skewed toward Traditional Chinese (zh-TW / HK). Prefer Mainland
Simplified Chinese (zh-CN) by default, without regressing exact-match queries
such as `南京领域翻译`.

## Root cause

- `auto → all` left Google CSE with `hl=ZZ` and no `gl`, so ranking followed
  proxy/international bias (often TW/HK sources).
- Upstream Google traits map `zh-CN` → region `HK`, which biases Traditional
  Chinese even when the UI language is Simplified.

## What changed

- `python/Lib/site-packages/searx/engines/google_cse.py` — for `all` / `zh` /
  `zh-CN` / `zh_Hans*`, force `hl=zh-CN` and `gl=cn`; still omit `lr`/`cr`;
  keep traits-based `gl` for `zh-TW` / `zh-HK` and other locales.
- `tools/build-portable.ps1` — same CSE patch for clean rebuilds.
- `README.md` — document Mainland Simplified default for CSE.

## Validation

- Local `127.0.0.1:18893`, `Accept-Language: zh-CN`, `language=auto`:
  - `人工智能`: Simplified lead (`百度百科` / `维基百科`), cn=6 tw=0
  - `今日新闻`: CCTV / BBC 中文 simplified, tw=0
  - `南京领域翻译`: wowtran official site still first (`wow=True`)
  - `南京天气`: mainland weather sites, tw=0
- Clean rebuild `.build/portable-zhcn-bias` contains `hl=zh-CN` / `gl=cn`.
- Test process on `18893` stopped after checks.

## Portable artifact

`dist/SearXNGforWindows-2026.07.22.zip` (local, Git-ignored)

- Size: 55,627,561 bytes
- SHA-256: `24CC26DFA4E3477DE2BD6DC7DD96E826D09C5BD7AA624F2F651A85594A875CBC`
- Built from `.build/portable-zhcn-bias`
- No packaged `.secret`

## Git state

- Branch: `codex/rebuild-2026`
- Feature commit and tip: see `git rev-parse HEAD` after push
- Parent before this delivery: `abdf5ce092ae3966ad0f8bf2bd5b6a149de277ac`
- Ignored only: `.build/`, `dist/`, `config/.secret`

## Remaining work

- Deploy the new ZIP to production `search.wowtran.com` and restart SearXNG.
- No other blockers for the zh-CN bias fix.

## Next recommended action

Deploy the ZIP and confirm live queries such as `人工智能` show Simplified
Chinese leads while `南京领域翻译` still returns the company site.
