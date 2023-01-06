# [Random Number Generators](@id rng)

LoadLeveller takes care of storing and managing the state of random number generators (RNG) for you. It is accessible through the `rng` field of [`MCContext`](@ref)
and the type of RNG to use can be set by the `rng` parameter in every task (see [`TaskInfo`](@ref)).

The currently supported types are

- `Random.Xoshiro`
