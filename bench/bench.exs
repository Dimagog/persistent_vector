alias PersistentVector, as: Vec

only =
  case System.argv do
    ["--only", x | rest] -> System.argv(rest); String.upcase(x)
    _ -> nil
  end

full  = Enum.member?(System.argv, "full")
quick = Enum.member?(System.argv, "quick")

defmodule Runner do
  @print_opts [benchmarking: false, fast_warning: false, configuration: false]

  @opts  [
    warmup: 2,
    time: (if quick, do: 3, else: 10),
    print: @print_opts,
    # formatters: [
    #   &Benchee.Formatters.HTML.output/1,
    #   &Benchee.Formatters.Console.output/1
    # ],
    # formatter_options: [html: [file: "html/bench.html"]],
  ]

  IO.puts :stderr, "Time per test: #{Keyword.get(@opts, :time)} sec"

  @only only

  def bench(name, tests, inputs \\ nil) do
    if should_run?(@only, name) do
      IO.puts ""
      IO.puts "#"
      IO.puts "# #{name}"
      IO.puts "#"

      opts =
        if inputs do
          @opts ++ [inputs: inputs]
        else
          @opts
        end

      Benchee.run(tests, opts)
    end
  end

  defp should_run?(nil, _), do: true
  defp should_run?(only, this), do: only == String.upcase(this)
end

inputs =
  if full do
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

IO.puts :stderr, "Using #{Enum.count(inputs)} inputs"

Runner.bench("Build",
  %{
  "Vector Build" => fn range -> Enum.reduce(range, Vec.empty(), &(&2 |> Vec.append(&1))) end,
  "Array  Build" => fn range -> Enum.reduce(range, :array.new(), &:array.set(&1, &1, &2)) end,
  "List   Build" => fn range -> Enum.reduce(range, [], &[&1 | &2]) |> :lists.reverse() end,
  "Map    Build" => fn range -> Enum.reduce(range, %{}, &Map.put(&2, &1, &1)) end,
  },
  inputs)

data_inputs =
  inputs
  |> Enum.map(
      fn {text, range} ->
        vec = Enum.reduce(range, Vec.empty(), &(&2 |> Vec.append(&1)))
        if vec |> Vec.count != range.last+1, do: raise "Vector size didn't match"

        arr = Enum.reduce(range, :array.new(), &:array.set(&1, &1, &2))
        if arr |> :array.size != range.last+1, do: raise "Array size didn't match"

        map = Enum.reduce(range, %{}, &Map.put(&2, &1, &1))
        if map |> Enum.count != range.last+1, do: raise "Map size didn't match"

        {text, %{range: range, vec: vec, arr: arr, map: map}}
      end)
  |> Enum.into(%{})

Runner.bench("Shrink",
  %{
  "Vector remove_last" => fn %{range: range, vec: vec} -> Enum.reduce(range, vec, fn _, vec -> vec |> Vec.remove_last() end) end,
  "Array  resize     " => fn %{range: range, arr: arr} -> Enum.reduce(range, arr, fn _, arr -> :array.resize(:array.size(arr) - 1, arr) end) end,
  "Map    resize     " => fn %{range: range, map: map} -> Enum.reduce(range, map, fn _, map -> Map.delete(map, Enum.count(map) - 1) end) end,
  },
  data_inputs)

Runner.bench("Get",
  %{
  "Vector Get" => fn %{range: range, vec: vec} -> Enum.each(range, &(vec |> Vec.get(&1))) end,
  "Array  Get" => fn %{range: range, arr: arr} -> Enum.each(range, &:array.get(&1, arr)) end,
  "Map    Get" => fn %{range: range, map: map} -> Enum.each(range, &(map |> Map.get(&1))) end,
  },
  data_inputs)

Runner.bench("Set",
  %{
  "Vector Set" => fn %{range: range, vec: vec} -> Enum.reduce(range, vec, &(&2 |> Vec.set(&1, &1 + 1))) end,
  "Array  Set" => fn %{range: range, arr: arr} -> Enum.reduce(range, arr, &:array.set(&1, &1 + 1, &2)) end,
  "Map    Set" => fn %{range: range, map: map} -> Enum.reduce(range, map, &(&2 |> Map.put(&1, &1 + 1))) end,
  },
  data_inputs)

Runner.bench("Enumerate",
  %{
  "Vector Enumerate" => fn %{vec: vec} -> Enum.each(vec, &(&1)) end,
  "Map    Enumerate" => fn %{map: map} -> Enum.each(map, &(&1)) end,
  },
  data_inputs)

Runner.bench("to_list",
  %{
  "Vector into"    => fn %{vec: vec} -> vec |> Enum.into([]) end,
  "Vector to_list" => fn %{vec: vec} -> vec |> Vec.to_list() end,
  "Array  to_list" => fn %{arr: arr} -> arr |> :array.to_list() end,
  "Map    into"    => fn %{map: map} -> map |> Enum.into([]) end,
  "Map    to_list" => fn %{map: map} -> map |> Map.to_list() end,
  },
  data_inputs)
