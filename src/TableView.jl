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

struct IteratorAndFirst{F, T}
    first::F
    source::T
    len::Int
    function IteratorAndFirst(x)
        len = Base.haslength(x) ? length(x) : 0
        first = iterate(x)
        return new{typeof(first), typeof(x)}(first, x, len)
    end
    function IteratorAndFirst(first, x)
        len = Base.haslength(x) ? length(x) + 1 : 1
        return new{typeof(first), typeof(x)}(first, x, len)
    end
end
Base.IteratorSize(::Type{IteratorAndFirst{F, T}}) where {F, T} = Base.IteratorSize(T)
Base.length(x::IteratorAndFirst) = x.len
Base.IteratorEltype(::Type{IteratorAndFirst{F, T}}) where {F, T} = Base.IteratorEltype(T)
Base.eltype(x::IteratorAndFirst) = eltype(x.source)
Base.iterate(x::IteratorAndFirst) = x.first
function Base.iterate(x::IteratorAndFirst, st)
    st === nothing && return nothing
    return iterate(x.source, st)
end

showtable(table::AbstractMatrix; kwargs...) = showtable(Tables.table(table); kwargs...)

"""
    showtable(table; dark = false, height = :auto, width = "100%", cell_changed = nothing)

Return a `WebIO.Scope` that displays the provided `table`.

Optional arguments:
  - `dark`: Switch to a dark theme.
  - `height`/`width`: CSS attributes specifying the output height and with.
  - `cell_changed`: Either `nothing` or a function that takes a single argument with the fields
                    `"new"`, `"old"`, `"row"`, and `"col"`. This function is called whenever the
                    user edits a table field. Note that all values will be strings, so you need to
                    do the necessary conversions yourself.
"""
function showtable(table; dark = false, height = :auto, width = "100%", cell_changed = nothing)
    rows = Tables.rows(table)
    tablelength = Base.IteratorSize(rows) == Base.HasLength() ? length(rows) : nothing

    if height === :auto
        height = 500
        if tablelength !== nothing
            # header + footer height ≈ 40px, 28px per row
            height = min(40 + tablelength*28, height)
        end
    end

    schema = Tables.schema(rows)
    if schema === nothing
        st = iterate(rows)
        rows = IteratorAndFirst(st, rows)
        names = Symbol[]
        types = []
        if st !== nothing
            row = st[1]
            for nm in propertynames(row)
                push!(names, nm)
                push!(types, typeof(getproperty(row, nm)))
            end
        else
            # no schema and no rows
        end
    else
        names = schema.names
        types = schema.types
    end

    async = tablelength === nothing || tablelength > 10_000

    w = Scope(imports = ag_grid_imports)

    onCellValueChanged = @js function () end
    if cell_changed != nothing
        onedit = Observable(w, "onedit", Dict{Any,Any}(
                                                "row" => 0,
                                                "col" => 0,
                                                "old" => 0,
                                                "new" => 0
                                              ))
        on(onedit) do x
            cell_changed(x)
        end

        onCellValueChanged = @js function (ev)
            $onedit[] = Dict(
                                "row" => ev.rowIndex,
                                "col" => ev.colDef.headerName,
                                "old" => ev.oldValue,
                                "new" => ev.newValue
                            )
        end
    end

    coldefs = [(
                headerName = n,
                editable = cell_changed !== nothing,
                headerTooltip = types[i],
                field = n,
                sortable = !async,
                resizable = true,
                type = types[i] <: Union{Missing, T where T <: Number} ? "numericColumn" : nothing,
                filter = types[i] <: Union{Missing, T where T <: Dates.Date} ? "agDateColumnFilter" :
                         types[i] <: Union{Missing, T where T <: Number} ? "agNumberColumnFilter" : true,
                filterParams = async ? Dict("applyButton" => true, "clearButton" => true) : nothing
               ) for (i, n) in enumerate(names)]

    id = string("grid-", string(uuid1())[1:8])
    w.dom = dom"div"(className = "ag-theme-balham$(dark ? "-dark" : "")",
                     style = Dict("width" => to_css_size(width),
                                  "height" => to_css_size(height)),
                     id = id)

    showfun = async ? _showtable_async! : _showtable_sync!

    showfun(w, names, types, rows, coldefs, tablelength, dark, id, onCellValueChanged)

    w
end

