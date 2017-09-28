# Benchmarks

## Running

* Quick run: `mix run bench/bench.exs`
* Full run: `mix run bench/bench.exs full`

## Benchmarking Summary

Perf-wise, the sweet spot for `PersistentVector` is scenarios when vector needs to be built by repeatedly appending to the end **AND** random-access (`get`/`set`  operations) are also used.

If *random-access* after building is not required, then building and reversing a `List` is more efficient.

If building speed is not important, but removal from the end happens often, then Erlang's `:array` shows better performance.

`get`/`set` operations perform similar to `:array`:
* `PersistentVector.get/2` is slightly faster for *larger* collections compared to `:array`.
* `PersistentVector.set/3` is slightly faster for *smaller* collections compared to `:array`.

## Future Perf Improvements

This is a first version and no perf-tuning has been done so far.

The speed of building from `enumerable` can be further improved by reading input in 32-element chunks and appending them directly to `root` bypassing `tail`.

## Raw Benchmarking results for v0.1.0

```none
Using 2 inputs

#
# Build
#

##### With input     1'000 #####
Name                   ips        average  deviation         median
List   Build       41.33 K       24.19 μs    ±32.16%       31.00 μs
Vector Build        9.18 K      108.99 μs    ±65.96%      150.00 μs
Array  Build        4.41 K      226.61 μs    ±34.41%      160.00 μs

Comparison:
List   Build       41.33 K
Vector Build        9.18 K - 4.50x slower
Array  Build        4.41 K - 9.37x slower

##### With input 1'000'000 #####
Name                   ips        average  deviation         median
List   Build         13.76       72.70 ms    ±10.24%       78.00 ms
Vector Build          5.76      173.48 ms     ±5.75%      172.00 ms
Array  Build          1.65      607.53 ms     ±1.94%      609.00 ms

Comparison:
List   Build         13.76
Vector Build          5.76 - 2.39x slower
Array  Build          1.65 - 8.36x slower

#
# Shrink
#

##### With input     1'000 #####
Name                         ips        average  deviation         median
Array  resize            14.73 K       67.89 μs    ±10.95%       63.00 μs
Vector remove_last        7.55 K      132.49 μs    ±42.49%      160.00 μs

Comparison:
Array  resize            14.73 K
Vector remove_last        7.55 K - 1.95x slower

##### With input 1'000'000 #####
Name                         ips        average  deviation         median
Array  resize              13.36       74.86 ms     ±8.55%       78.00 ms
Vector remove_last          6.25      159.97 ms     ±4.19%      156.00 ms

Comparison:
Array  resize              13.36
Vector remove_last          6.25 - 2.14x slower

#
# Get
#

##### With input     1'000 #####
Name                 ips        average  deviation         median
Vector Get        7.68 K      130.20 μs    ±44.88%      160.00 μs
Array  Get        7.36 K      135.89 μs    ±38.84%      160.00 μs

Comparison:
Vector Get        7.68 K
Array  Get        7.36 K - 1.04x slower

##### With input 1'000'000 #####
Name                 ips        average  deviation         median
Vector Get          5.86      170.54 ms     ±2.53%      172.00 ms
Array  Get          4.13      242.19 ms     ±3.23%      242.50 ms

Comparison:
Vector Get          5.86
Array  Get          4.13 - 1.42x slower

#
# Set
#

##### With input     1'000 #####
Name                 ips        average  deviation         median
Vector Set        4.40 K      227.12 μs    ±34.31%      160.00 μs
Array  Set        3.38 K      295.90 μs    ±16.25%      310.00 μs

Comparison:
Vector Set        4.40 K
Array  Set        3.38 K - 1.30x slower

##### With input 1'000'000 #####
Name                 ips        average  deviation         median
Array  Set          1.44      694.80 ms     ±2.17%      688.00 ms
Vector Set          1.24      807.69 ms     ±2.32%      813.00 ms

Comparison:
Array  Set          1.44
Vector Set          1.24 - 1.16x slower
```
