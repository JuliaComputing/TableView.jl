using TableView
using Test, WebIO

@test isfile(joinpath(@__DIR__, "..", "deps", "ag-grid", "ag-grid.js"))

nttable = [
    (a = 2.0, b = 3),
    (a = 3.0, b = 12)
]
@test showtable(nttable) isa WebIO.Scope