function _showtable_sync!(w, names, types, rows, coldefs, tablelength, dark, id, onCellValueChanged)
    options = Dict(
        :onCellValueChanged => onCellValueChanged,
        :rowData => JSONText(table2json(rows, names, types)),
        :columnDefs => coldefs,
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

const _mapnumberop = Dict{String, String}(
    "equals" => "==",
    "notEqual" => "!=",
    "lessThan" => "<",
    "lessThanOrEqual" => "<=",
    "greaterThan" => ">",
    "greaterThanOrEqual" => ">=",
    )

const _mapdateop = Dict{String, String}(
    "equals" => "==",
    "greaterThan" => ">",
    "lessThan" => "<",
    "notEqual" => "!=",
)

const _dateformat = DateFormat("y-m-d")

function _regex_escape(s::AbstractString)
    res = replace(s, r"([()[\]{}?*+\-|^\$\\.&~#\s=!<>|:])" => s"\\\1")
    replace(res, "\0" => "\\0")
end

function _build_expressions(filtermodel)
    # Return an array of column expression strings

    function build_number(column, filter)
        optype = filter["type"]
        filtervalue = filter["filter"]
        expression = "true"

        if optype == "inRange"
            expression = """($filtervalue <= getproperty(row, Symbol("$column")) <= $(filter["filterTo"]))"""
        else
            expression = """(getproperty(row, Symbol("$column")) $(_mapnumberop[optype]) $filtervalue)"""
        end

        return expression
    end

    function build_text(column, filter)
        optype = filter["type"]

        # Unfortunately ag-grid's default text filter converts the user's input
        # to lowercase. Using regex with ignore case option rather normalizing
        # case on the field value. Thus we need to escape the user's input
        filtervalue = _regex_escape(filter["filter"])

        expression = "true"

        if optype == "equals"
            expression = "occursin(r\"\"\"^$filtervalue\$\"\"\"i, getproperty(row, Symbol(\"$column\")))"
        elseif optype == "notEqual"
            expression = "!occursin(r\"\"\"^$filtervalue\$\"\"\"i, getproperty(row, Symbol(\"$column\")))"
        elseif optype == "startsWith"
            expression = "occursin(r\"\"\"^$filtervalue\"\"\"i, getproperty(row, Symbol(\"$column\")))"
        elseif optype == "endsWith"
            expression = "occursin(r\"\"\"$filtervalue\$\"\"\"i, getproperty(row, Symbol(\"$column\")))"
        elseif optype == "contains"
            expression = "occursin(r\"\"\"$filtervalue\"\"\"i, getproperty(row, Symbol(\"$column\")))"
        elseif optype == "notContains"
            expression = "!occursin(r\"\"\"$filtervalue\"\"\"i, getproperty(row, Symbol(\"$column\")))"
        end

        return expression
    end

    function build_date(column, filter)
        optype = filter["type"]
        filtervalue = "Date(\"$(filter["dateFrom"])\", _dateformat)"
        expression = "true"

        if optype == "inRange"
            filterto = "Date(\"$(filter["dateTo"])\", _dateformat)"
            expression = """($filtervalue <= getproperty(row, Symbol("$column")) <= $filterto)"""
        else
            expression = """(getproperty(row, Symbol("$column")) $(_mapdateop[optype]) $filtervalue)"""
        end

        return expression
    end

    function build_filter(column, filter)
        filtertype = filter["filterType"]
        expression = "true"

        if filtertype == "number"
            expression = build_number(column, filter)
        elseif filtertype == "text"
            expression = build_text(column, filter)
        elseif filtertype == "date"
            expression = build_date(column, filter)
        end

        return expression
    end

    function build_boolean(column, conditions)
        return "(" *
            build_filter(column, conditions["condition1"]) *
                (conditions["operator"] == "OR" ? "||" : "&&") *
            build_filter(column, conditions["condition2"]) *
            ")"
    end

    return [
        (haskey(value, "filterType") ? build_filter(key, value) : build_boolean(key, value))
        for (key, value) in filtermodel
    ]
end

const _filterfns = Dict{String, Any}()

function _filterfn(filtermodel)
    code = "(row) -> begin $(join(_build_expressions(filtermodel), " && ")) end"
    if haskey(_filterfns, code)
        return _filterfns[code]
    end

    println("For filterModel: $filtermodel")
    println("Built code: $code")
    return _filterfns[code] = eval(Meta.parse(code))
end

function _showtable_async!(w, names, types, rows, coldefs, tablelength, dark, id, onCellValueChanged)
    rowparams = Observable(w, "rowparams", Dict("startRow" => 1,
                                                "endRow" => 100,
                                                "successCallback" => @js v -> nothing))
    requestedrows = Observable(w, "requestedrows", JSONText("{}"))
    on(rowparams) do x
        filtermodel = x["filterModel"]
        if length(filtermodel) > 0
            fltr = _filterfn(filtermodel)
            data = Base.Iterators.filter(rows) do row
                Base.invokelatest(fltr, row)
            end
        else
            data = rows
        end
        requestedrows[] = JSONText(table2json(data, names, types, requested = [x["startRow"], x["endRow"]]))
    end

    onjs(requestedrows, @js function (val)
        ($rowparams[]).successCallback(val, $(tablelength))
    end)

    options = Dict(
        :onCellValueChanged => onCellValueChanged,
        :columnDefs => coldefs,
        :maxConcurrentDatasourceRequests => 1,
        :cacheBlockSize => 1000,
        :maxBlocksInCache => 100,
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
                if col isa Number && isfinite(col)
                    JSON.print(io, col)
                elseif col === nothing
                    JSON.print(io, "nothing")
                elseif col === missing
                    JSON.print(io, "missing")
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
