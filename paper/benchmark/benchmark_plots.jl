using CairoMakie
using MakieCore
using DelimitedFiles
using DataFrames
using LaTeXStrings
using Carlo.ResultTools
using HDF5
using JSON
using StatsBase
using Printf
import Plots
import Measurements: value, uncertainty

include("makie.jl")

function plots_defaults()
    Plots.default(
        linewidth = 2,
        framestyle = :box,
        size = (390, 280),
        label = nothing,
        grid = false,
        markerstrokecolor = :black,
        thickness_scaling = 1,
        tickfontsize = 8,
        lw = 2,
        legendfontsize = 8,
        legendtitlefontsize = 10,
        labelfontsize = 8,
        palette = Plots.palette(Makie.wong_colors()),
    )
end


function plot_example()
    df = DataFrame(ResultTools.dataframe("data/example_job.results.json"))

    plots_defaults()
    Plots.plot(
        df.T,
        df.BinderRatio;
        xlabel = "Temperature",
        ylabel = "Binder ratio",
        group = df.Lx,
        legendtitle = "L",
    )
    Plots.savefig("../figs/binder_ratio.pdf")
end

function plot_scaling()
    data = readdlm("data/benchmark.dat", ',')

    set_theme!(default_theme())
    fig = Figure(size = (390, 280))
    ax = Axis(
        fig[1, 1],
        xscale = log10,
        yscale = log10,
        xlabel = "Number of CPUs",
        ylabel = "Runtime (seconds)",
    )


    scatter!(ax, data[:, 1], data[:, 2])
    lines!(ax, data[:, 1], data[end, 2] * data[end, 1] ./ data[:, 1])
    save("../figs/scaling.pdf", fig, pt_per_unit = 0.625)
    fig
end

function plot_stats()
    set_theme!(default_theme())
    data = DataFrame(ResultTools.dataframe("data/error_bench.results.json"))


    fig = Figure(size = (600, 280))

    ax1 = Axis(fig[1, 1], xlabel = "Energy per spin", ylabel = "Probability density")
    ax2 = Axis(fig[1, 2], xlabel = "Binder ratio")
    plot_stats!(ax1, data.Energy)
    plot_stats!(ax2, data.BinderRatio)
    hideydecorations!(ax2, ticks = false)
    linkyaxes!(ax1, ax2)
    axislegend(ax2, position = (1, 0.8))

    ax3 = Axis(
        fig[1, 3],
        xlabel = "MC sweeps",
        ylabel = "Energy Autocorrelation",
        yticks = (
            [0, exp(-1), 0.5, 1],
            ["0.0", L"\fontfamily{TeXGyreHeros}e^{-1}", "0.5", "1.0"],
        ),
    )
    plot_autocorr!(ax3, expanduser("~/ceph/carlo/error_bench"), "Energy")

    text!(
        ax1,
        0.02,
        1,
        text = "(a)",
        font = :bold,
        align = (:left, :top),
        space = :relative,
    )
    text!(
        ax2,
        0.02,
        1,
        text = "(b)",
        font = :bold,
        align = (:left, :top),
        space = :relative,
    )
    text!(
        ax3,
        0.02,
        1,
        text = "(c)",
        font = :bold,
        align = (:left, :top),
        space = :relative,
    )
    # Legend(fig[1,2, Top()], ax2, orientation = :horizontal, framevisible=false)

    # text!(ax2, 0.5, 0.75, space=:relative, align=(:center, :center), justification=:center, text = "T = 2.3\nL = 20")

    save("../figs/stats.pdf", fig, pt_per_unit = 0.625)
    fig
end

function plot_stats!(ax, obs)
    ens_mean = mean(value.(obs))
    ens_std = mean(uncertainty.(obs))

    xlims = ens_mean .+ (-4, 4) .* ens_std
    hist!(ax, value.(obs), normalization = :pdf, label = "Repeated\nruns")

    gauss(x) = 1 / sqrt(2π * ens_std^2) * exp(-abs2(x .- ens_mean) / (2ens_std^2))

    xs = range(xlims..., 100)
    lines!(ax, xs, gauss.(xs), color = :black, label = "Binning\nanalysis")
    xlims!(ax, xlims)
    ylims!(ax, (0, 51))
    ax
end

function generate_autocorr()
    path = expanduser("~/ceph/carlo/error_bench")
    obsname = "Energy"

    xs = 0:10000
    corrs = reduce(
        hcat,
        autocor(
            h5read(
                "$path.data/task$(@sprintf("%04d",i))/run0001.meas.h5",
                "observables/$obsname/samples",
            ),
            xs,
        ) for i = 1:9000
    )

    h5open("data/error_bench_autocorr.h5", "w") do file
        file["/energy_autocorr", chunk = (100, 100), shuffle = (), deflate = 3] = corrs
    end
