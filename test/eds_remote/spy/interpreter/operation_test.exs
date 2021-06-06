defmodule EDS.Remote.Spy.Interpreter.OperationTests do
  use EDSWeb.ConnCase, async: true

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.Operations

  setup_all do
    start_supervised(Server)
    Server.load(Operations)
    :ok
  end

  test "+" do
    assert 20 === Operations.add(10, 10)
    assert 20.0 === Operations.add(10.0, 10.0)
  end

  test "-" do
    assert 0 === Operations.subtract(10, 10)
    assert 0.0 === Operations.subtract(10.0, 10.0)
  end

  test "*" do
    assert 100 === Operations.multiply(10, 10)
    assert 100.0 === Operations.multiply(10.0, 10.0)
  end

  test "/" do
    assert 1.0 === Operations.divide(10, 10)
    assert 1.0 === Operations.divide(10.0, 10.0)
  end

  test "div" do
    assert 1 === Operations.integer_divide(10, 10)

    assert_raise ArithmeticError, fn ->
      Operations.integer_divide(10.0, 10.0)
    end
  end

  test "rem" do
    assert 0 === Operations.integer_remainder(10, 10)

    assert_raise ArithmeticError, fn ->
      Operations.integer_remainder(10.0, 10.0)
    end
  end

  test "or" do
    assert Operations.boolean_or(true, true)
    assert Operations.boolean_or(true, false)
    assert Operations.boolean_or(false, true)
    refute Operations.boolean_or(false, false)

    assert_raise BadBooleanError, fn ->
      Operations.boolean_or(1.0, 1.0)
    end

    assert Operations.boolean_or_short_circuit(true)

    assert_raise RuntimeError, "short circuit failover", fn ->
      Operations.boolean_or_short_circuit(false)
    end
  end

  test "||" do
    assert Operations.loose_or(true, true)
    assert Operations.loose_or(true, false)
    assert Operations.loose_or(false, true)
    refute Operations.loose_or(false, false)
    assert Operations.loose_or(1, 1)
    assert Operations.loose_or(nil, 1)
    assert Operations.loose_or(1, nil)
    refute Operations.loose_or(nil, nil)
    assert Operations.loose_or_short_circuit(true)
    assert Operations.loose_or_short_circuit(1.0)

    assert_raise RuntimeError, "short circuit failover", fn ->
      Operations.loose_or_short_circuit(false)
    end

    assert_raise RuntimeError, "short circuit failover", fn ->
      Operations.loose_or_short_circuit(nil)
    end
  end

  test "and" do
    assert Operations.boolean_and(true, true)
    refute Operations.boolean_and(true, false)
    refute Operations.boolean_and(false, true)
    refute Operations.boolean_and(false, false)
    refute Operations.boolean_and_short_circuit(false)

    assert_raise BadBooleanError, fn ->
      Operations.boolean_and(1.0, 1.0)
    end

    assert_raise RuntimeError, "short circuit failover", fn ->
      Operations.boolean_and_short_circuit(true)
    end
  end

  test "&&" do
    assert Operations.loose_and(true, true)
    refute Operations.loose_and(true, false)
    refute Operations.loose_and(false, true)
    refute Operations.loose_and(false, false)
    assert Operations.loose_and(1, 1)
    refute Operations.loose_and(nil, 1)
    refute Operations.loose_and(1, nil)
    refute Operations.loose_and(nil, nil)
    refute Operations.loose_and_short_circuit(false)
    refute Operations.loose_and_short_circuit(nil)

    assert_raise RuntimeError, "short circuit failover", fn ->
      Operations.loose_and_short_circuit(true)
    end

    assert_raise RuntimeError, "short circuit failover", fn ->
      Operations.loose_and_short_circuit(1.0)
    end
  end

  test "not" do
    assert Operations.boolean_not(false)
    refute Operations.boolean_not(true)

    assert_raise ArgumentError, fn ->
      Operations.boolean_not(1.0)
    end
  end

  test "!" do
    assert Operations.loose_not(false)
    refute Operations.loose_not(true)
    assert Operations.loose_not(nil)
    refute Operations.loose_not(1.0)
  end

  test "==" do
    assert Operations.equals(1, 1)
    assert Operations.equals(1.0, 1)
    assert Operations.equals(%{}, %{})
    assert Operations.equals([], [])
    refute Operations.equals(%{a: :a}, %{})
    refute Operations.equals([1], [])
  end

  test "!=" do
    refute Operations.not_equals(1, 1)
    refute Operations.not_equals(1.0, 1)
    refute Operations.not_equals(%{}, %{})
    refute Operations.not_equals([], [])
    assert Operations.not_equals(%{a: :a}, %{})
    assert Operations.not_equals([1], [])
  end

  test "===" do
    assert Operations.strictly_equals(1, 1)
    refute Operations.strictly_equals(1.0, 1)
    assert Operations.strictly_equals(%{}, %{})
    assert Operations.strictly_equals([], [])
    refute Operations.strictly_equals(%{a: :a}, %{})
    refute Operations.strictly_equals([1], [])
  end

  test "!==" do
    refute Operations.strictly_not_equals(1, 1)
    assert Operations.strictly_not_equals(1.0, 1)
    refute Operations.strictly_not_equals(%{}, %{})
    refute Operations.strictly_not_equals([], [])
    assert Operations.strictly_not_equals(%{a: :a}, %{})
    assert Operations.strictly_not_equals([1], [])
  end

  test "<" do
    assert Operations.less_than(0, 1)
    refute Operations.less_than(1, 1)
    assert Operations.less_than(1, :atom)
  end

  test ">" do
    assert Operations.greater_than(1, 0)
    refute Operations.greater_than(1, 1)
    refute Operations.greater_than(1, :atom)
  end

  test "<=" do
    assert Operations.less_than_equals(0, 1)
    assert Operations.less_than_equals(1, 1)
    assert Operations.less_than_equals(1, :atom)
  end

  test ">=" do
    assert Operations.greater_than_equals(1, 0)
    assert Operations.greater_than_equals(1, 1)
    refute Operations.greater_than_equals(1, :atom)
  end

  test "[|]" do
    assert [:a, :b] == Operations.cons(:a, :b)
  end

  test "<>" do
    assert "ab" == Operations.concatenation("a", "b")
  end
end
