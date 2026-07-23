# AGENTS.md

## Scope

These instructions apply to the entire `SearXNGforWindows` repository.

This repository builds and ships a self-contained SearXNG portable package for
64-bit Windows Server 2012 R2 and later. Preserve the portable, application-only
deployment model: do not introduce a system-wide Python, proxy, or service
dependency unless the user explicitly requests it.

## Code discovery

Use the codebase knowledge graph before broad code searches:

1. `search_graph` to find symbols and routes.
2. `trace_path` to inspect callers and callees.
3. `get_code_snippet` to read a known symbol.
4. `query_graph` for more complex relationships.
5. `get_architecture` for a high-level overview.

Run `index_repository` first if this repository is not already indexed. Fall
back to `rg` or direct file reads for string literals, YAML, PowerShell, batch
files, templates, generated/vendor files, or when the graph is insufficient.

## Project invariants

- The local SearXNG endpoint is `127.0.0.1:3001`.
- SearXNG outbound search traffic uses the application-level HTTP proxy
  `http://127.0.0.1:7897`.
- Do not change Windows system proxy, WinHTTP proxy, or settings for unrelated
  applications.
- `config/.secret` is generated per deployment and must never be committed,
  copied into release archives, logged, or shared between servers.
- The public engine name is `google`; its implementation is currently
  `google_cse`. Do not expose `google cse` in the user interface.
- Keep the operator copyright and ICP registration footer unless the user
  explicitly supplies replacement legal text.
- Preserve the automatic, light, and dark theme switcher on every page,
  including search results and preferences.

## Sources of truth

- `config/settings.yml` controls runtime settings, enabled engines, port, bind
  address, and outbound proxy.
- `custom/theme.css` and `custom/theme.js` are the editable theme sources.
- `tools/build-portable.ps1` is the reproducible build recipe and must install
  every local customization into a fresh portable output.
- `SearXNG for Windows.bat` is the portable launcher.
- `python/` is the checked-in runnable artifact. Changes made directly under
  `python/Lib/site-packages/searx/` must also be represented in the build
  script or another source file so a clean rebuild does not lose them.
- `.build/`, `dist/`, and `config/.secret` are local artifacts and remain
  ignored by Git.

## Change workflow

1. Inspect `git status` before editing and preserve unrelated user changes.
2. Make source changes in `config/`, `custom/`, `tools/`, or the launcher as
   appropriate.
3. Mirror intentional runtime changes into `python/` when the checked-in
   portable runtime is part of the requested deliverable.
4. Rebuild into a clean directory with:

   ```powershell
   .\tools\build-portable.ps1 -OutputDirectory .\.build\portable-check
   ```

5. Test the clean output, not only the existing checked-in runtime.
6. Review the staged file list and confirm that no secret or generated release
   archive is included before committing.

Use a fixed upstream SearXNG commit in normal builds. Updating the upstream
reference is a deliberate dependency upgrade and requires a clean rebuild plus
search and UI regression testing.

## Validation

Run checks proportional to the change. For normal application changes, use:

```powershell
node --check .\custom\theme.js

$errors = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\tools\build-portable.ps1),
    [ref]$tokens,
    [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { $errors; exit 1 }
```

For a release or changes to settings, engines, templates, dependencies, or the
build script, also:

- complete a fresh portable build;
- start it on an unused local test port when port `3001` is occupied;
- verify the home, search results, and preferences pages;
- verify automatic/light/dark theme switching persists across navigation;
- query Google and confirm results are returned with engine label `google`;
- confirm the response has no unresponsive engine;
- stop every test process after validation;
- ensure `git status` contains only the intended changes.

When creating a ZIP, exclude `config/.secret`, report its SHA-256 hash, and keep
the ZIP outside Git unless the user explicitly requests a GitHub release asset.

## Git

Do not rewrite, discard, or overwrite unrelated work. Never use destructive Git
commands such as `git reset --hard` or `git checkout --` on user changes.

Commit and push only when the user asks. Before pushing, verify that the local
commit hash matches the remote branch after the push. Opening or merging a pull
request is a separate external action and requires an explicit request.

## Session handoff

Before the final response for every completed development task, update
`SESSION_HANDOFF.md` in the repository root. Treat this as a required part of
finishing the task, even when the user does not mention it again.

The handoff must be concise, current, and sufficient for a new AI with no chat
history to continue safely. Replace stale status instead of accumulating a long
conversation log. Include:

- the current objective and the latest user decision;
- what changed, with the important file paths;
- validation that actually ran and its result;
- the current branch, HEAD commit, push state, and uncommitted files;
- any local-only artifacts and their hashes when relevant;
- remaining work, blockers, risks, or an explicit statement that none remain;
- the exact next recommended action.

Record facts only. Clearly distinguish completed work from proposed work and
never include passwords, tokens, proxy credentials, `config/.secret`, or other
sensitive values. Re-read `git status` immediately before writing the handoff so
its Git state is accurate.
