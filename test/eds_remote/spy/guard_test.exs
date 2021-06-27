defmodule EDS.Remote.Spy.Interpreter.GuardTests do
  use EDS.DataCase, async: false

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.Guards

  setup_all do
    start_supervised(Server)
    Server.load(Guards)
    :ok
  end

  test "addition" do
    assert Guards.addition(0, 0, 0)
    assert Guards.addition(0, 1, 1)
    assert Guards.addition(1, 1, 2)
    assert Guards.addition(-1, 1, 0)
    assert Guards.addition(1.0, 1, 2.0)
    assert Guards.addition(-1.0, 1, 0.0)
    assert Guards.addition(10, 10, 20)
    refute Guards.addition(1, 1, 10)
    refute Guards.addition(%{a: :a}, %{a: :a}, 1)
  end

  test "binary_and" do
    assert Guards.binary_and(0, 0, 0)
    assert Guards.binary_and(-1, 1, 1)
    refute Guards.binary_and({}, 0, 0)
  end

  test "binary_band" do
    assert Guards.binary_band(0, 0, 0)
    assert Guards.binary_band(-1, 1, 1)
    refute Guards.binary_band({}, 0, 0)
  end

  test "binary_or" do
    assert Guards.binary_or(0, 0, 0)
    assert Guards.binary_or(-1, 1, -1)
    refute Guards.binary_or({}, 0, 0)
  end

  test "binary_bor" do
    assert Guards.binary_bor(0, 0, 0)
    assert Guards.binary_bor(-1, 1, -1)
    refute Guards.binary_bor({}, 0, 0)
  end

  test "binary_left_bit_shift" do
    assert Guards.binary_left_bit_shift(0, 0, 0)
    assert Guards.binary_left_bit_shift(1, 1, 2)
    refute Guards.binary_left_bit_shift({}, 0, 0)
  end

  test "binary_bsl" do
    assert Guards.binary_bsl(0, 0, 0)
    assert Guards.binary_bsl(1, 1, 2)
    refute Guards.binary_bsl({}, 0, 0)
  end

  test "binary_right_bit_shift" do
    assert Guards.binary_right_bit_shift(0, 0, 0)
    assert Guards.binary_right_bit_shift(2, 1, 1)
    refute Guards.binary_right_bit_shift({}, 0, 0)
  end

  test "binary_bsr" do
    assert Guards.binary_bsr(0, 0, 0)
    assert Guards.binary_bsr(2, 1, 1)
    refute Guards.binary_bsr({}, 0, 0)
  end

  test "binary_not" do
    assert Guards.binary_not(0, -1)
    assert Guards.binary_not(-1, 0)
    refute Guards.binary_not({}, 0)
  end

  test "binary_bnot" do
    assert Guards.binary_bnot(0, -1)
    assert Guards.binary_bnot(-1, 0)
    refute Guards.binary_bnot({}, 0)
  end

  test "binary_bxor" do
    assert Guards.binary_bxor(0, 0, 0)
    assert Guards.binary_bxor(-1, 1, -2)
    refute Guards.binary_bxor({}, 0, 0)
  end

  test "is_atom?" do
    assert Guards.is_atom?(:atom)
    refute Guards.is_atom?({})
  end

  test "is_binary?" do
    assert Guards.is_binary?("a")
    assert Guards.is_binary?("")
    assert Guards.is_binary?(<<1>>)
    refute Guards.is_tuple?(nil)
  end

  test "is_bitstring?" do
    assert Guards.is_bitstring?("a")
    refute Guards.is_bitstring?({})
  end

  test "is_boolean?" do
    assert Guards.is_boolean?(true)
    assert Guards.is_boolean?(false)
    refute Guards.is_boolean?({})
  end

  test "is_float?" do
    assert Guards.is_float?(0.0)
    assert Guards.is_float?(-0.0)
    refute Guards.is_float?(0)
    refute Guards.is_float?({})
  end

  test "is_function?" do
    assert Guards.is_function?(&Guards.is_function?/1)
    assert Guards.is_function?(fn -> nil end)
    refute Guards.is_function?({})
  end

  test "is_integer?" do
    assert Guards.is_integer?(0)
    assert Guards.is_integer?(-0)
    refute Guards.is_integer?(0.0)
    refute Guards.is_integer?({})
  end

  test "is_list?" do
    assert Guards.is_list?([])
    assert Guards.is_list?([:a])
    refute Guards.is_list?({})
  end

  test "is_map?" do
    assert Guards.is_map?(%{})
    assert Guards.is_map?(%{a: :a})
    assert Guards.is_map?(%{"a" => "a"})
    refute Guards.is_map?({})
  end

  test "is_nil?" do
    assert Guards.is_nil?(nil)
    refute Guards.is_nil?(false)
    refute Guards.is_nil?({})
  end

  test "is_number?" do
    assert Guards.is_number?(0)
    assert Guards.is_number?(0.0)
    refute Guards.is_number?({})
  end

  test "is_pid?" do
    assert Guards.is_pid?(self())
    refute Guards.is_pid?({})
  end

  test "is_port?" do
    assert Guards.is_port?(Port.list() |> hd())
    refute Guards.is_port?({})
  end

  test "is_reference?" do
    assert Guards.is_reference?(make_ref())
    refute Guards.is_reference?({})
  end

  test "is_tuple?" do
    assert Guards.is_tuple?({})
    assert Guards.is_tuple?({1, 2})
    refute Guards.is_tuple?([])
  end

  test "equal" do
    assert Guards.equal(1, 1)
    assert Guards.equal(1, 1.0)
    refute Guards.equal(1, 1.1)
    assert Guards.equal([:a], [:a])
    assert Guards.equal({:a, :a}, {:a, :a})
    assert Guards.equal(%{a: :a}, %{a: :a})
  end

  test "strict_equal" do
    assert Guards.strict_equal(1, 1)
    refute Guards.strict_equal(1, 1.0)
    refute Guards.strict_equal(1, 1.1)
    assert Guards.strict_equal([:a], [:a])
    assert Guards.strict_equal({:a, :a}, {:a, :a})
    assert Guards.strict_equal(%{a: :a}, %{a: :a})
  end

  test "not_equal" do
    refute Guards.not_equal(1, 1)
    refute Guards.not_equal(1, 1.0)
    assert Guards.not_equal(1, 1.1)
    refute Guards.not_equal([:a], [:a])
    refute Guards.not_equal({:a, :a}, {:a, :a})
    refute Guards.not_equal(%{a: :a}, %{a: :a})
  end

  test "strict_not_equal" do
    refute Guards.strict_not_equal(1, 1)
    assert Guards.strict_not_equal(1, 1.0)
    assert Guards.strict_not_equal(1, 1.1)
    refute Guards.strict_not_equal([:a], [:a])
    refute Guards.strict_not_equal({:a, :a}, {:a, :a})
    refute Guards.strict_not_equal(%{a: :a}, %{a: :a})
  end

  test "multiply" do
    assert Guards.multiply(0, 0, 0)
    assert Guards.multiply(0, 1, 0)
    assert Guards.multiply(1, 1, 1)
    assert Guards.multiply(-1, 1, -1)
    assert Guards.multiply(1.0, 1, 1.0)
    assert Guards.multiply(-1.0, 1, -1.0)
    assert Guards.multiply(10, 10, 100)
    refute Guards.multiply(1, 1, 10)
    refute Guards.multiply(true, false, %{})
  end

  test "positive" do
    assert Guards.positive(1)
    refute Guards.positive(0)
    refute Guards.positive(-1)
    refute Guards.positive(%{a: :a})
  end

  test "negative" do
    assert Guards.negative(-1)
    refute Guards.negative(0)
    refute Guards.negative(1)
    refute Guards.negative(%{a: :a})
  end

  test "subtraction" do
    assert Guards.subtraction(0, 0, 0)
    assert Guards.subtraction(0, 1, -1)
    assert Guards.subtraction(1, 1, 0)
    assert Guards.subtraction(-1, 1, -2)
    assert Guards.subtraction(1.0, 1, 0.0)
    assert Guards.subtraction(-1.0, 1, -2.0)
    assert Guards.subtraction(10, 10, 0)
    refute Guards.subtraction(1, 1, 10)
    refute Guards.subtraction(%{a: :a}, %{a: :a}, 1)
  end

  test "division" do
    refute Guards.division(0, 0, 0)
    assert Guards.division(0, 1, 0.0)
    assert Guards.division(1, 1, 1.0)
    assert Guards.division(-1, 1, -1.0)
    assert Guards.division(1.0, 1, 1.0)
    assert Guards.division(-1.0, 1, -1.0)
    assert Guards.division(10, 10, 1.0)
    refute Guards.division(1, 1, 10)
    refute Guards.division(%{a: :a}, %{a: :a}, 1)
  end

  test "less" do
    assert Guards.less(-1, 0)
    refute Guards.less(0, 0)
    refute Guards.less(1, 0)
  end

  test "less_or_equal" do
    assert Guards.less_or_equal(-1, 0)
    assert Guards.less_or_equal(0, 0)
    refute Guards.less_or_equal(1, 0)
  end

  test "greater" do
    assert Guards.greater(1, 0)
    refute Guards.greater(0, 0)
    refute Guards.greater(-1, 0)
  end

  test "greater_or_equal" do
    assert Guards.greater_or_equal(1, 0)
    assert Guards.greater_or_equal(0, 0)
    refute Guards.greater_or_equal(-1, 0)
  end

  test "absolute" do
    assert Guards.absolute(1)
    assert Guards.absolute(-1)
    refute Guards.absolute([])
  end

  test "boolean_and" do
    assert Guards.boolean_and(true, true)
    refute Guards.boolean_and(false, true)
    refute Guards.boolean_and({}, [])
  end

  test "boolean_or" do
    assert Guards.boolean_or(true, true)
    assert Guards.boolean_or(false, true)
    refute Guards.boolean_or({}, [])
  end

  test "binary_part" do
    assert Guards.binary_part("a", "a")
    refute Guards.binary_part("", "a")
    refute Guards.binary_part({}, "a")
  end

  test "bit_size" do
    assert Guards.bit_size("a", 8)
    assert Guards.bit_size("", 0)
    refute Guards.bit_size({}, 0)
  end

  test "byte_size" do
    assert Guards.byte_size("a", 1)
    assert Guards.byte_size("", 0)
    refute Guards.byte_size({}, 0)
  end

  test "ceil" do
    assert Guards.ceil(0, 0)
    assert Guards.ceil(0.1, 1)
    assert Guards.ceil(-0.1, 0)
    refute Guards.ceil({}, 0)
  end

  test "floor" do
    assert Guards.floor(0, 0)
    assert Guards.floor(0.1, 0)
    assert Guards.floor(-0.1, -1)
    refute Guards.floor({}, 0)
  end

  test "div" do
    assert Guards.div(2, 2, 1)
    assert Guards.div(-1, 1, -1)
    refute Guards.div(0, 0, 0)
    refute Guards.div({}, 0, 0)
  end

  test "elem" do
    assert Guards.elem({:a}, 0, :a)
    refute Guards.elem({:a}, 2, :a)
    refute Guards.elem([:a], 0, :a)
  end

  test "head" do
    assert Guards.head([:a], :a)
    refute Guards.head([:a, :b], :b)
    refute Guards.head([], nil)
    refute Guards.head({:a}, :a)
  end

  test "in_list" do
    assert Guards.in_list(:a)
    refute Guards.in_list(:b)
    refute Guards.in_list({})
  end

  test "in_list_not" do
    assert Guards.in_list_not(:b)
    assert Guards.in_list_not({})
    refute Guards.in_list_not(:a)
  end

  test "length" do
    assert Guards.length([:a], 1)
    assert Guards.length([], 0)
    refute Guards.length({}, 0)
  end

  test "map_size" do
    assert Guards.map_size(%{}, 0)
    assert Guards.map_size(%{a: :a}, 1)
    assert Guards.map_size(%{"a" => "a"}, 1)
    refute Guards.map_size([], 0)
  end

  test "node_guard" do
    assert Guards.node_guard(:"eds@127.0.0.1")
    assert Guards.node_guard(self(), :"eds@127.0.0.1")
    refute Guards.node_guard({}, :"eds@127.0.0.1")
  end

  test "not_guard" do
    assert Guards.not_guard(false)
    refute Guards.not_guard(nil)
  end

  test "rem" do
    assert Guards.rem(1, 2, 1)
    assert Guards.rem(-1, 2, -1)
    refute Guards.rem(0, 0, 0)
    refute Guards.rem({}, 0, 0)
  end

  test "round" do
    assert Guards.round(0, 0)
    assert Guards.round(1.49, 1)
    assert Guards.round(0.51, 1)
    assert Guards.round(-1.49, -1)
    assert Guards.round(-0.51, -1)
    refute Guards.round({}, 0)
  end

  test "self" do
    assert Guards.self(self())
  end

  test "tail" do
    assert Guards.tail([:a, :b], [:b])
    refute Guards.tail([:a], :a)
    refute Guards.tail([], nil)
    refute Guards.tail({:a}, :a)
  end

  test "trunc" do
    assert Guards.trunc(0, 0)
    assert Guards.trunc(1.1, 1)
    assert Guards.trunc(-1.1, -1)
    refute Guards.trunc({}, 0)
  end

  test "tuple_size" do
    assert Guards.tuple_size({}, 0)
    assert Guards.tuple_size({:a, :a}, 2)
    refute Guards.tuple_size({}, 1)
    refute Guards.tuple_size([], 0)
  end
end
