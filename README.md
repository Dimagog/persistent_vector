# Persistent Vector for Elixir
[![hex.pm version](https://img.shields.io/hexpm/v/persistent_vector.svg)](https://hex.pm/packages/persistent_vector)
[![license](https://img.shields.io/hexpm/l/persistent_vector.svg)](LICENSE.md)

## Installation

Add `persistent_vector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
[
  {:persistent_vector, "~> 0.1.0"}
]
end
```

## Description

`PersistentVector` is an array-like collection of values indexed by contiguous 0-based integer index.

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

## More info

See [Full Documentation](https://hexdocs.pm/persistent_vector)

See [Benchmarks](https://hexdocs.pm/persistent_vector/benchmarks.html)
