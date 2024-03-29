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
@testset "inf, nan, and missing serializing" begin
    names = [:a, :b, :c, :d, :e]
    rows = Tables.table([NaN Inf -Inf 0 missing]; header=names)
    types = vcat([Float64 for _ in 1:4], [Missing])
    Base.show(io::IO, x::Missing) = print(io, "test_missing")
    schema = Tables.Schema(names, types)
    json = TableView.table2json(schema, Tables.rows(rows), types)
    firstrow = JSON.parse(json)[1]
    @test firstrow["a"] == "NaN"
    @test firstrow["b"] == "Inf"
    @test firstrow["c"] == "-Inf"
    @test firstrow["d"] == 0
    @test firstrow["e"] == "test_missing"
end
@testset "large integers" begin
    names = [:a, :b, :c]
    rows = Tables.table([2^52 2^53 2^54]; header=names)
    types = [Int64 for _ in 1:3]
    schema = Tables.Schema(names, types)
    json = TableView.table2json(schema, Tables.rows(rows), types)
    firstrow = JSON.parse(json)[1]
    @test firstrow["a"] == 4503599627370496
    @test firstrow["b"] == "9007199254740992"
    @test firstrow["c"] == "18014398509481984"
end
@testset "large floats" begin
    names = [:a, :b]
    rows = Tables.table([1.0e50 1.0e100]; header=names)
    types = [Float64, Float64]
    schema = Tables.Schema(names, types)
    json = TableView.table2json(schema, Tables.rows(rows), types)
    firstrow = JSON.parse(json)[1]
    @test firstrow["a"] == "1.0e50"
    @test firstrow["b"] == "1.0e100"
end
@testset "normal array" begin
    array = rand(10, 10)
    @test showtable(array) isa WebIO.Scope
end
