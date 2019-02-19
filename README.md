# TableView

[![Build Status](https://travis-ci.org/JuliaComputing/TableView.jl.svg?branch=master)](https://travis-ci.org/JuliaComputing/TableView.jl)

TableView.jl is an [ag-grid](https://www.ag-grid.com/) based table viewer built on [WebIO.jl](https://github.com/JuliaGizmos/WebIO.jl). It can display arbitrarily large tables by lazy-loading additional data when scrolling (this is the default for datasets with more than 10k rows).

![demo](https://user-images.githubusercontent.com/6735977/53032222-b9d06500-346e-11e9-8b7e-c18cbeb563f6.png)

### Usage
`showtable(yourtable)` returns a `WebIO.Scope` which can be displayed with multiple frontends (e.g. IJulia, Blink, Juno...). See the WebIO readme for information on that.

### Limitations
When trying to display big tables (>10k rows) we switch to lazy-loading additional rows while scrolling, which disables the filtering/sorting that's possible for smaller datasets. It's possible (but not trivial) to write proper backend support for those operations -- PRs would be very welcome.
