# [Covariance estimation](@id covariance)

Carlo can estimate covariance matrices of observables. By default, this feature is disabled, but for tasks with the parameter `tm.estimate_covariance = true`, each array-valued observable and evaluable will get an additional `covariance` field in the `.results.json` file.

For scalar observables, this covariance field is always `nothing`. Covariances between different scalar (or array) observables can nevertheless be estimated by creating an array evaluable containing different observables as elements.

## Example for the Ising model

As an example where correlations become important, consider this job for the [Ising](https://github.com/lukas-weber/Ising.jl) reference implementation, which describes a model close to the critical point.

```@example
#!/usr/bin/env julia

using Carlo
using Carlo.JobTools
using Ising

tm = TaskMaker()
tm.sweeps = 10000
tm.thermalization = 2000
tm.binsize = 5

tm.Lx = 20
tm.Ly = 20

tm.estimate_covariance = true # enable covariance!

tm.T = 2.27
task(tm)

job = JobInfo(splitext(@__FILE__)[1], Ising.MC;
    checkpoint_time="30:00",
    run_time="15:00",
    tasks=make_tasks(tm)
)

start(dummy, dummy2) = nothing # hide
start(job, ARGS)
```

After running this job with `./covariance_job.jl run`, we extract the results using `Carlo.ResultTools`.

```@example correlation
using Plots
using DataFrames
using Carlo.ResultTools

df = DataFrame(ResultTools.dataframe("covariance_job.results.json"))

plot(df.SpinCorrelation[1]; xlabel = "x", ylabel = "Spin correlation C(x)")
```

Because we are close to the critical point, the correlation function decays slowly. When interpreting this data, e.g. using a fit, it is important to remember that the statistical fluctuations of the different values are not independent. They too, are highly correlated.

For each observable or evaluable that has a covariance matrix estimate, `ResultTools.dataframe` will create a new column of the form `*_cov`, containing the covariance matrix. If the observable itself is a matrix or a rank-``n`` tensor, the covariance matrix will be a rank-``2n`` tensor.

```@example correlation
heatmap(df.SpinCorrelation_cov[1]; xlabel = "C(x)", ylabel="C(x')", c = :Blues, rightmargin=5Plots.mm)
```
As we see, the statistical averages of the different components of the spin-spin correlation function are completely correlated. We can use the covariance matrix to account for this in further postprocessing.

Another application of the covariance matrix is the [control variates](https://en.wikipedia.org/wiki/Control_variates) method.

## Alternative approaches

Alternatively to measuring the covariance matrix, users may also choose to perform their own [bootstrapping](https://en.wikipedia.org/wiki/Bootstrapping_(statistics)) on the raw measurement data in the `.meas.h5` files.

## Autocorrelation time

When observables are strongly correlated, hidden autocorrelations can appear that are scrambled between different components. The resulting autocorrelation time may be underestimated by the standard estimator based on the rebinned error. When covariance estimation is enabled, Carlo will automatically use the covariance matrix to improve the estimate of the autocorrelation time by rotating to its eigenbasis:

```math
τ = \frac{1}{2} \max_i \left[Λ^{-\frac{1}{2}} U^\dagger Σ_{\overline{X}} U Λ^{-\frac{1}{2}} - 1\right]_{ii}
```

where ``Σ_{\overline{X}}`` is the covariance matrix of the mean of observable ``X`` (obtained from rebinning) and ``Σ_X = U Λ U^\dagger`` is the eigendecomposition of the covariance matrix of ``X`` without rebinning.

Just like without covariance estimation, this autocorrelation time is in units of the internal binsize. Furthermore, this estimator may still be inaccurate in cases where ``Σ_{\overline{X}}`` and ``Σ_{X}`` have very different eigenbases.
