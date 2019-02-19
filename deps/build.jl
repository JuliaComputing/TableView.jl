isdir(joinpath(@__DIR__, "ag-grid")) || mkdir(joinpath(@__DIR__, "ag-grid"))

ag_grid_base = joinpath(@__DIR__, "ag-grid", "ag-grid.js")
isfile(ag_grid_base) || download("https://unpkg.com/ag-grid-community/dist/ag-grid-community.min.noStyle.js", ag_grid_base)

ag_grid_base_style = joinpath(@__DIR__, "ag-grid", "ag-grid.css")
isfile(ag_grid_base_style) || download("https://unpkg.com/ag-grid-community/dist/styles/ag-grid.css", ag_grid_base_style)

ag_grid_light = joinpath(@__DIR__, "ag-grid", "ag-grid-light.css")
isfile(ag_grid_light) || download("https://unpkg.com/ag-grid-community/dist/styles/ag-theme-balham.css", ag_grid_light)

ag_grid_dark = joinpath(@__DIR__, "ag-grid", "ag-grid-dark.css")
isfile(ag_grid_dark) || download("https://unpkg.com/ag-grid-community/dist/styles/ag-theme-balham-dark.css", ag_grid_dark)
