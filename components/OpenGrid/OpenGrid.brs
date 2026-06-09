sub init()
	currentDesignResolution = m.top.getScene().currentDesignResolution
	m.width = currentDesignResolution.width
	m.height = currentDesignResolution.height

	m.top.width = m.width
	m.top.height = m.height

	' How much extra we want to render to the left and right of the onscreen content for the focused row
	m.extraWidthToRenderFocusedRow = m.width * 0.5

	' How much extra we want to render to the left and right of the onscreen content for the non-focused rows
	m.extraWidthToRenderNonFocusedRow = 0

	' How much extra we want to render above and below the onscreen content for all rows
	m.extraHeightToRender = m.height * 0.5

	' Variable default setup
	m.currentRowIndex = 0

	' Map of last-focused item index per row (keyed by row index)
	m.lastFocusedItemIndexByRow = []

	m.focusXOffset = 0
	m.focusYOffset = 0

	m.gridHasFocus = false

	' The actual content for the grid, an array of row configs where each row config has an array of item configs
	m.gridContent = []
	' IMPROVEMENT perhaps remove grid prefix from these variable names to make it less verbose

	' The nodes for each row that are currently in the grid, indexed by row index
	m.gridRowNodes = []

	m.gridRowHeaderNodes = []

	m.rowsRenderedNodesRanges = []

	' We need to access the item containers quite often so we store them here after they are made
	m.gridRowItemsContainerNodes = []

	' key is row index as string
	m.renderedRows = {}
	m.top.setRef("renderedRowsRef", m.renderedRows)

	m.availableRecycledNodes = {}

	m.renderThreadQueue = createObject("roRenderThreadQueue")
	contentSuppliedQueueId = "OGContentSuppliedQueue:" + createObject("roDeviceInfo").getRandomUUID()

	m.renderThreadQueue.addMessageHandler(contentSuppliedQueueId, "onContentSuppliedMessageReceived")
	m.top.contentSuppliedQueueId = contentSuppliedQueueId

	m.gridVerticalScroll = m.top.findNode("gridVerticalScroll")
	m.focusFeedback = m.top.findNode("focusFeedback")

	m.contentAssignedKey = "OPEN_GRID_CONTENT_ASSIGNED_TRACKING"

	' Used to allow us to stop creating nodes while we are animating and to also avoid time outs
	m.offscreenNodesTimer = createObject("roSGNode", "Timer")
	m.offscreenNodesTimer.duration = 0.01
	m.offscreenNodesTimer.observeFieldScoped("fire", "onOffscreenNodesTimerFired")

	m.top.observeFieldScoped("width", "onWidthChanged")
	m.top.observeFieldScoped("height", "onHeightChanged")
	m.top.observeFieldScoped("focusXOffset", "onFocusXOffsetChanged")
	m.top.observeFieldScoped("focusYOffset", "onFocusYOffsetChanged")
	m.top.observeFieldScoped("focusedChild", "onFocusedChildChanged")

	m.animationRate = 1400 / 1000000 ' Pixels per microsecond

	m.animationTimer = createObject("roSGNode", "Timer")
	m.animationTimer.duration = 0.001
	m.animationTimer.observeField("fire", "onAnimationTimerFired")
	m.animationTickTimeSpan = createObject("roTimespan")

	m.focusFeedbackTranslationYAnimateTo = 0
	m.focusFeedbackWidthAnimateTo = 0
	m.focusFeedbackHeightAnimateTo = 0
	m.gridVerticalScrollTranslationYAnimateTo = 0
	m.runningRowItemsAnimations = {}
	m.rowsNeedingHorizontalTranslationUpdate = {}

	' Includes the last rowFocusPercent values for each renderered row index. Used to avoid having to set fields when the value hasn't changed
	m.rowFocusPercents = {}

	' Includes the last focusPercent values for each renderered row item in the current row. Used to avoid having to set fields when the value hasn't changed
	m.currentRowFocusPercents = {}

	m.gridNeedsVerticalTranslationUpdate = false
end sub


sub onWidthChanged()
	m.width = m.top.width
end sub


sub onHeightChanged()
	m.height = m.top.height
end sub


sub onFocusXOffsetChanged()
	previousXOffset = m.focusXOffset
	m.focusXOffset = m.top.focusXOffset

	xOffsetDifference = m.focusXOffset - previousXOffset

	m.gridVerticalScroll.translation = [m.gridVerticalScroll.translation[0] + xOffsetDifference, m.gridVerticalScroll.translation[1]]
	m.focusFeedback.translation = [m.focusFeedback.translation[0] + xOffsetDifference, m.focusFeedback.translation[1]]
end sub


sub onFocusYOffsetChanged()
	previousYOffset = m.focusYOffset

	m.focusYOffset = m.top.focusYOffset

	yOffsetDifference = m.focusYOffset - previousYOffset

	m.gridVerticalScroll.translation = [m.gridVerticalScroll.translation[0], m.gridVerticalScroll.translation[1] + yOffsetDifference]
	m.focusFeedback.translation = [m.focusFeedback.translation[0], m.focusFeedback.translation[1] + yOffsetDifference]
end sub


sub onFocusedChildChanged()
	updatedFocus = false
	if m.top.hasFocus() = true then
		m.gridHasFocus = true
		updatedFocus = true
	else if m.top.isInFocusChain() = false then
		m.gridHasFocus = false
		updatedFocus = true
	end if

	if updatedFocus = true then
		for each rowIndex in m.renderedRows
			for each itemIndex in m.renderedRows[rowIndex]
				renderedNode = m.renderedRows[rowIndex][itemIndex]
				conditionallySetField(renderedNode, "gridHasFocus", m.gridHasFocus)
			end for
		end for
	end if
end sub


function getItemComponentName(itemData as Object, rowComponentName as String) as String
	if itemData.componentName <> invalid then
		return itemData.componentName
	else if rowComponentName <> invalid then
		return rowComponentName
	else
		print "No componentName included for item and row, defaulting to GridItemRenderer"
		return "Group"
	end if
end function


