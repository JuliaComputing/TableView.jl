module TableView
using Tables, TableTraits, IteratorInterfaceExtensions
using WebIO, JSExpr, JSON, Dates
using Observables: @map

function showtable(x; dark = false)
    iit = TableTraits.isiterabletable(x)
    if Tables.istable(typeof(x))
        return _showtable(x, dark)
    elseif ismissing(iit) || iit
        it = IteratorInterfaceExtensions.getiterator(x)
        return _showtable(Tables.DataValueUnwrapper(it), dark)
    end
    throw(ArgumentError("Argument is not a table."))
end

function _showtable(table, dark)
    tablelength = Base.IteratorSize(table) == Base.HasLength() ? length(Tables.rows(table)) : nothing

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
    w = Scope(imports=["https://unpkg.com/ag-grid-community/dist/ag-grid-community.min.noStyle.js",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-grid.css",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-theme-balham$(dark ? "-dark" : "").css",])

    coldefs = [(
                headerName = n,
                headerTooltip = types[i],
                field = n,
                type = types[i] <: Union{Missing, T where T <: Number} ? "numericColumn" : nothing,
                filter = types[i] <: Union{Missing, T where T <: Dates.Date} ? "agDateColumnFilter" :
                         types[i] <: Union{Missing, T where T <: Number} ? "agNumberColumnFilter" : nothing
               ) for (i, n) in enumerate(names)]

    tablelength === nothing || tablelength > 10_000 ? _showtable_async!(w, names, types, rows, coldefs, tablelength, dark) :
                                                      _showtable_sync!(w, names, types, rows, coldefs, tablelength, dark)

    w.dom = dom"div#grid"(className = "ag-theme-balham$(dark ? "-dark" : "")",
                          style = Dict("width" => "100%",
                                     "min-width" => "400px",
                                     "height" => "800px"))
    w
end

function _showtable_sync!(w, names, types, rows, coldefs, tablelength, dark)
    options = Dict(
        :rowData => table2json(rows, names, types),
        :columnDefs => coldefs,
        :enableSorting => true,
        :enableFilter => true,
        :enableColResize => true,
        :multiSortKey => "ctrl",
    )

    handler = @js function (agGrid)
        @var gridOptions = $options
        gridOptions.rowData = JSON.parse(gridOptions.rowData)
        this.table = @new agGrid.Grid(this.dom.querySelector("#grid"), gridOptions)
        gridOptions.columnApi.autoSizeColumns($names)
    end
    onimport(w, handler)
end


function _showtable_async!(w, names, types, rows, coldefs, tablelength, dark)
    rowparams = Observable(w, "rowparams", Dict("startRow" => 1,
                                                "endRow" => 100,
                                                "successCallback" => @js v -> nothing))
    requestedrows = Observable(w, "requestedrows", "")
    on(rowparams) do x
        requestedrows[] = table2json(rows, names, types, requested = [x["startRow"], x["endRow"]])
    end

    onjs(requestedrows, @js function (val)
        ($rowparams[]).successCallback(JSON.parse(val), $(tablelength))
    end)

    options = Dict(
        :columnDefs => coldefs,
        :enableSorting => true,
        :enableFilter => true,
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
        this.table = @new agGrid.Grid(this.dom.querySelector("#grid"), gridOptions)
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
