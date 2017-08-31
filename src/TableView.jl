module TableView

using WebIO
using IndexedTables

function showtable(t; rows=1:100)
    w = Widget(dependencies=["https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.js",
                             "https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.css"])
    data = Observable{Any}(w, "data", [])

    ks = keys(t)[rows]
    vs = values(t)[rows]

    if !isa(keys(t), Columns)
         ks = collect(ks)
         vs = collect(vs)
    end

    subt = IndexedTable(ks, vs)

    headers = [fieldnames(eltype(keys(t))); fieldnames(eltype(t));]
    options = Dict(
        :data => IndexedTables.rows(subt),
        :colHeaders => headers,
        :fixedColumnsLeft => ndims(t),
        :modifyColWidth => @js(w -> w > 300 ? 300 : w),
        :modifyRowHeight => @js(h -> h > 60 ? 50 : h),
        :manualColumnResize => true,
        :manualRowResize => true,
        :width =>800,
        :height =>400
    )
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
    ondependencies(w, handler)
    w()
end

end # module