' Creates nodes that are needed for content around the focused index.
sub createOnscreenNodes(focusedRowIndex as integer, focusedRowItemIndex as integer)
	' IMPROVEMENT Add optimization to only try to create nodes for the row that changed

	if focusedRowIndex < 0 then
		print "Focused row index is out of bounds: " focusedRowIndex
		return
	end if

	currentRowIndex = focusedRowIndex
	heightRendered = 0
	' Go forward from the focused row index
	while m.height - m.focusYOffset >= heightRendered AND currentRowIndex < m.gridContent.count()
		' print "Creating onscreen nodes for row " currentRowIndex " heightRendered: " heightRendered " heightToRender: " m.height - m.focusYOffset
		renderRow(currentRowIndex, focusedRowIndex, focusedRowItemIndex, false)

		rowHeaderNode = m.gridRowHeaderNodes[currentRowIndex]
		if rowHeaderNode = invalid then
			headerHeight = 0
		else
			headerHeight = rowHeaderNode.height
		end if

		rowItemContainerNode = m.gridRowItemsContainerNodes[currentRowIndex]
		heightRendered += rowItemContainerNode.yOffset + headerHeight
		currentRowIndex = currentRowIndex + 1
	end while

	' Go backwards from the focused row index for peek
	if focusedRowIndex > 0 then
		renderRow(focusedRowIndex - 1, focusedRowIndex, focusedRowItemIndex, false)
	end if
end sub


function renderRow(rowIndex as Integer, focusedRowIndex as Integer, focusedRowItemIndex as Integer, includeOffscreen as Boolean)
	' PREREQUISITES/SETUP START
	rowUpdated = false
	rowNode = m.gridRowNodes[rowIndex]

	if rowNode = invalid then
		' Should never happen
		print "row node invalid for row " rowIndex
		return false
	end if

	previousRowNode = m.gridRowNodes[rowIndex - 1]
	if rowIndex = 0 then
		rowNode.translation = [0, 0]
	else if previousRowNode = invalid then
		' Should not be possible
		return false
	else
		headerHeight = 0
		header = m.gridRowHeaderNodes[rowIndex - 1]
		if header <> invalid then
			headerHeight = header.height
		end if

		yOffset = m.gridRowItemsContainerNodes[rowIndex - 1].yOffset

		rowNode.translation = [0, previousRowNode.translation[1] + headerHeight + yOffset]
	end if

	rowConfig = m.gridContent[rowIndex]
	if rowConfig = invalid then
		print "No row config for row " rowIndex
		return false
	end if

	rowRenderedNodes = m.renderedRows[rowIndex.toStr()]
	if rowRenderedNodes = invalid then
		rowRenderedNodes = {}
		m.renderedRows[rowIndex.toStr()] = rowRenderedNodes
	end if
	' PREREQUISITES/SETUP END

	' HEADER START
	headerHeight = 0
	rowHeaderNode = m.gridRowHeaderNodes[rowIndex]
	if rowHeaderNode = invalid AND rowConfig.header <> invalid then
		componentName = rowConfig.header.componentName
		if componentName = invalid then
			print "No header componentName included for row " rowIndex
		else
			rowHeaderNode = createObject("roSGNode", componentName)
		end if

		if rowHeaderNode = invalid then
			print "Failed to create header component: " componentName
		else
			rowHeaderNode.setRef("content", rowConfig.header)
			rowHeaderNode.contentUpdated = true
			headerHeight = rowHeaderNode.height
			rowNode.insertChild(rowHeaderNode, 0)
			m.gridRowHeaderNodes[rowIndex] = rowHeaderNode
		end if
	end if
	' HEADER END

	' ROW ITEMS CONTAINER START
	rowItemContainerNode = m.gridRowItemsContainerNodes[rowIndex]
	if rowItemContainerNode = invalid then
		rowItemContainerNode = createObject("roSGNode", "Group")
		rowItemContainerNode.id = "rowItemsContainer"
		rowItemContainerNode.update({
			"yOffset": 0
		}, true)
		rowItemContainerNode.translation = [0, headerHeight]
		rowNode.appendChild(rowItemContainerNode)
		m.gridRowItemsContainerNodes[rowIndex] = rowItemContainerNode
	end if
	' ROW ITEMS CONTAINER END

	' ROW ITEMS GENERATION START
	' Going forward first from the focused item
	widthRendered = 0
	yOffset = 0

	if includeOffscreen = true then
		if focusedRowIndex = rowIndex then
			widthToRender = m.width - m.focusXOffset + m.extraWidthToRenderFocusedRow
		else
			widthToRender = m.width - m.focusXOffset + m.extraWidthToRenderNonFocusedRow
		end if
	else
		widthToRender = m.width - m.focusXOffset
	end if

	if rowIndex = focusedRowIndex then
		currentRowItemIndex = focusedRowItemIndex
	else
		currentRowItemIndex = m.lastFocusedItemIndexByRow[rowIndex]
	end if

	while currentRowItemIndex < rowConfig.items.count() AND widthRendered <= widthToRender
		rowItemNode = rowRenderedNodes[currentRowItemIndex.toStr()]
		if rowItemNode <> invalid then
			' print "Node already rendered for row " rowIndex " item " currentRowItemIndex

			widthRendered += rowItemNode.xOffset
			currentRowItemIndex = currentRowItemIndex + 1
			continue while
		end if

		rowItemNode = conditionallyCreateNodeAndAssignContent(rowIndex, currentRowItemIndex)

		if rowItemNode = invalid then
			print "Failed to create node for row " rowIndex " item " currentRowItemIndex
		else
			rowUpdated = true
			if yOffset = 0 AND rowItemNode.hasField("yOffset") then
				yOffset = rowItemNode.yOffset
				rowItemContainerNode.yOffset = yOffset
				' print "Setting yOffset for row " rowIndex " to " yOffset
			end if

			previousRowItemNode = invalid
			for i = currentRowItemIndex - 1 to 0 step -1
				previousRowItemNode = rowRenderedNodes[i.toStr()]
				if previousRowItemNode <> invalid then
					exit for
				end if
			end for

			if previousRowItemNode = invalid then
				xTranslation = 0
			else
				xTranslation = previousRowItemNode.translation[0] + previousRowItemNode.xOffset
			end if
			rowItemNode.translation = [xTranslation, 0]

			widthRendered = widthRendered + rowItemNode.xOffset

			rowItemContainerNode.appendChild(rowItemNode)
		end if

		currentRowItemIndex = currentRowItemIndex + 1
	end while

	if rowIndex = focusedRowIndex then
		currentRowItemIndex = focusedRowItemIndex - 1
	else
		currentRowItemIndex = m.lastFocusedItemIndexByRow[rowIndex] - 1
	end if

	' Going backward from the focused item
	widthRendered = 0

	if rowIndex = focusedRowIndex then
		currentRowItemIndex = focusedRowItemIndex - 1
	else
		currentRowItemIndex = m.lastFocusedItemIndexByRow[rowIndex] - 1
	end if

	if includeOffscreen = true then
		if focusedRowIndex = rowIndex then
			widthToRender = m.focusXOffset + m.extraWidthToRenderFocusedRow
		else
			widthToRender = m.focusXOffset + m.extraWidthToRenderNonFocusedRow
		end if
	else
		widthToRender = m.focusXOffset
	end if

	while currentRowItemIndex >= 0 AND widthRendered <= widthToRender
		rowItemNode = rowRenderedNodes[currentRowItemIndex.toStr()]
		if rowItemNode <> invalid then
			' print "Reverse: Node already rendered for row " rowIndex " item " currentRowItemIndex

			widthRendered += rowItemNode.xOffset
			currentRowItemIndex = currentRowItemIndex - 1
			continue while
		end if

		' print "reverse widthRendered: " widthRendered " widthToRender: " widthToRender " currentRowItemIndex: " currentRowItemIndex
		rowItemNode = conditionallyCreateNodeAndAssignContent(rowIndex, currentRowItemIndex)

		if rowItemNode = invalid then
			print "Failed to create node for row " rowIndex " item " currentRowItemIndex
		else
			reversePreviousRowItemIndex = currentRowItemIndex + 1
			reversePreviousRowItemNode = rowRenderedNodes[reversePreviousRowItemIndex.toStr()]
			if reversePreviousRowItemNode = invalid then
				' Should never happen
				print "Previous row item node invalid for row " rowIndex " item " reversePreviousRowItemIndex
				return false
			else
				xTranslation = reversePreviousRowItemNode.translation[0] - rowItemNode.xOffset
			end if
			rowItemNode.translation = [xTranslation, 0]

			widthRendered += rowItemNode.xOffset

			rowItemContainerNode.insertChild(rowItemNode, 0)
		end if

		currentRowItemIndex = currentRowItemIndex - 1
	end while
	' ROW ITEMS GENERATION END

	return rowUpdated
