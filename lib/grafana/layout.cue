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

// #LayoutRows organizes panels declared in horizontal rows across a 24-column grid.
// Each row is a list of panels with defined gridPos.h and gridPos.w.
// The x and y offsets are computed automatically based on row height and panel widths.
#LayoutRows: {
	rows: [...[...{
		gridPos: {h: int, w: int, x?: int, y?: int, ...}
		...
	}]]

	out: [
		for rowIdx, row in rows
		for colIdx, panel in row {
			let runningY = list.Sum([
				for i, r in rows if i < rowIdx {
					list.Max([for p in r {p.gridPos.h}])
				},
			])
			let runningX = list.Sum([for j, prev in row if j < colIdx {prev.gridPos.w}])
			panel & {
				gridPos: {
					x: runningX
					y: runningY
				}
			}
		},
	]
}
