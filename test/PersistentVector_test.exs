defmodule PersistentVectorTest do
  use ExUnit.Case
  use EQC.ExUnit

  import PersistentVector
  import ERange

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
    c = 68
    v = Enum.reduce(erange(0, c), empty(), &(&2 |> append(&1) |> assert_element_identity()))

    assert v |> count() == c

    v = v |> append(c) |> assert_element_identity()

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

    c = 4
    v1 = Enum.reduce(erange(0, c), empty(), &(&2 |> append(&1)))
    v2 = Enum.reduce(erange(0, c), v1, &(&2 |> set(&1, &1 + 10)))
    assert v1 |> count == v2 |> count

    Enum.each(erange(0, c), &(assert v1 |> get(&1) == ((v2 |> get(&1)) - 10)))
  end

  test "set root" do
    c = 20
    v1 = Enum.reduce(erange(0, c), empty(), &(&2 |> append(&1)))
    v2 = Enum.reduce(erange(0, c), v1, &(&2 |> set(&1, &1 + 10)))
    assert v1 |> count == v2 |> count

    Enum.each(erange(0, c), &(assert v1 |> get(&1) == ((v2 |> get(&1)) - 10)))

    assert_raise ArgumentError, "Attempt to set index 1 for vector of size 0", fn -> empty() |> set(1, 1) end
    assert_raise ArgumentError, "Attempt to set index \"bla\" for vector of size 0", fn -> empty() |> set("bla", 1) end
  end

  property "Equality" do
    let [n <- nat(), m <- choose(n + 1, 17_000)] do
      small = Enum.reduce(erange(0, n), empty(), &(&2 |> append(&1))) |> assert_element_identity()

      big = Enum.reduce(erange(0, m), empty(), &(&2 |> append(&1))) |> assert_element_identity()
      big = Enum.reduce(erange(n, m), big, fn _, v -> v |> remove_last() end) |> assert_element_identity()

      assert small |> count() == big |> count()
      ensure small == big
    end
  end

  property "Enumerable" do
    forall n <- nat() do
      v = Enum.reduce(erange(0, n), empty(), &(&2 |> append(&1))) |> assert_element_identity()
      assert (v |> Enum.into([])) == (erange(0, n) |> Enum.into([]))
      ls = v |> Enum.map(&(&1 + 1))
      assert ls |> Enum.count() == v |> count()
      erange(0, n) |> Enum.each(&(assert ls |> Enum.at(&1) == &1 + 1))
      assert Stream.zip(v, v) |> Enum.count() == v |> count()

      if n > 0 do
        assert v |> Enum.member?(0)
        assert v |> Enum.member?(n-1)
      end

      assert (empty() |> Enum.into([])) == []
    end
  end

  property "Enumerable.halt" do
    let [m <- nat(), n <- choose(m, 17_000)] do
      v = Enum.reduce(erange(0, n), empty(), &(&2 |> append(&1))) |> assert_element_identity()
      lt = v |> Enum.take(m)
      lt |> new() |> assert_element_identity()
      assert lt |> Enum.count() == m
    end
  end

  property "Collectable" do
    forall n <- choose(0, 1500) do
      v = erange(0, n) |> Enum.into(empty()) |> assert_element_identity()
      assert v |> count() == n
      assert (v |> Enum.into([])) == (erange(0, n) |> Enum.into([]))
      ls = v |> Enum.map(&(&1 + 1))
      assert ls |> Enum.count() == v |> count()
      erange(0, n) |> Enum.each(&(assert ls |> Enum.at(&1) == &1 + 1))
      assert v |> to_list() == v |> Enum.into([])

      if n > 0 do
        assert v |> Enum.member?(n-1)
        assert v |> Enum.member?(0)
      end

      mid = div(n, 2)
      v1 = erange(0, mid) |> Enum.into(empty()) |> assert_element_identity()
      erange(mid, n) |> Enum.into(v1) |> assert_element_identity()

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

    # "randomly" use different getters
    validation_fun =
      case rem(c, 4) do
        0 -> &(assert v |> get(&1) == &1)
        1 -> &(assert v[&1] == &1)
        2 -> &(assert v |> get(&1, :not_found) == &1)
        3 -> &(assert v |> fetch(&1) == {:ok, &1})
      end

    erange(0, c) |> Enum.each(validation_fun)

    if c > 0 do
      assert v |> last(:empty) == c - 1
      assert v |> last() == c - 1
    else
      assert v |> last(:empty) == :empty
      assert_raise ArgumentError, fn -> v |> last() end
    end

    v
  end
end
