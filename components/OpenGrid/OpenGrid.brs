sub init()
	' Variable default setup
	m.currentRowIndex = 0
	m.currentItemIndex = 0
	m.composition = invalid

	m.gridContent = m.top.findNode("gridContent")
	m.focusFeedback = m.top.findNode("focusFeedback")

	' key is row index as string
	m.gridRenderedNodes = {}

	m.gridRowsNodes = {}

	m.top.observeFieldScoped("composition", "onCompositionChanged")

	assignTestComposition()
end sub


sub assignTestComposition()
	composition = createObject("roSgNode", "Node")
	composition.update({
		"rows": [{
			"subtype": "Node",
			"header": {
				"content": {
					"subtype": "Node",
					"componentName": "OpenGridHeaderTitle",
					"title": "Header Title"
				}
			},
			"height": 100,
			"itemSpacing": 10,
			"componentName": "OpenGridItem",
			"content": [{
				"subtype": "Node",
				"component": "OpenGridItem2",
				"title": "Title 1"
			}, {
				"subtype": "Node",
				"title": "Title 2"
			}, {
				"subtype": "Node",
				"title": "Title 3"
			}]
		}, {
			"subtype": "Node",
			"header": {
				"content": {
					"subtype": "Node",
					"componentName": "OpenGridHeaderTitle",
					"title": "Header Title"
				}
			},
			"height": 100,
			"itemSpacing": 10,
			"componentName": "OpenGridItem",
			"content": [{
				"subtype": "Node",
				"componentName": "OpenGridItem2",
				"title": "Title 1"
			}, {
				"subtype": "Node",
				"title": "Title 2"
			}, {
				"subtype": "Node",
				"title": "Title 3"
			}]
		}]
	}, true)
	' stop

	m.top.composition = composition
end sub


sub onCompositionChanged(msg as object)
	' Storing a local copy to avoid having to copy when referencing
	m.composition = msg.getData()

	updateComposition()
end sub


Function updateComposition() as boolean
	rowIndex = 0
	nextComponentVerticalTranslation = 0
	for each rowComposition in m.composition.rows
		headerContent = rowComposition.headerContent
		if headerContent <> invalid then
			componentName = headerContent.componentName
			if componentName = invalid then
				print "No componentName included for row " rowIndex " headerContent"
			else
				header = createObject("roSGNode", componentName)
				if header = invalid then
					print "Failed to create header component: " + componentName
				else
					header.translation = [0, nextComponentVerticalTranslation]
					header.content = headerContent
					m.gridContent.appendChild(header)
					headerHeight = header.height
					if headerHeight = invalid then
						print "Header height not provided for row " rowIndex
					else
						nextComponentVerticalTranslation += headerHeight
					end if
				end if
			end if
		end if

		rowHeight = rowComposition.height
		if rowHeight = invalid then
			print "No height included for row " rowIndex ". Can not continue."
			return false
		else
			' TODO probably can reuse these in the future although pretty cheap to make
			row = createObject("roSGNode", "Group")
			row.update({
				"currentItemIndex": 0
				"rowIndex": rowIndex
				"translation": [0, nextComponentVerticalTranslation]
			}, true)

			m.gridRowsNodes[rowIndex.toStr()] = row

			' Variables for row
			fallbackRowItemComponentName = rowComposition.componentName

			rowItemSpacing = rowComposition.itemSpacing
			if rowItemSpacing = invalid then
				rowItemSpacing = 0
			end if

			index = 0
			nextRowItemHorizontalTranslation = 0
			for each rowItemContent in rowComposition.content
				' Figure out what component we want to make
				rowItemComponentName = rowItemContent.componentName
				if rowItemComponentName = invalid then
					if fallbackRowItemComponentName = invalid then
						print "No componentName included for item at index" index " in row " rowIndex
					else
						rowItemComponentName = fallbackRowItemComponentName
					end if
				end if

				if rowItemComponentName <> invalid then
					' TODO switch to only making if needed and reusing existing in future
					rowItem = createObject("roSGNode", rowItemComponentName)
					if rowItem = invalid then
						print "Failed to create row item component: " + rowItemComponentName
					else
						rowItem.content = rowItemContent

						' Update the translation after we assign the content so the element has a chance to update its width
						rowItem.translation = [nextRowItemHorizontalTranslation, 0]

						nextRowItemHorizontalTranslation += rowItem.width + rowItemSpacing

						' Assign it to the parent after the component has a chance to do setup as this is more performant
						row.appendChild(rowItem)
					end if


					' Store the row item in the gridRenderedNodes AA so we can reference it later
					rowRenderedNodes = m.gridRenderedNodes[rowIndex.toStr()]
					if rowRenderedNodes = invalid then
						rowRenderedNodes = {}
						m.gridRenderedNodes[rowIndex.toStr()] = rowRenderedNodes
					end if
					rowRenderedNodes[index.toStr()] = rowItem

					' rowItem.observeFieldScoped("width", "onRowItemWidthChanged")
					index++
				end if
			end for

			rowIndex++
			m.gridContent.appendChild(row)

			nextComponentVerticalTranslation += rowHeight
		end if
	end for

	return navigateToRowItem(0, 0)
