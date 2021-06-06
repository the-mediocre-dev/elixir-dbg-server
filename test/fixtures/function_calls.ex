defmodule EDS.Fixtures.FunctionCalls.SharedFunctions do
  alias EDS.Fixtures.FunctionCalls

  defmacro __using__(_opts) do
    quote do
      def public_call(), do: public_stub()

      def private_call(), do: private_stub()

      def public_stub(), do: true

      def public_recursion(), do: public_recursive_stub(0)

      def private_recursion(), do: private_recursive_stub(0)

      def public_recursive_stub(2), do: true

      def public_recursive_stub(call_count),
        do: public_recursive_stub(call_count + 1)

      def interpreted_call(),
        do: FunctionCalls.Interpreted.public_stub()

      def non_interpreted_call(),
        do: FunctionCalls.NonInterpreted.public_stub()

      def interpreted_reentry_call(),
        do: FunctionCalls.Interpreted.reentry()

      def non_interpreted_reentry_call(),
        do: FunctionCalls.NonInterpreted.reentry()

      def reentry(), do: FunctionCalls.public_stub()

      defp private_stub(), do: true

      defp private_recursive_stub(2), do: true

      defp private_recursive_stub(call_count),
        do: private_recursive_stub(call_count + 1)
    end
  end
end

defmodule EDS.Fixtures.FunctionCalls.NonInterpreted do
  use EDS.Fixtures.FunctionCalls.SharedFunctions
end

defmodule EDS.Fixtures.FunctionCalls.Interpreted do
  use EDS.Fixtures.FunctionCalls.SharedFunctions
end

defmodule EDS.Fixtures.FunctionCalls do
  use EDS.Fixtures.FunctionCalls.SharedFunctions

  alias __MODULE__.{
    Interpreted,
    NonInterpreted
  }

  def internal_public_call(), do: public_stub()

  def internal_private_call(), do: private_stub()

  def internal_public_recursion(), do: public_recursive_stub(0)

  def internal_private_recursion(), do: private_recursive_stub(0)

  def external_non_interpreted_public_call(),
    do: NonInterpreted.public_call()

  def external_non_interpreted_private_call(),
    do: NonInterpreted.private_call()

  def external_non_interpreted_public_recursion(),
    do: NonInterpreted.public_recursion()

  def external_non_interpreted_private_recursion(),
    do: NonInterpreted.private_recursion()

  def external_non_interpreted_to_interpreted_call(),
    do: NonInterpreted.interpreted_call()

  def external_non_interpreted_to_interpreted_reentry_call(),
    do: NonInterpreted.non_interpreted_reentry_call()

  def external_interpreted_public_call(),
    do: Interpreted.public_call()

  def external_interpreted_private_call(),
    do: Interpreted.private_call()

  def external_interpreted_public_recursion(),
    do: Interpreted.public_recursion()

  def external_interpreted_private_recursion(),
    do: Interpreted.private_recursion()

  def external_interpreted_to_non_interpreted_call(),
    do: Interpreted.non_interpreted_call()

  def external_interpreted_to_non_interpreted_reentry_call(),
    do: Interpreted.non_interpreted_reentry_call()
end
