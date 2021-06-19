defmodule EDS.Remote.Spy.Meta do
  alias EDS.Remote.Spy.{
    Bindings,
    Eval,
    Host,
    Server,
    Stack
  }

  def start(host, {module, _, _} = mfa) do
    Process.flag(:trap_exit, true)
    Process.monitor(host)
    Process.put(:cache, [])
    Process.put(:host, host)
    Process.put(:stacktrace, [])
    Process.put(:exit_info, :undefined)
    Stack.init()
    Server.register_meta(module, self())

    send(host, {:sys, self(), eval_mfa(%Eval{}, mfa)})
    message_loop(%Eval{}, host, Bindings.new())
  end

  defp message_loop(%{level: level} = eval, host, bindings) do
    receive do
      {:sys, ^host, {:value, value}} ->
        {:value, value, bindings}

      {:sys, ^host, {:value, value, value_bindings}} ->
        {:value, value, merge_bindings(eval, value_bindings, bindings)}

      {:sys, ^host, {:exception, class, reason, stacktrace}} ->
        case Process.get(:exit_info) do
          :undefined ->
            make_stack = fn depth ->
              depth = max(0, depth - length(stacktrace))
              stacktrace ++ Stack.delayed_stacktrace().(depth)
            end

            raise_exception(eval, class, reason, make_stack, bindings)

          _ ->
            :erlang.raise(class, reason, stacktrace)
        end

      {:re_entry, ^host, {:eval, mfa}} when level === 1 ->
        Stack.init()
        Process.put(:exit_info, :undefined)
        Process.put(:stacktrace, [])
        send(host, {:sys, self(), eval_mfa(eval, mfa)})
        message_loop(eval, host, bindings)

      {:re_entry, ^host, {:eval, mfa}} when level > 1 ->
        result =
          eval
          |> Map.put(:module, nil)
          |> Map.put(:line, -1)
          |> eval_mfa(mfa)

        send(host, {:sys, self(), result})
        message_loop(eval, host, bindings)

      message ->
        check_exit_message(eval, message, bindings)
        message_loop(eval, host, bindings)
    end
  end

  defp host_cmd(eval, cmd, bindings) do
    host = Process.get(:host)
    send(host, {:sys, self(), {:command, cmd}})
    message_loop(eval, host, bindings)
  end

  defp eval_mfa(%Eval{} = eval, mfa) do
    eval
    |> Map.update!(:level, &(&1 + 1))
    |> Map.put(:top_level, true)
    |> eval_function(mfa, Bindings.new(), :external)
    |> case do
      {:value, value, _bindings} ->
        {:ready, value}
    end
  catch
    :exit, {_process, reason} ->
      exit(reason)

    class, reason ->
      {:exception, class, reason, get_stacktrace()}
  end

  defp eval_function(eval, {__MODULE__, function, args}, bindings, _scope) do
    %{top_level: top_level} = eval

    case get_lambda(function, args) do
      {[{:clause, line, _, _, _} | _] = clauses, module, function, args, bindings} ->
        eval
        |> Map.put(:module, module)
        |> Map.put(:function, function)
        |> Map.put(:args, args)
        |> Map.put(:line, line)
        |> eval_clauses(clauses, args, bindings)

      :not_interpreted when top_level ->
        {:value, {:dbg_apply, {:erlang, :apply, [function, args]}}, bindings}

      :not_interpreted ->
        host_cmd(eval, {:apply, {:erlang, :apply, [function, args]}}, bindings)

      {:error, reason} ->
        exception(eval, :error, reason, bindings)
    end
  end

  defp eval_function(%{top_level: top_level} = eval, mfa, bindings, scope) do
    case get_function(mfa, scope) do
      {:ok, [{:clause, line, _, _, _} | _] = clauses} ->
        {module, function, args} = mfa

        eval
        |> Map.put(:module, module)
        |> Map.put(:function, function)
        |> Map.put(:args, args)
        |> Map.put(:line, line)
        |> eval_clauses(clauses, args, Bindings.new())

      :not_interpreted when top_level ->
        {:value, {:dbg_apply, mfa}, bindings}

      :not_interpreted ->
        host_cmd(eval, {:apply, mfa}, bindings)

      _ ->
        exception(eval, :error, "Undefined function: #{inspect(mfa)}", true)
    end
  end

  defp eval_function(eval, {module, name, args}, bindings, scope, last_call?) do
    case last_call? do
      false ->
        {:value, value, _} =
          eval
          |> Stack.push(bindings, last_call?)
          |> eval_function({module, name, args}, bindings, scope)

        Stack.pop()

        {:value, value, bindings}

      true ->
        eval_function(eval, {module, name, args}, bindings, scope)
    end
  end

  defp get_function({module, function, args}, :local) do
    module
    |> Server.fetch_module_db()
    |> :ets.match_object({{module, function, length(args), :_}, :_})
    |> case do
      [{{_module, _function, _arity, _exp}, clauses}] ->
        {:ok, clauses}

      _else ->
        nil
    end
  end

  defp get_function({module, function, args}, :external) do
    case Server.fetch_module_db(module) do
      :not_found ->
        :not_interpreted

      module_db ->
        function_lookup = :ets.lookup(module_db, {module, function, length(args), true})
        module_lookup = :ets.lookup(module_db, module)

        case {function_lookup, module_lookup} do
          {[{_, clauses}], _} -> {:ok, clauses}
          {_, [{_, _}]} -> nil
          {_, _} -> :not_interpreted
        end
    end
  end

  defp get_lambda(:eval_fun, [clauses, args, bindings, {module, name}]) do
    clauses
    |> hd()
    |> elem(2)
    |> length()
    |> Kernel.===(length(args))
    |> case do
      true ->
        Server.register_meta(module, self())
        {clauses, module, name, args, bindings}

      _else ->
        {:error, "bad eval_fun arity: #{inspect({module, name, args})}"}
    end
  end

  defp get_lambda(:eval_named_fun, [clauses, args, bindings, fname, rf, {module, name}]) do
    clauses
    |> hd()
    |> elem(2)
    |> length()
    |> Kernel.===(length(args))
    |> case do
      true ->
        Server.register_meta(module, self())
        {clauses, module, name, args, Bindings.add(fname, rf, bindings)}

      _else ->
        {:error, "bad eval_named_fun arity: #{inspect({module, name, args})}"}
    end
  end

  defp get_lambda(function, args) do
    case {:erlang.fun_info(function, :module), :erlang.fun_info(function, :arity)} do
      {{:module, __MODULE__}, {:arity, arity}} when length(args) === arity ->
        case :erlang.fun_info(function, :env) do
          {:env, [{{module, name}, bindings, clauses}]} ->
            {clauses, module, name, args, bindings}

          {:env, [{{module, name}, bindings, clauses, func_name}]} ->
            {clauses, module, name, args, Bindings.add(func_name, function, bindings)}
        end

      {{:module, __MODULE__}, _arity} ->
        {:error, "bad arity: #{inspect({function, args})}"}

      _else ->
        :not_interpreted
    end
  end

  defp eval_clauses(eval, [clause | clauses], args, bindings) do
    {:clause, line, patterns, guards, body} = clause

    with {:match, matches} <- head_match(eval, patterns, args, [], bindings),
         bindings <- Bindings.add(matches, bindings),
         true <- guard(eval, guards, bindings) do
      eval
      |> Map.put(:line, line)
      |> eval_exprs(body, bindings)
    else
      _ ->
        eval_clauses(eval, clauses, args, bindings)
    end
  end

  defp eval_clauses(eval, _, _args, bindings),
    do: exception(eval, :error, "Invalid functions clauses", bindings, true)

  defp head_match(eval, [pattern | patterns], [arg | args], matches, bindings) do
    with {:match, matches} <- match(eval, pattern, arg, matches, bindings) do
      head_match(eval, patterns, args, matches, bindings)
    end
  end

  defp head_match(_eval, [], [], matches, _bindings), do: {:match, matches}

  defp match(eval, pattern, term, bindings),
    do: match(eval, pattern, term, bindings, bindings)

  defp match(_eval, {:value, _, value}, value, matches, _bindings),
    do: {:match, matches}

  defp match(_eval, {:var, _, :_}, term, matches, _bindings),
    do: {:match, Bindings.add_anonymous(term, matches)}

  defp match(_eval, {:var, _, name}, term, matches, _bindings) do
    case Bindings.find(name, matches) do
      {:value, ^term} -> {:match, matches}
      {:value, _} -> :nomatch
      :unbound -> {:match, [{name, term} | matches]}
    end
  end

  defp match(eval, {:match, _, pattern0, pattern1}, term, matches, bindings) do
    with {:match, matches} <- match(eval, pattern0, term, matches, bindings) do
      match(eval, pattern1, term, matches, bindings)
    end
  end

  defp match(eval, {:cons, _, head0, tail0}, [head1 | tail1], matches, bindings) do
    with {:match, matches} <- match(eval, head0, head1, matches, bindings) do
      match(eval, tail0, tail1, matches, bindings)
    end
  end

  defp match(eval, {:tuple, _, elements}, tuple, matches, bindings)
       when length(elements) === tuple_size(tuple),
       do: match_tuple(eval, elements, tuple, 0, matches, bindings)

  defp match(eval, {:map, _, fields}, map, matches, bindings) when is_map(map),
    do: match_map(eval, fields, map, matches, bindings)

  defp match(eval, {:bin, _, fields}, bytes, matches, bindings) when is_bitstring(bytes) do
    :eval_bits.match_bits(
      fields,
      bytes,
      matches,
      bindings,
      match_function(eval, bindings),
      &eval_expr(%Eval{}, &1, &2),
      false
    )
  catch
    _error ->
      :nomatch
  end

  defp match(_, _, _, _, _), do: :nomatch

  defp match_function(eval, bindings) do
    fn
      :match, {l, r, matches} -> match(eval, l, r, matches, bindings)
      :binding, {name, matches} -> Bindings.find(name, matches)
      :add_binding, {name, value, matches} -> Bindings.add(name, value, matches)
    end
  end

  defp match_tuple(eval, [element | elements], tuple, index, matches, bindings) do
    with {:match, matches} <- match(eval, element, elem(tuple, index), matches, bindings) do
      match_tuple(eval, elements, tuple, index + 1, matches, bindings)
    end
  end

  defp match_tuple(_, [], _, _, matches, _bindings), do: {:match, matches}

  defp match_map(eval, [{:map_field_exact, _, key, pattern} | fields], map, matches, bindings) do
    with {:value, key} <- guard_expr(eval, key, bindings),
         value when not is_nil(value) <- Map.get(map, key),
         {:match, matches} <- match(eval, pattern, value, matches, bindings) do
      match_map(eval, fields, map, matches, bindings)
    else
      _ -> :nomatch
    end
  catch
    _error ->
      :nomatch
  end

  defp match_map(_, [], _, matches, _bindings), do: {:match, matches}

  defp eval_exprs(eval, [expr], bindings) do
    eval_expr(eval, expr, bindings)
  end

  defp eval_exprs(eval, [expr | exprs], bindings) do
    {:value, _, bindings} =
      eval
      |> Map.put(:top_level, false)
      |> eval_expr(expr, bindings)

    eval_exprs(eval, exprs, bindings)
  end

  defp eval_exprs(_eval, [], bindings),
    do: {:value, true, bindings}

  defp eval_expr(eval, {:var, line, var}, bindings) do
    case Bindings.find(var, bindings) do
      {:value, value} ->
        {:value, value, bindings}

      _else ->
        eval
        |> Map.put(:line, line)
        |> exception(:error, "Unbound variable #{inspect(var)}", bindings)
    end
  end

  defp eval_expr(_eval, {:value, _, value}, bindings),
    do: {:value, value, bindings}

  defp eval_expr(_eval, {:value, value}, bindings),
    do: {:value, value, bindings}

  defp eval_expr(eval, {:cons, line, head, tail}, bindings) do
    eval =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)

    {:value, head, head_bindings} = eval_expr(eval, head, bindings)
    {:value, tail, tail_bindings} = eval_expr(eval, tail, bindings)
    bindings = merge_bindings(eval, tail_bindings, head_bindings)
    {:value, [head | tail], bindings}
  end

  defp eval_expr(eval, {:tuple, line, elements}, bindings) do
    eval = Map.put(eval, :line, line)
    {values, bindings} = eval_list(eval, elements, bindings)
    {:value, List.to_tuple(values), bindings}
  end

  defp eval_expr(eval, {:map, line, fields}, bindings) do
    {map, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_new_map_fields(fields, bindings, &eval_expr/3)

    {:value, map, bindings}
  end

  defp eval_expr(eval, {:map, line, map, fields}, bindings) do
    eval =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)

    {:value, map, map_bindings} = eval_expr(eval, map, bindings)
    {fields, fields_bindings} = eval_map_fields(eval, fields, bindings)
    _ = Map.put(map, :key, :value)
    bindings = merge_bindings(eval, fields_bindings, map_bindings)

    value =
      Enum.reduce(fields, map, fn
        {_, key, value}, map -> Map.put(map, key, value)
      end)

    {:value, value, bindings}
  end

  defp eval_expr(eval, {:block, line, elements}, bindings),
    do: eval_exprs(Map.put(eval, :line, line), elements, bindings)

  defp eval_expr(eval, {:catch, line, expr}, bindings) do
    eval
    |> Map.put(:line, line)
    |> Map.put(:top_level, false)
    |> eval_expr(expr, bindings)
  catch
    class, reason ->
      value =
        case class do
          :error ->
            {:EXIT, {reason, get_stacktrace()}}

          :exit ->
            {:EXIT, reason}

          :throw ->
            reason
        end

      Process.put(:error_info, :undefined)
      Stack.pop(eval.level)
      {:value, value, bindings}
  end

  defp eval_expr(eval, {:try, _, _, _, _, _} = expr, bindings) do
    {:try, line, exprs, case_clauses, catch_clauses, after_clauses} = expr
    eval = Map.put(eval, :line, line)

    try do
      case {eval_exprs(Map.put(eval, :top_level, false), exprs, bindings), case_clauses} do
        {{:value, _value, _bindings} = result, []} ->
          result

        {{:value, value, bindings}, _case_clauses} ->
          eval_case_clauses(eval, value, case_clauses, bindings, :try_clause)
      end
    catch
      class, reason ->
        eval_catch_clauses(eval, {class, reason, get_stacktrace()}, catch_clauses, bindings)
    after
      eval
      |> Map.put(:top_level, false)
      |> Map.put(:line, line)
      |> eval_exprs(after_clauses, bindings)
    end
  end

  defp eval_expr(eval, {:case, line, case_expr, clauses}, bindings) do
    eval
    |> Map.put(:top_level, false)
    |> Map.put(:line, line)
    |> eval_expr(case_expr, bindings)
    |> case do
      {:value, value, bindings} ->
        eval
        |> Map.put(:line, line)
        |> eval_case_clauses(value, clauses, bindings, :case_clause)
    end
  end

  defp eval_expr(eval, {:if, line, clauses}, bindings),
    do: eval_if_clauses(Map.put(eval, :line, line), clauses, bindings)

  defp eval_expr(eval, {:andalso, line, expr_1, expr_2} = expr, bindings) do
    eval
    |> Map.put(:top_level, false)
    |> Map.put(:line, line)
    |> eval_expr(expr_1, bindings)
    |> case do
      {:value, false, _} = response ->
        response

      {:value, true, bindings} ->
        {:value, value, _} =
          eval
          |> Map.put(:top_level, false)
          |> Map.put(:line, line)
          |> eval_expr(expr_2, bindings)

        {:value, value, bindings}

      _else ->
        exception(eval, :error, "bad andalso expression: #{expr}", bindings)
    end
  end

  defp eval_expr(eval, {:orelse, line, expr_1, expr_2} = expr, bindings) do
    eval =
      eval
      |> Map.put(:top_level, false)
      |> Map.put(:line, line)

    case eval_expr(eval, expr_1, bindings) do
      {:value, true, _} = response ->
        response

      {:value, false, bindings} ->
        {:value, value, _} = eval_expr(eval, expr_2, bindings)
        {:value, value, bindings}

      _else ->
        exception(eval, :error, "bad orelse expression: #{expr}", bindings)
    end
  end

  defp eval_expr(eval, {:match, line, left, right} = expr, bindings) do
    {:value, right, bindings} =
      eval
      |> Map.put(:top_level, false)
      |> Map.put(:line, line)
      |> eval_expr(right, bindings)

    case match(eval, left, right, bindings) do
      {:match, bindings} ->
        {:value, right, bindings}

      _else ->
        eval
        |> Map.put(:line, line)
        |> exception(:error, "bad match expression: #{expr}", bindings)
    end
  end

  defp eval_expr(eval, {:make_fun, line, name, clauses} = expr, bindings) do
    arity =
      clauses
      |> hd()
      |> elem(2)
      |> length()

    eval_func = fn args ->
      Host.eval(__MODULE__, :eval_fun, [clauses, args, bindings, {eval.module, name}])
    end

    case :eds_utils.make_func(arity, eval_func) do
      {:ok, function} ->
        {:value, function, bindings}

      _else ->
        eval
        |> Map.put(:line, line)
        |> exception(:error, "Arguement limit: #{inspect(expr)}", bindings)
    end
  end

  defp eval_expr(eval, {:make_named_fun, line, name, fname, clauses} = expr, bindings) do
    arity =
      clauses
      |> hd()
      |> elem(2)
      |> length()

    eval_func = fn args, rf ->
      Host.eval(__MODULE__, :eval_named_fun, [clauses, args, bindings, fname, rf, {eval.module, name}])
    end

    case :eds_utils.make_named_func(arity, eval_func) do
      {:ok, function} ->
        {:value, function, bindings}

      _else ->
        eval
        |> Map.put(:line, line)
        |> exception(:error, "Arguement limit: #{inspect(expr)}", bindings)
    end
  end

  defp eval_expr(eval, {:make_ext_fun, line, mfa}, bindings) do
    {[module, function, args], bindings} = eval_list(eval, mfa, bindings)

    try do
      {:value, :erlang.make_fun(module, function, args), bindings}
    catch
      :error, :badarg ->
        eval
        |> Map.put(:line, line)
        |> Stack.push(bindings, false)

        eval
        |> Map.put(:line, -1)
        |> Map.put(:module, :erlang)
        |> Map.put(:function, :make_fun)
        |> Map.put(:arguements, [module, function, args])
        |> exception(:error, :badarg, bindings, true)
    end
  end

  defp eval_expr(eval, {:local_call, line, function, args, last_call?}, bindings) do
    eval = Map.put(eval, :line, line)
    {args, bindings} = eval_list(eval, args, bindings)
    eval_function(eval, {eval.module, function, args}, bindings, :local, last_call?)
  end

  defp eval_expr(eval, {:call_remote, line, module, function, args, last_call?}, bindings) do
    eval = Map.put(eval, :line, line)
    {args, bindings} = eval_list(eval, args, bindings)
    eval_function(eval, {module, function, args}, bindings, :external, last_call?)
  end

  defp eval_expr(_eval, {:dbg, _line, :self, []}, bindings) do
    {:value, Process.get(:host), bindings}
  end

  defp eval_expr(eval, {:dbg, line, :raise, args}, bindings) do
    eval = Map.put(eval, :line, line)
    {[class, reason, stacktrace], bindings} = eval_list(eval, args, bindings)

    try do
      {:value, :erlang.raise(class, reason, stacktrace), bindings}
    catch
      _, _ ->
        raise_exception(eval, class, reason, fn -> __STACKTRACE__ end, bindings)
    end
  end

  defp eval_expr(eval, {:dbg, line, :throw, args}, bindings) do
    eval = Map.put(eval, :line, line)
    {[term], bindings} = eval_list(eval, args, bindings)
    exception(eval, :throw, term, bindings)
  end

  defp eval_expr(eval, {:dbg, line, :error, args}, bindings) do
    eval = Map.put(eval, :line, line)
    {[term], bindings} = eval_list(eval, args, bindings)
    exception(eval, :error, term, bindings)
  end

  defp eval_expr(eval, {:dbg, line, :exit, args}, bindings) do
    eval = Map.put(eval, :line, line)
    {[term], bindings} = eval_list(eval, args, bindings)
    exception(eval, :exit, term, bindings)
  end

  defp eval_expr(eval, {:safe_bif, line, module, function, args}, bindings) do
    {args, bindings} =
      eval
      |> Map.put(:line, line)
      |> eval_list(args, bindings)

    eval
    |> Map.put(:line, line)
    |> Stack.push(bindings, false)

    eval =
      eval
      |> Map.put(:module, module)
      |> Map.put(:function, function)
      |> Map.put(:args, args)
      |> Map.put(:line, -1)

    try do
      response = apply(module, function, args)

      Stack.pop()

      {:value, response, bindings}
    catch
      class, reason ->
        [{_, _, _, info} | _] = __STACKTRACE__

        eval =
          case List.keyfind(info, :error_info, 1) do
            false -> Map.put(eval, :error_info, [])
            error_info -> Map.put(eval, :error_info, [error_info])
          end

        exception(eval, class, reason, bindings, true)
    end
  end

  defp eval_expr(eval, {:bif, line, module, function, args}, bindings) do
    {args, bindings} =
      eval
      |> Map.put(:line, line)
      |> eval_list(args, bindings)

    eval
    |> Map.put(:line, line)
    |> Stack.push(bindings, false)

    response =
      eval
      |> Map.put(:module, module)
      |> Map.put(:function, module)
      |> Map.put(:args, args)
      |> Map.put(:line, -1)
      |> host_cmd({:apply, {module, function, args}}, bindings)

    Stack.pop()

    response
  end

  defp eval_expr(eval, {:op, line, op, args}, bindings) do
    {args, bindings} =
      eval
      |> Map.put(:line, line)
      |> eval_list(args, bindings)

    {:value, apply(:erlang, op, args), bindings}
  catch
    class, reason ->
      exception(eval, class, reason, bindings)
  end

  defp eval_expr(eval, {:apply_fun, line, function, args, last_call?} = expr, bindings) do
    eval = Map.put(eval, :line, line)

    func_value =
      with {:value, {:dbg_apply, mfa}, bindings} <-
             eval_expr(eval, function, bindings) do
        eval
        |> Map.put(:level, eval.level + 1)
        |> host_cmd({:apply, mfa}, bindings)
      end

    case func_value do
      {:value, function, bindings} when is_function(function) ->
        {args, bindings} = eval_list(eval, args, bindings)
        eval_function(eval, {nil, function, args}, bindings, :external, last_call?)

      {:value, {module, function}, bindings} when is_atom(module) and is_atom(function) ->
        {args, bindings} = eval_list(eval, args, bindings)
        eval_function(eval, {module, function, args}, bindings, :external, last_call?)

      _else ->
        exception(eval, :error, "Bad function expression: #{expr}", bindings)
    end
  end

  defp eval_expr(eval, {:apply, line, args, last_call?}, bindings) do
    {[moudle, function, args], bindings} =
      eval
      |> Map.put(:line, line)
      |> eval_list(args, bindings)

    eval
    |> Map.put(:line, line)
    |> eval_function({moudle, function, args}, bindings, :external, last_call?)
  end

  defp eval_expr(eval, {:receive, line, clauses}, bindings) do
    eval
    |> Map.put(:line, line)
    |> eval_receive(Process.get(:host), clauses, bindings)
  end

  defp eval_expr(eval, {:receive, line, clauses, to, to_exprs}, bindings) do
    {:value, to_value, to_bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(to, bindings)

    valid_timeout? = fn
      x when is_integer(x) and x >= 0 -> true
      :ininity -> true
      _else -> false
    end

    to_value
    |> valid_timeout?.()
    |> Kernel.not()
    |> if do
      eval
      |> Map.put(:line, line)
      |> exception(:error, "Invalid timeout: #{to_value}", to_bindings)
    end

    {stamp, _} = :erlang.statistics(:wall_clock)
    to = {to_value, to_exprs, to_bindings}

    eval
    |> Map.put(:line, line)
    |> eval_receive(Process.get(:host), clauses, to, bindings, 0, stamp)
  end

  defp eval_expr(eval, {:send, line, to, message}, bindings) do
    eval =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)

    {:value, to, to_bindings} = eval_expr(eval, to, bindings)
    {:value, message, message_bindings} = eval_expr(eval, message, bindings)
    eval = Map.put(eval, :top_level, true)
    bindings = merge_bindings(eval, message_bindings, to_bindings)

    try do
      {:value, send(to, message), bindings}
    catch
      class, reason ->
        exception(eval, class, reason, bindings)
    end
  end

  defp eval_expr(eval, {:bin, line, fields}, bindings) do
    eval =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)

    try do
      :eval_bits.expr_grp(
        fields,
        bindings,
        &eval_expr(eval, &1, &2),
        [],
        false
      )
    catch
      class, reason ->
        exception(eval, class, reason, bindings)
    end
  end

  defp eval_expr(eval, {:lc, _line, expr, qualifiers}, bindings) do
    {:value, eval_list_comprehension(eval, expr, qualifiers, bindings), bindings}
  end

  defp eval_expr(eval, {:bc, _line, expr, qualifiers}, bindings) do
    value =
      eval
      |> eval_binary_comprehension(expr, qualifiers, bindings)
      |> :erlang.list_to_bitstring()

    {:value, value, bindings}
  end

  defp eval_expr(eval, exp, bindings),
    do: exception(eval, :error, "Unknown expression: #{inspect(exp)}", bindings)

  defp eval_list(eval, elements, bindings) do
    eval
    |> Map.put(:top_level, false)
    |> eval_list(elements, [], bindings, bindings)
  end

  defp eval_list(eval, [element | elements], values, original_bindings, bindings) do
    {:value, value, new_bindings} = eval_expr(eval, element, bindings)
    merged_bindings = merge_bindings(eval, new_bindings, bindings)
    eval_list(eval, elements, [value | values], original_bindings, merged_bindings)
  end

  defp eval_list(_eval, [], values, _, bindings) do
    {Enum.reverse(values), bindings}
  end

  def eval_map_fields(eval, fields, bindings),
    do: eval_map_fields(eval, fields, bindings, &eval_expr/3)

  defp eval_map_fields(eval, fields, bindings, eval_func) do
    {values, bindings} =
      fields
      |> Enum.reduce({[], bindings}, fn
        {:map_field_assoc, line, key, value}, {acc, bindings} ->
          eval = Map.put(eval, :line, line)
          {:value, key, bindings} = eval_func.(eval, key, bindings)
          {:value, value, bindings} = eval_func.(eval, value, bindings)
          {[{:map_assoc, key, value} | acc], bindings}

        {:map_field_exact, line, key, value}, {acc, bindings} ->
          eval = Map.put(eval, :line, line)
          {:value, key, bindings} = eval_func.(eval, key, bindings)
          {:value, value, bindings} = eval_func.(eval, value, bindings)
          {[{:map_exact, key, value} | acc], bindings}
      end)

    {Enum.reverse(values), bindings}
  end

  defp eval_new_map_fields(eval, fields, bindings, eval_func) do
    {values, bindings} =
      Enum.reduce(fields, {[], bindings}, fn {line, key, value}, {acc, bindings} ->
        eval = Map.put(eval, :line, line)
        {:value, key, bindings} = eval_func.(eval, key, bindings)
        {:value, value, bindings} = eval_func.(eval, value, bindings)
        {[{key, value} | acc], bindings}
      end)

    values =
      values
      |> Enum.reverse()
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        Map.put(acc, key, value)
      end)

    {values, bindings}
  end

  defp eval_map_fields_guard(eval, fields, bindings) do
    {fields, _} =
      eval_map_fields(
        eval,
        fields,
        bindings,
        fn expr, bindings, _ ->
          {:value, value} = guard_expr(eval, expr, bindings)
          {:value, value, bindings}
        end
      )

    fields
  end

  defp eval_if_clauses(eval, [{:clause, _, [], guards, body} | clauses], bindings) do
    case guard(eval, guards, bindings) do
      true -> eval_exprs(eval, body, bindings)
      false -> eval_if_clauses(eval, clauses, bindings)
    end
  end

  defp eval_if_clauses(eval, [], bindings),
    do: exception(eval, :error, "Invalid if clause", bindings)

  defp eval_case_clauses(eval, value, [clause | clauses], bindings, error) do
    {:clause, _, [pattern], guards, body} = clause

    case match(eval, pattern, value, bindings) do
      {:match, bindings} ->
        case guard(eval, guards, bindings) do
          true ->
            eval_exprs(eval, body, bindings)

          false ->
            eval_case_clauses(eval, value, clauses, bindings, error)
        end

      _else ->
        eval_case_clauses(eval, value, clauses, bindings, error)
    end
  end

  defp eval_case_clauses(eval, value, [], bindings, error),
    do: exception(eval, :error, "#{inspect({error, value})}", bindings)

  defp eval_catch_clauses(eval, exception, [clause | clauses], bindings) do
    {:clause, _, [pattern], guards, body} = clause

    case match(eval, pattern, exception, bindings) do
      {:match, bindings} ->
        case guard(eval, guards, bindings) do
          true ->
            Process.put(:exit_info, :undefined)
            Stack.pop(eval.level)
            eval_exprs(eval, body, bindings)

          false ->
            eval_catch_clauses(eval, exception, clauses, bindings)
        end

      :nomatch ->
        eval_catch_clauses(eval, exception, clauses, bindings)
    end
  end

  defp eval_catch_clauses(eval, {class, reason, _}, [], bindings),
    do: exception(eval, class, reason, bindings)

  defp eval_receive(eval, host, clauses, bindings) do
    :erlang.trace(host, true, [:receive])
    {_, messages} = Process.info(host, :messages)

    case eval_receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        eval_next_message(eval, host, clauses, bindings)

      {:eval, body, bindings, message} ->
        recieve_message(eval, host, message, bindings)
        eval_exprs(eval, body, bindings)
    end
  end

  defp eval_next_message(eval, host, clauses, bindings) do
    messages = recieve_messages(eval, host, bindings)

    case eval_receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        eval_next_message(eval, host, clauses, bindings)

      {:eval, body, bindings, message} ->
        recieve_message(eval, host, message, bindings)
        eval_exprs(eval, body, bindings)
    end
  end

  defp eval_receive(eval, host, clauses, {0, _, _} = to, bindings, 0, _stamp) do
    {_, messages} = Process.info(host, :messages)

    case eval_receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        {_to_value, to_exprs, to_bindings} = to
        eval_exprs(eval, to_exprs, to_bindings)

      {:eval, body, bindings, message} ->
        recieve_message_no_trace(eval, host, message, bindings)
        eval_exprs(eval, body, bindings)
    end
  end

  defp eval_receive(eval, host, clauses, to, bindings, 0, stamp) do
    :erlang.trace(host, true, [:receive])
    {_, messages} = Process.info(host, :messages)

    case eval_receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        {to_value, to_exprs, to_bindings} = to
        {stamp, to_value} = new_timeout(stamp, to_value)
        to = {to_value, to_exprs, to_bindings}
        eval_receive(eval, host, clauses, to, bindings, :infinity, stamp)

      {:eval, body, bindings, message} ->
        recieve_message(eval, host, message, bindings)
        eval_exprs(eval, body, bindings)
    end
  end

  defp eval_receive(eval, host, clauses, to, bindings, _, stamp) do
    {to_value, to_exprs, to_bindings} = to

    case recieve_message(eval, host, to_value, stamp, bindings) do
      :timeout ->
        recieve_message(host)
        eval_exprs(eval, to_exprs, to_bindings)

      messages ->
        case eval_receive_clauses(eval, clauses, bindings, messages) do
          :nomatch ->
            {stamp, to_value} = new_timeout(stamp, to_value)
            to = {to_value, to_exprs, to_bindings}
            eval_receive(eval, host, clauses, to, bindings, :infinity, stamp)

          {:eval, body, bindings, message} ->
            recieve_message(eval, host, message, bindings)
            eval_exprs(eval, body, bindings)
        end
    end
  end

  defp recieve_messages(eval, host, bindings) do
    receive do
      {:trace, ^host, :receive, message} ->
        [message]

      message ->
        check_exit_message(eval, message, bindings)
        recieve_messages(eval, host, bindings)
    end
  end

  defp recieve_message(host) do
    :erlang.trace(host, false, [:receive])
    flush_traces(host)
  end

  defp recieve_message(eval, host, message, bindings) do
    :erlang.trace(host, false, [:receive])
    flush_traces(host)
    send(host, {:sys, self(), {:receive, message}})
    receive_response(eval, host, bindings)
  end

  defp recieve_message(eval, host, time, stamp, bindings) do
    receive do
      {:trace, ^host, :receive, message} ->
        [message]

      {:user, :timeout} ->
        :timeout

      message ->
        check_exit_message(eval, message, bindings)
        {stamp1, time1} = new_timeout(stamp, time)
        recieve_message(eval, host, time1, stamp1, bindings)
    after
      time ->
        :timeout
    end
  end

  defp recieve_message_no_trace(eval, host, message, bindings) do
    send(host, {:sys, self(), {:receive, message}})
    receive_response(eval, host, bindings)
  end

  defp receive_response(eval, host, bindings) do
    receive do
      {:receive_response, ^host} ->
        true

      message ->
        check_exit_message(eval, message, bindings)
        IO.puts(:stderr, "***WARNING*** Unexpected message: #{inspect(message)}")
    end
  end

  defp eval_receive_clauses(eval, clauses, bindings, [message | messages]) do
    case receive_message_clauses(eval, clauses, bindings, message) do
      :nomatch ->
        eval_receive_clauses(eval, clauses, bindings, messages)

      {:eval, body, bindings} ->
        {:eval, body, bindings, message}
    end
  end

  defp eval_receive_clauses(_, _, _, []), do: :nomatch

  defp receive_message_clauses(eval, [{:clause, _, [pattern], guards, body} | clauses], bindings, message) do
    case match(eval, pattern, message, bindings) do
      {:match, bindings} ->
        case guard(eval, guards, bindings) do
          true ->
            {:eval, body, bindings}

          false ->
            receive_message_clauses(eval, clauses, bindings, message)
        end

      :nomatch ->
        receive_message_clauses(eval, clauses, bindings, message)
    end
  end

  defp receive_message_clauses(_, [], _, _), do: :nomatch

  defp eval_list_comprehension(eval, expr, [{:generate, line, pattern, list} | qualifiers], bindings) do
    {:value, list, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = fn bindings ->
      eval
      |> Map.put(:line, line)
      |> eval_list_comprehension(expr, qualifiers, bindings)
    end

    eval
    |> Map.put(:line, line)
    |> generate(list, pattern, bindings, comp_func)
  end

  defp eval_list_comprehension(eval, expr, [{:b_generate, line, pattern, list} | qualifiers], bindings) do
    {:value, binary, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = fn bindings ->
      eval
      |> Map.put(:line, line)
      |> eval_list_comprehension(expr, qualifiers, bindings)
    end

    eval
    |> Map.put(:line, line)
    |> binary_generate(binary, pattern, bindings, comp_func)
  end

  defp eval_list_comprehension(eval, expr, [{:guard, qualifier} | qualifiers], bindings) do
    case guard(eval, qualifier, bindings) do
      true -> eval_list_comprehension(eval, expr, qualifiers, bindings)
      false -> []
    end
  end

  defp eval_list_comprehension(eval, expr, [qualifier | qualifiers], bindings) do
    eval
    |> Map.put(:top_level, false)
    |> eval_expr(qualifier, bindings)
    |> case do
      {:value, true, bindings} ->
        eval_list_comprehension(eval, expr, qualifiers, bindings)

      {:value, false, _bindings} ->
        []

      {:value, value, bindings} ->
        exception(eval, :error, "bad filter: #{inspect({value, bindings})}", bindings)
    end
  end

  defp eval_list_comprehension(eval, expr, [], bindings) do
    {:value, value, _} =
      eval
      |> Map.put(:top_level, false)
      |> eval_expr(expr, bindings)

    [value]
  end

  defp eval_binary_comprehension(eval, expr, [{:generate, line, pattern, list} | qualifiers], bindings) do
    {:value, binary, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = fn bindings ->
      eval
      |> Map.put(:line, line)
      |> eval_binary_comprehension(expr, qualifiers, bindings)
    end

    eval
    |> Map.put(:line, line)
    |> generate(binary, pattern, bindings, comp_func)
  end

  defp eval_binary_comprehension(eval, expr, [{:b_generate, line, pattern, list} | qualifiers], bindings) do
    {:value, binary, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = fn bindings ->
      eval
      |> Map.put(:line, line)
      |> eval_binary_comprehension(expr, qualifiers, bindings)
    end

    eval
    |> Map.put(:line, line)
    |> binary_generate(binary, pattern, bindings, comp_func)
  end

  defp eval_binary_comprehension(eval, expr, [{:guard, qualifier} | qualifiers], bindings) do
    case guard(eval, qualifier, bindings) do
      true -> eval_binary_comprehension(eval, expr, qualifiers, bindings)
      false -> []
    end
  end

  defp eval_binary_comprehension(eval, expr, [qualifier | qualifiers], bindings) do
    eval
    |> Map.put(:top_level, false)
    |> eval_expr(qualifier, bindings)
    |> case do
      {:value, true, bindings} ->
        eval_binary_comprehension(eval, expr, qualifiers, bindings)

      {:value, false, _bindings} ->
        []

      {:value, value, bindings} ->
        exception(eval, :error, "bad filter: #{inspect({value, bindings})}", bindings)
    end
  end

  defp eval_binary_comprehension(eval, expr, [], bindings) do
    {:value, value, _} =
      eval
      |> Map.put(:top_level, false)
      |> eval_expr(expr, bindings)

    [value]
  end

  defp generate(eval, [value | values], pattern, bindings, comp_func) do
    case match(eval, pattern, value, Bindings.new(), bindings) do
      {:match, match_bindings} ->
        match_bindings
        |> Bindings.add(bindings)
        |> comp_func.()
        |> Kernel.++(generate(eval, values, pattern, bindings, comp_func))

      :nomatch ->
        generate(eval, values, pattern, bindings, comp_func)
    end
  end

  defp generate(_eval, [], _pattern, _bindings, _comp_func), do: []

  defp generate(eval, term, _pattern, bindings, _comp_func),
    do: exception(eval, :error, "bad generator: #{inspect(term)}", bindings)

  defp binary_generate(eval, <<_::bitstring>> = binary, pattern, bindings, comp_func) do
    match_func = match_function(eval, bindings)
    eval_func = &eval_expr(%Eval{}, &1, &2)

    pattern
    |> :eval_bits.bin_gen(binary, Bindings.new(), bindings, match_func, eval_func)
    |> case do
      {:match, rest, match_bindings} ->
        match_bindings
        |> Bindings.add(bindings)
        |> comp_func.()
        |> Kernel.++(binary_generate(eval, rest, pattern, bindings, comp_func))

      {:nomatch, rest} ->
        binary_generate(eval, rest, pattern, bindings, comp_func)

      :done ->
        []
    end
  end

  defp binary_generate(eval, term, _pattern, bindings, _comp_func),
    do: exception(eval, :error, "bad binary generator: #{inspect(term)}", bindings)

  defp guard(_eval, [], _bindings), do: true

  defp guard(eval, guards, bindings), do: or_guard(eval, guards, bindings)

  defp or_guard(eval, [guard | guards], bindings),
    do: and_guard(eval, guard, bindings) or or_guard(eval, guards, bindings)

  defp or_guard(_eval, [], _bindings), do: false

  defp and_guard(eval, [guard | guards], bindings) do
    case guard_expr(eval, guard, bindings) do
      {:value, true} -> and_guard(eval, guards, bindings)
      _ -> false
    end
  catch
    _, _ -> false
  end

  defp and_guard(_eval, [], _bindings), do: true

  defp guard_expr(eval, {:andalso, _, expr_1, expr_2} = expr, bindings) do
    case guard_expr(eval, expr_1, bindings) do
      {:value, false} = response ->
        response

      {:value, true} ->
        guard_expr(eval, expr_2, bindings)

      _else ->
        exception(eval, :error, "bad andalso guard: #{expr}", bindings)
    end
  end

  defp guard_expr(eval, {:orelse, _, expr_1, expr_2} = expr, bindings) do
    case guard_expr(eval, expr_1, bindings) do
      {:value, true} = response ->
        response

      {:value, false} ->
        guard_expr(eval, expr_2, bindings)

      _else ->
        exception(eval, :error, "bad orelse guard: #{expr}", bindings)
    end
  end

  defp guard_expr(_eval, {:dbg, _, :self, []}, _),
    do: {:value, Process.get(:host)}

  defp guard_expr(eval, {:safe_bif, _, :erlang, :not, args}, bindings) do
    {:values, args} = guard_exprs(eval, args, bindings)
    {:value, apply(:erlang, :not, args)}
  end

  defp guard_expr(eval, {:safe_bif, _, module, function, args}, bindings) do
    {:values, args} = guard_exprs(eval, args, bindings)
    {:value, apply(module, function, args)}
  end

  defp guard_expr(_eval, {:var, _, var}, bindings),
    do: {:value, _} = Bindings.find(var, bindings)

  defp guard_expr(_eval, {:value, _, value}, _bindings),
    do: {:value, value}

  defp guard_expr(eval, {:cons, _, head, tail}, bindings) do
    {:value, head} = guard_expr(eval, head, bindings)
    {:value, tail} = guard_expr(eval, tail, bindings)
    {:value, [head | tail]}
  end

  defp guard_expr(eval, {:tuple, _, elements}, bindings) do
    {:values, elements} = guard_exprs(eval, elements, bindings)
    {:value, List.to_tuple(elements)}
  end

  defp guard_expr(eval, {:map, _, fields}, bindings) do
    eval_func = fn guard, bindings, _ ->
      {:value, guard} = guard_expr(eval, guard, bindings)
      {:value, guard, bindings}
    end

    {map, _} =
      eval
      |> Map.put(:top_level, false)
      |> eval_new_map_fields(fields, bindings, eval_func)

    {:value, map}
  end

  defp guard_expr(eval, {:map, _, expr, fields}, bindings) do
    {:value, map} = guard_expr(eval, expr, bindings)
    fields = eval_map_fields_guard(eval, fields, bindings)

    value =
      Enum.reduce(fields, map, fn
        {_, key, value}, map -> Map.put(map, key, value)
      end)

    {:value, value}
  end

  defp guard_expr(eval, {:bin, _, fields}, bindings) do
    {:value, value, _bindings} =
      :eval_bits.expr_grp(
        fields,
        bindings,
        fn expr, bindings ->
          {:value, value} = guard_expr(eval, expr, bindings)
          {:value, value, bindings}
        end,
        [],
        false
      )

    {:value, value}
  end

  defp guard_expr(eval, exp, bindings),
    do: exception(eval, bindings, :error, "Unknown guard: #{inspect(exp)}")

  defp guard_exprs(eval, [arg | args], bindings) do
    {:value, value} = guard_expr(eval, arg, bindings)
    {:values, values} = guard_exprs(eval, args, bindings)
    {:values, [value | values]}
  end

  defp guard_exprs(_eval, [], _bindings), do: {:values, []}

  defp new_timeout(stamp, :infinity), do: {stamp, :infinity}

  defp new_timeout(old_stamp, old_time) do
    {new_stamp, _} = :erlang.statistics(:wall_clock)

    case old_time - (new_stamp - old_stamp) do
      new_time when new_time > 0 ->
        {new_stamp, new_time}

      _ ->
        {new_stamp, 0}
    end
  end

  defp check_exit_message(eval, {:EXIT, process, reason}, _bindings) do
    case eval.level do
      1 -> exit(reason)
      _else -> exit({process, reason})
    end
  end

  defp check_exit_message(eval, {:DOWN, _, _, _, reason}, _bindings) do
    case eval.level do
      1 -> exit(reason)
      _else -> exit({Process.get(:host), reason})
    end
  end

  defp check_exit_message(_eval, _message, _bindings), do: :ignore

  defp flush_traces(host) do
    receive do
      {:trace, ^host, :receive, _} ->
        flush_traces(host)
    after
      0 ->
        true
    end
  end

  defp exception(eval, class, reason, bindings, include_args \\ false) do
    raise_exception(
      eval,
      class,
      reason,
      Stack.delayed_stacktrace(eval, include_args),
      bindings
    )
  end

  defp raise_exception(eval, class, reason, stacktrace, bindings) do
    stack = Stack.delayed_to_external().()

    exit_info = fn ->
      {{eval.module, eval.line}, bindings, stack}
    end

    Process.put(:exit_info, exit_info)
    Process.put(:stacktrace, stacktrace)

    :erlang.raise(class, reason, [])
  end

  def merge_bindings(eval, source, destination) do
    case Bindings.merge(eval, source, destination) do
      {:error, variable, bindings} ->
        exception(eval, :error, "badmatch: #{variable}", bindings)

      bindings ->
        bindings
    end
  end

  def get_stacktrace() do
    case Process.get(:stacktrace) do
      make_stack when is_function(make_stack, 1) ->
        depth = :erlang.system_flag(:backtrace_depth, 8)
        :erlang.system_flag(:backtrace_depth, depth)
        stack = make_stack.(depth)
        Process.put(:stacktrace, stack)
        stack

      stack when is_list(stack) ->
        stack
    end
  end
end
