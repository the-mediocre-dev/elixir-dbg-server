defmodule EDS.Remote.Spy.Bindings do
  def add(from, []), do: from

  def add([{name, value} | from], to) do
    add(from, add(name, value, to))
  end

  def add([], to), do: to

  def add(name, value, [{name, _} | bindings]),
    do: [{name, value} | bindings]

  def add(name, value, [b1, {name, _} | bindings]),
    do: [b1, {name, value} | bindings]

  def add(name, value, [b1, b2, {name, _} | bindings]),
    do: [b1, b2, {name, value} | bindings]

  def add(name, value, [b1, b2, b3, {name, _} | bindings]),
    do: [b1, b2, b3, {name, value} | bindings]

  def add(name, value, [b1, b2, b3, b4, {name, _} | bindings]),
    do: [b1, b2, b3, b4, {name, value} | bindings]

  def add(name, value, [b1, b2, b3, b4, b5, {name, _} | bindings]),
    do: [b1, b2, b3, b4, b5, {name, value} | bindings]

  def add(name, value, [b1, b2, b3, b4, b5, b6 | bindings]),
    do: [b1, b2, b3, b4, b5, b6 | add(name, value, bindings)]

  def add(name, value, [b1, b2, b3, b4, b5 | bindings]),
    do: [b1, b2, b3, b4, b5 | add(name, value, bindings)]

  def add(name, value, [b1, b2, b3, b4 | bindings]),
    do: [b1, b2, b3, b4 | add(name, value, bindings)]

  def add(name, value, [b1, b2, b3 | bindings]),
    do: [b1, b2, b3 | add(name, value, bindings)]

  def add(name, value, [b1, b2 | bindings]),
    do: [b1, b2 | add(name, value, bindings)]

  def add(name, value, [b1 | bindings]),
    do: [b1 | add(name, value, bindings)]

  def add(name, value, []),
    do: [{name, value}]

  def add_anonymous(value, [{:_, _} | bindings]),
    do: [{:_, value} | bindings]

  def add_anonymous(value, [b1, {:_, _} | bindings]),
    do: [b1, {:_, value} | bindings]

  def add_anonymous(value, [b1, b2, {:_, _} | bindings]),
    do: [b1, b2, {:_, value} | bindings]

  def add_anonymous(value, [b1, b2, b3, {:_, _} | bindings]),
    do: [b1, b2, b3, {:_, value} | bindings]

  def add_anonymous(value, [b1, b2, b3, b4, {:_, _} | bindings]),
    do: [b1, b2, b3, b4, {:_, value} | bindings]

  def add_anonymous(value, [b1, b2, b3, b4, b5, {:_, _} | bindings]),
    do: [b1, b2, b3, b4, b5, {:_, value} | bindings]

  def add_anonymous(value, [b1, b2, b3, b4, b5, b6 | bindings]),
    do: [b1, b2, b3, b4, b5, b6 | add_anonymous(value, bindings)]

  def add_anonymous(value, [b1, b2, b3, b4, b5 | bindings]),
    do: [b1, b2, b3, b4, b5 | add_anonymous(value, bindings)]

  def add_anonymous(value, [b1, b2, b3, b4 | bindings]),
    do: [b1, b2, b3, b4 | add_anonymous(value, bindings)]

  def add_anonymous(value, [b1, b2, b3 | bindings]),
    do: [b1, b2, b3 | add_anonymous(value, bindings)]

  def add_anonymous(value, [b1, b2 | bindings]),
    do: [b1, b2 | add_anonymous(value, bindings)]

  def add_anonymous(value, [b1 | bindings]),
    do: [b1 | add_anonymous(value, bindings)]

  def add_anonymous(value, []),
    do: [{:_, value}]

  def find(name, [{name, value} | _]), do: {:value, value}

  def find(name, [_, {name, value} | _]), do: {:value, value}

  def find(name, [_, _, {name, value} | _]), do: {:value, value}

  def find(name, [_, _, _, {name, value} | _]), do: {:value, value}

  def find(name, [_, _, _, _, {name, value} | _]), do: {:value, value}

  def find(name, [_, _, _, _, _, {name, value} | _]), do: {:value, value}

  def find(name, [_, _, _, _, _, _ | bindings]), do: find(name, bindings)

  def find(name, [_, _, _, _, _ | bindings]), do: find(name, bindings)

  def find(name, [_, _, _, _ | bindings]), do: find(name, bindings)

  def find(name, [_, _, _ | bindings]), do: find(name, bindings)

  def find(name, [_, _ | bindings]), do: find(name, bindings)

  def find(name, [_ | bindings]), do: find(name, bindings)

  def find(_, []), do: :unbound

  def merge(_eval, source, destination) do
    source
    |> Enum.reduce_while(destination, fn {name, variable}, acc ->
      case {find(name, acc), name} do
        {{:value, ^variable}, _name} ->
          {:cont, acc}

        {{:value, _}, :_} ->
          {:cont, [{name, variable} | List.keydelete(acc, :_, 1)]}

        {{:value, _}, _name} ->
          {:halt, {:error, variable, acc}}

        {:unbound, _name} ->
          {:cont, [{name, variable} | acc]}
      end
    end)
    |> case do
      {:halt, term} -> term
      bindings -> bindings
    end
  end

  def new(), do: :erl_eval.new_bindings()
end
