module TableView

using WebIO
using JSExpr
using JuliaDB
using DataValues

import JuliaDB: DNDSparse, DNextTable, NextTable

function JuliaDB.subtable(t::DNextTable, r)
    table(collect(rows(t)[r]), pkey=t.pkey)
end

showna(xs) = xs
function showna(xs::AbstractArray{T}) where {T<:DataValue}
    map(xs) do x
        isnull(x) ? "NA" : get(x)
    end
end

function showna(xs::Columns)
    rows(map(showna, columns(xs)))
end

function showtable(t::Union{DNextTable, NextTable}; rows=1:100, colopts=Dict(), kwargs...)
    w = Scope(imports=["https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.js",
                       "https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.css"])

    trunc_rows = max(1, first(rows)):min(length(t), last(rows))
    subt = JuliaDB.subtable(t, trunc_rows)

    headers = colnames(subt)
    cols = [merge(Dict(:data=>n), get(colopts, n, Dict())) for n in headers]

    options = Dict(
        :data => showna(collect(JuliaDB.rows(subt))),
        :colHeaders => headers,
        :modifyColWidth => @js(w -> w > 300 ? 300 : w),
        :modifyRowHeight => @js(h -> h > 60 ? 50 : h),
        :manualColumnResize => true,
        :manualRowResize => true,
        :columns => cols,
        :width => 800,
        :height => 400,
    )
    if (length(t.pkey) > 0 && t.pkey == [1:length(t.pkey);])
        options[:fixedColumnsLeft] = length(t.pkey)
    end

    merge!(options, Dict(kwargs))

    handler = @js function (Handsontable)
        @var sizefix = document.createElement("style");
        sizefix.textContent = """
            .htCore td {
                white-space:nowrap
            }
        """
        this.dom.appendChild(sizefix)
        this.hot = @new Handsontable(this.dom, $options);
    end
    onimport(w, handler)
    w.dom = dom"div"()
    w
end

function showtable(t::Union{DNDSparse, NDSparse}; rows=1:100, colopts=Dict(), kwargs...)
    w = Scope(imports=["https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.js",
                       "https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.css"])
    data = Observable{Any}(w, "data", [])

    trunc_rows = max(1, first(rows)):min(length(t), last(rows))

    ks = keys(t)[trunc_rows]
    vs = values(t)[trunc_rows]

    if !isa(keys(t), Columns)
         ks = collect(ks)
         vs = collect(vs)
    end

    subt = NDSparse(showna(ks), showna(vs))

    headers = colnames(subt)
    cols = [merge(Dict(:data=>n), get(colopts, n, Dict())) for n in headers]

    options = Dict(
        :data => JuliaDB.rows(subt),
        :colHeaders => headers,
        :fixedColumnsLeft => ndims(t),
        :modifyColWidth => @js(w -> w > 300 ? 300 : w),
        :modifyRowHeight => @js(h -> h > 60 ? 50 : h),
        :manualColumnResize => true,
        :manualRowResize => true,
        :columns => cols,
        :width => 800,
        :height => 400,
    )

    merge!(options, Dict(kwargs))

    handler = @js function (Handsontable)
        @var sizefix = document.createElement("style");
        sizefix.textContent = """
            .htCore td {
                white-space:nowrap
            }
        """
        this.dom.appendChild(sizefix)
        this.hot = @new Handsontable(this.dom, $options);
    end
    onimport(w, handler)
    w.dom = dom"div"()
    w
end

end # module
