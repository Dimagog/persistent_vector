defmodule ERangeTest do
  use ExUnit.Case

  import ERange

  test "ERange" do
    tests = [
      {erange(1, 2),  [1],     "[1, 2)",  "(2, 1]"},
      {erange(1, 3),  [1, 2],  "[1, 3)",  "(3, 1]"},
      {erange(2, 1),  [1],     "(2, 1]",  "[1, 2)"},
      {erange(3, 1),  [2, 1],  "(3, 1]",  "[1, 3)"},
      {erange(1, 1),  [],      "[1, 1)",  "[1, 1)"},
      {erange(-1, 1), [-1, 0], "[-1, 1)", "(1, -1]"},
      {erange(1, -1), [0, -1], "(1, -1]", "[-1, 1)"},
    ]

    tests |> Enum.each(fn {r, list, string, inv_string} ->
      assert Enum.count(r) == Enum.count(list)
      assert r |> Enum.into([]) == list
      assert inspect(r) == string
      rr = r |> reverse()
      assert inspect(rr) == inv_string
      assert rr |> Enum.into([]) == :lists.reverse(list)
      list |> Enum.each(&assert(r |> Enum.member?(&1)))
      zr = Stream.zip(r, r)
      assert (zr |> Enum.count) == (r |> Enum.count)
    end)
  end
end