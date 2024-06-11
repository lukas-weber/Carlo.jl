# [ResultTools](@id result_tools)

This is a small module to ease importing Carlo results back into Julia. It contains the function

```@docs
Carlo.ResultTools.dataframe
```

If we use ResultTools with DataFrames.jl to read out the results of the Ising example, it would be the following.

```@example
using Plots
using DataFrames
using Carlo.ResultTools

df = DataFrame(ResultTools.dataframe("example.results.json"))

plot(df.T, df.Energy; xlabel = "Temperature", ylabel="Energy per spin", group=df.Lx, legendtitle="L")
```
In the plot we can nicely see how the model approaches the ground state energy at low temperatures.
