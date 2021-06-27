defmodule EDS.Utils.Code do
  def redirect_breakpoint() do
    true = :code.unstick_mod(:error_handler)

    function = :forms.to_abstract('breakpoint(M, F, A) -> \'Elixir.EDS.Remote.Spy.Host\':eval(M, F, A).')

    :breakpoint
    |> :meta.replace_function(3, function, :forms.read(:error_handler))
    |> :meta.apply_changes()

    true = :code.stick_mod(:error_handler)
  end

  def parse_mfa_or_ml(mfa_or_ml) do
    case String.split(mfa_or_ml, "/") do
      [module, function, arity] ->
        module = String.to_atom(module)
        function = String.to_atom(function)

        case Integer.parse(arity) do
          {arity, _} ->
            {:ok, {Module.concat(Elixir, module), function, arity}}

          _else ->
            {:error, :invalid_mfa}
        end

      [module, line] ->
        module = String.to_atom(module)

        case Integer.parse(line) do
          {line, _} ->
            {:ok, {Module.concat(Elixir, module), line}}

          _else ->
            {:error, :invalid_ml}
        end

      _else ->
        {:error, :invalid_mfa_or_ml}
    end
  end
end