end

function plot_autocorr!(ax, path, obsname)
    json = JSON.parsefile(path * ".results.json"; allownan = true)

    autocorrs = map(x -> x["results"][obsname]["autocorr_time"], json)

    data = h5read("data/error_bench_autocorr.h5", "/energy_autocorr")

    autocorr_fun = mean(data, dims = 2)

    xs = 0:300
    hlines!(ax, exp(-1), color = :black, linewidth = 1, linestyle = :dash)
    lines!(ax, autocorr_fun[xs.+1, 1])

    str_mean = @sprintf(
        "%.2f(%1d)",
        mean(autocorrs),
        100 * std(autocorrs) / sqrt(length(autocorrs))
    )
    text!(ax, 40, 0.39, text = L"\fontfamily{TeXGyreHeros}τ_\mathrm{auto} = %$(str_mean)")
    vlines!(ax, mean(autocorrs), color = :black)
    ylims!(ax, -0.05, 1.1)

    xlims!(ax, -30, 300)
end

function plot_language_comparison()
    set_theme!(default_theme())
    julia_data = DataFrame(ResultTools.dataframe("data/ffb.results.json"))
    cpp_data = DataFrame(ResultTools.dataframe("data/ffb_frust.results.json"))

    fig = Figure(size = (390, 280))
    ax = Axis(
        fig[1, 1],
        xlabel = L"Inverse temperature $\fontfamily{TeXGyreHeros}J/T$",
        ylabel = "Time per sweep (ms)",
    )

    colors = Makie.wong_colors()[1:2]

    plot!(
        ax,
        1 ./ cpp_data.T,
        color = colors[2],
        marker = :rect,
        value.(1000 * cpp_data._ll_sweep_time),
        label = "sweep (C++)",
    )
    plot!(
        ax,
        1 ./ julia_data.T,
        color = colors[1],
        marker = :circle,
        value.(1000 * julia_data._ll_sweep_time),
        label = "sweep (Julia)",
    )
    plot!(
        ax,
        1 ./ cpp_data.T,
        strokewidth = 1,
        strokecolor = colors[2],
        color = :white,
        marker = :rect,
        value.(1000 * cpp_data._ll_measurement_time),
        label = "measure (C++)",
    )
    plot!(
        ax,
        1 ./ julia_data.T,
        strokewidth = 1,
        strokecolor = colors[1],
        color = :white,
        marker = :circle,
        value.(1000 * julia_data._ll_measure_time),
        label = "measure (Julia)",
    )
    ylims!(ax, -0.4, 10.99)

    axislegend(ax, position = :lt)
    save("../figs/language_comparison.pdf", fig, pt_per_unit = 0.625)
    return fig
end

function plot_banivo()
    df = DataFrame(ResultTools.dataframe("data/bani2v2o8.results.json"))

    df.L = [lattice["size"][1] for lattice in df.lattice]
    plots_defaults()

    p = Plots.plot(
        df.T,
        df.MagChi,
        group = df.L,
        xlabel = L"Temperature $T/J$",
        ylabel = L"Magnetic susceptibility $χ^z J$",
        legend_title = "L",
    )

    Plots.savefig("../figs/bani2v2o8.pdf")
end

function plot_parallel_tempering()
    df2 = filter(
        :Lx => ==(64),
        DataFrame(ResultTools.dataframe("data/parallel_tempering_comparison.results.json")),
    )
    df = filter(
        :Lx => ==(64),
        DataFrame(ResultTools.dataframe("data/parallel_tempering.results.json")),
    )


    set_theme!(default_theme())
    fig = Figure(size = (390, 280))
    ax = Axis(
        fig[1, 1],
        ylabel = L"\fontfamily{TeXGyreHeros}Specific Heat $C$",
        xlabel = L"Temperature $\fontfamily{TeXGyreHeros}T/J$",
    )

    Ts = df.parallel_tempering[1]["values"]

    measplot!(ax, df2.T, df2.SpecificHeat, label = "no parallel tempering")

    for (L, SpecificHeat) in zip(df.Lx, df.SpecificHeat)
        measplot!(ax, Ts, SpecificHeat, label = "parallel tempering", marker = :rect)
    end

    axislegend(ax)

    save("../figs/parallel_tempering.pdf", fig, pt_per_unit = 0.625)

end
