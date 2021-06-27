defmodule EDS.Remote.Spy.Interpreter.ControlFlowTests do
  use EDS.DataCase, async: false

  alias EDS.Remote.Spy.Server
  alias EDS.Fixtures.ControlFlows

  setup_all do
    start_supervised(Server)
    Server.load(ControlFlows)
    :ok
  end

  test "if clauses" do
    assert ControlFlows.if_clause(true)
    refute ControlFlows.if_clause(false)
  end

  test "if blocks" do
    assert ControlFlows.if_block(true)
    refute ControlFlows.if_block(false)
  end

  test "unless clauses" do
    refute ControlFlows.unless_clause(true)
    assert ControlFlows.unless_clause(false)
  end

  test "unless blocks" do
    refute ControlFlows.unless_block(true)
    assert ControlFlows.unless_block(false)
  end

  test "case clauses" do
    assert :case_1 == ControlFlows.case_clause(true)
    assert :case_2 == ControlFlows.case_clause(false)
    assert :case_3 == ControlFlows.case_clause(1)
  end

  test "cond clauses" do
    assert ControlFlows.cond_clause(true)
    refute ControlFlows.cond_clause(false)
    assert ControlFlows.cond_clause(1)
  end
end
