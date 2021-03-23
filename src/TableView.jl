module TableView

using Tables
using WebIO, JSExpr, JSON, Dates, UUIDs
using Observables: @map

export showtable

const ag_grid_imports = []
const js_max_safe_int = Int128(2^53-1)

function __init__()
    version = readchomp(joinpath(@__DIR__, "..", "ag-grid.version"))
    empty!(ag_grid_imports)
    for f in ["ag-grid.js", "ag-grid.css", "ag-grid-light.css", "ag-grid-dark.css"]
        push!(ag_grid_imports, normpath(joinpath(@__DIR__, "..", "deps", "ag-grid-$(version)", f)))
    end
    pushfirst!(ag_grid_imports, normpath(joinpath(@__DIR__, "rowNumberRenderer.js")))
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
  - `title`: Displayed above the table if non-empty;
  - `height`/`width`: CSS attributes specifying the output height and with.
  - `cell_changed`: Either `nothing` or a function that takes a single argument with the fields
                    `"new"`, `"old"`, `"row"`, and `"col"`. This function is called whenever the
                    user edits a table field. Note that all values will be strings, so you need to
                    do the necessary conversions yourself.
"""
function showtable(table, options::Dict{Symbol, Any} = Dict{Symbol, Any}();
        dark::Bool = false,
        title::String = "",
        height = :auto,
        width = "100%",
        cell_changed = nothing
    )
    rows = Tables.rows(table)
    it_sz = Base.IteratorSize(rows)
    has_len = it_sz isa Base.HasLength || it_sz isa Base.HasShape
    tablelength = has_len ? length(rows) : nothing

    if height === :auto
        height = 500
        if tablelength !== nothing
            # header + footer height ≈ 40px, 28px per row
            height = min(50 + tablelength*28, height)
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
            schema = Tables.Schema(names, types)
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

    coldefs = [Dict(
                :headerName => string(n),
                :editable => cell_changed !== nothing,
                :headerTooltip => string(types[i]),
                :field => string(n),
                :sortable => !async,
                :resizable => true,
                :type => types[i] <: Union{Missing, T where T <: Number} ? "numericColumn" : nothing,
                :filter => async ? false : types[i] <: Union{Missing, T where T <: Dates.Date} ? "agDateColumnFilter" :
                         types[i] <: Union{Missing, T where T <: Number} ? "agNumberColumnFilter" : true,
               ) for (i, n) in enumerate(names)]

    pushfirst!(coldefs, Dict(
        :headerName => "Row",
        :editable => false,
        :headerTooltip => "",
        :field => "__row__",
        :sortable => !async,
        :resizable => true,
        :type => "numericColumn",
        :cellRenderer => "rowNumberRenderer",
        :filter => false
    ))

    options[:onCellValueChanged] = onCellValueChanged
    options[:columnDefs] = coldefs
    options[:multiSortKey] = "ctrl"
    options[:rowSelection] = "multiple"

    for e in ["onCellClicked", "onCellDoubleClicked", "onRowClicked", "onCellFocused", "onCellKeyDown"]
        o = Observable{Any}(w, e, nothing)
        handler = @js function (ev)
            @var x = Dict()
            if ev.rowIndex !== undefined
                x["rowIndex"] = ev.rowIndex + 1
            end
            if ev.colDef !== undefined
                x["column"] = ev.colDef.headerName
            end
            $o[] = x
        end
        options[Symbol(e)] = handler
    end

    id = string("grid-", string(uuid1())[1:8])
    w.dom = dom"div"(
                dom"div"(
                    title,
                    style = Dict(
                        "background-color" => dark ? "#1c1f20" : "#F5F7F7",
                        "color" => dark ? "#F5F7F7" : "#1c1f20",
                        "height" => isempty(title) ? "0" : "18px",
                        "padding" => isempty(title) ? "0" : "5px",
                        "font-family" => """-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif"""
                    )
                ),
                dom"div"(className = "ag-theme-balham$(dark ? "-dark" : "")",
                     style = Dict("width" => to_css_size(width),
                                  "height" => to_css_size(height)),
                     id = id
                )
            )

    showfun = async ? _showtable_async! : _showtable_sync!

    showfun(w, schema, names, types, rows, coldefs, tablelength, id, options)

    w
end

function _showtable_sync!(w, schema, names, types, rows, coldefs, tablelength, id, options)
    options[:rowData] = JSONText(table2json(schema, rows, types))
    license = get(ENV, "AG_GRID_LICENSE_KEY", nothing)
    handler = @js function (RowNumberRenderer, agGrid)
        @var gridOptions = $options
        @var el = document.getElementById($id)
        gridOptions.components = Dict(
            "rowNumberRenderer" => RowNumberRenderer
        )
        if $(license !== nothing)
            agGrid.LicenseManager.setLicenseKey($license)
        end
        this.table = @new agGrid.Grid(el, gridOptions)
        gridOptions.columnApi.autoSizeAllColumns()
    end
    onimport(w, handler)
end

function _showtable_async!(w, schema, names, types, rows, coldefs, tablelength, id, options)
    rowparams = Observable(w, "rowparams", Dict("startRow" => 1,
                                                "endRow" => 100,
                                                "successCallback" => @js v -> nothing))
    requestedrows = Observable(w, "requestedrows", JSONText("{}"))
    on(rowparams) do x
        requestedrows[] = JSONText(table2json(schema, rows, types, requested = [x["startRow"] + 1, x["endRow"] + 1]))
    end

    onjs(requestedrows, @js function (val)
        ($rowparams[]).successCallback(val, $(tablelength))
    end)

    options[:maxConcurrentDatasourceRequests] = 1
    options[:cacheBlockSize] = 1000
    options[:maxBlocksInCache] = 100
    options[:rowModelType] = "infinite"
    options[:datasource] = Dict(
        "getRows" =>
            @js function (rowParams)
                $rowparams[] = rowParams
            end
        ,
        "rowCount" => tablelength
    )
    license = get(ENV, "AG_GRID_LICENSE_KEY", nothing)

    handler = @js function (RowNumberRenderer, agGrid)
        @var gridOptions = $options
        @var el = document.getElementById($id)

        gridOptions.components = Dict(
            "rowNumberRenderer" => RowNumberRenderer
        )
        if $(license !== nothing)
            agGrid.LicenseManager.setLicenseKey($license)
        end
        this.table = @new agGrid.Grid(el, gridOptions)
        gridOptions.columnApi.autoSizeAllColumns()
    end
    onimport(w, handler)
end

# directly write JSON instead of allocating temporary dicts etc
function table2json(schema, rows, types; requested = nothing)
    io = IOBuffer()
    rowwriter = JSON.Writer.CompactContext(io)
    JSON.begin_array(rowwriter)
    ser = JSON.StandardSerialization()
    for (i, row) in enumerate(rows)
        if requested != nothing && (i < first(requested) || i > last(requested))
            continue
        end
        JSON.delimit(rowwriter)
        columnwriter = JSON.Writer.CompactContext(io)
        JSON.begin_object(columnwriter)
        Tables.eachcolumn(schema, row) do val, ind, name
            if val isa Real && isfinite(val) && -js_max_safe_int < trunc(Int128, val) < js_max_safe_int
                JSON.show_pair(columnwriter, ser, name, val)
            elseif val === nothing || val === missing
                JSON.show_pair(columnwriter, ser, name, repr(val))
            else
                JSON.show_pair(columnwriter, ser, name, sprint(print, val))
            end
        end
        JSON.end_object(columnwriter)
    end
    JSON.end_array(rowwriter)
    String(take!(io))
end
end
