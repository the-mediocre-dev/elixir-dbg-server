defmodule EDS.Utils.Code do
  def redirect_breakpoint() do
    true = :code.unstick_mod(:error_handler)

    function = :forms.to_abstract('breakpoint(M, F, A) -> \'Elixir.EDS.Remote.Spy.Host\':eval(M, F, A).')

    :breakpoint
    |> :meta.replace_function(3, function, :forms.read(:error_handler))
    |> :meta.apply_changes()

    true = :code.stick_mod(:error_handler)
  end
end
