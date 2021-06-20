defmodule EDS.Fixtures.Guards do
  import Bitwise

  def addition(a, b, c) when a + b === c, do: true

  def addition(_, _, _), do: false

  def binary_and(a, b, c) when (a &&& b) === c, do: true

  def binary_and(_, _, _), do: false

  def binary_band(a, b, c) when band(a, b) === c, do: true

  def binary_band(_, _, _), do: false

  def binary_or(a, b, c) when (a ||| b) === c, do: true

  def binary_or(_, _, _), do: false

  def binary_bor(a, b, c) when bor(a, b) === c, do: true

  def binary_bor(_, _, _), do: false

  def binary_left_bit_shift(a, b, c) when a <<< b === c, do: true

  def binary_left_bit_shift(_, _, _), do: false

  def binary_bsl(a, b, c) when bsl(a, b) === c, do: true

  def binary_bsl(_, _, _), do: false

  def binary_right_bit_shift(a, b, c) when a >>> b === c, do: true

  def binary_right_bit_shift(_, _, _), do: false

  def binary_bsr(a, b, c) when bsr(a, b) === c, do: true

  def binary_bsr(_, _, _), do: false

  def binary_not(a, b) when ~~~a === b, do: true

  def binary_not(_, _), do: false

  def binary_bnot(a, b) when bnot(a) === b, do: true

  def binary_bnot(_, _), do: false

  def binary_bxor(a, b, c) when bxor(a, b) === c, do: true

  def binary_bxor(_, _, _), do: false

  def is_atom?(a) when is_atom(a), do: true

  def is_atom?(_), do: false

  def is_binary?(a) when is_binary(a), do: true

  def is_binary?(_), do: false

  def is_bitstring?(a) when is_bitstring(a), do: true

  def is_bitstring?(_), do: false

  def is_boolean?(a) when is_boolean(a), do: true

  def is_boolean?(_), do: false

  def is_float?(a) when is_float(a), do: true

  def is_float?(_), do: false

  def is_function?(func) when is_function(func), do: true

  def is_function?(_), do: false

  def is_function?(func, arity) when is_function(func, arity), do: true

  def is_function?(_, _), do: false

  def is_integer?(a) when is_integer(a), do: true

  def is_integer?(_), do: false

  def is_list?(a) when is_list(a), do: true

  def is_list?(_), do: false

  def is_map?(map) when is_map(map), do: true

  def is_map?(_), do: false

  def is_nil?(a) when is_nil(a), do: true

  def is_nil?(_), do: false

  def is_number?(a) when is_number(a), do: true

  def is_number?(_), do: false

  def is_pid?(a) when is_pid(a), do: true

  def is_pid?(_), do: false

  def is_port?(a) when is_port(a), do: true

  def is_port?(_), do: false

  def is_reference?(a) when is_reference(a), do: true

  def is_reference?(_), do: false

  def is_tuple?(a) when is_tuple(a), do: true

  def is_tuple?(_), do: false

  def equal(a, b) when a == b, do: true

  def equal(_, _), do: false

  def strict_equal(a, b) when a === b, do: true

  def strict_equal(_, _), do: false

  def not_equal(a, b) when a != b, do: true

  def not_equal(_, _), do: false

  def strict_not_equal(a, b) when a !== b, do: true

  def strict_not_equal(_, _), do: false

  def multiply(a, b, c) when a * b === c, do: true

  def multiply(_, _, _), do: false

  def positive(a) when +a > 0, do: true

  def positive(_), do: false

  def negative(a) when -a > 0, do: true

  def negative(_), do: false

  def subtraction(a, b, c) when a - b === c, do: true

  def subtraction(_, _, _), do: false

  def division(a, b, c) when a / b === c, do: true

  def division(_, _, _), do: false

  def less(a, b) when a < b, do: true

  def less(_, _), do: false

  def less_or_equal(a, b) when a <= b, do: true

  def less_or_equal(_, _), do: false

  def greater(a, b) when a > b, do: true

  def greater(_, _), do: false

  def greater_or_equal(a, b) when a >= b, do: true

  def greater_or_equal(_, _), do: false

  def absolute(a) when abs(a) >= 0, do: true

  def absolute(_), do: false

  def boolean_and(a, b) when a and b, do: true

  def boolean_and(_, _), do: false

  def boolean_or(a, b) when a or b, do: true

  def boolean_or(_, _), do: false

  def binary_part(a, b) when binary_part(a, 0, 1) === b, do: true

  def binary_part(_, _), do: false

  def bit_size(a, b) when bit_size(a) === b, do: true

  def bit_size(_, _), do: false

  def byte_size(a, b) when byte_size(a) === b, do: true

  def byte_size(_, _), do: false

  def ceil(a, b) when ceil(a) === b, do: true

  def ceil(_, _), do: false

  def floor(a, b) when floor(a) === b, do: true

  def floor(_, _), do: false

  def div(a, b, c) when div(a, b) === c, do: true

  def div(_, _, _), do: false

  def elem(a, b, c) when elem(a, b) === c, do: true

  def elem(_, _, _), do: false

  def head(a, b) when hd(a) === b, do: true

  def head(_, _), do: false

  def in_list(a) when a in [:a], do: true

  def in_list(_), do: false

  def in_list_not(a) when a not in [:a], do: true

  def in_list_not(_), do: false

  def length(a, b) when length(a) === b, do: true

  def length(_, _), do: false

  def map_size(a, b) when map_size(a) === b, do: true

  def map_size(_, _), do: false

  def node_guard(node) when node() === node, do: true

  def node_guard(_), do: false

  def node_guard(pid, node) when node(pid) === node, do: true

  def node_guard(_, _), do: false

  def not_guard(a) when not a, do: true

  def not_guard(_), do: false

  def rem(a, b, c) when rem(a, b) === c, do: true

  def rem(_, _, _), do: false

  def round(a, b) when round(a) === b, do: true

  def round(_, _), do: false

  def self(pid) when self() === pid, do: true

  def self(_), do: false

  def tail(a, b) when tl(a) === b, do: true

  def tail(_, _), do: false

  def trunc(a, b) when trunc(a) === b, do: true

  def trunc(_, _), do: false

  def tuple_size(tuple, size) when tuple_size(tuple) === size, do: true

  def tuple_size(_, _), do: false
end