end function


sub recycleOffscreenNodes()
	' Shallow clone so we can have different policies based on the row
	renderedRows = m.renderedRows

	' Next handle other rows
	for each rowIndex in renderedRows
		' First check if this is outside the vertical render area, if it is then we can recycle the entire row without needing to check each individual item
		translationDifference = calculateRowVerticalTranslationDifference(rowIndex.toInt())
		if translationDifference > m.height - m.focusYOffset + m.extraHeightToRender OR translationDifference + m.focusYOffset < -m.extraHeightToRender then
			' print "Recycling entire row " rowIndex " with vertical translation difference of " translationDifference

			' Recycle entire row
			for each rowItemIndex in renderedRows[rowIndex]
				recycleNode(rowIndex, rowItemIndex)
			end for

			renderedRows.delete(rowIndex)
			m.rowsRenderedNodesRanges[rowIndex.toInt()] = {"start": -1, "end": -1}

			continue for
		end if

		' Now handle rendered rows that are within the vertical render area but may have items that are outside the horizontal render area

		didRecycleNode = false

		' Check if this is the currently focused row as we may want to have different horizontal render area thresholds for the focused row vs the non-focused rows
		if rowIndex.toInt() = m.currentRowIndex then
			' Focused row, use focused row render area thresholds
			' print "Checking horizontal thresholds for focused row " rowIndex

			for each rowItemIndex in renderedRows[rowIndex]
				rowItemNode = renderedRows[rowIndex][rowItemIndex]
				if rowItemNode = invalid then
					print "Row item node invalid for row " rowIndex " item " rowItemIndex
					continue for
				end if

				translationDifference = calculateHorizontalTranslationDifference(rowItemNode, true)
				if (translationDifference > m.width - m.focusXOffset + m.extraWidthToRenderFocusedRow) OR (translationDifference + rowItemNode.width < -m.focusXOffset - m.extraWidthToRenderFocusedRow) then
					recycleNode(rowIndex, rowItemIndex)
					didRecycleNode = true
				end if
			end for
		else
			' Non-focused row, use non-focused row render area thresholds
			' print "Checking horizontal thresholds for non-focused row " rowIndex

			for each rowItemIndex in renderedRows[rowIndex]
				rowItemNode = renderedRows[rowIndex][rowItemIndex]
				if rowItemNode = invalid then
					print "Row item node invalid for row " rowIndex " item " rowItemIndex
					continue for
				end if

				translationDifference = calculateHorizontalTranslationDifference(rowItemNode, false)
				if translationDifference > m.width - m.focusXOffset + m.extraWidthToRenderNonFocusedRow OR translationDifference + rowItemNode.width < -m.focusXOffset - m.extraWidthToRenderNonFocusedRow then
					recycleNode(rowIndex, rowItemIndex)
					didRecycleNode = true
				end if
			end for
		end if

		' If we recycled nodes then we need to update the rendered nodes range
		if didRecycleNode then
			renderedRowIndexes = []
			for each renderedRowItemIndex in renderedRows[rowIndex]
				renderedRowIndexes.push(renderedRowItemIndex.toInt())
			end for
			renderedRowIndexes.sort()

			rowRenderedNodesRange = m.rowsRenderedNodesRanges[rowIndex.toInt()]
			rowRenderedNodesRange.start = renderedRowIndexes[0]
			rowRenderedNodesRange.end = renderedRowIndexes.peek()
		end if
	end for
end sub


sub recycleNode(rowIndex as String, rowItemIndex as String)
	' print "Recycling node for row " rowIndex " item " rowItemIndex
	renderedRows = m.renderedRows
	rowItemNode = renderedRows[rowIndex.toStr()][rowItemIndex.toStr()]

	nodeTypeAvailableRecycledNodes = m.availableRecycledNodes[rowItemNode.subtype()]
	if nodeTypeAvailableRecycledNodes = invalid then
		nodeTypeAvailableRecycledNodes = []
		m.availableRecycledNodes[rowItemNode.subtype()] = nodeTypeAvailableRecycledNodes
	end if
	nodeTypeAvailableRecycledNodes.push(rowItemNode)

	renderedRows[rowIndex].delete(rowItemIndex)

	trackingKey = "row" + rowIndex.toStr() + "item" + rowItemIndex.toStr()
	rowContent = m.gridContent[rowIndex.toInt()].items
	rowItemContent = rowContent[rowItemIndex.toInt()]
	rowItemContent[m.contentAssignedKey].delete(trackingKey)

	rowItemNode.content = invalid

	rowItemNode.unobserveFieldScoped("xOffset")
	rowItemNode.unobserveFieldScoped("yOffset")
	rowItemNode.unobserveFieldScoped("width")
	rowItemNode.unobserveFieldScoped("height")
	rowItemNode.unobserveFieldScoped("animate")

	rowItemContainerNode = rowItemNode.getParent()
	rowItemContainerNode.removeChild(rowItemNode)
end sub


