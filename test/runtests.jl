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
    fields = Array{Union{Missing, Nothing, Float64}}(NaN Inf -Inf 0 missing nothing)
    rows = Tables.table(fields)
    names = [:a, :b, :c, :d, :e, :f]
    types = vcat([Float64 for _ in 1:4], [Missing, Nothing])
    Base.show(io::IO, x::Missing) = print(io, "test_missing")
    Base.show(io::IO, x::Nothing) = print(io, "test_nothing")
    json = TableView.table2json(Tables.Schema(names, types), rows, types)
    firstrow = JSON.parse(json)[1]
    @test firstrow["a"] == "NaN"
    @test firstrow["b"] == "Inf"
    @test firstrow["c"] == "-Inf"
    @test firstrow["d"] == 0
    @test firstrow["e"] == "test_missing"
    @test firstrow["f"] == "test_nothing"
end
@testset "normal array" begin
    array = rand(10, 10)
    @test showtable(array) isa WebIO.Scope
end
