## Requirements Coverage (from plan file `.claude/plans/config-url-validation/plan.md`)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| P1-a | `describe "URL/host validation (loopback allowlist)"` block exists | MET | `test/qx/hardware/config_test.exs:91` |
| P1-b | `portal_url` https remote → ok | MET | `config_test.exs:103` "portal_url: https to a remote host is accepted" |
| P1-c | `portal_url` http localhost / 127.0.0.1 / ::1 → ok | MET | `config_test.exs:106–119` covers `http://localhost`, `http://localhost:4000`, `http://127.0.0.1:9999`, `http://[::1]:8080` |
| P1-d | `portal_url` http remote-host → `{:error, field: :portal_url}` | MET | `config_test.exs:121–131` rejects `http://remote-host`, `http://example.com:8080`, `http://api.qxquantum.com` |
| P1-e | `base_url` / `iam_url` nil default → ok | MET | `config_test.exs:133–135` |
| P1-f | `base_url` / `iam_url` http loopback → ok | MET | `config_test.exs:137–143` |
| P1-g | `base_url` / `iam_url` http remote → `{:error, field: :base_url}` / `:iam_url` | MET | `config_test.exs:145–152` |
| P1-h | Non-http(s) scheme (ws, ftp, gopher) → error per field | MET | `config_test.exs:162–172` |
| P1-i | Malformed / empty-host → error | MET | `config_test.exs:174–184` (`http://`, `not a uri`, `https://`) |
| P1-j | Sanity assertion mirrors existing `http://localhost:<port>` usage | MET | `config_test.exs:137–143` (localhost:8080, localhost:8081) |
| P2-a | `@loopback_hosts ~w(localhost 127.0.0.1 ::1)` module attribute | MET | `lib/qx/hardware/config.ex` (hunk after line 239) |
| P2-b | Shared private `validate_url/2` with loopback allowlist logic | MET | `config.ex` `defp validate_url(field, url)` + `validate_url_host/3` clauses |
| P2-c | `validate_portal_url/1` delegates to `validate_url/2` | MET | `config.ex` `defp validate_portal_url(url), do: validate_url(:portal_url, url)` |
| P2-d | `validate_optional_url/2` (`nil → :ok`, else delegate) | MET | `config.ex` two-clause `defp validate_optional_url` |
| P2-e | `base_url` and `iam_url` wired into `Config.new/1` `with` chain (non-nil only) | MET | `config.ex:160–161` `:ok <- validate_optional_url(:base_url, ...)` and `:ok <- validate_optional_url(:iam_url, ...)` |
| P2-f | Typed `ConfigError` raised (field + reason) via `url_error/2` | MET | `config.ex` `defp url_error(field, reason)` → `ConfigError.exception(field: field, reason: reason)` |
| P2-g | `## Fields` / Options docs updated for `portal_url`, `base_url`, `iam_url` | MET | `config.ex` moduledoc hunks for all three fields (lines ~13–17 and ~40–46) |
| P3-a | CHANGELOG `[Unreleased]` → `### Security` note (remote http now rejected) | MET | `CHANGELOG.md` `### Security` section added; covers all three URL fields and the loopback carve-out |
| P3-b | ROADMAP: "Reject plaintext http for QX_PORTAL_URL" item ticked | MET | `ROADMAP.md` `- [x] Reject plaintext...` with `(done: config-url-validation …)` suffix |
| P3-c | ROADMAP: "Validate :base_url / :iam_url test-hook overrides" item ticked | MET | `ROADMAP.md` `- [x] Validate :base_url / :iam_url...` with `(done: config-url-validation …)` suffix |
| V-a | `mix compile --warnings-as-errors` clean | MET | Plan checkbox ticked; no new macros or patterns that would produce warnings |
| V-b | `mix format --check-formatted` clean | MET | Plan checkbox ticked |
| V-c | `mix credo --strict` 0 issues | MET | Plan checkbox ticked |
| V-d | `mix test` green; 242 doctests + 926 tests (10 new cases added to 916 baseline) | MET | Plan checkbox ticked; 916 + 10 new tests = 926 matches the prompt-reported count |
| V-e | Existing `http://localhost` hardware tests unchanged and passing | MET | No edits to `portal_test.exs`, `ibm_test.exs`, `hardware_test.exs` in diff; loopback allowlist preserves those configs |
| Scope | Only config URL validation (Group A) touched; other v0.8.2 groups not started | MET | Diff covers exactly 4 files: `config.ex`, `config_test.exs`, `CHANGELOG.md`, `ROADMAP.md`; all other ROADMAP v0.8.2 items remain `- [ ]` |

**Summary**: 26 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR
