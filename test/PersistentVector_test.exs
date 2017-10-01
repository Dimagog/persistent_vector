defmodule PersistentVectorTest do
  use ExUnit.Case
  use EQC.ExUnit

  import PersistentVector

  doctest PersistentVector

  test "empty" do
    v = empty()
    assert v |> empty?()
    assert v |> count() == 0
    assert v |> Enum.count() == 0
    assert v |> last(nil) == nil
    assert v |> last(:it_is_empty) == :it_is_empty

    assert_raise ArgumentError, "Attempt to get index 0 for vector of size 0", fn -> v |> get(0) end
    assert_raise ArgumentError, "last/1 called for empty vector", fn -> v |> last() end

    assert v |> get(1, :not_found) == :not_found
    assert v |> fetch(1) == :error
  end

  test "brute get" do
    v = %PersistentVector{count: 5, root: {{0, 1, 2}, {4}}}
    assert v |> get(0) == 0
    assert v |> get(1) == 1
    assert v |> get(2) == 2
    assert v |> get(4) == 4
  end

  test "append to tail" do
    v = empty() |> append(0)
    assert v |> count() == 1
    refute v |> empty?()
    assert v |> get(0) == 0

    v = v |> append(1)
    assert v |> count() == 2
    assert v |> get(0) == 0
    assert v |> get(1) == 1
  end

  test "append to root" do
    c = 68-1
    v = Enum.reduce(0..c, empty(), &(&2 |> append(&1) |> assert_element_identity()))

    c = c + 1
    assert v |> count() == c

    v = v |> append(c) |> assert_element_identity()
    # IO.inspect v, pretty: true
    assert v |> count() == c + 1
    assert v |> get(c) == c

    assert_raise ArgumentError, "Attempt to get index #{c+1} for vector of size #{c+1}", fn -> v |> get(c+1) end
    assert_raise ArgumentError, "Attempt to get index \"hello\" for vector of size #{c+1}", fn -> v |> get("hello") end
    assert_raise ArgumentError, "Attempt to get index {1} for vector of size #{c+1}", fn -> v |> get({1}) end
  end

  test "remove_last tail" do
    v = empty() |> append(0)
    r = v |> remove_last()
    assert r |> count() == 0

    v = v |> append(1)
    r = v |> remove_last()
    assert r |> count() == 1
    assert r |> get(0) == 0
  end

  test "remove_last root" do
    c = 20
    v = Enum.reduce(0..c, empty(), &(&2 |> append(&1)))

    s = Enum.reduce(c..0, v, fn c, v -> assert v |> assert_element_identity() |> count() == c+1; v |> remove_last() end)

    assert s |> count() == 0
    assert_raise ArgumentError, "Cannot remove_last from empty vector", fn -> s |> remove_last() end
  end

  test "set tail" do
    v0 = empty() |> set(0, 0) |> set(1, 1) |> assert_element_identity
    assert v0 |> count == 2

    c = 4-1
    v1 = Enum.reduce(0..c, empty(), &(&2 |> append(&1)))
    v2 = Enum.reduce(0..c, v1, &(&2 |> set(&1, &1 + 10)))
    assert v1 |> count == v2 |> count

    Enum.each(0..c, &(assert v1 |> get(&1) == ((v2 |> get(&1)) - 10)))
  end

  test "set root" do
    c = 20-1
    v1 = Enum.reduce(0..c, empty(), &(&2 |> append(&1)))
    v2 = Enum.reduce(0..c, v1, &(&2 |> set(&1, &1 + 10)))
    assert v1 |> count == v2 |> count

    Enum.each(0..c, &(assert v1 |> get(&1) == ((v2 |> get(&1)) - 10)))

    assert_raise ArgumentError, "Attempt to set index 1 for vector of size 0", fn -> empty() |> set(1, 1) end
    assert_raise ArgumentError, "Attempt to set index \"bla\" for vector of size 0", fn -> empty() |> set("bla", 1) end
  end

  property "Equality" do
    let [n <- nat(), m <- choose(n + 1, 17_000)] do
      small =
        if n > 0 do
          Enum.reduce(0..n-1, empty(), &(&2 |> append(&1))) |> assert_element_identity()
        else
          empty()
        end

      big = Enum.reduce(0..m-1, empty(), &(&2 |> append(&1))) |> assert_element_identity()
      big = Enum.reduce(n..m-1, big, fn _, v -> v |> remove_last() end) |> assert_element_identity()

      assert small |> count() == big |> count()
      ensure small == big
    end
  end

  property "Enumerable" do
    forall n <- nat() do
      if n > 0 do
        v = Enum.reduce(0..n-1, empty(), &(&2 |> append(&1))) |> assert_element_identity()
        assert (v |> Enum.into([])) == (0..n-1 |> Enum.into([]))
        ls = v |> Enum.map(&(&1 + 1))
        assert ls |> Enum.count() == v |> count()
        0..n-1 |> Enum.each(&(assert ls |> Enum.at(&1) == &1 + 1))
        assert v |> Enum.member?(n-1)
        assert Stream.zip(v, v) |> Enum.count() == v |> count()
      else
        assert (empty() |> Enum.into([])) == []
      end
    end
  end

  property "Enumerable.halt" do
    let [m <- nat(), n <- choose(m, 17_000)] do
      v =
        if n > 0 do
          Enum.reduce(0..n-1, empty(), &(&2 |> append(&1))) |> assert_element_identity()
        else
          empty()
        end
      lt = v |> Enum.take(m)
      lt |> new() |> assert_element_identity()
      assert lt |> Enum.count() == m
    end
  end

  property "Collectable" do
    forall n <- nat() do
      if n > 0 do
        v = 0..n-1 |> Enum.into(empty()) |> assert_element_identity()
        assert v |> count() == n
        assert (v |> Enum.into([])) == (0..n-1 |> Enum.into([]))
        ls = v |> Enum.map(&(&1 + 1))
        assert ls |> Enum.count() == v |> count()
        0..n-1 |> Enum.each(&(assert ls |> Enum.at(&1) == &1 + 1))
        assert v |> Enum.member?(n-1)
        assert v |> to_list() == v |> Enum.into([])
      else
        assert ([] |> Enum.into(empty())) == empty()
      end

      if n > 2 do
        v1 = 0 .. div(n, 2)-1 |> Enum.into(empty()) |> assert_element_identity()
        div(n, 2) .. n-1 |> Enum.into(v1) |> assert_element_identity()
      end

      true
    end
  end

  test "Inspect" do
    assert inspect(new()) == "#PersistentVector<count: 0, []>"
    assert inspect(new([1])) == "#PersistentVector<count: 1, [1]>"
    assert inspect(new([1, 2])) == "#PersistentVector<count: 2, [1, 2]>"
    assert inspect(new([1, 2, 3])) == "#PersistentVector<count: 3, [1, 2, 3]>"
    assert inspect(new([1, 2, 3]), limit: 2) == "#PersistentVector<count: 3, [1, 2, ...]>"
  end

  test "100% code coverage" do
    assert_raise UndefinedFunctionError, fn -> new() |> Access.get_and_update(0, &(&1)) end
    assert_raise UndefinedFunctionError, fn -> new([1, 2, 3]) |> Access.pop(0) end
  end

  defp assert_element_identity(v = %PersistentVector{}) do
    c = v |> count()
    if c > 0 do
      # "randomly" use different getters
      validation_fun =
        case rem(c, 4) do
          0 -> &(assert v |> get(&1) == &1)
          1 -> &(assert v[&1] == &1)
          2 -> &(assert v |> get(&1, :not_found) == &1)
          3 -> &(assert v |> fetch(&1) == {:ok, &1})
        end

      Enum.each(0..c-1, validation_fun)

      assert v |> last(:empty) == c - 1
      assert v |> last() == c - 1
    end
    v
  end
end
