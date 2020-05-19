defmodule Assertion.Test do
  def assert(:==, lhs, rhs) when lhs == rhs do
    IO.write "."
  end
  def assert(:==, lhs, rhs) do
    IO.puts """
    Failure:
    Expected:       #{lhs}
    to be equal to: #{rhs}
    """
  end

  def assert(:>, lhs, rhs) when lhs == rhs do
    IO.write "."
  end
  def assert(:>, lhs, rhs) do
    IO.puts """
    Failure:
    Expected:           #{lhs}
    to be greater than: #{rhs}
    """
  end

end

defmodule Assertion do

  defmacro assert({operator, _, [lhs, rhs]}) do
    quote bind_quoted: [operator: operator, lhs: lhs, rhs: rhs] do
      Assertion.Test.assert(operator, lhs, rhs)
    end
  end

end

