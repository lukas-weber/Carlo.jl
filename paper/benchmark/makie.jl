using Measurements

default_theme() = Theme(
    figure_padding = 2,
    Axis = (xtickalign = 1, ytickalign = 1, xgridvisible = false, ygridvisible = false),
)


@recipe MeasPlot (x, y) begin
    errorcolor = @inherit markercolor
    MakieCore.documented_attributes(Scatter)...
end

function Makie.plot!(mp::MeasPlot{<:Tuple{AbstractVector,AbstractVector}})
    vals = @lift(Measurements.value.($(mp.y)))
    errs = @lift(Measurements.uncertainty.($(mp.y)))
    errorbars!(mp, mp.x, vals, errs, color = mp.errorcolor)
    scatter!(
        mp,
        mp.x,
        vals;
        marker = mp.marker,
        color = mp.color,
        strokecolor = mp.strokecolor,
        strokewidth = mp.strokewidth,
    )
    return mp
end

function Makie.legendelements(plot::MeasPlot, legend)
    LegendElement[
        LineElement(
            linepoints = [Point2f(0.5, 0), Point2f(0.5, 1)],
            color = plot.errorcolor,
        ),
        # MarkerElement(points = [Point2f(0.5, 0), Point2f(0.5, 1)], marker = :hline, markersize = 10),
        MarkerElement(
            points = [Point2f(0.5, 0.5)],
            marker = plot.marker,
            color = plot.color,
            strokecolor = plot.strokecolor,
            strokewidth = plot.strokewidth,
        ),
    ]
end
