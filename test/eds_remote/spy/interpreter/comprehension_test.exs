defmodule EDS.Remote.Spy.Interpreter.ComprehensionTests do
  use EDS.DataCase, async: false

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.Comprehensions

  setup_all do
    start_supervised(Server)
    Server.load(Comprehensions)
    :ok
  end

  test "list comprehension with generator" do
    assert [] == Comprehensions.identity_list_comprehension([])
    assert [1, 2, 3] == Comprehensions.identity_list_comprehension([1, 2, 3])
    assert [{:a, 1}, {:b, 2}] == Comprehensions.identity_list_comprehension(%{a: 1, b: 2})
    assert [{"a", 1}, {"b", 2}] == Comprehensions.identity_list_comprehension(%{"a" => 1, "b" => 2})
  end

  test "binary comprehension with generator" do
    assert "" == Comprehensions.identity_binary_comprehension("")
    assert "abc" == Comprehensions.identity_binary_comprehension("abc")
    assert "😀😀😀" == Comprehensions.identity_binary_comprehension("😀😀😀")
  end

  test "list comprehension with filter" do
    assert [] == Comprehensions.list_comprehension_with_filter([], &(&1 != 0))
    assert [1, 3] == Comprehensions.list_comprehension_with_filter([1, 2, 3], &(&1 != 2))
    assert [{:b, 2}] = Comprehensions.list_comprehension_with_filter(%{a: 1, b: 2}, &(elem(&1, 0) != :a))
    assert [{"b", 2}] = Comprehensions.list_comprehension_with_filter(%{"a" => 1, "b" => 2}, &(elem(&1, 0) != "a"))
  end

  test "binary comprehension with filter" do
    assert "" == Comprehensions.binary_comprehension_with_filter("", &(&1 != ""))
    assert "ac" == Comprehensions.binary_comprehension_with_filter("abc", &(&1 != 98))
  end

  test "list comprehension with generator filter" do
    assert [] == Comprehensions.list_comprehension_with_generator_filter([])
    assert [a: :a] == Comprehensions.list_comprehension_with_generator_filter(a: :a, b: 2)
    assert [{:a, :a}] == Comprehensions.list_comprehension_with_generator_filter(%{a: :a, b: 2})
    assert [{"a", :a}] == Comprehensions.list_comprehension_with_generator_filter(%{"a" => :a, "b" => 2})
  end

  test "list comprehension with multiple generators" do
    assert [] == Comprehensions.list_comprehension_with_multiple_generators([], [])
    assert [] == Comprehensions.list_comprehension_with_multiple_generators([:a, :b], [])
    assert [] == Comprehensions.list_comprehension_with_multiple_generators([], [1, 2])
    assert [a: 1, a: 2, b: 1, b: 2] == Comprehensions.list_comprehension_with_multiple_generators([:a, :b], [1, 2])

    assert [{"a", 1}, {"a", 2}, {"b", 1}, {"b", 2}] ==
             Comprehensions.list_comprehension_with_multiple_generators(["a", "b"], [1, 2])
  end

  test "binary comprehension with multiple generators" do
    assert "" == Comprehensions.binary_comprehension_with_multiple_generators("", "")
    assert "a1a2b1b2" == Comprehensions.binary_comprehension_with_multiple_generators("ab", "12")
  end

  test "list comprehension with uniq" do
    assert [] == Comprehensions.list_comprehension_with_uniq([])
    assert [1, 2, 3] == Comprehensions.list_comprehension_with_uniq([1, 2, 3, 2])
  end

  test "binary comprehension with uniq" do
    assert "" == Comprehensions.binary_comprehension_with_uniq("")
    assert "abc" == Comprehensions.binary_comprehension_with_uniq("abcb")
  end

  test "list comprehension with into" do
    assert %{} == Comprehensions.list_comprehension_with_into([], %{})
    assert [] == Comprehensions.list_comprehension_with_into(%{}, [])
    assert %{a: 1, b: 2} == Comprehensions.list_comprehension_with_into([{:a, 1}, {:b, 2}], %{})
    assert [{:a, 1}, {:b, 2}] == Comprehensions.list_comprehension_with_into(%{a: 1, b: 2}, [])
    assert [{"a", 1}, {"b", 2}] == Comprehensions.list_comprehension_with_into(%{"a" => 1, "b" => 2}, [])
  end

  test "binary comprehension with into" do
    assert "" == Comprehensions.binary_comprehension_with_into("", "")
    assert "abc" == Comprehensions.binary_comprehension_with_into("abc", "")
    assert "abcdef" == Comprehensions.binary_comprehension_with_into("def", "abc")
  end

  test "list comprehension with reduce" do
    assert %{} == Comprehensions.list_comprehension_with_reduce([], %{}, &Map.put(&1, &2, &2))
    assert [] == Comprehensions.list_comprehension_with_reduce(%{}, [], &[&2 | &1])
    assert %{a: :a, b: :b} == Comprehensions.list_comprehension_with_reduce([:a, :b], %{}, &Map.put(&1, &2, &2))

    assert %{"a" => "a", "b" => "b"} ==
             Comprehensions.list_comprehension_with_reduce(["a", "b"], %{}, &Map.put(&1, &2, &2))

    assert [a: 1, b: 2] == Comprehensions.list_comprehension_with_reduce(%{a: 1, b: 2}, [], &(&1 ++ [&2]))

    assert [{"a", 1}, {"b", 2}] ==
             Comprehensions.list_comprehension_with_reduce(%{"a" => 1, "b" => 2}, [], &(&1 ++ [&2]))
  end

  test "binary comprehension with reduce" do
    reducer = &(&1 <> <<&2>>)
    assert "" == Comprehensions.binary_comprehension_with_reduce("", "", reducer)
    assert "abc" == Comprehensions.binary_comprehension_with_reduce("abc", "", reducer)
    assert "abcdef" == Comprehensions.binary_comprehension_with_reduce("def", "abc", reducer)
  end
end
