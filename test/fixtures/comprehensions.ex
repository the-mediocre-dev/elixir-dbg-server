defmodule EDS.Fixtures.Comprehensions do
  require Integer

  def identity_list_comprehension(enum) do
    for x <- enum, do: x
  end

  def identity_binary_comprehension(bytes) do
    for(<<byte <- bytes>>, do: <<byte>>) |> List.to_string()
  end

  def list_comprehension_with_filter(enum, filter) do
    for x <- enum, filter.(x), do: x
  end

  def binary_comprehension_with_filter(bytes, filter) do
    for(<<byte <- bytes>>, filter.(byte), do: <<byte>>) |> List.to_string()
  end

  def list_comprehension_with_generator_filter(enum) do
    for {key, value} when is_atom(value) or (is_tuple(value) and is_atom(elem(value, 1))) <- enum, do: {key, value}
  end

  def list_comprehension_with_multiple_generators(keys, values) do
    for key <- keys, value <- values, do: {key, value}
  end

  def binary_comprehension_with_multiple_generators(bytes_1, bytes_2) do
    for(<<byte_1 <- bytes_1>>, <<byte_2 <- bytes_2>>, do: <<byte_1>> <> <<byte_2>>) |> List.to_string()
  end

  def list_comprehension_with_uniq(enum) do
    for x <- enum, uniq: true, do: x
  end

  def binary_comprehension_with_uniq(bytes) do
    for(<<byte <- bytes>>, uniq: true, do: <<byte>>) |> List.to_string()
  end

  def list_comprehension_with_into(enum, into) do
    for x <- enum, into: into, do: x
  end

  def binary_comprehension_with_into(bytes, into) do
    for <<byte <- bytes>>, into: into, do: <<byte>>
  end

  def list_comprehension_with_reduce(enum, acc, reducer) do
    for x <- enum, reduce: acc do
      acc -> reducer.(acc, x)
    end
  end

  def binary_comprehension_with_reduce(bytes, acc, reducer) do
    for <<byte <- bytes>>, reduce: acc do
      acc -> reducer.(acc, byte)
    end
  end
end
