defmodule EDS.Remote.Spy.Eval do
  defstruct level: 1,
            source: nil,
            line: -1,
            module: nil,
            function: nil,
            args: nil,
            error_info: [],
            top_level: false
end
