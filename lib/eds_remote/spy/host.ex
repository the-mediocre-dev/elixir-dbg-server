defmodule EDS.Remote.Spy.Host do
  def eval(meta) do
    meta
    |> Process.monitor()
    |> message_loop()
  end

  def message_loop(monitor_ref) do
    receive do
      {:sys, _meta, {:ready, {:dbg_apply, {module, function, args}}}} ->
        Process.demonitor(monitor_ref, [:flush])
        apply(module, function, args)

      {:sys, _meta, {:ready, value}} ->
        Process.demonitor(monitor_ref, [:flush])
        value

      {:sys, _meta, {:exception, class, exception, stacktrace}} ->
        Process.demonitor(monitor_ref, [:flush])

        class
        |> :erlang.raise(exception, stacktrace)
        |> :erlang.error()

      {:sys, meta, {:receive, message}} ->
        receive do
          ^message ->
            send(meta, {:receive_response, self()})
        end

        message_loop(monitor_ref)

      {:sys, meta, {:command, cmd}} ->
        send(meta, {:sys, self(), process_command(cmd)})
        message_loop(monitor_ref)

      {:DOWN, _monitor_ref, _, _, reason} ->
        {:interpreter_terminated, reason}
    end
  end

  defp process_command(cmd) do
    try do
      case cmd do
        {:apply, {m, f, a}} ->
          {:value, apply(m, f, a)}

        {:eval, expression, bindings} ->
          :erl_eval.expr(expression, Enum.sort(bindings))
      end
    catch
      class, exception ->
        {:exception, class, exception, sanitize_stacktrace(__STACKTRACE__)}
    end
  end

  defp sanitize_stacktrace([]), do: []

  defp sanitize_stacktrace([frame | stack]) do
    [frame | sanitize_stacktrace(stack)]
  end
end
