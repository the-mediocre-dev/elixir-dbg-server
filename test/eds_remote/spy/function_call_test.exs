defmodule EDS.Remote.Spy.Interpreter.FunctionCallTests do
  use EDS.DataCase, async: false

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.FunctionCalls

  setup_all do
    start_supervised(Server)
    Server.load(FunctionCalls)
    Server.load(FunctionCalls.Interpreted)
    :ok
  end

  test "internal, public calls" do
    assert FunctionCalls.internal_public_call()
  end

  test "interal, private calls" do
    assert FunctionCalls.internal_private_call()
  end

  test "public recursive calls" do
    assert FunctionCalls.internal_public_recursion()
  end

  test "private recursive calls" do
    assert FunctionCalls.internal_private_recursion()
  end

  test "external, non-interpreted public calls" do
    assert FunctionCalls.external_non_interpreted_public_call()
  end

  test "external, non-interpreted private calls" do
    assert FunctionCalls.external_non_interpreted_private_call()
  end

  test "external, non-interpreted public recursive calls" do
    assert FunctionCalls.external_non_interpreted_public_recursion()
  end

  test "external, non-interpreted private recursive calls" do
    assert FunctionCalls.external_non_interpreted_public_recursion()
  end

  test "external, non-interpreted to interpreted calls" do
    assert FunctionCalls.external_non_interpreted_to_interpreted_call()
  end

  test "external, non-interpreted to interpreted reentry calls" do
    assert FunctionCalls.external_non_interpreted_to_interpreted_reentry_call()
  end

  test "external, interpreted public calls" do
    assert FunctionCalls.external_interpreted_public_call()
  end

  test "external, interpreted private calls" do
    assert FunctionCalls.external_interpreted_private_call()
  end

  test "external, interpreted public recursive calls" do
    assert FunctionCalls.external_interpreted_public_recursion()
  end

  test "external, interpreted private recursive calls" do
    assert FunctionCalls.external_interpreted_public_recursion()
  end

  test "external, interpreted to non-interpreted calls" do
    assert FunctionCalls.external_interpreted_to_non_interpreted_call()
  end

  test "external, interpreted to non-interpreted reentry calls" do
    assert FunctionCalls.external_interpreted_to_non_interpreted_reentry_call()
  end
end
