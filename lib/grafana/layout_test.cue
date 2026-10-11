package grafana

// Tests for layout engine behaviors and width computations.
// Run with: cue vet -c ./lib/grafana/
_testLayoutRows: {
	// Test 1: Single panel row auto-expands to full width (w: 24)
	testSinglePanelAutoWidth: {
		input: #LayoutRows & {
			rows: [[#GaugePanel & {gridPos: h: 7}]]
		}
		expected: [{
			gridPos: {h: 7, w: 24, x: 0, y: 0}
		}]
		assert: input.out & expected
	}

	// Test 2: Two panels in a row divide width equally (w: 12 each)
	testTwoPanelsAutoWidth: {
		input: #LayoutRows & {
			rows: [[
				#TimeSeriesPanel & {gridPos: h: 9},
				#TimeSeriesPanel & {gridPos: h: 9},
			]]
		}
		expected: [
			{gridPos: {h: 9, w: 12, x: 0, y: 0}},
			{gridPos: {h: 9, w: 12, x: 12, y: 0}},
		]
		assert: input.out & expected
	}

	// Test 3: Explicit panel width is preserved
	testExplicitWidthPreserved: {
		input: #LayoutRows & {
			rows: [[
				#TimeSeriesPanel & {gridPos: {h: 6, w: 8}},
				#TimeSeriesPanel & {gridPos: {h: 6, w: 16}},
			]]
		}
		expected: [
			{gridPos: {h: 6, w: 8, x: 0, y: 0}},
			{gridPos: {h: 6, w: 16, x: 8, y: 0}},
		]
		assert: input.out & expected
	}

	// Test 4: Default height is applied when h is unspecified
	testDefaultHeightApplied: {
		input: #LayoutRows & {
			rows: [[#TimeSeriesPanel]]
		}
		expected: [{
			gridPos: {h: 8, w: 24, x: 0, y: 0}
		}]
		assert: input.out & expected
	}

	// Test 4b: Default height is applied when panel specifies explicit width without explicit height
	testDefaultHeightAppliedWithExplicitWidth: {
		input: #LayoutRows & {
			defaultHeight: 6
			rows: [[#TimeSeriesPanel & {gridPos: w: 10}]]
		}
		expected: [{
			gridPos: {h: 6, w: 10, x: 0, y: 0}
		}]
		assert: input.out & expected
	}

	// Test 5: Row with 3 panels divides 24 evenly into w: 8 each
	testThreePanelsAutoWidth: {
		input: #LayoutRows & {
			rows: [[
				#StatPanel & {gridPos: h: 4},
				#StatPanel & {gridPos: h: 4},
				#StatPanel & {gridPos: h: 4},
			]]
		}
		expected: [
			{gridPos: {h: 4, w: 8, x: 0, y: 0}},
			{gridPos: {h: 4, w: 8, x: 8, y: 0}},
			{gridPos: {h: 4, w: 8, x: 16, y: 0}},
		]
		assert: input.out & expected
	}
}

// Tests for #LayoutColumns
_testLayoutColumns: {
	testTwoColumns: {
		input: #LayoutColumns & {
			colWidth: 6
			columns: [
				[#TimeSeriesPanel & {gridPos: {h: 4, w: 6}}],
				[#TimeSeriesPanel & {gridPos: {h: 4, w: 6}}],
			]
		}
		expected: [
			{gridPos: {h: 4, w: 6, x: 0, y: 0}},
			{gridPos: {h: 4, w: 6, x: 6, y: 0}},
		]
		assert: input.out & expected
	}
}

// Tests for #RowSection
_testRowSection: {
	testRowSectionYOffsets: {
		input: #RowSection & {
			title:         "System CPU"
			startY:        0
			defaultHeight: 9
			rows: [
				[#TimeSeriesPanel & {gridPos: h: 9}, #TimeSeriesPanel & {gridPos: h: 9}],
				[#GaugePanel & {gridPos: h: 7}],
			]
		}
		expected: [
			// Row header: h: 1, w: 24 at y: 0
			{type: "row", title: "System CPU", gridPos: {h: 1, w: 24, x: 0, y: 0}},
			// Row 1: two panels at y: 1
			{gridPos: {h: 9, w: 12, x: 0, y: 1}},
			{gridPos: {h: 9, w: 12, x: 12, y: 1}},
			// Row 2: single panel auto-width (w: 24) at y: 10
			{gridPos: {h: 7, w: 24, x: 0, y: 10}},
		]
		assert: input.out & expected
	}
}
