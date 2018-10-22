module TableView
using Tables, TableTraits, IteratorInterfaceExtensions
using WebIO, JSExpr, JSON, Dates

function showtable(x; dark = false)
    if Tables.istable(typeof(x))
        return _showtable(x, dark)
    elseif TableTraits.isiterabletable(x)
        it = IteratorInterfaceExtensions.getiterator(x)
        return _showtable(Tables.DataValueUnwrapper(it), dark)
    end
    throw(ArgumentError("Argument is not a table."))
end

function _showtable(table, dark)
    schema = Tables.schema(table)
    names = schema.names
    types = schema.types
    rows = Tables.rows(table)

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

    options = Dict(
        :rowData => table2json(rows, names, types),
        :columnDefs => coldefs,
        :enableSorting => true,
        :enableFilter => true,
        :enableColResize => true,
        :multiSortKey => "ctrl"
    )

    handler = @js function (agGrid)
        gridOptions = $options
        gridOptions.rowData = JSON.parse(gridOptions.rowData)
        this.table = @new agGrid.Grid(this.dom.querySelector("#grid"), gridOptions)
        gridOptions.columnApi.autoSizeColumns($names)
    end
    onimport(w, handler)
    w.dom = dom"div#grid"(className = "ag-theme-balham$(dark ? "-dark" : "")",
                          style=Dict(:width => "100%",
                                     "min-width" => "400px",
                                     :height => "800px"))
    w
end

# directly write JSON instead of allocating temporary dicts etc
function table2json(rows, names, types)
    io = IOBuffer()
    print(io, '[')
    for row in rows
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
    skip(io, -1)
    print(io, ']')

    String(take!(io))
end
end
