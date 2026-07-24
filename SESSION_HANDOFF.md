# Session handoff

Updated: 2026-07-24 (Asia/Singapore)

## Current objective / latest user decision

Fix results-page autocomplete occlusion, then rebuild the portable package,
commit, push, and refresh this handoff. Homepage autocomplete was out of
scope.

## What changed

Root cause: `#search_header` `backdrop-filter` creates a stacking context that
traps `.autocomplete.open { z-index: 5000 }`. On the results page, later
`.search_filters` selects (`z-index: 100`) paint over that context and cover
suggestion items.

Files:

- `custom/theme.css` — `body.results_endpoint #search_header { position:
  relative; z-index: 110; }`
- `python/Lib/site-packages/searx/static/themes/simple/wowtran-theme.css` —
  runtime mirror
- `python/Lib/site-packages/searx/templates/simple/base.html` — theme cache
  key `20260724-10`
- `tools/build-portable.ps1` — same cache key for clean rebuilds

## Validation

- `node --check custom/theme.js` passed.
- PowerShell AST parse passed for `tools/build-portable.ps1` and
  `tools/package-portable.ps1`.
- Clean rebuild:
  `.\tools\build-portable.ps1 -OutputDirectory .\.build\portable-autocomplete-fix`
- Source and clean-build theme CSS SHA-256 matched:
  `B282CAACCC0D3DE74FC24CC22E0C4902EDAA6BE31DAE1FFE815ECA1C2845ED69`
- Clean-build HTTP on `127.0.0.1:18891`: home 200, search 200, autocompleter
  200, theme cache `20260724-10`, CSS fix present, no unresponsive-engine
  marker; Google and Bing labels present in results HTML.
- Chrome MCP on clean-build results page: with autocomplete open over the
  filter band, `elementFromPoint` hit an autocomplete `<li>`;
  `#search_header` computed `z-index: 110`; `fixed: true`.
- Test listener on `18891` was stopped after validation.

## Portable artifact

Local ignored ZIP:
`dist/SearXNGforWindows-2026.07.22.zip`

- Size: 55,629,790 bytes
- SHA-256: `18BA3F6AC4727FE4613BDF035E9018AD859CD378333632B4FB0A92C80D1D3D14`
- Built from `.build/portable-autocomplete-fix` via
  `tools/package-portable.ps1`
- Required root files present; no packaged `.secret`

## Git state

- Branch: `codex/rebuild-2026`
- Feature commit: `ead98199ca57bd05cab970ef6146eef9194747bd`
- Prior handoff commit: `79384675a006958deccd967e014bdf0a253785d7`
- Current tip: this commit (Git-state clarification); confirm with
  `git rev-parse HEAD` and `git status -sb`
- Remote tracking branch is updated when this tip is pushed
- Working tree clean after push; ignored only: `.build/`, `dist/`,
  `config/.secret`

## Remaining work

- Deploy the new ZIP to the Windows Server hosting `search.wowtran.com` and
  restart SearXNG there. Pushing Git does not update production by itself.
- Keep the service on `127.0.0.1:3001` behind the reverse proxy; outbound
  search proxy remains `127.0.0.1:7897`.
- No other blockers in this repository for the autocomplete fix.

## Next recommended action

Copy `dist/SearXNGforWindows-2026.07.22.zip` to the production Windows Server,
replace the portable tree, and restart the SearXNG process. Then confirm on
the live results page that suggestion items remain clickable above the
language / time / safesearch row.