sub onOffscreenNodesTimerFired()
	' print "Offscreen Nodes Timer Fired"

	timeBudget = 16 ' ms
	ts = createObject("roTimespan")
	rowUpdated = false

	currentRowIndex = m.currentRowIndex
	heightRendered = 0

	' Go forward from the focused row index
	while m.height - m.focusYOffset + m.extraHeightToRender >= heightRendered AND currentRowIndex < m.gridContent.count() AND ts.totalMilliseconds() < timeBudget
		rowUpdated = renderRow(currentRowIndex, m.currentRowIndex, m.lastFocusedItemIndexByRow[currentRowIndex], true) OR rowUpdated

		rowHeaderNode = m.gridRowHeaderNodes[currentRowIndex]
		if rowHeaderNode = invalid then
			headerHeight = 0
		else
			headerHeight = rowHeaderNode.height
		end if

		rowItemContainerNode = m.gridRowItemsContainerNodes[currentRowIndex]
		heightRendered += rowItemContainerNode.yOffset + headerHeight
		currentRowIndex += 1
	end while

	' Go backward from the focused row index
	heightRendered = 0
	currentRowIndex = m.currentRowIndex - 1

	while m.focusYOffset + m.extraHeightToRender >= heightRendered AND currentRowIndex >= 0 AND ts.totalMilliseconds() < timeBudget
		' print "Offscreen timer going backwards, currentRowIndex: " currentRowIndex " heightRendered: " heightRendered " focusYOffset: " m.focusYOffset
		rowUpdated = renderRow(currentRowIndex, m.currentRowIndex, m.lastFocusedItemIndexByRow[currentRowIndex], true) OR rowUpdated

		rowHeaderNode = m.gridRowHeaderNodes[currentRowIndex]
		if rowHeaderNode = invalid then
			headerHeight = 0
		else
			headerHeight = rowHeaderNode.height
		end if

		rowItemContainerNode = m.gridRowItemsContainerNodes[currentRowIndex]
		heightRendered += rowItemContainerNode.yOffset + headerHeight
		currentRowIndex -= 1
	end while

	elapsedTime = ts.totalMilliseconds()

	' print "onOffscreenNodesTimerFired elapsed time: " elapsedTime " ms"

	' If we ran out of time start the timer again.
	if elapsedTime > timeBudget then
		' print "Starting timer again"
		m.offscreenNodesTimer.control = "start"
	end if
end sub


function conditionallyCreateNodeAndAssignContent(rowIndex as Integer, rowItemIndex as Integer)
	rowRenderedNodes = m.renderedRows[rowIndex.toStr()]
	rowItemNode = rowRenderedNodes[rowItemIndex.toStr()]

	rowGridContent = m.gridContent[rowIndex]
	rowItemContent = rowGridContent.items[rowItemIndex]

	if rowItemContent.componentName <> invalid then
		itemComponentName = rowItemContent.componentName
	else if rowGridContent.componentName <> invalid then
		itemComponentName = rowGridContent.componentName
	else
		print "No componentName included for " "row " rowIndex " item " rowItemIndex
		return invalid
	end if

	needsNodeCreation = true
	if rowItemNode <> invalid then
		if rowItemNode.subtype() = itemComponentName then
			needsNodeCreation = false
		end if
	end if

	if needsNodeCreation then
		if m.availableRecycledNodes[itemComponentName] <> invalid AND m.availableRecycledNodes[itemComponentName].count() > 0 then
			' print "Reusing node from recycled pool for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName
			rowItemNode = m.availableRecycledNodes[itemComponentName].pop()
		else
			' print "Creating node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName
			rowItemNode = createObject("roSGNode", itemComponentName)

			if rowItemNode.hasField("xOffset") = false then
				print "Node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName + " does not have required xOffset field"
				return invalid
			else if rowItemNode.hasField("rowIndex") = false then
				print "Node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName + " does not have required rowIndex field"
				return invalid
			else if rowItemNode.hasField("rowItemIndex") = false then
				print "Node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName + " does not have required rowItemIndex field"
				return invalid
			end if
		endif
	end if

	if rowItemNode = invalid then
		print "Could not get node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName
		return invalid
	end if

	rowItemContent = rowGridContent.items[rowItemIndex]
	' Only set content if we have not already to improve performance. We add our own field to track this
	contentAssigned = rowItemContent[m.contentAssignedKey]
	if contentAssigned = invalid then
		contentAssigned = {}
		rowItemContent[m.contentAssignedKey] = contentAssigned
	end if

	trackingKey = "row" + rowIndex.toStr() + "item" + rowItemIndex.toStr()
	if contentAssigned[trackingKey] <> true then
		rowItemNode.rowIndex = rowIndex
		rowItemNode.rowItemIndex = rowItemIndex
		conditionallySetField(rowItemNode, "gridHasFocus", m.gridHasFocus)
		rowItemNode.setRef("content", rowItemContent)
		rowItemNode.contentUpdated = true
		contentAssigned[trackingKey] = true

		rowRenderedNodes[rowItemIndex.toStr()] = rowItemNode

		rowRenderedNodesRanges = m.rowsRenderedNodesRanges[rowIndex]
		if rowRenderedNodesRanges.start = -1 OR rowItemIndex < rowRenderedNodesRanges.start then
			rowRenderedNodesRanges.start = rowItemIndex
		end if

		if rowRenderedNodesRanges.end = -1 OR rowItemIndex > rowRenderedNodesRanges.end then
			rowRenderedNodesRanges.end = rowItemIndex
		end if

		' We don't add our observers until after initial content set to avoid extra triggering
		rowItemNode.observeFieldScoped("xOffset", "onRowItemXOffsetChanged")
		rowItemNode.observeFieldScoped("yOffset", "onRowItemYOffsetChanged")
		rowItemNode.observeFieldScoped("width", "onRowItemWidthChanged")
		rowItemNode.observeFieldScoped("height", "onRowItemHeightChanged")
		rowItemNode.observeFieldScoped("animate", "onRowItemAnimateChanged")
	else
		' print "Content already assigned for row " currentRowIndex " item " currentRowItemIndex
	end if

	return rowItemNode
end function


sub conditionallySetField(node as Object, fieldName as String, value as Dynamic)
	if node.hasField(fieldName) then
		node[fieldName] = value
	end if
end sub


sub onRowItemXOffsetChanged(msg)
	rowItem = msg.getRoSgNode()

	m.rowsNeedingHorizontalTranslationUpdate[rowItem.rowIndex.toStr()] = true

	conditionallyStartAnimationTimer()
end sub


sub onRowItemYOffsetChanged(msg)
	yOffset = msg.getData()
	rowItem = msg.getRoSgNode()

	rowIndex = rowItem.rowIndex
	rowItemIndex = rowItem.rowItemIndex

	if rowIndex <> m.currentRowIndex OR rowItemIndex <> m.lastFocusedItemIndexByRow[rowIndex] then
		' Perhaps revisit in the future but this keeps it simple
		return
	end if

	' Update the parent container's translation to reflect our new needed vertical space
	rowItemsContainer = rowItem.getParent()
	rowItemsContainer.yOffset = yOffset

	m.gridNeedsVerticalTranslationUpdate = true

	conditionallyStartAnimationTimer()
