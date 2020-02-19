function RowNumberRenderer() {}

RowNumberRenderer.prototype.init = function (params) {
    this.eGui = document.createElement('span');
    this.eGui.innerHTML = params.rowIndex + 1;
};

RowNumberRenderer.prototype.getGui = function() {
    return this.eGui;
};
