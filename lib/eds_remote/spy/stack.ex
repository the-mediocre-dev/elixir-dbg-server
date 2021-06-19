defmodule EDS.Remote.Spy.Stack.Frame do
  defstruct level: 1,
            mfa: nil,
            line: 0,
            error_info: [],
            bindings: nil,
            last_call: false
end

defmodule EDS.Remote.Spy.Stack do
  alias __MODULE__.Frame

  alias EDS.Remote.Spy.{Eval, Server}

  def init() do
    Process.put(__MODULE__, [])
  end

  def push(%Eval{} = eval, _bindings, true), do: eval

  def push(%Eval{} = eval, bindings, false) do
    frame = %Frame{
      level: eval.level,
      mfa: {eval.module, eval.function, eval.args},
      line: eval.line,
      bindings: bindings,
      last_call: false
    }

    Process.put(__MODULE__, [frame | Process.get(__MODULE__)])
    Map.update!(eval, :level, &(&1 + 1))
  end

  def pop() do
    case Process.get(__MODULE__) do
      [_frame | stack] ->
        Process.put(__MODULE__, stack)

      [] ->
        :ignore
    end
  end

  def pop(level) do
    stack =
      __MODULE__
      |> Process.get()
      |> pop(level)

    Process.put(__MODULE__, stack)
  end

  def delayed_to_external() do
    fn -> {:stack, :erlang.term_to_binary(Process.get(__MODULE__))} end
  end

  def from_external({:stack, stack}) do
    Process.put(__MODULE__, stack)
  end

  def delayed_stacktrace() do
    stack = Process.get(__MODULE__)

    fn num_entries ->
      num_entries
      |> stacktrace(stack, [])
      |> finalise_stack()
    end
  end

  def delayed_stacktrace(%Eval{} = eval, true) do
    frame = %Frame{
      mfa: {eval.module, eval.function, eval.args},
      line: eval.line,
      error_info: eval.error_info
    }

    stack = [frame | Process.get(__MODULE__)]

    fn num_entries ->
      case stacktrace(num_entries, stack, []) do
        [] ->
          []

        [{_, with_args} | stack] ->
          [finalize(with_args) | finalise_stack(stack)]
      end
    end
  end

  def delayed_stacktrace(%Eval{} = eval, false) do
    frame = %Frame{
      mfa: {eval.module, eval.function, eval.args},
      line: eval.line
    }

    stack = [frame | Process.get(__MODULE__)]

    fn num_entries ->
      num_entries
      |> stacktrace(stack, [])
      |> finalise_stack()
    end
  end

  defp stacktrace(num_entries, [%Frame{last_call: true} | tail], acc),
    do: stacktrace(num_entries, tail, acc)

  defp stacktrace(num_entries, [frame | tail], []),
    do: stacktrace(num_entries - 1, tail, [normalize(frame)])

  defp stacktrace(num_entries, [frame | tail], [{p, _} | _] = acc) when num_entries > 0 do
    case normalize(frame) do
      {^p, _} ->
        stacktrace(num_entries, tail, acc)

      new ->
        stacktrace(num_entries - 1, tail, [new | acc])
    end
  end

  defp stacktrace(_, _, acc),
    do: Enum.reverse(acc)

  defp normalize(%Frame{mfa: {module, function, args}} = frame) when is_function(function) do
    local = {module, frame.line, frame.error_info}
    {{function, length(args), local}, {function, args, local}}
  end

  defp normalize(%Frame{mfa: {module, function, args}} = frame) do
    local = {module, frame.line, frame.error_info}
    {{module, function, length(args), local}, {module, function, args, local}}
  end

  defp finalise_stack(stack) do
    for {arity_only, _} <- stack do
      finalize(arity_only)
    end
  end

  defp finalize({module, function, args, local}),
    do: {module, function, args, line(local)}

  defp finalize({function, args, local}),
    do: {function, args, line(local)}

  defp line({module, line, error_info}) do
    cond do
      line > 0 ->
        [{:file, fetch_source(module)}, {:line, line} | error_info]

      true ->
        error_info
    end
  end

  defp line(_), do: []

  defp pop([%{level: frame_level} | stack], level) when frame_level <= level,
    do: pop(stack, level)

  defp pop(stack, _level), do: stack

  defp fetch_source(nil), do: "UNKNOWN"

  defp fetch_source(module) do
    case Server.fetch_module_db(module) do
      :not_found ->
        "UNKNOWN"

      module_db ->
        module_db
        |> :ets.lookup(:mod_file)
        |> case do
          [mod_file: source] -> Path.relative_to_cwd(source)
          _else -> "UNKNOWN"
        end
    end
  end
end
