defmodule EDS.Remote.Spy.Interpreter.ErrorsTests do
  use EDS.DataCase, async: false

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.Errors

  setup_all do
    start_supervised(Server)
    Server.load(Errors)
    Server.load(Errors.Interpreted)
    :ok
  end

  test "raise in non-interpreted function" do
    assert_raise RuntimeError, "error", fn ->
      Errors.raise_non_interpreted()
    end
  end

  test "raise in non-interpreted function with rescue" do
    assert %RuntimeError{message: "error"} = Errors.raise_rescue_non_interpreted()
  end

  test "raise in interpreted function" do
    assert_raise RuntimeError, "error", fn ->
      Errors.raise_interpreted()
    end
  end

  test "raise in interpreted function with rescue" do
    assert %RuntimeError{message: "error"} = Errors.raise_rescue_interpreted()
  end

  test "throw in non-interpreted function" do
    assert catch_throw(Errors.throw_non_interpreted()) == :thrown
  end

  test "throw in non-interpreted function with catch" do
    assert :thrown == Errors.throw_catch_non_interpreted()
  end

  test "throw in interpreted function" do
    assert :thrown == catch_throw(Errors.throw_interpreted())
  end

  test "throw in interpreted function with catch" do
    assert :thrown == Errors.throw_catch_interpreted()
  end

  test "exit in non-interpreted function" do
    assert :exited == catch_exit(Errors.exit_non_interpreted())
  end

  test "exit in non-interpreted function with trap" do
    assert :exited == Errors.exit_trap_non_interpreted()
  end

  test "exit in interpreted function" do
    assert :exited == catch_exit(Errors.exit_interpreted())
  end

  test "exit in interpreted function with trap" do
    assert :exited == Errors.exit_trap_interpreted()
  end

  test "undefined function error in non-interpreted function" do
    assert_raise UndefinedFunctionError, fn ->
      Errors.undefined_function_non_interpreted()
    end
  end

  test "undefined function error in interpreted function" do
    assert_raise UndefinedFunctionError, fn ->
      Errors.undefined_function_interpreted()
    end
  end

  test "after rescue block" do
    assert_raise RuntimeError, "after", fn ->
      Errors.after_rescue_block()
    end
  end

  test "after catch block" do
    assert_raise RuntimeError, "after", fn ->
      Errors.after_catch_block()
    end
  end

  test "BIF exception in non-interpreted " do
    assert_raise ArgumentError, fn ->
      Errors.bif_error_non_interpreted()
    end
  end

  test "BIF exception in interpreted" do
    assert_raise ArgumentError, fn ->
      Errors.bif_error_interpreted()
    end
  end
end