end sub


sub onRowItemWidthChanged(msg)
	rowItem = msg.getRoSgNode()

	rowIndex = rowItem.rowIndex

	if rowIndex <> m.currentRowIndex then
		return
	end if

	if rowItem.rowItemIndex <> m.lastFocusedItemIndexByRow[rowIndex] then
		return
	end if

	' Only update the focus feedback width if the currently focused item changed
	m.focusFeedbackWidthAnimateTo = rowItem.width

	conditionallyStartAnimationTimer()
end sub


sub onRowItemHeightChanged(msg)
	rowItem = msg.getRoSgNode()

	rowIndex = rowItem.rowIndex

	if rowIndex <> m.currentRowIndex then
		return
	end if

	if rowItem.rowItemIndex <> m.lastFocusedItemIndexByRow[rowIndex] then
		return
	end if

	' Only update the focus feedback width if the currently focused item changed
	m.focusFeedbackHeightAnimateTo = rowItem.width

	conditionallyStartAnimationTimer()
end sub


sub onRowItemAnimateChanged(msg)
	animate = msg.getData()

	if animate = invalid then return

	rowItemNode = msg.getRoSgNode()

	rowIndex = rowItemNode.rowIndex

	animationsKey = rowIndex.toStr() + "_" + rowItemNode.rowItemIndex.toStr()
	runningRowItemAnimations = m.runningRowItemsAnimations[animationsKey]
	if runningRowItemAnimations = invalid then
		runningRowItemAnimations = {}
		m.runningRowItemsAnimations[animationsKey] = runningRowItemAnimations
	end if

	animateXOffset = animate.xOffset
	if animateXOffset <> invalid then
		' Make sure we have the correct parameters
		animateTo = animateXOffset.animateTo
		if animateTo <> invalid then
			runningRowItemAnimations["xOffset"] = {
				"node": rowItemNode
				"animateTo": animateTo
			}
		end if
	end if

	animateYOffset = animate.yOffset
	if animateYOffset <> invalid then
		' Make sure we have the correct parameters
		animateTo = animateYOffset.animateTo
		if animateTo <> invalid then
			runningRowItemAnimations["yOffset"] = {
				"node": rowItemNode
				"animateTo": animateTo
			}
			' print "Added Y offset animation for row " rowIndex " item " rowItemNode.rowItemIndex  ":" rowItemNode.rowItemIndex" animateTo: " animateTo
		end if
	end if

	conditionallyStartAnimationTimer()
end sub


' Calculates the horizontal distance from the currently focused node to this node
function calculateHorizontalTranslationDifference(rowItemNode, calculateBasedOffAnimationTarget as Boolean) as Float
	rowItemContainerNode = rowItemNode.getParent()

	if calculateBasedOffAnimationTarget = true then
		rowXTranslation = 0
	else
		rowXTranslation = rowItemContainerNode.translation[0]
	end if

	rowItemXTranslation = rowItemNode.translation[0]

	' rowXTranslation is negative so we add to get the difference
	translationDifference = rowItemXTranslation + rowXTranslation

	return translationDifference
end function


function calculateRowVerticalTranslationDifference(rowIndex as Integer) as Float
	rowNode = m.gridRowNodes[rowIndex]
	rowYTranslation = rowNode.translation[1]
	translationDifference = m.gridVerticalScroll.translation[1] + rowYTranslation - m.focusYOffset

	return translationDifference
end function


sub conditionallyStartAnimationTimer()
	if m.animationTimer.control <> "start" then
		m.animationTickTimeSpan.mark()
		m.animationTimer.control = "start"
	end if
end sub


