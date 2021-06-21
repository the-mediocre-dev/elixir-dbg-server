defmodule EDS.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import EDS.DataCase
    end
  end

  setup _tags do
    :ets.delete_all_objects(EDS.Repo)

    :ok
  end
end
