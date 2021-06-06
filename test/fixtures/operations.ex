defmodule EDS.Fixtures.Operations do
  def add(a, b), do: a + b

  def subtract(a, b), do: a - b

  def multiply(a, b), do: a * b

  def divide(a, b), do: a / b

  def integer_divide(a, b), do: div(a, b)

  def integer_remainder(a, b), do: rem(a, b)

  def boolean_or(a, b), do: a or b

  def boolean_or_short_circuit(a) do
    a or raise "short circuit failover"
  end

  def loose_or(a, b), do: a || b

  def loose_or_short_circuit(a) do
    a || raise "short circuit failover"
  end

  def boolean_and(a, b), do: a and b

  def boolean_and_short_circuit(a) do
    a and raise "short circuit failover"
  end

  def loose_and(a, b), do: a && b

  def loose_and_short_circuit(a) do
    a && raise "short circuit failover"
  end

  def boolean_not(a), do: not a

  def loose_not(a), do: !a

  def equals(a, b), do: a == b

  def not_equals(a, b), do: a != b

  def strictly_equals(a, b), do: a === b

  def strictly_not_equals(a, b), do: a !== b

  def less_than(a, b), do: a < b

  def greater_than(a, b), do: a > b

  def less_than_equals(a, b), do: a <= b

  def greater_than_equals(a, b), do: a >= b

  def cons(a, b), do: [a | [b]]

  def concatenation(a, b), do: a <> b
end