sub onAnimationTimerFired()
	timeElapsed = m.animationTickTimeSpan.totalMicroseconds()
	changeAmount = m.animationRate * timeElapsed

	isFocusFeedbackAnimationCompleted = animateFocusFeedback(changeAmount)

	shouldUpdateRowFocusPercent = true
	isGridVerticalScrollTranslationYAnimationCompleted = true
	animateTo = m.gridVerticalScrollTranslationYAnimateTo
	currentGridVerticalScrollYTranslation = m.gridVerticalScroll.translation[1]
	if animateTo < currentGridVerticalScrollYTranslation then
		newTranslationY = currentGridVerticalScrollYTranslation - changeAmount
		if newTranslationY < animateTo then
			newTranslationY = animateTo
		else
			isGridVerticalScrollTranslationYAnimationCompleted = false
		end if

		m.gridVerticalScroll.translation = [m.gridVerticalScroll.translation[0], newTranslationY]
	else if animateTo > currentGridVerticalScrollYTranslation then
		newTranslationY = currentGridVerticalScrollYTranslation + changeAmount
		if newTranslationY > animateTo then
			newTranslationY = animateTo
		else
			isGridVerticalScrollTranslationYAnimationCompleted = false
		end if

		m.gridVerticalScroll.translation = [m.gridVerticalScroll.translation[0], newTranslationY]
	else
		shouldUpdateRowFocusPercent = false
	end if

	currentRowIndex = m.currentRowIndex
	currentRowItemIndex = m.lastFocusedItemIndexByRow[currentRowIndex].toStr()
	isCurrentFocusedRowItemTranslationXAnimationCompleted = true

	renderedRowItems = m.renderedRows[currentRowIndex.toStr()]
	if renderedRowItems = invalid then
		print "No rendered row items for current row index " currentRowIndex
		shouldUpdateFocusPercent = false
	else
		shouldUpdateFocusPercent = true

		focusedRowItem = renderedRowItems[currentRowItemIndex]
		if focusedRowItem = invalid then
			print "Focused row item node invalid for current row index " currentRowIndex " item index " currentRowItemIndex
		else
			currentFocusedRowItemTranslationX = focusedRowItem.translation[0]
			animateTo = 0
			if animateTo < currentFocusedRowItemTranslationX then
				newTranslationX = currentFocusedRowItemTranslationX - changeAmount
				if newTranslationX < animateTo then
					newTranslationX = animateTo
				else
					isCurrentFocusedRowItemTranslationXAnimationCompleted = false
				end if

				focusedRowItem.translation = [newTranslationX, focusedRowItem.translation[1]]
				m.rowsNeedingHorizontalTranslationUpdate[currentRowIndex.toStr()] = true
			else if animateTo > currentFocusedRowItemTranslationX then
				newTranslationX = currentFocusedRowItemTranslationX + changeAmount
				if newTranslationX > animateTo then
					newTranslationX = animateTo
				else
					isCurrentFocusedRowItemTranslationXAnimationCompleted = false
				end if

				focusedRowItem.translation = [newTranslationX, focusedRowItem.translation[1]]
				m.rowsNeedingHorizontalTranslationUpdate[currentRowIndex.toStr()] = true
			else
				shouldUpdateFocusPercent = false
			end if
		end if
	end if

	for each key in m.runningRowItemsAnimations
		runningRowItemAnimations = m.runningRowItemsAnimations[key]

		if runningRowItemAnimations["xOffset"] <> invalid then
			rowItemNode = runningRowItemAnimations["xOffset"].node
			animateTo = runningRowItemAnimations["xOffset"].animateTo

			m.rowsNeedingHorizontalTranslationUpdate[rowItemNode.rowIndex.toStr()] = true

			currentXOffset = rowItemNode.xOffset
			if animateTo < currentXOffset then
				newXOffset = currentXOffset - changeAmount
				if newXOffset < animateTo then
					newXOffset = animateTo
					runningRowItemAnimations.delete("xOffset")
				end if

				rowItemNode.xOffset = newXOffset
			else if animateTo > currentXOffset then
				newXOffset = currentXOffset + changeAmount
				if newXOffset > animateTo then
					newXOffset = animateTo
					runningRowItemAnimations.delete("xOffset")
				end if

				rowItemNode.xOffset = newXOffset
			else
				runningRowItemAnimations.delete("xOffset")
			end if
		end if

		if runningRowItemAnimations["yOffset"] <> invalid then
			rowItemNode = runningRowItemAnimations["yOffset"].node
			animateTo = runningRowItemAnimations["yOffset"].animateTo

			m.rowsNeedingHorizontalTranslationUpdate[rowItemNode.rowIndex.toStr()] = true

			currentYOffset = rowItemNode.yOffset
			if animateTo < currentYOffset then
				newYOffset = currentYOffset - changeAmount
				if newYOffset < animateTo then
					newYOffset = animateTo
					runningRowItemAnimations.delete("yOffset")
				end if

				rowItemNode.yOffset = newYOffset
			else if animateTo > currentYOffset then
				newYOffset = currentYOffset + changeAmount
				if newYOffset > animateTo then
					newYOffset = animateTo
					runningRowItemAnimations.delete("yOffset")
				end if

				rowItemNode.yOffset = newYOffset
			else
				runningRowItemAnimations.delete("yOffset")
			end if
		end if

		if runningRowItemAnimations.count() = 0 then
			m.runningRowItemsAnimations.delete(key)
		end if
	end for

	isAllRowItemAnimationsCompleted = (m.runningRowItemsAnimations.count() = 0)

	' Now that we have adjusted all our data go ahead and check what translations we need to update due to the changes we made
	if m.rowsNeedingHorizontalTranslationUpdate.count() > 0 then
		for each rowIndex in m.rowsNeedingHorizontalTranslationUpdate
			updateRowItemTranslations(rowIndex.toInt())
		end for

		m.rowsNeedingHorizontalTranslationUpdate = {}
	end if

	if m.gridNeedsVerticalTranslationUpdate then
		for i = m.currentRowIndex to m.gridRowItemsContainerNodes.count() - 2
			currentGridRowNodeYTranslation = m.gridRowNodes[i].translation[1]

			nextGridRowNode = m.gridRowNodes[i + 1]
			totalYOffset = m.gridRowItemsContainerNodes[i].yOffset

			headerNode = m.gridRowHeaderNodes[i]
			if headerNode <> invalid then
				totalYOffset = totalYOffset + headerNode.height
			end if

			nextGridRowNode.translation = [nextGridRowNode.translation[0], currentGridRowNodeYTranslation + totalYOffset]
		end for
	end if

	' Calculate our rowFocusPercent and rowHasFocus
	if shouldUpdateRowFocusPercent then
		' t = createObject("roTimespan")
		gridVerticalScrollVerticalTranslation = m.gridVerticalScroll.translation[1] - m.focusYOffset

		for each rowIndex in m.renderedRows
			' Possibly revisit in the future. Using current rowIndex for focus percent calculations makes things simpler but focus percent will be different than the actual with different size items
			rowIndexInt = rowIndex.toInt()
			rowNode = m.gridRowNodes[rowIndexInt]
			rowVerticalTranslation = rowNode.translation[1]

			previousRowFocusOffsetPercentage = m.rowFocusPercents[rowIndex]

			' gridVerticalScrollVerticalTranslation is negative so we add to get the difference
			difference = gridVerticalScrollVerticalTranslation + rowVerticalTranslation
			' print "Row " rowIndex " vertical translation difference from focus: " difference

			focusFieldUpdates = []

			if difference = 0 then
				if previousRowFocusOffsetPercentage <> 1 then
				' 	' Row was not fully focused before so need to update to fully focused
					m.rowFocusPercents[rowIndex] = 1
					rowFocusPercentUpdate = 1
					focusFieldUpdates.push(["rowFocusPercent", 1])
					focusFieldUpdates.push(["rowHasFocus", true])
				end if
			else
				gridRowItemsContainerNode = m.gridRowItemsContainerNodes[rowIndexInt]

				rowHeight = gridRowItemsContainerNode.yOffset

				gridRowHeaderNode = m.gridRowHeaderNodes[rowIndexInt]
				if gridRowHeaderNode <> invalid then
					rowHeight = rowHeight + gridRowHeaderNode.height
				end if

				rowFocusPercent = 1 + (difference / rowHeight)
				if rowFocusPercent < 0 then
					rowFocusPercent = 0
				else if rowFocusPercent > 2 then
					rowFocusPercent = 2
				end if

				if previousRowFocusOffsetPercentage <> rowFocusPercent then
					m.rowFocusPercents[rowIndex] = rowFocusPercent
					focusFieldUpdates.push(["rowFocusPercent", rowFocusPercent])
					if previousRowFocusOffsetPercentage = 1 then
						focusFieldUpdates.push(["rowHasFocus", false])
					end if
				end if
			end if

			if focusFieldUpdates.isEmpty() = false then
				for each rowKey in m.renderedRows
					for each rowItemIndex in m.renderedRows[rowKey]
						rowItemNode = m.renderedRows[rowKey][rowItemIndex]
						if rowItemNode = invalid then
							print "Row item node invalid for row " rowKey " item " rowItemIndex
							continue for
						end if

						for each focusFieldUpdate in focusFieldUpdates
							conditionallySetField(rowItemNode, focusFieldUpdate[0], focusFieldUpdate[1])
						end for
					end for
				end for
			end if
		end for
		' print "calculate rowFocusPercent and rowHasFocus took:" ; t.totalMicroseconds() / 1000000
	end if

	if shouldUpdateFocusPercent then
		' t = createObject("roTimespan")
		' Update focus percent values for current row
		rowItems = m.renderedRows[currentRowIndex.toStr()]

		for each rowItemIndex in rowItems
			rowItemNode = rowItems[rowItemIndex]
			difference = calculateHorizontalTranslationDifference(rowItemNode, false)

			' Possibly revisit in the future. Using current rowItemIndex for focus percent calculations makes things simpler but focus percent will be different than the actual with different size items
			focusPercent = 1 + (difference / rowItemNode.xOffset)
			if focusPercent < 0 then
				focusPercent = 0
			else if focusPercent > 2 then
				focusPercent = 2
			end if

			previousFocusPercent = m.currentRowFocusPercents[rowItemIndex]
			if previousFocusPercent <> focusPercent then
				' print "Row " currentRowIndex " item " rowItemIndex " horizontal translation difference from focus: " difference " focusPercent: " focusPercent
				m.currentRowFocusPercents[rowItemIndex] = focusPercent
				conditionallySetField(rowItemNode, "focusPercent", focusPercent)

				if focusPercent = 1 then
					conditionallySetField(rowItemNode, "itemHasFocus", true)
				else if previousFocusPercent = 1 then
					conditionallySetField(rowItemNode, "itemHasFocus", false)
				end if
			end if
		end for
		' print "calculate rowFocusPercent and rowHasFocus took:" ; t.totalMicroseconds() / 1000000
	end if

	allAnimationsCompleted = isFocusFeedbackAnimationCompleted AND isGridVerticalScrollTranslationYAnimationCompleted AND isCurrentFocusedRowItemTranslationXAnimationCompleted AND isAllRowItemAnimationsCompleted

	' We are using control for knowing if the timer is already running so need to set it to stop so conditionallyStartAnimationTimer restarts properly
	m.animationTimer.control = "stop"

	if allAnimationsCompleted = false then
		conditionallyStartAnimationTimer()
	else
		' Do one final cleanup
		recycleOffscreenNodes()
	end if
