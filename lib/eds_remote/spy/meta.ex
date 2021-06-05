defmodule EDS.Remote.Spy.Meta.Eval do
  defstruct level: 1,
            line: -1,
            module: nil,
            function: nil,
            args: nil,
            error_info: [],
            top_level: false
end

defmodule EDS.Remote.Spy.Meta do
  alias __MODULE__.Eval
  alias EDS.Remote.Spy.Server

  def start(host, {module, _, _} = mfa) do
    Process.flag(:trap_exit, true)
    Process.monitor(host)
    Process.put(:cache, [])
    Process.put(:host, host)
    Process.put(:stacktrace, [])

    Server.register_meta(module, self())

    send(host, {:sys, self(), eval_mfa(%Eval{}, mfa)})
    message_loop(%Eval{}, host, :erl_eval.new_bindings())
  end

  defp message_loop(%{level: level} = eval, host, bindings) do
    receive do
      {:sys, ^host, {:value, value}} ->
        {:value, value, bindings}

      {:sys, ^host, {:value, value, value_bindings}} ->
        {:value, value, merge_bindings(eval, value_bindings, bindings)}

      {:sys, ^host, {:exception, {class, reason, stacktrace}}} ->
        raise_exception(class, reason, stacktrace)

      {:re_entry, ^host, {:eval, mfa}} when level === 1 ->
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
    bindings = :erl_eval.new_bindings()

    eval
    |> Map.update!(:level, &(&1 + 1))
    |> Map.put(:top, true)
    |> eval_function(mfa, bindings, :external)
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
        |> eval_clauses(clauses, args, :erl_eval.new_bindings())

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
        {:value, value, _} = eval_function(eval, {module, name, args}, bindings, scope)
        {:value, value, bindings}

      true ->
        eval_function(eval, {module, name, args}, bindings, scope)
    end
  end

  defp get_lambda(:eval_fun, [clauses, args, bindings, {module, name}]) do
    clauses
    |> hd()
    |> elem(3)
    |> length()
    |> Kernel.===(length(args))
    |> case do
      true ->
        Server.register_meta(module, self())
        {clauses, module, name, args, bindings}

      _else ->
        {:error, "bad arity: #{inspect({module, name, args})}"}
    end
  end

  defp get_lambda(:eval_named_fun, [clauses, args, bindings, func_name, rf, {module, name}]) do
    clauses
    |> hd()
    |> elem(3)
    |> length()
    |> Kernel.===(length(args))
    |> case do
      true ->
        Server.register_meta(module, self())
        {clauses, module, name, args, add_binding(func_name, rf, bindings)}

      _else ->
        {:error, "bad arity: #{inspect({module, name, args})}"}
    end
  end

  defp get_lambda(function, args) do
    case {:erlang.fun_info(function, :module), :erlang.fun_info(function, :arity)} do
      {{:module, __MODULE__}, {:arity, arity}} when length(args) === arity ->
        case :erlang.fun_info(function, :env) do
          {:env, [{{module, name}, bindings, clauses}]} ->
            {clauses, module, name, args, bindings}

          {:env, [{{module, name}, bindings, clauses, func_name}]} ->
            {clauses, module, name, args, add_binding(func_name, function, bindings)}
        end

      {{:module, __MODULE__}, _arity} ->
        {:error, "bad arity: #{inspect({function, args})}"}

      _else ->
        :not_interpreted
    end
  end

  defp eval_clauses(eval, [clause | _] = clauses, args, bindings) do
    {:clause, line, patterns, guards, body} = clause

    with {:match, matches} <- head_match(eval, patterns, args, [], bindings),
         bindings <- add_bindings(matches, bindings),
         true <- guard(eval, guards, bindings) do
      eval
      |> Map.put(:line, line)
      |> sequence(body, bindings)
    else
      _ -> eval_clauses(eval, clauses, args, bindings)
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
    do: {:match, add_anonymous(term, matches)}

  defp match(_eval, {:var, _, name}, term, matches, _bindings) do
    case binding(name, matches) do
      {:value, ^term} -> {:match, matches}
      {:value, _} -> :nomatch
      :unbound -> {:match, [{name, term} | matches]}
    end
  end

  defp match(eval, {:match, _, pattern0, pattern1}, term, matches, bindings) do
    with {:match, matches} = match(eval, pattern0, term, matches, bindings) do
      match(eval, pattern1, term, matches, bindings)
    end
  end

  defp match(eval, {:cons, _, head0, tail0}, [head1 | tail1], matches, bindings) do
    with {:match, matches} = match(eval, head0, head1, matches, bindings) do
      match(eval, tail0, tail1, matches, bindings)
    end
  end

  defp match(eval, {:tuple, _, elements}, tuple, matches, bindings)
       when length(elements) === tuple_size(tuple),
       do: match_tuple(eval, elements, tuple, 1, matches, bindings)

  defp match(eval, {:map, _, fields}, map, matches, bindings) when is_map(map),
    do: match_map(eval, fields, map, matches, bindings)

  defp match(eval, {:bin, _, fields}, bytes, matches, bindings) when is_bitstring(bytes) do
    :eval_bits.match_bits(
      fields,
      bytes,
      matches,
      bindings,
      match_function(eval, bindings),
      &eval_expr(&1, &2, %Eval{}),
      false
    )
  catch
    _ -> :nomatch
  end

  defp match(_, _, _, _, _), do: :nomatch

  defp match_function(eval, bindings) do
    fn
      :match, {l, r, matches} -> match(eval, l, r, matches, bindings)
      :binding, {name, matches} -> binding(name, matches)
      :add_binding, {name, value, matches} -> add_binding(name, value, matches)
    end
  end

  defp match_tuple(eval, [element | elements], tuple, index, matches, bindings) do
    with {:match, matches} <- match(eval, element, Kernel.elem(tuple, index), matches, bindings) do
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
    _ -> :nomatch
  end

  defp match_map(_, [], _, matches, _bindings), do: {:match, matches}

  defp binding(name, [{name, value} | _]), do: {:value, value}

  defp binding(name, [_, {name, value} | _]), do: {:value, value}

  defp binding(name, [_, _, {name, value} | _]), do: {:value, value}

  defp binding(name, [_, _, _, {name, value} | _]), do: {:value, value}

  defp binding(name, [_, _, _, _, {name, value} | _]), do: {:value, value}

  defp binding(name, [_, _, _, _, _, {name, value} | _]), do: {:value, value}

  defp binding(name, [_, _, _, _, _, _ | bindings]), do: binding(name, bindings)

  defp binding(name, [_, _, _, _, _ | bindings]), do: binding(name, bindings)

  defp binding(name, [_, _, _, _ | bindings]), do: binding(name, bindings)

  defp binding(name, [_, _, _ | bindings]), do: binding(name, bindings)

  defp binding(name, [_, _ | bindings]), do: binding(name, bindings)

  defp binding(name, [_ | bindings]), do: binding(name, bindings)

  defp binding(_, []), do: :unbound

  defp add_anonymous(value, [{:_, _} | bindings]),
    do: [{:_, value} | bindings]

  defp add_anonymous(value, [b1, {:_, _} | bindings]),
    do: [b1, {:_, value} | bindings]

  defp add_anonymous(value, [b1, b2, {:_, _} | bindings]),
    do: [b1, b2, {:_, value} | bindings]

  defp add_anonymous(value, [b1, b2, b3, {:_, _} | bindings]),
    do: [b1, b2, b3, {:_, value} | bindings]

  defp add_anonymous(value, [b1, b2, b3, b4, {:_, _} | bindings]),
    do: [b1, b2, b3, b4, {:_, value} | bindings]

  defp add_anonymous(value, [b1, b2, b3, b4, b5, {:_, _} | bindings]),
    do: [b1, b2, b3, b4, b5, {:_, value} | bindings]

  defp add_anonymous(value, [b1, b2, b3, b4, b5, b6 | bindings]),
    do: [b1, b2, b3, b4, b5, b6 | add_anonymous(value, bindings)]

  defp add_anonymous(value, [b1, b2, b3, b4, b5 | bindings]),
    do: [b1, b2, b3, b4, b5 | add_anonymous(value, bindings)]

  defp add_anonymous(value, [b1, b2, b3, b4 | bindings]),
    do: [b1, b2, b3, b4 | add_anonymous(value, bindings)]

  defp add_anonymous(value, [b1, b2, b3 | bindings]),
    do: [b1, b2, b3 | add_anonymous(value, bindings)]

  defp add_anonymous(value, [b1, b2 | bindings]),
    do: [b1, b2 | add_anonymous(value, bindings)]

  defp add_anonymous(value, [b1 | bindings]),
    do: [b1 | add_anonymous(value, bindings)]

  defp add_anonymous(value, []),
    do: [{:_, value}]

  defp add_bindings(from, []), do: from

  defp add_bindings([{name, value} | from], to) do
    add_bindings(from, add_binding(name, value, to))
  end

  defp add_bindings([], to), do: to

  defp add_binding(name, value, [{name, _} | bindings]),
    do: [{name, value} | bindings]

  defp add_binding(name, value, [b1, {name, _} | bindings]),
    do: [b1, {name, value} | bindings]

  defp add_binding(name, value, [b1, b2, {name, _} | bindings]),
    do: [b1, b2, {name, value} | bindings]

  defp add_binding(name, value, [b1, b2, b3, {name, _} | bindings]),
    do: [b1, b2, b3, {name, value} | bindings]

  defp add_binding(name, value, [b1, b2, b3, b4, {name, _} | bindings]),
    do: [b1, b2, b3, b4, {name, value} | bindings]

  defp add_binding(name, value, [b1, b2, b3, b4, b5, {name, _} | bindings]),
    do: [b1, b2, b3, b4, b5, {name, value} | bindings]

  defp add_binding(name, value, [b1, b2, b3, b4, b5, b6 | bindings]),
    do: [b1, b2, b3, b4, b5, b6 | add_binding(name, value, bindings)]

  defp add_binding(name, value, [b1, b2, b3, b4, b5 | bindings]),
    do: [b1, b2, b3, b4, b5 | add_binding(name, value, bindings)]

  defp add_binding(name, value, [b1, b2, b3, b4 | bindings]),
    do: [b1, b2, b3, b4 | add_binding(name, value, bindings)]

  defp add_binding(name, value, [b1, b2, b3 | bindings]),
    do: [b1, b2, b3 | add_binding(name, value, bindings)]

  defp add_binding(name, value, [b1, b2 | bindings]),
    do: [b1, b2 | add_binding(name, value, bindings)]

  defp add_binding(name, value, [b1 | bindings]),
    do: [b1 | add_binding(name, value, bindings)]

  defp add_binding(name, value, []),
    do: [{name, value}]

  defp merge_bindings(_eval, bindings, bindings), do: bindings

  defp merge_bindings(eval, [{name, variable} | bindings_1], bindings_2) do
    case {binding(name, bindings_2), name} do
      {{:value, ^variable}, _name} ->
        merge_bindings(eval, bindings_1, bindings_2)

      {{:value, _}, :_} ->
        bindings_2 = List.keydelete(bindings_2, :_, 1)
        [{name, variable} | merge_bindings(eval, bindings_1, bindings_2)]

      {{:value, _}, _name} ->
        exception(eval, :error, "badmatch: #{variable}", bindings_2)

      {:unbound, _name} ->
        [{name, variable} | merge_bindings(eval, bindings_1, bindings_2)]
    end
  end

  defp merge_bindings(_eval, [], bindings), do: bindings

  defp sequence(eval, [expr], bindings) do
    eval_expr(eval, expr, bindings)
  end

  defp sequence(eval, [expr | exprs], bindings) do
    {:value, _, bindings} =
      eval
      |> Map.put(:top_level, false)
      |> eval_expr(expr, bindings)

    sequence(eval, exprs, bindings)
  end

  defp sequence(_eval, [], bindings),
    do: {:value, true, bindings}

  defp eval_expr(eval, {:var, line, var}, bindings) do
    case binding(var, bindings) do
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
    do: sequence(Map.put(eval, :line, line), elements, bindings)

  defp eval_expr(eval, {:catch, line, expr}, bindings) do
    eval
    |> Map.put(:line, line)
    |> Map.put(:top_level, false)
    |> eval_expr(expr, bindings)
  catch
    :error, reason ->
      {:value, {:EXIT, {reason, get_stacktrace()}}, bindings}

    :exit, reason ->
      {:value, {:EXIT, reason}, bindings}

    :throw, reason ->
      {:value, reason, bindings}
  end

  defp eval_expr(eval, {:try, _, _, _, _, _} = expr, bindings) do
    {:try, line, exprs, case_clauses, catch_clauses, after_clauses} = expr
    eval = Map.put(eval, :line, line)

    try do
      case {sequence(Map.put(eval, :top_level, false), exprs, bindings), case_clauses} do
        {{:value, value, _bindings}, []} ->
          value

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
      |> sequence(after_clauses, bindings)
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
    eval =
      eval
      |> Map.put(:top_level, false)
      |> Map.put(:line, line)

    case eval_expr(eval, expr_1, bindings) do
      {:value, false, _} = response ->
        response

      {:value, true, bindings} ->
        {:value, value, _} = eval_expr(eval, expr_2, bindings)
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

  defp eval_expr(eval, {:make_fun, line, name, [{_, _, _, args}] = clauses} = expr, bindings) do
    eval_func = fn args ->
      eval_mfa(eval, {__MODULE__, :eval_fun, [clauses, args, bindings, {eval.module, name}]})
    end

    function =
      case length(args) do
        0 ->
          fn -> eval_func.([]) end

        1 ->
          fn a -> eval_func.([a]) end

        2 ->
          fn a, b -> eval_func.([a, b]) end

        3 ->
          fn a, b, c -> eval_func.([a, b, c]) end

        4 ->
          fn a, b, c, d -> eval_func.([a, b, c, d]) end

        5 ->
          fn a, b, c, d, e -> eval_func.([a, b, c, d, e]) end

        6 ->
          fn a, b, c, d, e, f -> eval_func.([a, b, c, d, e, f]) end

        7 ->
          fn a, b, c, d, e, f, g ->
            eval_func.([a, b, c, d, e, f, g])
          end

        8 ->
          fn a, b, c, d, e, f, g, h ->
            eval_func.([a, b, c, d, e, f, g, h])
          end

        9 ->
          fn a, b, c, d, e, f, g, h, i ->
            eval_func.([a, b, c, d, e, f, g, h, i])
          end

        10 ->
          fn a, b, c, d, e, f, g, h, i, j ->
            eval_func.([a, b, c, d, e, f, g, h, i, j])
          end

        11 ->
          fn a, b, c, d, e, f, g, h, i, j, k ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k])
          end

        12 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l])
          end

        13 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m])
          end

        14 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m, n ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m, n])
          end

        15 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m, n, o ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m, n, o])
          end

        16 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p])
          end

        17 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q])
          end

        18 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r])
          end

        19 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s])
          end

        20 ->
          fn a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t ->
            eval_func.([a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t])
          end

        _else ->
          eval
          |> Map.put(:line, line)
          |> exception(:error, "Arguement limit: #{expr}", bindings)
      end

    {:value, function, bindings}
  end

  defp eval_expr(eval, {:make_ext_fun, _line, mfa}, bindings) do
    {[module, function, args], bindings} = eval_list(eval, mfa, bindings)

    try do
      {:value, :erlang.make_fun(module, function, args), bindings}
    catch
      :error, :badarg ->
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
    {args, bindings} = eval_list(args, bindings, eval)
    eval_function(eval, {eval.module, function, args}, bindings, :local, last_call?)
  end

  defp eval_expr(eval, {:call_remote, line, module, function, args, last_call?}, bindings) do
    eval = Map.put(eval, :line, line)
    {args, bindings} = eval_list(args, bindings, eval)
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
        raise_exception(class, reason, __STACKTRACE__)
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

    eval =
      eval
      |> Map.put(:module, module)
      |> Map.put(:function, function)
      |> Map.put(:args, args)
      |> Map.put(:line, -1)

    try do
      {:value, apply(module, function, args), bindings}
    catch
      class, reason ->
        exception(eval, class, reason, bindings, true)
    end
  end

  defp eval_expr(eval, {:bif, line, module, function, args}, bindings) do
    {args, bindings} =
      eval
      |> Map.put(:line, line)
      |> eval_list(args, bindings)

    eval
    |> Map.put(:module, module)
    |> Map.put(:function, module)
    |> Map.put(:args, args)
    |> Map.put(:line, -1)
    |> host_cmd({:apply, {module, function, args}}, bindings)
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
      x when is_integer(x) and x > 0 -> true
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
    :eval_bits.expr_grp(
      fields,
      bindings,
      fn expr, bindings ->
        eval
        |> Map.put(:line, line)
        |> Map.put(:top_level, false)
        |> eval_expr(expr, bindings)
      end,
      [],
      false
    )
  catch
    class, reason ->
      exception(eval, bindings, class, reason)
  end

  defp eval_expr(eval, {:lc, _line, expr, qualifier}, bindings),
    do: eval_lc(eval, expr, qualifier, bindings)

  defp eval_expr(eval, {:bc, _line, expr, qualifier}, bindings),
    do: eval_bc(eval, expr, qualifier, bindings)

  defp eval_expr(eval, exp, bindings),
    do: exception(eval, bindings, :error, "Unknown expression: #{inspect(exp)}")

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
      |> Enum.map_reduce(%{}, fn {key, value}, acc ->
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
      true -> sequence(eval, body, bindings)
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
            sequence(eval, body, bindings)

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
            sequence(eval, body, bindings)

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

    case receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        eval_receive1(eval, host, clauses, bindings)

      {:eval, body, bindings, message} ->
        recieve_message(eval, host, message, bindings)
        sequence(eval, body, bindings)
    end
  end

  defp eval_receive1(eval, host, clauses, bindings) do
    messages = do_receive(eval, host, bindings)

    case receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        eval_receive1(eval, host, clauses, bindings)

      {:eval, body, bindings, message} ->
        recieve_message(eval, host, message, bindings)
        sequence(eval, body, bindings)
    end
  end

  defp eval_receive(eval, host, clauses, {0, _, _} = to, bindings, 0, _stamp) do
    {_, messages} = Process.info(host, :messages)

    case receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        {_to_value, to_exprs, to_bindings} = to
        sequence(eval, to_exprs, to_bindings)

      {:eval, body, bindings, message} ->
        recieve_message_no_trace(eval, host, message, bindings)
        sequence(eval, body, bindings)
    end
  end

  defp eval_receive(eval, host, clauses, to, bindings, 0, stamp) do
    :erlang.trace(host, true, [:receive])
    {_, messages} = Process.info(host, :messages)

    case receive_clauses(eval, clauses, bindings, messages) do
      :nomatch ->
        {to_value, to_exprs, to_bindings} = to
        {stamp, to_value} = new_timeout(stamp, to_value)
        to = {to_value, to_exprs, to_bindings}
        eval_receive(eval, host, clauses, to, bindings, :infinity, stamp)

      {:eval, body, bindings, message} ->
        recieve_message(eval, host, message, bindings)
        sequence(eval, body, bindings)
    end
  end

  defp eval_receive(eval, host, clauses, to, bindings, _, stamp) do
    {to_value, to_exprs, to_bindings} = to

    case do_receive(eval, host, to_value, stamp, bindings) do
      :timeout ->
        recieve_message(host)
        sequence(eval, to_exprs, to_bindings)

      messages ->
        case receive_clauses(eval, clauses, bindings, messages) do
          :nomatch ->
            {stamp, to_value} = new_timeout(stamp, to_value)
            to = {to_value, to_exprs, to_bindings}
            eval_receive(eval, host, clauses, to, bindings, :infinity, stamp)

          {:eval, body, bindings, message} ->
            recieve_message(eval, host, message, bindings)
            sequence(eval, body, bindings)
        end
    end
  end

  defp do_receive(eval, host, bindings) do
    receive do
      {:trace, ^host, :receive, message} ->
        [message]

      message ->
        check_exit_message(eval, message, bindings)
        do_receive(eval, host, bindings)
    end
  end

  defp do_receive(eval, host, time, stamp, bindings) do
    receive do
      {:trace, ^host, :receive, message} ->
        [message]

      {:user, :timeout} ->
        :timeout

      message ->
        check_exit_message(eval, message, bindings)
        {stamp1, time1} = new_timeout(stamp, time)
        do_receive(eval, host, time1, stamp1, bindings)
    after
      time ->
        :timeout
    end
  end

  defp recieve_message(eval, host, message, bindings) do
    :erlang.trace(host, false, [:receive])
    flush_traces(host)
    send(host, {:sys, self(), {:receive, message}})
    receive_response(eval, host, bindings)
  end

  defp recieve_message(host) do
    :erlang.trace(host, false, [:receive])
    flush_traces(host)
  end

  defp recieve_message_no_trace(eval, host, message, bindings) do
    send(host, {:sys, self(), {:receive, message}})
    receive_response(eval, host, bindings)
  end

  defp receive_response(eval, host, bindings) do
    receive do
      {^host, :receive_response} ->
        true

      message ->
        check_exit_message(eval, message, bindings)
        IO.puts(:stderr, "***WARNING*** Unexpected message: #{inspect(message)}")
    end
  end

  defp flush_traces(host) do
    receive do
      {:trace, ^host, :receive, _} ->
        flush_traces(host)
    after
      0 ->
        true
    end
  end

  defp receive_clauses(eval, clauses, bindings, [message | messages]) do
    case rec_clauses(eval, clauses, bindings, message) do
      :nomatch ->
        receive_clauses(eval, clauses, bindings, messages)

      {:eval, body, bindings} ->
        {:eval, body, bindings, message}
    end
  end

  defp receive_clauses(_, _, _, []), do: :nomatch

  defp rec_clauses(eval, [{:clause, _, [pattern], guards, body} | clauses], bindings, message) do
    case match(eval, pattern, message, bindings) do
      {:match, bindings} ->
        case guard(eval, guards, bindings) do
          true ->
            {:eval, body, bindings}

          false ->
            rec_clauses(eval, clauses, bindings, message)
        end

      :nomatch ->
        rec_clauses(eval, clauses, bindings, message)
    end
  end

  defp rec_clauses(_, [], _, _), do: :nomatch

  defp eval_lc(eval, expr, qualifiers, bindings) do
    {:value, expand_lc(eval, expr, qualifiers, bindings), bindings}
  end

  defp expand_lc(eval, expr, [{:generate, line, pattern, list} | qualifiers], bindings) do
    {:value, list, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = &expand_lc(eval, expr, qualifiers, &1)

    eval
    |> Map.put(:line, line)
    |> eval_generate(list, pattern, bindings, comp_func)
  end

  defp expand_lc(eval, expr, [{:b_generate, line, pattern, list} | qualifiers], bindings) do
    {:value, binary, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = &expand_lc(eval, expr, qualifiers, &1)

    eval
    |> Map.put(:line, line)
    |> eval_b_generate(binary, pattern, bindings, comp_func)
  end

  defp expand_lc(eval, expr, [{:guard, qualifier} | qualifiers], bindings) do
    case guard(eval, qualifier, bindings) do
      true -> expand_lc(eval, expr, qualifiers, bindings)
      false -> []
    end
  end

  defp expand_lc(eval, expr, [qualifier | qualifiers], bindings) do
    eval
    |> Map.put(:top_level, false)
    |> eval_expr(qualifier, bindings)
    |> case do
      {:value, true, bindings} ->
        expand_lc(eval, expr, qualifiers, bindings)

      {:value, false, _bindings} ->
        []

      {:value, value, bindings} ->
        exception(eval, :error, "bad filter: #{inspect({value, bindings})}", bindings)
    end
  end

  defp expand_lc(eval, expr, [], bindings) do
    {:value, value, _} =
      eval
      |> Map.put(:top_level, false)
      |> eval_expr(expr, bindings)

    [value]
  end

  defp eval_bc(eval, expr, qualifiers, bindings) do
    value =
      eval
      |> expand_bc(expr, qualifiers, bindings)
      |> :erlang.list_to_bitstring()

    {:value, value, bindings}
  end

  defp expand_bc(eval, expr, [{:generate, line, pattern, list} | qualifiers], bindings) do
    {:value, binary, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = &expand_bc(eval, expr, qualifiers, &1)

    eval
    |> Map.put(:line, line)
    |> eval_generate(binary, pattern, bindings, comp_func)
  end

  defp expand_bc(eval, expr, [{:b_generate, line, pattern, list} | qualifiers], bindings) do
    {:value, binary, bindings} =
      eval
      |> Map.put(:line, line)
      |> Map.put(:top_level, false)
      |> eval_expr(list, bindings)

    comp_func = &expand_bc(eval, expr, qualifiers, &1)

    eval
    |> Map.put(:line, line)
    |> eval_b_generate(binary, pattern, bindings, comp_func)
  end

  defp expand_bc(eval, expr, [{:guard, qualifier} | qualifiers], bindings) do
    case guard(eval, qualifier, bindings) do
      true -> expand_bc(eval, expr, qualifiers, bindings)
      false -> []
    end
  end

  defp expand_bc(eval, expr, [qualifier | qualifiers], bindings) do
    eval
    |> Map.put(:top_level, false)
    |> eval_expr(qualifier, bindings)
    |> case do
      {:value, true, bindings} ->
        expand_bc(eval, expr, qualifiers, bindings)

      {:value, false, _bindings} ->
        []

      {:value, value, bindings} ->
        exception(eval, :error, "bad filter: #{inspect({value, bindings})}", bindings)
    end
  end

  defp expand_bc(eval, expr, [], bindings) do
    {:value, value, _} =
      eval
      |> Map.put(:top_level, false)
      |> eval_expr(expr, bindings)

    [value]
  end

  defp eval_generate(eval, [value | values], pattern, bindings, comp_func) do
    case match(eval, pattern, value, :erl_eval.new_bindings(), bindings) do
      {:match, match_bindings} ->
        match_bindings
        |> add_bindings(bindings)
        |> comp_func.()
        |> Kernel.++(eval_generate(eval, values, pattern, bindings, comp_func))

      :nomatch ->
        eval_generate(eval, values, pattern, bindings, comp_func)
    end
  end

  defp eval_generate(_eval, [], _pattern, _bindings, _comp_func), do: []

  defp eval_generate(eval, term, _pattern, bindings, _comp_func),
    do: exception(eval, :error, "bad generator: #{inspect(term)}", bindings)

  defp eval_b_generate(eval, <<>> = binary, pattern, bindings, comp_func) do
    match_func = match_function(eval, bindings)
    eval_func = &eval_expr(%Eval{}, &1, &2)

    pattern
    |> :eval_bits.bin_gen(binary, :erl_eval.new_bindings(), bindings, match_func, eval_func)
    |> case do
      {:match, rest, match_bindings} ->
        match_bindings
        |> add_bindings(bindings)
        |> comp_func.()
        |> Kernel.++(eval_b_generate(eval, rest, pattern, bindings, comp_func))

      {:nomatch, rest} ->
        eval_b_generate(eval, rest, pattern, bindings, comp_func)

      :done ->
        []
    end
  end

  defp eval_b_generate(eval, term, _pattern, bindings, _comp_func),
    do: exception(eval, :error, "bad generator: #{inspect(term)}", bindings)

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
    do: {:value, _} = binding(var, bindings)

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

  defp exception(eval, class, reason, bindings) do
    exception(eval, class, reason, [], bindings)
  end

  defp exception(_eval, class, reason, stacktrace, _bindings) do
    raise_exception(class, reason, stacktrace)
  end

  defp raise_exception(class, reason, stacktrace) do
    class
    |> :erlang.raise(reason, stacktrace)
    |> :erlang.error()
  end

  defp get_stacktrace(), do: []
end
