defmodule EDS.Remote.Spy.Host do
  alias EDS.Remote.Spy.Server

  def eval(module, function, args) do
    save_stacktrace()

    {module, function, args}
    |> Server.get_meta!()
    |> Process.monitor()
    |> message_loop()
  end

  def message_loop(monitor_ref) do
    receive do
      {:sys, _meta, {:ready, {:dbg_apply, mfa}}} ->
        Process.demonitor(monitor_ref, [:flush])
        apply_mfa(mfa)

      {:sys, _meta, {:ready, value}} ->
        Process.demonitor(monitor_ref, [:flush])
        value

      {:sys, _meta, {:exception, class, exception, stacktrace}} ->
        Process.demonitor(monitor_ref, [:flush])

        class
        |> :erlang.raise(exception, restore_stacktrace(stacktrace))
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
        {:apply, mfa} ->
          {:value, apply_mfa(mfa)}

        {:eval, expression, bindings} ->
          :erl_eval.expr(expression, Enum.sort(bindings))
      end
    catch
      class, reason ->
        {:exception, class, reason, sanitize_stacktrace(__STACKTRACE__)}
    end
  end

  defp apply_mfa({nil, function, args}), do: apply(function, args)

  defp apply_mfa({module, function, args}), do: apply(module, function, args)

  defp save_stacktrace() do
    unless Process.get(:stacktrace) do
      stack =
        self()
        |> Process.info(:current_stacktrace)
        |> elem(1)
        |> Enum.drop(3)

      Process.put(:stacktrace, stack)
    end
  end

  defp restore_stacktrace(error_stacktrace) do
    depth = :erlang.system_flag(:backtrace_depth, 8)
    :erlang.system_flag(:backtrace_depth, depth)

    error_stacktrace
    |> Kernel.++(Process.delete(:stacktrace) || [])
    |> Enum.slice(0..(depth - 1))
  end

  defp sanitize_stacktrace(stacktrace) do
    Enum.reject(stacktrace, fn
      {__MODULE__, _, _, _} -> true
      _ -> false
    end)
  end
end