end sub


function animateFocusFeedback(changeAmount) as Boolean
	isFocusFeedbackWidthAnimationCompleted = true
	currentFocusFeedbackWidth = m.focusFeedback.width
	animateTo = m.focusFeedbackWidthAnimateTo
	if animateTo > currentFocusFeedbackWidth then
		newWidth = currentFocusFeedbackWidth + changeAmount
		if newWidth > animateTo then
			newWidth = animateTo
		else
			isFocusFeedbackWidthAnimationCompleted = false
		end if

		' print "Focus feedback width animation newWidth " newWidth " animateTo: " animateTo

		m.focusFeedback.width = newWidth
	else if animateTo < currentFocusFeedbackWidth then
		newWidth = currentFocusFeedbackWidth - changeAmount
		if newWidth < animateTo then
			newWidth = animateTo
		else
			isFocusFeedbackWidthAnimationCompleted = false
		end if

		' print "Focus feedback width animation newWidth " newWidth " animateTo: " animateTo

		m.focusFeedback.width = newWidth
	else
		' print "Focus feedback width animation completed"
	end if

	isFocusFeedbackHeightAnimationCompleted = true
	currentFocusFeedbackHeight = m.focusFeedback.height
	animateTo = m.focusFeedbackHeightAnimateTo
	if animateTo > currentFocusFeedbackHeight then
		newHeight = currentFocusFeedbackHeight + changeAmount
		if newHeight > animateTo then
			newHeight = animateTo
		else
			isFocusFeedbackHeightAnimationCompleted = false
		end if

		' print "Focus feedback height animation newHeight " newHeight " animateTo: " animateTo

		m.focusFeedback.height = newHeight
	else if animateTo < currentFocusFeedbackHeight then
		' print "Focus feedback height animation run 2"
		newHeight = currentFocusFeedbackHeight - changeAmount
		if newHeight < animateTo then
			newHeight = animateTo
		else
			isFocusFeedbackHeightAnimationCompleted = false
		end if

		' print "Focus feedback height animation newHeight " newHeight " animateTo: " animateTo

		m.focusFeedback.height = newHeight
	else
		' print "Focus feedback height animation completed"
	end if

	isFocusFeedbackTranslationYAnimationCompleted = true
	animateTo = m.focusFeedbackTranslationYAnimateTo
	currentFocusFeedbackYTranslation = m.focusFeedback.translation[1]
	if animateTo < currentFocusFeedbackYTranslation then
		newTranslationY = currentFocusFeedbackYTranslation - changeAmount
		if newTranslationY < animateTo then
			newTranslationY = animateTo
		else
			isFocusFeedbackTranslationYAnimationCompleted = false
		end if

		' print "Focus feedback Y translation animation newTranslationY " newTranslationY " animateTo: " animateTo

		m.focusFeedback.translation = [m.focusFeedback.translation[0], newTranslationY]
	else if animateTo > currentFocusFeedbackYTranslation then
		newTranslationY = currentFocusFeedbackYTranslation + changeAmount
		if newTranslationY > animateTo then
			newTranslationY = animateTo
		else
			isFocusFeedbackTranslationYAnimationCompleted = false
		end if

		' print "Focus feedback Y translation animation newTranslationY " newTranslationY " animateTo: " animateTo

		m.focusFeedback.translation = [m.focusFeedback.translation[0], newTranslationY]
	else
		' print "Focus Feedback Y translation animation completed"
	end if

	return isFocusFeedbackHeightAnimationCompleted AND isFocusFeedbackWidthAnimationCompleted AND isFocusFeedbackTranslationYAnimationCompleted
end function


