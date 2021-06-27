defmodule EDS.Fixtures.Remote.SharedFunctions do
  defmacro __using__(_opts) do
    quote do
      def function_call(a, b), do: a * b

      def raise_exception() do
        raise "error"
      end
    end
  end
end

defmodule EDS.Fixtures.Remote.NonInterpreted do
  use EDS.Fixtures.Remote.SharedFunctions
end

defmodule EDS.Fixtures.Remote.Interpreted do
  use EDS.Fixtures.Remote.SharedFunctions
end

defmodule EDS.Fixtures.Remote do
  alias EDS.Fixtures.Remote.NonInterpreted
  alias EDS.Fixtures.Remote.Interpreted

  def call_remote_function() do
    a = 10
    b = 10
    c = NonInterpreted.function_call(a, b)
    a + b + c
  end

  def noninterpreted_exception(),
    do: NonInterpreted.raise_exception()

  def interpreted_exception(),
    do: Interpreted.raise_exception()

  def recursive_function(0), do: true

  def recursive_function(count), do: recursive_function(count - 1)
end
