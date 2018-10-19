module TableView
using Tables, WebIO, JSExpr, JSON, Dates

function showtable(x; dark = false)
    w = Scope(imports=["https://unpkg.com/ag-grid-community/dist/ag-grid-community.min.noStyle.js",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-grid.css",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-theme-balham$(dark ? "-dark" : "").css",])

    schema = Tables.schema(x)
    names = schema.names
    types = schema.types

    coldefs = [(
                    headerName = n,
                    field = n,
                    type = types[i] <: Union{Missing, T where T <: Number} ? "numericColumn" : nothing,
                    filter = types[i] <: Union{Missing, T where T <: Dates.Date} ? "agDateColumnFilter" :
                             types[i] <: Union{Missing, T where T <: Number} ? "agNumberColumnFilter" : nothing
               ) for (i, n) in enumerate(names)]

    options = Dict(
        :rowData => table2json(x),
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
                          style=Dict(:position => "absolute",
                                     :top => "0",
                                     :left => "0",
                                     :width => "100%",
                                     :height => "100%",
                                     :minHeight => "200px"))
    w
end

# directly write JSON instead of allocating temporary dicts etc
function table2json(table)
    names = Tables.schema(table).names

    io = IOBuffer()
    print(io, '[')
    for row in Tables.rows(table)
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
