defmodule EDS.Fixtures.Errors.SharedFunctions do
  defmacro __using__(_opts) do
    quote do
      def bif_error(atom) do
        :erlang.atom_to_binary(atom)
      end

      def exit_process() do
        exit(:exited)
      end

      def raise_exception() do
        raise "error"
      end

      def throw_term() do
        throw(:thrown)
      end

      def undefined_function_error() do
        apply(:missing_module, :missing_function, [])
      end
    end
  end
end

defmodule EDS.Fixtures.Errors.NonInterpreted do
  use EDS.Fixtures.Errors.SharedFunctions
end

defmodule EDS.Fixtures.Errors.Interpreted do
  use EDS.Fixtures.Errors.SharedFunctions
end

defmodule EDS.Fixtures.Errors do
  alias __MODULE__.{
    Interpreted,
    NonInterpreted
  }

  def raise_non_interpreted() do
    NonInterpreted.raise_exception()
  end

  def raise_rescue_non_interpreted() do
    NonInterpreted.raise_exception()
  rescue
    error -> error
  end

  def raise_interpreted() do
    Interpreted.raise_exception()
  end

  def raise_rescue_interpreted() do
    Interpreted.raise_exception()
  rescue
    error -> error
  end

  def throw_non_interpreted() do
    NonInterpreted.throw_term()
  end

  def throw_catch_non_interpreted() do
    NonInterpreted.throw_term()
  catch
    term -> term
  end

  def throw_interpreted() do
    Interpreted.throw_term()
  end

  def throw_catch_interpreted() do
    Interpreted.throw_term()
  catch
    term -> term
  end

  def exit_non_interpreted() do
    NonInterpreted.exit_process()
  end

  def exit_trap_non_interpreted() do
    NonInterpreted.exit_process()
  catch
    :exit, reason -> reason
  end

  def exit_interpreted() do
    Interpreted.exit_process()
  end

  def exit_trap_interpreted() do
    Interpreted.exit_process()
  catch
    :exit, reason -> reason
  end

  def undefined_function_non_interpreted() do
    NonInterpreted.undefined_function_error()
  end

  def undefined_function_interpreted() do
    Interpreted.undefined_function_error()
  end

  def after_rescue_block() do
    raise "error"
  rescue
    error -> error
  after
    raise "after"
  end

  def after_catch_block() do
    throw(:thrown)
  catch
    term -> term
  after
    raise "after"
  end

  def bif_error_non_interpreted() do
    NonInterpreted.bif_error("")
  end

  def bif_error_interpreted() do
    Interpreted.bif_error("")
  end
end
