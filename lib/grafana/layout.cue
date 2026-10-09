package grafana

import "list"

// #LayoutColumns organizes panels declared in vertical columns across a 24-column grid.
// Each column is a list of panels with defined gridPos.h and gridPos.w (defaulting to colWidth).
// The x and y offsets are computed automatically based on column order and accumulated panel heights.
#LayoutColumns: {
	columns: [...[...{
		gridPos: {h: int, w?: int, x?: int, y?: int, ...}
		...
	}]]
	colWidth: int | *6

	out: [
		for colIdx, col in columns
		for rowIdx, panel in col {
			let runningY = list.Sum([for j, prev in col if j < rowIdx {prev.gridPos.h}])
			let colX = colIdx * colWidth
			panel & {
				gridPos: {
					w: *colWidth | int
					x: colX
					y: runningY
				}
			}
		},
	]
}
