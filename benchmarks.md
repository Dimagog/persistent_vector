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

`Map` is added only for a baseline. In a sense that if `Map` was to outperform `PersistentVector` then this library would not be needed.
This comparison is *not fair* to `Map` as it has much richer capabilities.
The fact that `Map` performs worse for bigger collections is not surprising and is not `Map`'s fault :-).

## Raw Benchmarking results for v0.1.3

```none
Using 2 inputs

#
# Build
#

##### With input     1'000 #####
Name                   ips        average  deviation         median
List   Build       41.43 K       24.13 μs    ±32.24%       31.00 μs
Vector Build        9.25 K      108.15 μs    ±66.78%      150.00 μs
Map    Build        4.60 K      217.59 μs    ±35.13%      160.00 μs
Array  Build        4.42 K      226.07 μs    ±34.40%      160.00 μs

Comparison:
List   Build       41.43 K
Vector Build        9.25 K - 4.48x slower
Map    Build        4.60 K - 9.02x slower
Array  Build        4.42 K - 9.37x slower

##### With input 1'000'000 #####
Name                   ips        average  deviation         median
List   Build         14.06       71.15 ms    ±10.85%       78.00 ms
Vector Build          5.77      173.22 ms     ±5.30%      172.00 ms
Array  Build          1.66      602.94 ms     ±1.61%      609.00 ms
Map    Build          0.99     1007.80 ms     ±1.97%     1007.50 ms

Comparison:
List   Build         14.06
Vector Build          5.77 - 2.43x slower
Array  Build          1.66 - 8.47x slower
Map    Build          0.99 - 14.16x slower

#
# Shrink
#

##### With input     1'000 #####
Name                         ips        average  deviation         median
Array  resize            13.96 K       71.65 μs    ±11.36%       78.00 μs
Vector remove_last        6.91 K      144.74 μs    ±36.61%      160.00 μs
Map    resize             4.05 K      246.67 μs    ±31.47%      310.00 μs

Comparison:
Array  resize            13.96 K
Vector remove_last        6.91 K - 2.02x slower
Map    resize             4.05 K - 3.44x slower

##### With input 1'000'000 #####
Name                         ips        average  deviation         median
Array  resize              13.10       76.34 ms     ±7.94%       78.00 ms
Vector remove_last          6.14      162.81 ms     ±5.01%      157.00 ms
Map    resize               1.05      950.27 ms     ±3.57%      937.00 ms

Comparison:
Array  resize              13.10
Vector remove_last          6.14 - 2.13x slower
Map    resize               1.05 - 12.45x slower

#
# Get
#

##### With input     1'000 #####
Name                 ips        average  deviation         median
Map    Get       15.58 K       64.20 μs   ±119.83%         0.0 μs
Vector Get        7.68 K      130.25 μs    ±44.82%      160.00 μs
Array  Get        7.37 K      135.70 μs    ±39.04%      160.00 μs

Comparison:
Map    Get       15.58 K
Vector Get        7.68 K - 2.03x slower
Array  Get        7.37 K - 2.11x slower

##### With input 1'000'000 #####
Name                 ips        average  deviation         median
Vector Get          5.85      171.08 ms     ±2.05%      172.00 ms
Array  Get          4.14      241.81 ms     ±3.23%      235.00 ms
Map    Get          3.14      318.84 ms     ±6.58%      312.00 ms

Comparison:
Vector Get          5.85
Array  Get          4.14 - 1.41x slower
Map    Get          3.14 - 1.86x slower

#
# Set
#

##### With input     1'000 #####
Name                 ips        average  deviation         median
Map    Set        4.58 K      218.36 μs    ±35.04%      160.00 μs
Vector Set        4.36 K      229.54 μs    ±33.97%      160.00 μs
Array  Set        3.35 K      298.54 μs    ±15.06%      310.00 μs

Comparison:
Map    Set        4.58 K
Vector Set        4.36 K - 1.05x slower
Array  Set        3.35 K - 1.37x slower

##### With input 1'000'000 #####
Name                 ips        average  deviation         median
Array  Set          1.41      708.33 ms     ±3.22%      703.00 ms
Vector Set          1.18      849.00 ms     ±2.85%      844.00 ms
Map    Set          0.80     1253.88 ms     ±3.92%     1234.00 ms

Comparison:
Array  Set          1.41
Vector Set          1.18 - 1.20x slower
Map    Set          0.80 - 1.77x slower

#
# Enumerate
#

##### With input     1'000 #####
Name                       ips        average  deviation         median
Vector Enumerate       17.19 K       58.17 μs    ±12.08%       62.00 μs
Map    Enumerate       14.01 K       71.36 μs    ±10.89%       78.00 μs

Comparison:
Vector Enumerate       17.19 K
Map    Enumerate       14.01 K - 1.23x slower

##### With input 1'000'000 #####
Name                       ips        average  deviation         median
Vector Enumerate         15.60       64.10 ms     ±7.92%       63.00 ms
Map    Enumerate          8.07      123.84 ms    ±15.47%      125.00 ms

Comparison:
Vector Enumerate         15.60
Map    Enumerate          8.07 - 1.93x slower

#
# to_list
#

##### With input     1'000 #####
Name                     ips        average  deviation         median
Array  to_list       65.50 K       15.27 μs    ±18.44%       16.00 μs
Map    to_list       55.73 K       17.94 μs    ±31.20%       16.00 μs
Vector into          17.06 K       58.61 μs   ±129.18%         0.0 μs
Map    into          13.31 K       75.14 μs   ±104.00%         0.0 μs
Vector to_list        9.26 K      108.02 μs     ±4.11%      109.00 μs

Comparison:
Array  to_list       65.50 K
Map    to_list       55.73 K - 1.18x slower
Vector into          17.06 K - 3.84x slower
Map    into          13.31 K - 4.92x slower
Vector to_list        9.26 K - 7.08x slower

##### With input 1'000'000 #####
Name                     ips        average  deviation         median
Array  to_list         53.27       18.77 ms    ±36.93%       16.00 ms
Map    to_list         26.62       37.57 ms    ±57.36%       31.00 ms
Vector into            10.97       91.19 ms    ±13.77%       94.00 ms
Map    into             8.33      119.98 ms     ±6.39%      125.00 ms
Vector to_list          6.31      158.49 ms     ±3.92%      156.00 ms

Comparison:
Array  to_list         53.27
Map    to_list         26.62 - 2.00x slower
Vector into            10.97 - 4.86x slower
Map    into             8.33 - 6.39x slower
Vector to_list          6.31 - 8.44x slower
```
