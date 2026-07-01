defmodule Qx.Hardware.HttpTest do
  use ExUnit.Case, async: true

  alias Qx.Hardware.Http

  describe "redact_body/1" do
    test "extracts a recognised error field from a map" do
      assert Http.redact_body(%{"errorMessage" => "boom", "secret" => "x"}) == "boom"
      assert Http.redact_body(%{"detail" => "why"}) == "why"
    end

    test "drops content of a map with no recognised error field" do
      out = Http.redact_body(%{"leaked" => "SECRET", "token" => "SECRET"})
      assert out == "(response body redacted: 2 field(s))"
      refute out =~ "SECRET"
    end

    test "truncates a binary body to the byte cap" do
      out = Http.redact_body(String.duplicate("a", 1000))
      assert byte_size(out) <= 272
      assert out =~ "truncated"
    end

    test "truncates an over-long recognised error value" do
      out = Http.redact_body(%{"message" => String.duplicate("b", 1000)})
      assert byte_size(out) <= 272
      assert out =~ "truncated"
    end

    test "passes nil through and returns short bodies intact" do
      assert Http.redact_body(nil) == nil
      assert Http.redact_body("ok") == "ok"
    end
  end

  describe "http_error/2" do
    test "wraps status + redacted body" do
      assert {:error, {:http, 500, "nope"}} = Http.http_error(500, %{"message" => "nope"})
    end
  end

  describe "retry_after_seconds/1" do
    test "parses an integer retry-after header" do
      resp = %Req.Response{status: 429, headers: %{"retry-after" => ["12"]}}
      assert Http.retry_after_seconds(resp) == 12
    end

    test "returns nil when absent or non-integer" do
      assert Http.retry_after_seconds(%Req.Response{status: 429}) == nil

      resp = %Req.Response{status: 429, headers: %{"retry-after" => ["soon"]}}
      assert Http.retry_after_seconds(resp) == nil
    end
  end
end
