defmodule ERange do
  defstruct(from: nil, to: nil)

  @type t :: %__MODULE__{from: integer, to: integer}

  @spec erange(integer, integer) :: t
  def erange(from, to)
    when is_integer(from) and is_integer(to)
  do
    %__MODULE__{from: from, to: to}
  end

  @spec reverse(t) :: t
  def reverse(%__MODULE__{from: from, to: to}) do
    %__MODULE__{from: to, to: from}
  end

  defimpl Enumerable do
    def reduce(%@for{from: from, to: to}, acc, fun) do
      if from <= to do
        reduce(from, to, acc, fun, 1)
      else
        reduce(from-1, to-1, acc, fun, -1)
      end
    end

    defp reduce(x, y, {:cont, acc}, fun, step) when x != y do
      reduce(x + step, y, fun.(x, acc), fun, step)
    end

    defp reduce(_, _, {:cont, acc}, _fun, _step) do
      {:done, acc}
    end

    defp reduce(_x, _y, {:halt, acc}, _fun, _step) do
      {:halted, acc}
    end

    defp reduce(x, y, {:suspend, acc}, fun, step) do
      {:suspended, acc, &reduce(x, y, &1, fun, step)}
    end

    def member?(%@for{from: from, to: to}, value) when is_integer(value) do
      if from <= to do
        {:ok, from <= value and value < to}
      else
        {:ok, from > value and value >= to}
      end
    end

    def member?(%@for{}, _value) do
      {:ok, false}
    end

    def count(%@for{from: from, to: to}) do
      if from <= to do
        {:ok, to - from}
      else
        {:ok, from - to}
      end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%@for{from: from, to: to}, opts) do
      concat [
        (if from <= to, do: "[", else: "("),
        to_doc(from, opts), ", ", to_doc(to, opts),
        (if from <= to, do: ")", else: "]")
      ]
    end
  end
end
