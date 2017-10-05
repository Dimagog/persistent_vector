defmodule PersistentVector do
  @moduledoc """
  `PersistentVector` is an array-like collection of values indexed by contiguous `0`-based integer index
  and optimized for growing/shrinking at the end.

  `PersistentVector` optimizes the following operations:
  * Get element count
  * Lookup element by index
  * Update element by index
  * Adding new element to the end
  * Removing element from the end
  * Enumeration

  Get count operation is `O(1)`, most others are `O(log32(N))`.

  `PersistentVector` is implemented as a trie with 32-way branching at each level and uses *structural sharing* for updates.
  All ideas are borrowed directly from Clojure, yet the implementation (and all the bugs) are my own.

  ### Supported protocols
  `PersistentVector` implements the following protocols/behaviors:
  * `Access`
  * `Collectable`
  * `Enumerable`
  * `Inspect`

  ## Usage example
      iex> v = new(1..3)
      #PersistentVector<count: 3, [1, 2, 3]>
      iex> get(v, 0)
      1
      iex> v[1]
      2
      iex> set(v, 1, :two)
      #PersistentVector<count: 3, [1, :two, 3]>
      iex> v # but v remains unchanged
      #PersistentVector<count: 3, [1, 2, 3]>
      iex> append(v, 4)
      #PersistentVector<count: 4, [1, 2, 3, 4]>
      iex> remove_last(v)
      #PersistentVector<count: 2, [1, 2]>

  ## Efficiency
  Creating big vectors is OK both CPU-wise and memory-wise.
  For a `100_000`-element vector the trie depths is 4
  *(because `log32(100_000) = 3.3`)*, leading to fast lookup in 4 hops:

      iex> big = new(100_000..0)
      iex> big[70_000]
      30_000

  Update is also fast and efficient as it needs to build only 4 new trie nodes.
  Apart from that `big1` and `big2` share majority of the elements, leading to efficient memory usage:

      iex> big1 = new(100_000..0)
      iex> big2 = set(big1, 70_000, "thirty thousand")
      iex> big2[70_000]
      "thirty thousand"
  """

  use Bitwise

  @shift if Mix.env() == :test, do: 2, else: 5
  @block 1 <<< @shift
  @mask @block - 1

  @state __MODULE__

  @typep shift :: pos_integer
  @typedoc "Integer >= 0 for indexing elements."
  @type index :: non_neg_integer
  @typedoc "Stored values."
  @type value :: any
  @typedoc "The `PersistentVector` itself."
  @type t :: %__MODULE__{count: index, shift: shift, root: tuple, tail: tuple}

  defstruct(
    count: 0,
    shift: @shift,
    root: {},
    tail: {}
  )

  @compile {:inline, tail_start: 1}
  @spec tail_start(t) :: index
  defp tail_start(v = %@state{}), do: v.count - tuple_size(v.tail)

  @doc "Returns empty `PersistentVector`, same as `new/0`."
  @spec empty() :: t
  def empty(), do: %@state{}

  @doc "Creates new empty `PersistentVector`, same as `empty/0`."
  @spec new() :: t
  def new(), do: %@state{}

  @doc "Returns `PersistentVector` with elements from `enumerable`."
  @spec new(Enumerable.t) :: t
  def new(enumerable), do: enumerable |> Enum.reduce(empty(), &(&2 |> append(&1)))

  @doc "Returns `true` if `v` is empty and `false` otherwise."
  @spec empty?(t) :: boolean
  def empty?(v)

  def empty?(%@state{count: 0}), do: true

  def empty?(%@state{}), do: false

  @doc "Returns element count in `v`."
  @spec count(t) :: index
  def count(v)

  def count(%@state{count: count}), do: count

  @doc """
  Returns value of element in `v` at `0`-based `index`.

  Index must be an integer and satisfy condition `0 <= index < count(v)` or `ArgumentError` will be raised.

  **Note** that since `PersistentVector` implements `Access` behavior, a shorter syntax `v[i]` can be used.

  *See also:* `get/3`

  ## Examples:
      iex> v = new([:a, :b, :c])
      #PersistentVector<count: 3, [:a, :b, :c]>
      iex> get(v, 0)
      :a
      iex> v[1]
      :b
      iex> get(v, 10)
      ** (ArgumentError) Attempt to get index 10 for vector of size 3
      iex> v[10]
      nil
  """
  @spec get(t, index) :: value | no_return
  def get(v = %@state{count: count}, index)
    when is_integer(index) and index >= 0 and index < count
  do
    fast_get(v, index)
  end

  def get(%@state{count: count}, i) do
    raise ArgumentError, "Attempt to get index #{inspect i} for vector of size #{count}"
  end

  @doc """
  Returns value of element in `v` at `0`-based `index` or `default` if `index >= count(v)`.

  Index must be an integer and satisfy condition `0 <= index` or `ArgumentError` will be raised.

  *See also:* `get/2`

  ## Examples:
      iex> v = new([:a, :b, :c])
      #PersistentVector<count: 3, [:a, :b, :c]>
      iex> get(v, 0, :not_found)
      :a
      iex> get(v, 10, :not_found)
      :not_found
      iex> get(v, :bad_index, :not_found)
      ** (ArgumentError) Attempt to get index :bad_index for vector of size 3
  """
  @impl Access
  @spec get(t, index, value) :: value | no_return
  def get(v = %@state{count: count}, index, _default)
    when is_integer(index) and index >= 0 and index < count
  do
    fast_get(v, index)
  end

  def get(%@state{count: count}, index, default)
    when is_integer(index) and index >= count
  do
    default
  end

  def get(%@state{count: count}, i, _default) do
    raise ArgumentError, "Attempt to get index #{inspect i} for vector of size #{count}"
  end

  @doc false
  @compile {:inline, fast_get: 2}
  @spec fast_get(t, index) :: value
  def fast_get(v, i) do
    if i >= tail_start(v) do
      v.tail
    else
      do_get(v.root, v.shift, i)
    end
    |> elem(i &&& @mask)
  end

  @spec do_get(tuple, shift, index) :: tuple
  defp do_get(arr, level, i)
    when level > 0
  do
    arr |> elem((i >>> level) &&& @mask) |> do_get(level - @shift, i)
  end

  defp do_get(arr, _level, _i)
  # when level == 0
  do
    arr
  end

  @doc """
  Returns last element in `v`, or raises `ArgumentError` if `v` is empty.

  *See also:* `last/2`

  ## Examples:
      iex> v = new(1..3)
      iex> last(v)
      3
      iex> last(empty())
      ** (ArgumentError) last/1 called for empty vector
  """
  @spec last(t) :: value | no_return
  def last(v = %@state{count: count})
    when count > 0
  do
    v |> fast_get(count - 1)
  end

  def last(%@state{})
  # when count == 0
  do
    raise ArgumentError, "last/1 called for empty vector"
  end

  @doc """
  Returns last element in `v`, or `default` if `v` is empty.

  *See also:* `last/1`

  ## Examples:
      iex> v = new(1..3)
      iex> last(v, nil)
      3
      iex> last(empty(), nil)
      nil
      iex> last(empty(), 0)
      0
  """
  @spec last(t, value) :: value | nil
  def last(v = %@state{count: count}, _default)
    when count > 0
  do
    v |> fast_get(count - 1)
  end

  def last(%@state{}, default)
  # when count == 0
  do
    default
  end

  @doc """
  Returns updated `v` with element at `0`-based `index` set to `new_value`.

  Index must be an integer and satisfy condition `0 <= index <= count(v)` or `ArgumentError` will be raised.

  **Note** that setting `index` equal to `count(v)` is allowed and behaves as `append/2`.
  ## Examples:
      iex> v = new([:a, :b, :c])
      #PersistentVector<count: 3, [:a, :b, :c]>
      iex> get(v, 1)
      :b
      iex> set(v, 1, :new_value)
      #PersistentVector<count: 3, [:a, :new_value, :c]>
      iex> set(v, 3, :append)
      #PersistentVector<count: 4, [:a, :b, :c, :append]>
      iex> set(v, 10, :wrong_index)
      ** (ArgumentError) Attempt to set index 10 for vector of size 3
  """
  @spec set(t, index, value) :: t | no_return
  def set(v = %@state{count: count}, index, new_value)
    when is_integer(index) and index >=0 and index < count
  do
    if index >= tail_start(v) do
      new_tail = v.tail |> put_elem(index &&& @mask, new_value)
      %{v | tail: new_tail}
    else
      new_root = v.root |> do_set(v.shift, index, new_value)
      %{v | root: new_root}
    end
  end

  def set(v = %@state{count: count}, index, new_value)
    when is_integer(index) and index == count
  do
    v |> append(new_value)
  end

  def set(%@state{count: count}, index, _new_value) do
    raise ArgumentError, "Attempt to set index #{inspect index} for vector of size #{count}"
  end

  @spec do_set(tuple, shift, index, value) :: tuple
  defp do_set(arr, level, i, val)
    when level > 0
  do
    child_index = (i >>> level) &&& @mask
    new_child = arr |> elem(child_index) |> do_set(level - @shift, i, val)
    arr |> put_elem(child_index, new_child)
  end

  defp do_set(arr, _level, i, val)
  # when level == 0
  do
    arr |> put_elem(i &&& @mask, val)
  end

  @doc """
  Appends `new_value` to the end of `v`.

  ## Examples:
      iex> v = append(empty(), 1)
      #PersistentVector<count: 1, [1]>
      iex> append(v, 2)
      #PersistentVector<count: 2, [1, 2]>
  """
  @spec append(t, value) :: t
  def append(v = %@state{tail: tail}, new_value)
    when tuple_size(tail) < @block
  do
    new_tail = tail |> Tuple.append(new_value)
    %{v | count: v.count + 1, tail: new_tail}
  end

  def append(v = %@state{}, new_value) do
    new_count = v.count + 1
    new_tail = {new_value}
    case v.root |> append_block(v.shift, v.tail) do
      {:ok, new_root} ->
        %{v | count: new_count, root: new_root, tail: new_tail}
      {:overflow, tail_path} ->
        new_root = {v.root, tail_path}
        %{v | count: new_count, root: new_root, tail: new_tail, shift: v.shift + @shift}
    end
  end

  @spec append_block(tuple, shift, tuple) :: {:ok | :overflow, tuple}
  defp append_block(arr, level, tail)
    when level > @shift
  do
    last_child_index = tuple_size(arr) - 1
    case arr |> elem(last_child_index) |> append_block(level - @shift, tail) do
      {:ok, new_child} ->
        {:ok, arr |> put_elem(last_child_index, new_child)}
      {:overflow, tail_path} ->
        arr |> append_block_here(tail_path)
    end
  end

  defp append_block(arr, _level, tail)
  # when level == @shift
  do
    arr |> append_block_here(tail)
  end

  @compile {:inline, append_block_here: 2}
  @spec append_block_here(tuple, tuple) :: {:ok | :overflow, tuple}
  defp append_block_here(arr, tail_path) do
    if tuple_size(arr) < @block do
      {:ok, arr |> Tuple.append(tail_path)}
    else
      {:overflow, {tail_path}}
    end
  end

  @doc """
  Removes last element from `v` or raises `ArgumentError` if `v` is empty.

  ## Examples:
      iex> v = new(1..3)
      #PersistentVector<count: 3, [1, 2, 3]>
      iex> remove_last(v)
      #PersistentVector<count: 2, [1, 2]>
      iex> remove_last(empty())
      ** (ArgumentError) Cannot remove_last from empty vector
  """
  @spec remove_last(t) :: t | no_return
  def remove_last(v = %@state{tail: tail})
    when tuple_size(tail) > 1
  do
    new_tail = tail |> tuple_delete_last()
    %{v | count: v.count - 1, tail: new_tail}
  end

  def remove_last(v = %@state{count: count})
    when count > 1 # and tuple_size(tail) == 1
  do
    new_count = v.count - 1
    {new_root, new_tail} = remove_last_block(v.root, v.shift)
    if tuple_size(new_root) == 1 && v.shift > @shift do
      {new_root} = new_root # remove topmost tree level
      %{v | count: new_count, root: new_root, shift: v.shift - @shift, tail: new_tail}
    else
      %{v | count: new_count, root: new_root, tail: new_tail}
    end
  end

  def remove_last(%@state{count: count})
    when count == 1
  do
    empty()
  end


  def remove_last(%@state{})
  # when count == 0
  do
    raise ArgumentError, "Cannot remove_last from empty vector"
  end

  @spec remove_last_block(tuple, shift) :: {tuple, tuple}
  defp remove_last_block(arr, level)
    when level > @shift
  do
    last_child_index = tuple_size(arr) - 1
    case remove_last_block(arr |> elem(last_child_index), level - @shift) do
      {{}, last_block} ->
        {arr |> Tuple.delete_at(last_child_index), last_block}
      {new_child, last_block} ->
        {arr |> put_elem(last_child_index, new_child), last_block}
    end
  end

  defp remove_last_block(arr, _level)
  # when level == @shift
  do
    last_child_index = tuple_size(arr) - 1
    last_block = arr |> elem(last_child_index)
    new_path = arr |> Tuple.delete_at(last_child_index)
    {new_path, last_block}
  end

  @compile {:inline, tuple_delete_last: 1}
  @spec tuple_delete_last(tuple) :: tuple
  defp tuple_delete_last(tuple) do
    tuple |> Tuple.delete_at(tuple_size(tuple) - 1)
  end

  @doc """
  Converts `PersistentVector` `v` to `List`.

  This function is more efficient than `Enum.into/2``(v, [])` call
  because it builds the list in correct order right away and
  does not require `:lists.reverse/1` call at the end.

  ## Examples:
      iex> to_list(new(1..3))
      [1, 2, 3]
      iex> to_list(empty())
      []
  """
  @spec to_list(t) :: [value]
  def to_list(v = %@state{root: root, shift: shift})
  do
    acc = Tuple.to_list(v.tail)
    if root == {} do
      acc
    else
      big? = shift > 2 * @shift
      to_list(root, shift, tuple_size(root)-1, big?, acc)
    end
  end

  defp to_list(arr, level, i, big?, acc)
    when level > 0
  do
    child = elem(arr, i)
    acc = to_list(child, level - @shift, tuple_size(child)-1, big?, acc)
    if i > 0 do
      to_list(arr, level, i-1, big?, acc)
    else
      acc
    end
  end

  defp to_list(arr, _level, i, big?, acc)
  # when level == 0
  do
    if big? do
      to_list_leaf(arr, i-1, [elem(arr, i) | acc])
    else
      Tuple.to_list(arr) ++ acc
    end
  end

  defp to_list_leaf(arr, i, acc) do
    acc = [elem(arr, i) | acc]
    if i > 0 do
      to_list_leaf(arr, i-1, acc)
    else
      acc
    end
  end

  @doc false # "See `Enumerable.reduce/3`"
  @spec reduce(t, Enumerable.acc, Enumerable.reducer) :: Enumerable.result
  def reduce(v = %@state{}, acc, fun) do
    reduce_root(v.root, v.tail, v.shift, 0, acc, fun)
  end

  @spec reduce_root(tuple, tuple, shift, index, Enumerable.acc | Enumerable.result, Enumerable.reducer) :: Enumerable.result
  defp reduce_root(arr, tail, level, i, acc = {:cont, _}, fun)
    when i < tuple_size(arr)
  do
    reduce_root(arr, tail, level, i+1, reduce_node(elem(arr, i), level - @shift, 0, acc, fun), fun)
  end

  defp reduce_root(_arr, tail, _level, _i, acc = {:cont, _}, fun)
  # when i == tuple_size(arr)
  do
    reduce_tail(tail, 0, acc, fun)
  end

  defp reduce_root(_arr, _tail, _level, _i, acc = {:halted, _}, _fun) do
    acc
  end

  defp reduce_root(_arr, _tail, _level, _i, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  defp reduce_root(arr, tail, level, i, {:suspended, acc, cont_fn}, fun) do
    {:suspended, acc, &reduce_root(arr, tail, level, i, cont_fn.(&1), fun)}
  end

  @spec reduce_tail(tuple, index, Enumerable.acc, Enumerable.reducer) :: Enumerable.result
  defp reduce_tail(arr, i, {:cont, acc}, fun)
    when i < tuple_size(arr)
  do
    reduce_tail(arr, i+1, fun.(elem(arr, i), acc), fun)
  end

  defp reduce_tail(_arr, _i, {:cont, acc}, _fun)
  # when i == tuple_size(arr)
  do
    {:done, acc}
  end

  defp reduce_tail(_arr, _i, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  defp reduce_tail(arr, i, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce_tail(arr, i, &1, fun)}
  end

  @spec reduce_node(tuple, shift, index, Enumerable.acc | Enumerable.result, Enumerable.reducer) :: Enumerable.result
  defp reduce_node(arr, level, i, acc = {:cont, _}, fun)
    when level > 0 and i < tuple_size(arr)
  do
    reduce_node(arr, level, i+1, reduce_node(elem(arr, i), level - @shift, 0, acc, fun), fun)
  end

  defp reduce_node(arr, level, i, {:cont, acc}, fun)
    when i < tuple_size(arr) # and level == 0
  do
    reduce_node(arr, level, i+1, fun.(elem(arr, i), acc), fun)
  end

  defp reduce_node(_arr, _level, _i, acc = {:cont, _}, _fun)
  # when i == tuple_size(arr)
  do
    acc
  end

  defp reduce_node(_arr, 0, _i, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  defp reduce_node(_arr, _level, _i, acc = {:halted, _}, _fun) do
    acc
  end

  defp reduce_node(arr, 0, i, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce_node(arr, 0, i, &1, fun)}
  end

  defp reduce_node(arr, level, i, {:suspended, acc, cont_fn}, fun) do
    {:suspended, acc, &reduce_node(arr, level, i, cont_fn.(&1), fun)}
  end

  @behaviour Access

  # `get/3` is implemented above

  @impl Access
  def fetch(v = %@state{count: count}, key)
    when is_integer(key) and key >= 0 and key < count
  do
    {:ok, v |> fast_get(key)}
  end

  def fetch(%@state{}, _key) do
    :error
  end

  @impl Access
  @spec get_and_update(t, index, fun) :: no_return
  def get_and_update(%@state{}, _key, _function) do
    raise UndefinedFunctionError
  end

  @impl Access
  @spec pop(t, index) :: no_return
  def pop(%@state{}, _key) do
    raise UndefinedFunctionError
  end

  defimpl Enumerable do
    def count(v), do: {:ok, @for.count(v)}

    def member?(%@for{}, _element), do: {:error, __MODULE__}

    def reduce(v, acc, fun), do: @for.reduce(v, acc, fun)
  end

  defimpl Collectable do
    def into(original) do
      collector_fun = fn
        v, {:cont, val} -> v |> @for.append(val)
        v, :done -> v
        _, :halt -> :ok
      end

      {original, collector_fun}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    @prefix "#" <> inspect(@for) <> "<count: "

    def inspect(v, opts) do
      concat [@prefix <> Integer.to_string(v.count) <> ", ", to_doc(v |> Enum.take(opts.limit + 1), opts), ">"]
    end
  end
end
