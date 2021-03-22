version = readchomp(joinpath(@__DIR__, "..", "ag-grid.version"))
distribution = haskey(ENV, "AG_GRID_LICENSE_KEY") ? "enterprise" : "community"
println("building: distribution=$distribution version=$version")

isdir(joinpath(@__DIR__, "ag-grid-$(version)")) || mkdir(joinpath(@__DIR__, "ag-grid-$(version)"))

ag_grid_base = joinpath(@__DIR__, "ag-grid-$(version)", "ag-grid.js")
isfile(ag_grid_base) || download("https://cdn.jsdelivr.net/npm/ag-grid-$(distribution)@$(version)/dist/ag-grid-$(distribution).min.noStyle.js", ag_grid_base)

ag_grid_base_style = joinpath(@__DIR__, "ag-grid-$(version)", "ag-grid.css")
isfile(ag_grid_base_style) || download("https://cdn.jsdelivr.net/npm/ag-grid-$(distribution)@$(version)/dist/styles/ag-grid.css", ag_grid_base_style)

ag_grid_light = joinpath(@__DIR__, "ag-grid-$(version)", "ag-grid-light.css")
isfile(ag_grid_light) || download("https://cdn.jsdelivr.net/npm/ag-grid-$(distribution)@$(version)/dist/styles/ag-theme-balham.css", ag_grid_light)

ag_grid_dark = joinpath(@__DIR__, "ag-grid-$(version)", "ag-grid-dark.css")
isfile(ag_grid_dark) || download("https://cdn.jsdelivr.net/npm/ag-grid-$(distribution)@$(version)/dist/styles/ag-theme-balham-dark.css", ag_grid_dark)
