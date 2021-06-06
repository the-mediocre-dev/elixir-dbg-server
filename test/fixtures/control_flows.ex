defmodule EDS.Fixtures.ControlFlows do
  def if_clause(input) do
    if input do
      true
    else
      false
    end
  end

  def if_block(input) do
    if input, do: true, else: false
  end

  def unless_clause(input) do
    unless input do
      true
    else
      false
    end
  end

  def unless_block(input) do
    unless input, do: true, else: false
  end

  def case_clause(input) do
    case input do
      true -> :case_1
      false -> :case_2
      _else -> :case_3
    end
  end

  def cond_clause(input) do
    cond do
      input -> true
      true -> false
    end
  end
end
