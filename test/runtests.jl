using TableView
using Test, WebIO

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
@testset "normal array" begin
    array = rand(10, 10)
    @test showtable(array) isa WebIO.Scope
end
