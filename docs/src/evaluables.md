# [Evaluables](@id evaluables)

In addition to simply calculating the averages of some observables in your Monte Carlo simulations, sometimes you are also interested in quantities that are functions of these observables, such as the Binder cumulant which is related to the ratio of moments of the magnetization.

This presents two problems. First, estimating the errors of such quantities is not trivial due to correlations. Second, simply computing functions of quantities with errorbars incurs a bias.

Luckily, Carlo can help you with this by letting you define such quantities – we call them *evaluables* – in the [`Carlo.register_evaluables(YourMC, eval, params)`](@ref) function.

This function gets an `Evaluator` which can be used to

```@docs
evaluate!
```

## Example

This is an example for a `register_evaluables` implementation for a model of a magnet.

```@example
using Carlo
struct YourMC <: AbstractMC end # hide

function Carlo.register_evaluables(
    ::Type{YourMC},
    eval::Evaluator,
    params::AbstractDict,
)

    T = params[:T]
    Lx = params[:Lx]
    Ly = get(params, :Ly, Lx)
    
    evaluate!(eval, :Susceptibility, (:Magnetization2,)) do mag2
        return Lx * Ly * mag2 / T
    end

    evaluate!(eval, :BinderRatio, (:Magnetization2, :Magnetization4)) do mag2, mag4
        return mag2 * mag2 / mag4
    end

    return nothing
end
```

Note that this code is called after the simulation is over, so there is no way to access the simulation state. However, it is possible to get the needed information about the system (e.g. temperature, system size) from the task parameters `params`.

