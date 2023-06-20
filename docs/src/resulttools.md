# [ResultTools](@id result_tools)

This is a small module to ease importing LoadLeveller results back into Julia. It contains the function

```@docs
LoadLeveller.ResultTools.dataframe
```

An example of using ResultTools with DataFrames.jl would be the following.

```@example
using Plots
using DataFrames
using LoadLeveller.ResultTools

df = DataFrame(ResultTools.dataframe("example.results.json"))

plot(df.T, df.Energy)
```