End Function


' Navigate to a specific row and item index
' Returns true if navigation was successful, false if not (out of bounds or no composition loaded)
Function navigateToRowItem(rowIndex as integer, itemIndex as integer) as boolean
	if m.composition = invalid then
		print "No composition loaded, cannot focus"
		return false
	end if

	if rowIndex < 0 then
		' Already was at first row
		return false
	end if

	compositionRows = m.composition.rows
	if rowIndex >= compositionRows.count() then
		' Already was at last row
		return false
	end if

	if itemIndex < 0 then
		' Already was at first item in row
		return false
	end if

	if itemIndex >= compositionRows[rowIndex].content.count() then
		' Already was at last item in row
		return false
	end if

	rowRenderedNodes = m.gridRenderedNodes[rowIndex.toStr()]
	if rowRenderedNodes = invalid then
		print "No rendered nodes for row" rowIndex
		return false
	end if

	rowItem = rowRenderedNodes[itemIndex.toStr()]
	if rowItem = invalid then
		print "No item at index" itemIndex " in row" rowIndex
		return false
	end if

	rowItemRow = rowItem.getParent()
	if rowItemRow = invalid then
		print "Row item has no parent"
		return false
	end if

	previousRowIndex = m.currentRowIndex
	previousItemIndex = rowItemRow.currentItemIndex

	m.currentRowIndex = rowIndex
	m.currentItemIndex = itemIndex

	verticalTranslationOffset = 0

	direction = 1
	if rowIndex < previousRowIndex then
		direction = -1
	end if

	for i = previousRowIndex to rowIndex - direction step direction
		verticalTranslationOffset += compositionRows[i].height * direction
	end for

	translation = m.gridContent.translation
	m.gridContent.translation = [
		translation[0],
		translation[1] - verticalTranslationOffset
	]

	horizontalTranslationOffset = 0

	direction = 1
	if itemIndex < previousItemIndex then
		direction = -1
	end if

	for i = previousItemIndex to itemIndex - direction step direction
		item = rowRenderedNodes[i.toStr()]
		horizontalTranslationOffset += item.width * direction

		itemSpacing = 0
		if compositionRows[rowIndex].itemSpacing <> invalid then
			horizontalTranslationOffset += compositionRows[rowIndex].itemSpacing * direction
		end if
	end for

	translation = rowItemRow.translation
	rowItemRow.translation = [
		translation[0] - horizontalTranslationOffset,
		translation[1]
	]

	rowItemRow.currentItemIndex = itemIndex


	print "m.gridContent.translation = " m.gridContent.translation

	m.focusFeedback.width = rowItem.width
	m.focusFeedback.height = rowItem.height
	rowItem.setFocus(true)

	return true
End Function


Function getRowNode(rowIndex as integer) as object
	return m.gridRowsNodes[rowIndex.toStr()]
End Function


Function navigateToRow(rowIndex as integer) as boolean
	row = getRowNode(rowIndex)

	if row = invalid then
		print "No row at index" rowIndex
		return false
	end if

	return navigateToRowItem(rowIndex, row.currentItemIndex)
End Function


Function navigateToPreviousItem() as boolean
	return navigateToRowItem(m.currentRowIndex, m.currentItemIndex - 1)
End Function


Function navigateToNextItem() as boolean
	return navigateToRowItem(m.currentRowIndex, m.currentItemIndex + 1)
End Function


Function onKeyEvent(key as string, press as boolean) as boolean
	if press = false then return false
	if key = "up" then
		navigateToRow(m.currentRowIndex - 1)
	else if key = "down" then
		navigateToRow(m.currentRowIndex + 1)
	else if key = "left" then
		navigateToPreviousItem()
	else if key = "right" then
		navigateToNextItem()
	else
		return false
	end if
	return true
End Function
