defmodule EDS.Remote.Spy.Interpreter.MatchingTests do
  use EDS.DataCase, async: false

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.Matchings

  setup_all do
    start_supervised(Server)
    Server.load(Matchings)
    :ok
  end

  test "constants" do
    assert Matchings.constants(:a)
    refute Matchings.constants(:b)
  end

  test "variables" do
    match = fn a, b ->
      Matchings.variables(a, b)
    end

    assert match.(1, 1)
    refute match.(1, 2)
    assert match.("a", "a")
    refute match.("a", "b")
    assert match.(:a, :a)
    refute match.(:a, :b)
    assert match.({:a, :a}, {:a, :a})
    refute match.({:a, :a}, {:a, :b})
    assert match.([:a, :a], [:a, :a])
    refute match.([:a, :a], [:a, :b])
    assert match.(%{a: :a}, %{a: :a})
    refute match.(%{a: :a}, %{a: :b})
    assert match.(%{"a" => :a}, %{"a" => :a})
    refute match.(%{"a" => :a}, %{"a" => :b})
  end

  test "strings" do
    assert {:ok, "tail"} = Matchings.strings("headtail")
    refute Matchings.strings("tail")
  end

  test "anonymous" do
    assert Matchings.anonymous(:a, :b)
  end

  test "compound" do
    assert Matchings.compound({:a, :a}, {:a, :a})
    refute Matchings.compound({:a, :a}, {:a, :b})
  end

  test "tuples" do
    assert Matchings.tuples({:a, :a, :a}, {:a, :a, :a})
    refute Matchings.tuples({:a, :a, :a}, {:a, :a, :b})
  end

  test "maps" do
    assert Matchings.maps(%{a: :a}, %{a: :a})
    refute Matchings.maps(%{a: :a}, %{a: :b})
    refute Matchings.maps(%{a: :a}, %{b: :a})
  end

  test "string maps" do
    assert Matchings.string_maps(%{"a" => :a}, %{"a" => :a})
    refute Matchings.string_maps(%{"a" => :a}, %{"a" => :b})
    refute Matchings.string_maps(%{"a" => :a}, %{"b" => :a})
  end

  test "list" do
    assert Matchings.list([:a, :a], [:a, :a])
    refute Matchings.list([:a, :a], [:a, :b])
  end

  test "cons" do
    assert Matchings.cons([:a, :a], [:a, :a])
    assert Matchings.cons([:a, :a], [:a, :b])
    refute Matchings.cons([:a, :a], [:b, :a])
  end
end