sub updateRowItemTranslations(rowIndex as Integer)
	renderedRowItems = m.renderedRows[rowIndex.toStr()]
	if renderedRowItems = invalid then
		print "No rendered row items at index" rowIndex
		return
	end if

	currentlyFocusedItemIndex = m.lastFocusedItemIndexByRow[rowIndex]
	if currentlyFocusedItemIndex = -1 then
		print "No currently focused item index for row " rowIndex
		stop
		return
	end if

	focusedRowItemNode = renderedRowItems[currentlyFocusedItemIndex.toStr()]
	if focusedRowItemNode = invalid then
		print "Focused row item node invalid for row " rowIndex " item " currentlyFocusedItemIndex
		stop
		return
	end if

	' For items before the currently focused item we need to subtract the xOffset changes from the item to the right of it recursively to get the new translation
	lastRowItemNode = focusedRowItemNode
	for i = currentlyFocusedItemIndex - 1 to m.rowsRenderedNodesRanges[rowIndex].start step -1
		currentRowItemNode = renderedRowItems[i.toStr()]
		if currentRowItemNode = invalid then
			print "Row item node invalid for row " rowIndex " item " i
			stop
			continue for
		end if

		xTranslation = lastRowItemNode.translation[0] - currentRowItemNode.xOffset

		' print "Peak: Updating x translation for row " rowIndex " item " i " to " xTranslation
		currentRowItemNode.translation = [xTranslation, currentRowItemNode.translation[1]]

		lastRowItemNode = currentRowItemNode
	end for

	' For items after the currently focused item we need to add the xOffset changes from the item to the left of it recursively to get the new translation
	lastRowItemNode = focusedRowItemNode
	for i = currentlyFocusedItemIndex + 1 to m.rowsRenderedNodesRanges[rowIndex].end
		currentRowItemNode = renderedRowItems[i.toStr()]
		if currentRowItemNode = invalid then
			print "Row item node invalid for row " rowIndex " item " i
			stop
			continue for
		end if

		xTranslation = lastRowItemNode.translation[0] + lastRowItemNode.xOffset

		currentRowItemNode.translation = [xTranslation, currentRowItemNode.translation[1]]
		' print "Updating x translation for row " rowIndex " item " i " to " xTranslation
		lastRowItemNode = currentRowItemNode
	end for
end sub


sub onContentSuppliedMessageReceived(rows, msgInfo)
	' TODO rewrite to support subsequent content updates instead of just initial load
	previousRowIndex = -1
	rowIndex = 0
	for each rowConfig in rows
		' TODO need to build this out more
		m.gridContent[rowIndex] = rowConfig
		' We use the row index as the way to know if we are making a new row or updating an existing one
		' rowIndex = rowConfig.rowIndex
		' if rowIndex <> invalid then
		' 	rowNode = m.top.getChild(rowIndex)

		' 	previousRowIndex = rowIndex
		' 	isUpdate = true
		' else
			rowNode = createObject("roSGNode", "Group")
			m.lastFocusedItemIndexByRow[rowIndex] = 0

			previousRowIndex = previousRowIndex + 1
			rowIndex = previousRowIndex
			isUpdate = false
		' end if

		m.gridRowNodes[rowIndex] = rowNode

		if m.rowsRenderedNodesRanges[rowIndex] = invalid then
			m.rowsRenderedNodesRanges[rowIndex] = { "start": -1, "end": -1 }
		end if

		m.gridVerticalScroll.appendChild(rowNode)
		rowIndex++
	end for

	navigateToRowItem(0, 0)
	m.focusFeedback.visible = true
end sub


' Navigate to a specific row and item index
' Returns true if navigation was successful, false if not (out of bounds or no composition loaded)
Function navigateToRowItem(rowIndex as integer, rowItemIndex as integer) as boolean
	rowContent = m.gridContent[rowIndex]
	if rowContent = invalid then
		print "No content for row at index" rowIndex
		return false
	end if

	rowItemContent = rowContent.items[rowItemIndex]
	if rowItemContent = invalid then
		print "No content for row item at index" rowItemIndex " in row" rowIndex
		return false
	end if

	print "navigateToRowItem called with rowIndex: " rowIndex " rowItemIndex: " rowItemIndex

	' We make the nodes that are showing onscreen up front
	createOnscreenNodes(rowIndex, rowItemIndex)

	renderedRow = m.renderedRows[rowIndex.toStr()]
	if renderedRow = invalid then
		print "No rendered row at index" rowIndex
		return false
	end if

	rowItemNode = renderedRow[rowItemIndex.toStr()]
	if rowItemNode = invalid then
		print "No loaded item at index" rowItemIndex " in row" rowIndex
		return false
	end if

	if rowIndex <> m.currentRowIndex then
		previousFocusedRowRenderedRowItems = m.renderedRows[m.currentRowIndex.toStr()]
		for each key in previousFocusedRowRenderedRowItems
			previousFocusedRowRenderedRowItem = previousFocusedRowRenderedRowItems[key]
		end for

		nextFocusedRowRenderedRowItems = m.renderedRows[rowIndex.toStr()]
		for each key in nextFocusedRowRenderedRowItems
			nextFocusedRowRenderedRowItem = nextFocusedRowRenderedRowItems[key]
		end for
	else
		currentFocusedRowRenderedRowItems = m.renderedRows[rowIndex.toStr()]
		for each key in currentFocusedRowRenderedRowItems
			currentFocusedRowRenderedRowItem = currentFocusedRowRenderedRowItems[key]
		end for
	end if

	m.currentRowIndex = rowIndex
	m.lastFocusedItemIndexByRow[rowIndex] = rowItemIndex

	m.focusFeedbackWidthAnimateTo = rowItemNode.width
	m.focusFeedbackHeightAnimateTo = rowItemNode.height

	m.gridVerticalScrollTranslationYAnimateTo = -m.gridRowNodes[rowIndex].translation[1] + m.focusYOffset

	gridRowNode = m.gridRowNodes[rowIndex]

	currentRowHeaderHeight = 0
	header = m.gridRowHeaderNodes[rowIndex]
	if header <> invalid then
		currentRowHeaderHeight = header.height
	end if

	m.focusFeedbackTranslationYAnimateTo = currentRowHeaderHeight + m.focusYOffset

	conditionallyStartAnimationTimer()

	rowItemNode.setFocus(true)

	' Next go ahead and cleanup any nodes that are currently outside the renderer area due to this navigation
	' recycleOffscreenNodes()

	' Go ahead and start the offscreen node timer to allow new nodes to be created for the content that is now in the rendered area but not on screen yet
	m.offscreenNodesTimer.control = "start"

	return true
End Function


Function navigateToRow(rowIndex as integer) as boolean
	currentItemIndex = m.lastFocusedItemIndexByRow[rowIndex]

	if currentItemIndex = invalid then
		print "No row at index" rowIndex
		return false
	end if

	return navigateToRowItem(rowIndex, currentItemIndex)
End Function


Function navigateToRelativeRowItem(rowIndex as integer, itemIndexOffset as integer) as boolean
	currentItemIndex = m.lastFocusedItemIndexByRow[rowIndex]

	if currentItemIndex = invalid then
		print "No row at index" rowIndex
		return false
	end if

	newItemIndex = currentItemIndex + itemIndexOffset

	return navigateToRowItem(rowIndex, newItemIndex)
End Function


Function onKeyEvent(key as string, press as boolean) as boolean
	if press = false then return false
	if key = "up" then
		navigateToRow(m.currentRowIndex - 1)
	else if key = "down" then
		navigateToRow(m.currentRowIndex + 1)
	else if key = "left" then
		navigateToRelativeRowItem(m.currentRowIndex, -1)
	else if key = "right" then
		navigateToRelativeRowItem(m.currentRowIndex, 1)
	else
		return false
	end if
	return true
End Function
