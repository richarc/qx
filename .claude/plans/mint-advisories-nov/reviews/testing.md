# Test coverage assessment: mint 1.9.3 -> 1.11.0, hpax 1.0.4 -> 1.1.0

Method tags: [V] verified by reading code, [I] inferred.

## Answer
The hardware tests do make real HTTP round trips through Req -> Finch -> Mint. They are not stubbed at the Req level.

- [V] There is no `Req.Test`, no `plug:` option and no Mox anywhere under `test/`. `test/support/stub_ibm.ex` says Mox is not in deps.
- [V] `test/qx/hardware/ibm_test.exs` and `portal_test.exs` use `Bypass.open()` (a real Cowboy listener on localhost). `base_url`, `iam_url` and `portal_url` point at `http://localhost:<port>`. `lib/qx/hardware/{ibm,portal}.ex` call `Req.new/get/post` with no adapter or plug override, so the default Finch adapter and Mint client run.
- [V] `hardware_test.exs` only uses `http://localhost` as a config value (lines 23, 66). `config_test.exs`, `config_from_env_test.exs` and `http_test.exs` do no I/O. `http_test.exs` is the `retry_after_seconds` header parser, which I inferred does no I/O from its scope; I did not open it.

## Does the green suite exercise the new mint? Yes, over HTTP/1.1 only.
- [V] Every request goes to `http://` (cleartext) with no TLS.
- [I] Mint only negotiates HTTP/2 through TLS ALPN, or with explicit `protocols: [:http2]` prior knowledge. I found no `protocols`, `connect_options` or `Finch` setting in `lib/`, `test/` or `config/`, so the connections are HTTP/1.1.
- [I] No test reaches the HTTP/2 code path, and no test reaches the hpax 1.1.0 HPACK code. HPACK is HTTP/2-only.
- [I] No test covers TLS or certificate handling, because Bypass is plain HTTP only. Mint's TLS/SSL paths are untested.
- [V] I did not open mix.lock beyond confirming the dep names. The cowboy, ranch and bypass versions were not checked and are not needed for this conclusion.

## Response paths exercised end to end (real socket)
- [V] Success: 200, 201 and 204 on list_backends, configuration, submit, poll, results, cancel, me and transpile.
- [V] Error status: 400, 401, 404, 418 (unmapped), 422, 429 (with retry-after), 502, 503 and 504.
- [V] Retry: `ibm_test.exs` lines 127-133 (a 401 followed by a 200 on `/backends`) and 471-476 (a 503 followed by a 200 on `/backends`). `config/test.exs` sets `ibm_retry_delay: 0` so the retries are fast.
- [V] Network failure: `Bypass.down` produces a connection-refused error. It is asserted as `{:error, {:network, _}}` in `ibm_test.exs:89-92` and `portal_test.exs:190`.
- [V] Content-type mismatch: JSON sent as `text/plain` (`ibm_test.exs:373`) still decodes through the IBM module's own `decode`.
- [V] Unexpected body shape: a valid JSON object with the wrong shape (`ibm_test.exs:395`, `some_other_shape`) is handled.
- [V] Bodies that must not leak into error values (`ibm_test.exs:458`, `portal_test.exs:201`) are tested.

## Not exercised
- [V] Receive timeout: no test sets a short timeout or has the server delay. The 10s, 30s and 60s `receive_timeout` values are never hit.
- [V] Truly malformed or truncated bodies: no test sends invalid JSON, a short body against its content-length header, or a mid-body socket close.
- [V] Large or chunked bodies (including transfer-encoding): not tested explicitly. Bodies are small. Req may stream them, but that is untested.
- [I] Connection reuse and pool behaviour across requests (keep-alive, NimblePool): each test opens a fresh Bypass port, so pool reuse against one host is only lightly exercised.
- [I] Redirects, gzip and other compressed content, and HTTPS to real IBM or portal hosts.

## What the green suite proves about this bump
- It proves that mint 1.11.0 compiles and works with the installed req and finch for plain-HTTP/1.1 request/response cycles. Those cycles include status handling, JSON decode, retry on 5xx/401 and connection-refused errors.
- It does not prove HTTP/2 or HPACK (hpax 1.1.0) behaviour, TLS behaviour, timeout behaviour, or malformed or truncated response handling. Production IBM and portal traffic is HTTPS and probably negotiates HTTP/2 through ALPN, so the code paths most likely to change in a mint 1.9 -> 1.11 bump are not covered. The production HTTP/2 claim is [I]; I did not check the hosts.
- Because the diff is lockfile-only and the advisories target mint/hpax internals, the real risk is residual (HTTP/2 and TLS), not in what the tests cover.

## Suggestions (non-blocking)
- [ ] Optional: add one `@tag :external`/manual smoke test against the real IBM or portal HTTPS endpoint, or a local TLS+ALPN test server, before release, if HTTP/2 confidence is wanted.
- [ ] Optional: add a timeout test (Bypass handler sleeping beyond a tiny `receive_timeout`) and a malformed-JSON body test. This is hardening, not a requirement for this bump.
- [ ] Review the changelog entry so it does not claim that tests cover HTTP/2.
