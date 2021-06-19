defmodule EDS.Fixtures.Matchings do
  def constants(:a), do: true

  def constants(_), do: false

  def variables(a, a), do: true

  def variables(_, _), do: false

  def strings("head" <> tail), do: {:ok, tail}

  def strings(_), do: false

  def anonymous(_, _), do: true

  def compound({a, a}, {a, a}), do: true

  def compound(_, _), do: false

  def tuples({a, a, a}, {a, a, a}), do: true

  def tuples(_, _), do: false

  def maps(%{a: a}, %{a: a}), do: true

  def maps(_, _), do: false

  def string_maps(%{"a" => a}, %{"a" => a}), do: true

  def string_maps(_, _), do: false

  def list([a, a], [a, a]), do: true

  def list(_, _), do: false

  def cons([a | _], [a | _]), do: true

  def cons(_, _), do: false
end
