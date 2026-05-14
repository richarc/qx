defmodule Qx.Hardware.IbmTest do
  @moduledoc """
  Verifies `Qx.Hardware.Ibm` against Bypass-stubbed IBM Quantum responses.
  Real-IBM integration coverage lives behind a manual sanity step in the
  PR description (see `.claude/plans/qx-hardware/plan.md`).
  """
  use ExUnit.Case, async: true

  alias Qx.Hardware.Config
  alias Qx.Hardware.Ibm

  setup do
    api = Bypass.open()
    iam = Bypass.open()

    config = %Config{
      portal_url: "http://localhost:9999",
      portal_token: "ptok",
      ibm_api_key: "test_api_key",
      ibm_crn: "crn:v1:bluemix:public:quantum:us-south:a/...:test::",
      ibm_region: "us-south",
      backend: "ibm_brisbane",
      iam_url: "http://localhost:#{iam.port}/identity/token",
      base_url: "http://localhost:#{api.port}"
    }

    %{api: api, iam: iam, config: config}
  end

  defp json_resp(conn, status, payload) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(payload))
  end

  defp expect_iam(iam, opts) do
    expires_in = Keyword.get(opts, :expires_in, 3600)
    token = Keyword.get(opts, :token, "iam_token_v1")

    Bypass.expect_once(iam, "POST", "/identity/token", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "apikey=test_api_key"
      assert body =~ "grant_type="

      json_resp(conn, 200, %{
        access_token: token,
        expires_in: expires_in,
        refresh_token: "refresh_xyz",
        token_type: "Bearer"
      })
    end)
  end

  defp authed_config(config, token \\ "iam_token_v1") do
    %{
      config
      | access_token: token,
        token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }
  end

  describe "iam_exchange/1" do
    test "returns config with access_token + token_expires_at on 200", %{iam: iam, config: config} do
      expect_iam(iam, token: "fresh_token", expires_in: 3600)

      assert {:ok, refreshed} = Ibm.iam_exchange(config)
      assert refreshed.access_token == "fresh_token"
      assert %DateTime{} = refreshed.token_expires_at
      assert refreshed.ibm_api_key == "test_api_key"
      assert refreshed.ibm_region == "us-south"
    end

    test "401 maps to :unauthorized", %{iam: iam, config: config} do
      Bypass.expect_once(iam, "POST", "/identity/token", fn conn ->
        json_resp(conn, 401, %{errorMessage: "BXNIM0415E: Provided API key could not be found."})
      end)

      assert Ibm.iam_exchange(config) == {:error, :unauthorized}
    end

    test "400 (bad grant) maps to :unauthorized", %{iam: iam, config: config} do
      Bypass.expect_once(iam, "POST", "/identity/token", fn conn ->
        json_resp(conn, 400, %{errorMessage: "Bad grant"})
      end)

      assert Ibm.iam_exchange(config) == {:error, :unauthorized}
    end

    test "network failure maps to {:network, reason}", %{iam: iam, config: config} do
      Bypass.down(iam)
      assert {:error, {:network, _}} = Ibm.iam_exchange(config)
    end
  end

  describe "list_backends/1" do
    test "decodes :name, :status, :num_qubits from devices wrapper", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/backends", fn conn ->
        assert ["Bearer iam_token_v1"] = Plug.Conn.get_req_header(conn, "authorization")
        assert [_crn] = Plug.Conn.get_req_header(conn, "service-crn")
        assert ["2026-03-15"] = Plug.Conn.get_req_header(conn, "ibm-api-version")

        json_resp(conn, 200, %{
          devices: [
            %{name: "ibm_brisbane", status: "active", num_qubits: 127},
            %{name: "ibm_kyoto", status: "maintenance", num_qubits: 127}
          ]
        })
      end)

      assert {:ok, [first, second]} = Ibm.list_backends(authed_config(config))
      assert first == %{name: "ibm_brisbane", status: "active", num_qubits: 127}
      assert second.name == "ibm_kyoto"
    end

    test "tolerates `backends` wrapper", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/backends", fn conn ->
        json_resp(conn, 200, %{
          backends: [%{backend_name: "ibmq_qasm_simulator", status: "active", num_qubits: 32}]
        })
      end)

      assert {:ok, [%{name: "ibmq_qasm_simulator"}]} =
               Ibm.list_backends(authed_config(config))
    end

    test "401 triggers IAM refresh and one retry", %{api: api, iam: iam, config: config} do
      Bypass.expect(api, "GET", "/backends", fn conn ->
        case Plug.Conn.get_req_header(conn, "authorization") do
          ["Bearer stale_token"] ->
            json_resp(conn, 401, %{error: "expired"})

          ["Bearer fresh_token"] ->
            json_resp(conn, 200, %{
              devices: [%{name: "ibm_brisbane", status: "active", num_qubits: 127}]
            })
        end
      end)

      expect_iam(iam, token: "fresh_token")

      stale = authed_config(config, "stale_token")
      assert {:ok, [%{name: "ibm_brisbane"}]} = Ibm.list_backends(stale)
    end
  end

  describe "fetch_backend_configuration/2" do
    test "extracts coupling_map, basis_gates, num_qubits from /configuration", %{
      api: api,
      config: config
    } do
      Bypass.expect_once(api, "GET", "/backends/ibm_brisbane/configuration", fn conn ->
        json_resp(conn, 200, %{
          backend_name: "ibm_brisbane",
          coupling_map: [[0, 1], [1, 2]],
          basis_gates: ["id", "rz", "sx", "x", "cx"],
          n_qubits: 127,
          online_date: "2026-05-10T00:00:00Z"
        })
      end)

      assert {:ok, props} =
               Ibm.fetch_backend_configuration(authed_config(config), "ibm_brisbane")

      assert props.coupling_map == [[0, 1], [1, 2]]
      assert props.basis_gates == ["id", "rz", "sx", "x", "cx"]
      assert props.num_qubits == 127
    end

    test "tolerates legacy `num_qubits` field if a server returns it", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/backends/legacy/configuration", fn conn ->
        json_resp(conn, 200, %{
          coupling_map: [],
          basis_gates: ["x"],
          num_qubits: 5
        })
      end)

      assert {:ok, %{num_qubits: 5}} =
               Ibm.fetch_backend_configuration(authed_config(config), "legacy")
    end
  end

  describe "submit_sampler/4" do
    test "wraps qasm into pubs: [[qasm, nil, shots]] and POSTs without session", %{
      api: api,
      config: config
    } do
      qasm = "OPENQASM 3.0; qubit[2] q; h q[0]; cx q[0], q[1];"

      Bypass.expect_once(api, "POST", "/jobs", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert {:ok, decoded} = Jason.decode(body)

        assert decoded["program_id"] == "sampler"
        assert decoded["backend"] == "ibm_brisbane"
        refute Map.has_key?(decoded, "session_id")
        assert [[^qasm, nil, 4096]] = decoded["params"]["pubs"]
        assert decoded["params"]["version"] == 2

        json_resp(conn, 200, %{id: "job_xyz789", backend: "ibm_brisbane"})
      end)

      assert {:ok, "job_xyz789"} =
               Ibm.submit_sampler(authed_config(config), qasm, "ibm_brisbane", 4096)
    end

    test "honours custom shots count", %{api: api, config: config} do
      Bypass.expect_once(api, "POST", "/jobs", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert {:ok, %{"params" => %{"pubs" => [[_, nil, 1024]]}}} = Jason.decode(body)
        json_resp(conn, 200, %{id: "job_custom_shots"})
      end)

      assert {:ok, "job_custom_shots"} =
               Ibm.submit_sampler(
                 authed_config(config),
                 "OPENQASM 3.0;",
                 "ibm_brisbane",
                 1024
               )
    end
  end

  describe "poll_job/2" do
    test "Completed (nested state.status) returns binary status", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/job_xyz", fn conn ->
        json_resp(conn, 200, %{
          id: "job_xyz",
          state: %{status: "Completed", reason: ""},
          status: "Completed"
        })
      end)

      assert {:ok, %{status: "Completed", reason: ""}} =
               Ibm.poll_job(authed_config(config), "job_xyz")
    end

    test "reads top-level status when no nested state present", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/job_top", fn conn ->
        json_resp(conn, 200, %{id: "job_top", status: "Running"})
      end)

      assert {:ok, %{status: "Running"}} =
               Ibm.poll_job(authed_config(config), "job_top")
    end

    test "Failed status includes reason", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/job_e", fn conn ->
        json_resp(conn, 200, %{
          state: %{status: "Failed", reason: "circuit too large"}
        })
      end)

      assert {:ok, %{status: "Failed", reason: "circuit too large"}} =
               Ibm.poll_job(authed_config(config), "job_e")
    end

    test "all documented Pascal-Case statuses round-trip without atom conversion", %{
      api: api,
      config: config
    } do
      for status <- [
            "Queued",
            "Running",
            "Completed",
            "Cancelled",
            "Cancelled - Ran too long",
            "Failed"
          ] do
        path_safe = String.replace(status, " ", "_")

        Bypass.expect_once(api, "GET", "/jobs/poll_#{path_safe}", fn conn ->
          json_resp(conn, 200, %{state: %{status: status}})
        end)

        assert {:ok, %{status: ^status}} =
                 Ibm.poll_job(authed_config(config), "poll_#{path_safe}")
      end
    end

    test "unknown status surfaces loudly (no String.to_atom)", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/job_drift", fn conn ->
        json_resp(conn, 200, %{state: %{status: "WatNewState"}})
      end)

      assert {:error, {:unknown_status, "WatNewState"}} =
               Ibm.poll_job(authed_config(config), "job_drift")
    end

    test "response with no status at all → :unexpected_response", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/no_status", fn conn ->
        json_resp(conn, 200, %{id: "x", state: %{}})
      end)

      assert {:error, :unexpected_response} =
               Ibm.poll_job(authed_config(config), "no_status")
    end
  end

  describe "terminal_success?/1 + terminal_failure?/1" do
    test "Completed is terminal success" do
      assert Ibm.terminal_success?("Completed")
      refute Ibm.terminal_success?("Running")
      refute Ibm.terminal_success?("Failed")
    end

    test "Failed/Cancelled variants are terminal failure" do
      assert Ibm.terminal_failure?("Failed")
      assert Ibm.terminal_failure?("Cancelled")
      assert Ibm.terminal_failure?("Cancelled - Ran too long")
      refute Ibm.terminal_failure?("Queued")
      refute Ibm.terminal_failure?("Completed")
    end
  end

  describe "fetch_results/2" do
    test "Sampler V2 shape aggregates samples to counts", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/job_done/results", fn conn ->
        json_resp(conn, 200, %{
          results: [
            %{
              data: %{
                c: %{
                  samples: ["0x0", "0x3", "0x3", "0x0", "0x3", "0x1", "0x0", "0x3"],
                  num_bits: 2
                }
              },
              metadata: %{circuit_metadata: %{}}
            }
          ],
          metadata: %{execution: %{execution_spans: []}, version: 2}
        })
      end)

      assert {:ok, %{counts: counts, metadata: meta}} =
               Ibm.fetch_results(authed_config(config), "job_done")

      assert counts == %{"00" => 3, "11" => 4, "01" => 1}
      assert meta["version"] == 2
    end

    test "wide registers (num_bits > 4) zero-pad correctly", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/job_wide/results", fn conn ->
        json_resp(conn, 200, %{
          results: [
            %{
              data: %{
                c: %{
                  samples: ["0x0", "0x1", "0x10", "0x1f", "0x0"],
                  num_bits: 5
                }
              }
            }
          ]
        })
      end)

      assert {:ok, %{counts: counts}} =
               Ibm.fetch_results(authed_config(config), "job_wide")

      assert counts == %{"00000" => 2, "00001" => 1, "10000" => 1, "11111" => 1}
    end

    test "tolerates a JSON body returned as a plain binary (no content-type)",
         %{api: api, config: config} do
      json_body =
        Jason.encode!(%{
          results: [
            %{data: %{c: %{samples: ["0x0", "0x3"], num_bits: 2}}}
          ]
        })

      Bypass.expect_once(api, "GET", "/jobs/job_text/results", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.resp(200, json_body)
      end)

      assert {:ok, %{counts: %{"00" => 1, "11" => 1}}} =
               Ibm.fetch_results(authed_config(config), "job_text")
    end

    test "no recognizable register data → :unsupported_result", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/job_estim/results", fn conn ->
        json_resp(conn, 200, %{
          results: [%{data: %{c: %{values: "base64=="}}}]
        })
      end)

      assert {:error, :unsupported_result} =
               Ibm.fetch_results(authed_config(config), "job_estim")
    end

    test "body missing `results` key → :unexpected_response", %{api: api, config: config} do
      Bypass.expect_once(api, "GET", "/jobs/weird/results", fn conn ->
        json_resp(conn, 200, %{some_other_shape: true})
      end)

      assert {:error, :unexpected_response} =
               Ibm.fetch_results(authed_config(config), "weird")
    end
  end

  describe "cancel_job/2" do
    test "POST /jobs/:id/cancel → :ok on 200", %{api: api, config: config} do
      Bypass.expect_once(api, "POST", "/jobs/job_x/cancel", fn conn ->
        json_resp(conn, 200, %{id: "job_x", status: "Cancelled"})
      end)

      assert :ok = Ibm.cancel_job(authed_config(config), "job_x")
    end

    test "204 → :ok", %{api: api, config: config} do
      Bypass.expect_once(api, "POST", "/jobs/job_204/cancel", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Ibm.cancel_job(authed_config(config), "job_204")
    end

    test "404 (already terminal / unknown) → :ok (best-effort)", %{api: api, config: config} do
      Bypass.expect_once(api, "POST", "/jobs/gone/cancel", fn conn ->
        json_resp(conn, 404, %{error: "not_found"})
      end)

      assert :ok = Ibm.cancel_job(authed_config(config), "gone")
    end
  end

  describe "base_url_for/1" do
    test "us-south points at quantum.cloud.ibm.com" do
      assert Ibm.base_url_for("us-south") == "https://quantum.cloud.ibm.com/api/v1"
    end

    test "eu-de points at eu-de host" do
      assert Ibm.base_url_for("eu-de") == "https://eu-de.quantum.cloud.ibm.com/api/v1"
    end

    test "other allowlisted regions follow <region>.quantum.cloud.ibm.com" do
      assert Ibm.base_url_for("us-east") == "https://us-east.quantum.cloud.ibm.com/api/v1"
      assert Ibm.base_url_for("eu-es") == "https://eu-es.quantum.cloud.ibm.com/api/v1"
      assert Ibm.base_url_for("jp-tok") == "https://jp-tok.quantum.cloud.ibm.com/api/v1"
      assert Ibm.base_url_for("au-syd") == "https://au-syd.quantum.cloud.ibm.com/api/v1"
    end
  end
end
