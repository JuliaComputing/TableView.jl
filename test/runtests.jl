using TableView
using Test, WebIO, Tables, JSON

@testset "installation" begin
    version = readchomp(joinpath(@__DIR__, "..", "ag-grid.version"))
    @test isfile(joinpath(@__DIR__, "..", "deps", "ag-grid-$(version)", "ag-grid.js"))
end
@testset "named tuple table" begin
    nttable = [
        (a = 2.0, b = 3),
        (a = 3.0, b = 12)
    ]
    @test showtable(nttable) isa WebIO.Scope
end
@testset "named tuple table with missing and nothing" begin
    nttable = [
        (a = 2.0, b = 3, c = missing),
        (a = 3.0, b = 12, c = nothing)
    ]
    @test showtable(nttable) isa WebIO.Scope
end
@testset "inf and nan serializing" begin
    rows = Tables.table([NaN Inf -Inf 0])
    names = [:a, :b, :c, :d, :e, :f]
    types = [Float64 for _ in 1:6]
    json = TableView.table2json(rows, names, types)
    firstrow = JSON.parse(json)[1]
    @test firstrow["a"] == "NaN"
    @test firstrow["b"] == "Inf"
    @test firstrow["c"] == "-Inf"
    @test firstrow["d"] == 0
end
@testset "normal array" begin
    array = rand(10, 10)
    @test showtable(array) isa WebIO.Scope
end
