alias PersistentVector, as: Vec

print_opts = [benchmarking: false, fast_warning: false]
opts = [
  warmup: 2,
  time: 3,
  print: print_opts,
  # formatters: [
  #   &Benchee.Formatters.HTML.output/1,
  #   &Benchee.Formatters.Console.output/1
  # ],
  # formatter_options: [html: [file: "html/bench.html"]],
]

print_opts = print_opts ++ [configuration: false]
opts = opts ++ [print: print_opts]

inputs =
  if System.argv == ["full"] do
    %{
      "       10" => 0 ..        10,
      "      100" => 0 ..       100,
      "    1'000" => 0 ..     1_000,
      "   10'000" => 0 ..    10_000,
      "  100'000" => 0 ..   100_000,
      "1'000'000" => 0 .. 1_000_000,
    }
  else
    %{
      "    1'000" => 0 ..     1_000,
      "1'000'000" => 0 .. 1_000_000,
    }
  end

IO.puts "Using #{Enum.count(inputs)} inputs"

title = fn name ->
  IO.puts ""
  IO.puts "#"
  IO.puts "# #{name}"
  IO.puts "#"
end

title.("Build")
Benchee.run(%{
  "Vector Build" => fn range -> Enum.reduce(range, Vec.empty(), &(&2 |> Vec.append(&1))) end,
  "Array  Build" => fn range -> Enum.reduce(range, :array.new(), &:array.set(&1, &1, &2)) end,
  "List   Build" => fn range -> Enum.reduce(range, [], &[&1 | &2]) |> :lists.reverse() end,
  },
  opts ++ [inputs: inputs])

data_inputs =
  inputs
  |> Enum.map(
      fn {text, range} ->
        vec = Enum.reduce(range, Vec.empty(), &(&2 |> Vec.append(&1)))
        if vec |> Vec.count != range.last+1, do: raise "Vector size didn't match"

        arr = Enum.reduce(range, :array.new(), &:array.set(&1, &1, &2))
        if arr |> :array.size != range.last+1, do: raise "Array size didn't match"

        {text,{range, vec, arr}}
      end)
  |> Enum.into(%{})

title.("Shrink")
Benchee.run(%{
  "Vector remove_last" => fn {range, vec, _arr} -> Enum.reduce(range, vec, fn _, vec -> vec |> Vec.remove_last() end) end,
  "Array  resize     " => fn {range, _vec, arr} -> Enum.reduce(range, arr, fn _, arr -> :array.resize(:array.size(arr) - 1, arr) end) end,
  },
  opts ++ [inputs: data_inputs])

title.("Get")
Benchee.run(%{
  "Vector Get" => fn {range, vec, _arr} -> Enum.each(range, &(vec |> Vec.get(&1))) end,
  "Array  Get" => fn {range, _vec, arr} -> Enum.each(range, &:array.get(&1, arr)) end,
  },
  opts ++ [inputs: data_inputs])

title.("Set")
Benchee.run(%{
  "Vector Set" => fn {range, vec, _arr} -> Enum.reduce(range, vec, &(&2 |> Vec.set(&1, &1 + 1))) end,
  "Array  Set" => fn {range, _vec, arr} -> Enum.reduce(range, arr, &:array.set(&1, &1 + 1, &2)) end,
  },
  opts ++ [inputs: data_inputs])
