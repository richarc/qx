defmodule Qx.RemoteTest do
  use ExUnit.Case, async: true

  alias Qx.Remote
  alias Qx.Remote.Config

  @config Config.new!(url: "http://localhost:4040", api_key: "test-key")

  defp circuit do
    Qx.create_circuit(2, 2)
    |> Qx.h(0)
    |> Qx.cx(0, 1)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
  end

  defp stub_plug(test_name) do
    Req.Test.stub(test_name, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(self(), {:request, conn.method, conn.request_path, body})

      {status, resp_body} =
        receive do
          {:respond, status, body} -> {status, body}
        after
          0 -> {500, %{"error" => "no response configured"}}
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, Jason.encode!(resp_body))
    end)
  end

  defp req_options(test_name) do
    [req_options: [plug: {Req.Test, test_name}]]
  end

  describe "Config" do
    test "new/1 creates valid config" do
      assert {:ok, %Config{url: "http://localhost:4040"}} =
               Config.new(url: "http://localhost:4040")
    end

    test "new/1 strips trailing slash" do
      assert {:ok, %Config{url: "http://localhost:4040"}} =
               Config.new(url: "http://localhost:4040/")
    end

    test "new/1 rejects missing url" do
      assert {:error, "url is required"} = Config.new([])
    end

    test "new!/1 raises on invalid input" do
      assert_raise ArgumentError, fn -> Config.new!([]) end
    end

    test "new/1 sets defaults" do
      {:ok, config} = Config.new(url: "http://example.com")
      assert config.timeout == 300_000
      assert config.api_key == nil
    end
  end

  describe "submit/3" do
    test "sends QASM to server" do
      test_name = :submit_test
      stub_plug(test_name)

      send(self(), {:respond, 202, %{"job_id" => "abc123", "status" => "submitted"}})

      {:ok, job} = Remote.submit(circuit(), @config, [backend: "ibm_fez"] ++ req_options(test_name))

      assert job["job_id"] == "abc123"
      assert job["status"] == "submitted"

      assert_received {:request, "POST", "/api/v1/jobs", body}
      decoded = Jason.decode!(body)
      assert decoded["backend"] == "ibm_fez"
      assert decoded["shots"] == 4096
      assert String.contains?(decoded["qasm"], "OPENQASM 3.0")
    end

    test "raises without backend" do
      assert_raise ArgumentError, "backend is required", fn ->
        Remote.submit(circuit(), @config, [])
      end
    end

    test "returns error on server error" do
      test_name = :submit_error_test
      stub_plug(test_name)

      send(self(), {:respond, 400, %{"error" => "bad_request", "message" => "qasm is required"}})

      assert {:error, "qasm is required"} =
               Remote.submit(circuit(), @config, [backend: "ibm_fez"] ++ req_options(test_name))
    end
  end

  describe "status/3" do
    test "returns job status" do
      test_name = :status_test
      stub_plug(test_name)

      send(self(), {:respond, 200, %{"job_id" => "abc", "status" => "running"}})

      assert {:ok, %{"status" => "running"}} =
               Remote.status("abc", @config, req_options(test_name))
    end

    test "returns not_found for missing job" do
      test_name = :status_404_test
      stub_plug(test_name)

      send(self(), {:respond, 404, %{"error" => "not_found"}})

      assert {:error, :not_found} =
               Remote.status("unknown", @config, req_options(test_name))
    end
  end

  describe "cancel/3" do
    test "cancels a job" do
      test_name = :cancel_test
      stub_plug(test_name)

      send(self(), {:respond, 200, %{"job_id" => "abc", "status" => "cancelled"}})

      assert {:ok, %{"status" => "cancelled"}} =
               Remote.cancel("abc", @config, req_options(test_name))
    end
  end

  describe "list_backends/2" do
    test "lists backends" do
      test_name = :backends_test
      stub_plug(test_name)

      send(self(), {:respond, 200, %{"backends" => [%{"name" => "ibm_fez", "qubits" => 156}]}})

      assert {:ok, [%{"name" => "ibm_fez"}]} =
               Remote.list_backends(@config, req_options(test_name))
    end

    test "filters by provider" do
      test_name = :backends_filter_test

      Req.Test.stub(test_name, fn conn ->
        assert conn.query_string == "provider=ibm"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"backends" => []}))
      end)

      {:ok, []} = Remote.list_backends(@config, [provider: "ibm"] ++ req_options(test_name))
    end
  end

  describe "await/3" do
    test "polls until completed and returns SimulationResult" do
      test_name = :await_test
      stub_plug(test_name)

      # First poll: running
      send(self(), {:respond, 200, %{"job_id" => "abc", "status" => "running"}})
      # Second poll: completed
      send(self(), {:respond, 200, %{"job_id" => "abc", "status" => "completed"}})
      # Results fetch
      send(self(), {:respond, 200, %{"counts" => %{"00" => 500, "11" => 500}, "shots" => 1000, "num_classical_bits" => 2}})

      {:ok, result} =
        Remote.await("abc", @config,
          [poll_interval: 10, on_status: fn s -> send(self(), {:status_cb, s["status"]}) end] ++
            req_options(test_name)
        )

      assert %Qx.SimulationResult{} = result
      assert result.shots == 1000
      assert result.counts == %{"00" => 500, "11" => 500}

      assert_received {:status_cb, "running"}
      assert_received {:status_cb, "completed"}
    end

    test "returns error on failure" do
      test_name = :await_fail_test
      stub_plug(test_name)

      send(self(), {:respond, 200, %{"job_id" => "abc", "status" => "failed", "error" => "Hardware error"}})

      assert {:error, %{status: "failed"}} =
               Remote.await("abc", @config, [poll_interval: 10] ++ req_options(test_name))
    end

    test "returns timeout error" do
      test_name = :await_timeout_test
      stub_plug(test_name)

      # Always return running
      Req.Test.stub(test_name, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"job_id" => "abc", "status" => "queued"}))
      end)

      assert {:error, :timeout} =
               Remote.await("abc", @config,
                 [timeout: 50, poll_interval: 10] ++ req_options(test_name)
               )
    end
  end

  describe "run/3" do
    test "submits circuit and returns SimulationResult" do
      test_name = :run_test

      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(test_name, fn conn ->
        :counters.add(call_count, 1, 1)
        n = :counters.get(call_count, 1)

        {status, body} =
          case {conn.method, n} do
            {"POST", 1} ->
              {202, %{"job_id" => "run123", "status" => "submitted"}}

            {"GET", 2} ->
              {200, %{"job_id" => "run123", "status" => "completed"}}

            {"GET", 3} ->
              {200, %{"counts" => %{"00" => 600, "11" => 400}, "shots" => 1000, "num_classical_bits" => 2}}
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, Jason.encode!(body))
      end)

      {:ok, result} =
        Remote.run(circuit(), @config,
          [backend: "ibm_fez", shots: 1000, poll_interval: 10] ++ req_options(test_name)
        )

      assert %Qx.SimulationResult{} = result
      assert result.shots == 1000
      assert result.counts["00"] == 600
    end
  end
end
