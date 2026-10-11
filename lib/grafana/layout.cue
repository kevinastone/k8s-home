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
// Each row is a list of panels. If gridPos.w is not specified, it is automatically
// computed by dividing the 24-column grid equally among the row's panels (div(24, len(row))).
// If gridPos.h is not specified, it defaults to defaultHeight (default 8).
// The x and y offsets are computed automatically based on row heights and panel widths.
#LayoutRows: {
	rows: [...[...{
		_w?: int
		gridPos?: {h?: int, w?: int, x?: int, y?: int, ...}
		...
	}]]
	defaultHeight: int | *8
	startY:        int | *0

	let normalizedRows = [
		for r in rows {
			let numPanels = len(r)
			let autoWidth = div(24, numPanels)
			[
				for p in r {
					let _explicitW = [if p._w != _|_ {p._w}, if p.gridPos.w != _|_ && p.gridPos.w != 12 {p.gridPos.w}][0]
					let _finalW = [if _explicitW != _|_ {_explicitW}, autoWidth][0]
					let _explicitH = [if p.gridPos.h != _|_ && p.gridPos.h != 9 {p.gridPos.h}][0]
					let _finalH = [if _explicitH != _|_ {_explicitH}, defaultHeight][0]
					p & {
						gridPos: {
							w: _finalW
							h: _finalH
						}
					}
				},
			]
		},
	]

	totalHeight: list.Sum([
		for r in normalizedRows {
			list.Max([for p in r {p.gridPos.h}])
		},
	])

	out: [
		for rowIdx, row in normalizedRows
		for colIdx, panel in row {
			let runningY = list.Sum([
				startY,
				for i, r in normalizedRows if i < rowIdx {
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

// #RowSection encapsulates a group of panels under a Grafana row.
// When collapsed is false (default), it emits the row panel (h: 1, w: 24, panels: [])
// followed by the encapsulated rows laid out sequentially below it (starting at startY + 1).
// When collapsed is true, it emits a collapsed row panel with the nested panels inside panels: [...].
#RowSection: R={
	title:         string
	startY:        int | *0
	defaultHeight: int | *8
	collapsed:     bool | *false
	rows: [...[...{
		gridPos?: {h?: int, w?: int, x?: int, y?: int, ...}
		...
	}]]

	let childStartY = R.startY + 1
	let childLayout = #LayoutRows & {
		rows:          R.rows
		defaultHeight: R.defaultHeight
		if R.collapsed {
			startY: 0
		}
		if !R.collapsed {
			startY: childStartY
		}
	}

	let rowHeader = #RowPanel & {
		title:     R.title
		collapsed: R.collapsed
		gridPos: {
			h: 1
			w: 24
			x: 0
			y: R.startY
		}
		if R.collapsed {
			panels: childLayout.out
		}
	}

	if collapsed {
		totalHeight: 1
	}
	if !collapsed {
		totalHeight: 1 + childLayout.totalHeight
	}

	if !R.collapsed {
		out: list.Concat([[rowHeader], childLayout.out])
	}
	if R.collapsed {
		out: [rowHeader]
	}
}

// #LayoutSections organizes multiple sections (rows with child panels) sequentially down the dashboard.
// It automatically computes each section's startY based on the accumulated heights of preceding sections.
#LayoutSections: S={
	sections: [...#RowSection]

	let positionedSections = [
		for idx, sec in S.sections {
			sec & {
				startY: list.Sum([
					0,
					for i, prev in S.sections if i < idx {prev.totalHeight},
				])
			}
		},
	]

	out: list.Concat([for sec in positionedSections {sec.out}])
}
