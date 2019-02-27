module TableView

using Tables
using WebIO, JSExpr, JSON, Dates, UUIDs
using Observables: @map

export showtable

const ag_grid_imports = []

function __init__()
    version = readchomp(joinpath(@__DIR__, "..", "ag-grid.version"))
    empty!(ag_grid_imports)
    for f in ["ag-grid.js", "ag-grid.css", "ag-grid-light.css", "ag-grid-dark.css"]
        push!(ag_grid_imports, normpath(joinpath(@__DIR__, "..", "deps", "ag-grid-$(version)", f)))
    end
end

to_css_size(s::AbstractString) = s
to_css_size(s::Real) = "$(s)px"

function showtable(table; dark = false, height = :auto, width = "100%")
    if !Tables.istable(typeof(table))
        throw(ArgumentError("Argument is not a table."))
    end

    tablelength = Base.IteratorSize(table) == Base.HasLength() ? length(Tables.rows(table)) : nothing

    if height === :auto
        height = 500
        if tablelength !== nothing
            # header + footer height ≈ 40px, 28px per row
            height = min(40 + tablelength*28, height)
        end
    end

    rows = Tables.rows(table)
    schema = Tables.schema(table)
    if schema === nothing
        types = []
        for (i, c) in enumerate(Tables.eachcolumn(first(rows)))
            push!(types, typeof(c))
        end
        names = collect(propertynames(first(rows)))
    else
        names = schema.names
        types = schema.types
    end
    w = Scope(imports = ag_grid_imports)

    coldefs = [(
                headerName = n,
                headerTooltip = types[i],
                field = n,
                type = types[i] <: Union{Missing, T where T <: Number} ? "numericColumn" : nothing,
                filter = types[i] <: Union{Missing, T where T <: Dates.Date} ? "agDateColumnFilter" :
                         types[i] <: Union{Missing, T where T <: Number} ? "agNumberColumnFilter" : nothing
               ) for (i, n) in enumerate(names)]

    id = string("grid-", string(uuid1())[1:8])
    w.dom = dom"div"(className = "ag-theme-balham$(dark ? "-dark" : "")",
                     style = Dict("width" => to_css_size(width),
                                  "height" => to_css_size(height)),
                     id = id)

    tablelength === nothing || tablelength > 10_000 ? _showtable_async!(w, names, types, rows, coldefs, tablelength, dark, id) :
                                                      _showtable_sync!(w, names, types, rows, coldefs, tablelength, dark, id)

    w
end

function _showtable_sync!(w, names, types, rows, coldefs, tablelength, dark, id)
    options = Dict(
        :rowData => JSONText(table2json(rows, names, types)),
        :columnDefs => coldefs,
        :enableSorting => true,
        :enableFilter => true,
        :enableColResize => true,
        :multiSortKey => "ctrl",
    )

    handler = @js function (agGrid)
        @var gridOptions = $options
        @var el = document.getElementById($id)
        this.table = @new agGrid.Grid(el, gridOptions)
        gridOptions.columnApi.autoSizeColumns($names)
    end
    onimport(w, handler)
end


function _showtable_async!(w, names, types, rows, coldefs, tablelength, dark, id)
    rowparams = Observable(w, "rowparams", Dict("startRow" => 1,
                                                "endRow" => 100,
                                                "successCallback" => @js v -> nothing))
    requestedrows = Observable(w, "requestedrows", JSONText("{}"))
    on(rowparams) do x
        requestedrows[] = JSONText(table2json(rows, names, types, requested = [x["startRow"], x["endRow"]]))
    end

    onjs(requestedrows, @js function (val)
        ($rowparams[]).successCallback(val, $(tablelength))
    end)

    options = Dict(
        :columnDefs => coldefs,
        # can't sort or filter asynchronously loaded data without backend support,
        # which we don't have yet
        :enableSorting => false,
        :enableFilter => false,
        :maxConcurrentDatasourceRequests => 1,
        :cacheBlockSize => 1000,
        :maxBlocksInCache => 100,
        :enableColResize => true,
        :multiSortKey => "ctrl",
        :rowModelType => "infinite",
        :datasource => Dict(
            "getRows" =>
                @js function (rowParams)
                    $rowparams[] = rowParams
                end
            ,
            "rowCount" => tablelength
        )
    )

    handler = @js function (agGrid)
        @var gridOptions = $options
        @var el = document.getElementById($id)
        this.table = @new agGrid.Grid(el, gridOptions)
        gridOptions.columnApi.autoSizeColumns($names)
    end
    onimport(w, handler)
end

# directly write JSON instead of allocating temporary dicts etc
function table2json(rows, names, types; requested = nothing)
    io = IOBuffer()
    print(io, '[')
    for (i, row) in enumerate(rows)
        if requested == nothing || first(requested) <= i <= last(requested)
            print(io, '{')
            i = 1
            for col in Tables.eachcolumn(row)
                JSON.print(io, names[i])
                i += 1
                print(io, ':')
                if col isa Number
                    JSON.print(io, col)
                else
                    JSON.print(io, sprint(print, col))
                end
                print(io, ',')
            end
            skip(io, -1)
            print(io, '}')
            print(io, ',')
        end
    end
    skip(io, -1)
    print(io, ']')

    String(take!(io))
end
end
