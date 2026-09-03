sub init()
	currentDesignResolution = m.top.getScene().currentDesignResolution
	m.width = currentDesignResolution.width
	m.height = currentDesignResolution.height

	m.top.width = m.width
	m.top.height = m.height

	updateClippingRect()

	' How much extra we want to render to the left and right of the onscreen content for the focused row
	m.extraWidthToRenderFocusedRow = m.width * 0.5

	' How much extra we want to render to the left and right of the onscreen content for the non-focused rows
	m.extraWidthToRenderNonFocusedRow = 0

	' How much extra we want to render above and below the onscreen content for all rows
	m.extraHeightToRender = m.height * 0.5

	' Variable default setup
	m.currentRowIndex = 0

	m.currentRowHeaderIsFocused = false

	' Map of last-focused item index per row (keyed by row index)
	m.lastFocusedItemIndexByRow = []

	m.focusXOffset = 0
	m.focusYOffset = 0

	m.gridHasFocus = false

	' The actual content for the grid, an array of row configs where each row config has an array of item configs
	m.content = []

	' The nodes for each row that are currently in the grid, indexed by row index
	m.rowNodes = []

	m.rowHeaderNodes = []

	m.rowsRenderedNodesRanges = []

	' We need to access the item containers quite often so we store them here after they are made
	m.rowItemsContainerNodes = []

	' key is row index as string
	m.renderedRows = {}
	m.top.setRef("renderedRowsRef", m.renderedRows)

	m.availableRecycledNodes = {}

	' Key used to store OpenGrid-managed per-row pagination metadata directly on each row config
	' (resolved id, isAllRowContentLoaded, and the contentRequested in-flight guard)
	m.rowMetadataKey = "OPEN_GRID_ROW_METADATA"

	' Grid-level guard to avoid re-requesting more rows on every navigation near the bottom.
	' Reset to false whenever new rows are supplied.
	m.rowsContentRequested = false

	' Grid-level flag indicating there are no more rows to load. When true OpenGrid stops requesting
	' more rows. Derived from each envelope's isAllRowsLoaded, which defaults to true when omitted so a
	' client that never opts in to row pagination won't be asked for more rows.
	m.isAllRowsLoaded = true

	' bs:disable-next-line 1129
	m.renderThreadQueue = createObject("roRenderThreadQueue")
	contentQueueId = "OGContentQueueId:" + createObject("roDeviceInfo").getRandomUUID()

	m.renderThreadQueue.addMessageHandler(contentQueueId, "onContentSuppliedMessageReceived")
	m.top.contentQueueId = contentQueueId

	m.verticalScroll = m.top.findNode("verticalScroll")
	m.focusFeedback = m.top.findNode("focusFeedback")
	m.focusFeedbackPoster = m.top.findNode("focusFeedbackPoster")

	m.contentAssignedKey = "OPEN_GRID_CONTENT_ASSIGNED_TRACKING"

	' Used to allow us to have smoother animations and to also avoid time outs
	m.offscreenNodesTimer = createObject("roSGNode", "Timer")
	m.offscreenNodesTimer.duration = 0.01
	m.offscreenNodesTimer.observeFieldScoped("fire", "onOffscreenNodesTimerFired")

	m.top.observeFieldScoped("disableAnimation", "onDisableAnimationChanged")
	m.top.observeFieldScoped("animateToRowItem", "onAnimateToRowItemChanged")
	m.top.observeFieldScoped("jumpToRowItem", "onJumpToRowItemChanged")
	m.top.observeFieldScoped("width", "onWidthChanged")
	m.top.observeFieldScoped("height", "onHeightChanged")
	m.top.observeFieldScoped("focusXOffset", "onFocusXOffsetChanged")
	m.top.observeFieldScoped("focusYOffset", "onFocusYOffsetChanged")
	m.top.observeFieldScoped("focusedChild", "onFocusedChildChanged")
	m.top.observeFieldScoped("focusBitmapUri", "updateFocusFeedbackState")
	m.top.observeFieldScoped("focusBitmapBlendColor", "updateFocusFeedbackState")
	m.top.observeFieldScoped("focusFootprintBitmapUri", "updateFocusFeedbackState")
	m.top.observeFieldScoped("focusFootprintBlendColor", "updateFocusFeedbackState")
	m.top.observeFieldScoped("focusFeedbackExtension", "onFocusFeedbackExtensionChanged")
	m.top.observeFieldScoped("rowItemContentNeededThreshold", "onRowItemContentNeededThresholdChanged")
	m.top.observeFieldScoped("rowContentNeededThreshold", "onRowContentNeededThresholdChanged")

	m.focusFeedbackPoster.observeFieldScoped("bitmapMargins", "onFocusFeedbackPosterBitmapMarginsChanged")

	m.animationRate = 1800 / 1000000 ' Pixels per microsecond

	m.animationTimer = createObject("roSGNode", "Timer")
	m.animationTimer.duration = 1/60
	m.animationTimer.observeField("fire", "onAnimationTimerFired")
	m.animationTickTimeSpan = createObject("roTimespan")

	m.keyHoldTimer = createObject("roSGNode", "Timer")
	m.keyHoldTimer.duration = 0.8
	m.keyHoldTimer.observeField("fire", "onKeyHoldTimerFired")

	m.focusFeedbackTranslationYAnimateTo = 0
	m.focusFeedbackWidthAnimateTo = 0
	m.focusFeedbackHeightAnimateTo = 0
	m.verticalScrollTranslationYAnimateTo = 0
	m.runningRowItemsAnimations = {}
	m.rowsNeedingHorizontalTranslationUpdate = {}

	' Includes the last rowFocusPercent values for each renderered row index. Used to avoid having to set fields when the value hasn't changed
	m.rowFocusPercents = {}

	' Last focusPercent applied to each rendered row item, keyed [rowIndexStr][rowItemIndexStr] to mirror
	' m.renderedRows. Used to avoid setting fields when the value hasn't changed. Entries are removed as
	' nodes are recycled so a recreated node at the same index never inherits a stale value.
	m.rowItemFocusPercents = {}

	m.needsVerticalTranslationUpdate = false

	' Seed the cached pagination thresholds from their current field values. These are kept up to date
	' via onRowItemContentNeededThresholdChanged / onRowContentNeededThresholdChanged. See OpenGrid.xml.
	m.rowItemContentNeededThreshold = m.top.rowItemContentNeededThreshold
	m.rowContentNeededThreshold = m.top.rowContentNeededThreshold

	' How far the focus feedback extends past the content on each axis. Defaults to the poster's
	' bitmapMargins but can be overridden via m.top.focusFeedbackExtension (see onFocusFeedbackPosterBitmapMarginsChanged)
	m.focusFeedbackWidthExtension = 0
	m.focusFeedbackHeightExtension = 0
end sub


sub updateFocusFeedbackState()
	if m.top.isInFocusChain() = true then
		m.focusFeedbackPoster.blendColor = m.top.focusBitmapBlendColor
		m.focusFeedbackPoster.uri = m.top.focusBitmapUri
	else
		m.focusFeedbackPoster.blendColor = m.top.focusFootprintBlendColor
		m.focusFeedbackPoster.uri = m.top.focusFootprintBitmapUri
	end if
end sub


sub onDisableAnimationChanged(msg)
	m.disableAnimation = msg.getData()
end sub


sub onRowItemContentNeededThresholdChanged(msg)
	m.rowItemContentNeededThreshold = msg.getData()
end sub


sub onRowContentNeededThresholdChanged(msg)
	m.rowContentNeededThreshold = msg.getData()
end sub


sub onAnimateToRowItemChanged(msg)
	data = msg.getData()
	navigateToRowItem(data[0], data[1], true)
end sub


sub onJumpToRowItemChanged(msg)
	data = msg.getData()
	if data = invalid OR data.count() <> 2 then return

	navigateToRowItem(data[0], data[1], false)
end sub


sub onWidthChanged()
	m.width = m.top.width
	updateClippingRect()
end sub


sub onHeightChanged()
	m.height = m.top.height
	updateClippingRect()
end sub


sub onFocusFeedbackPosterBitmapMarginsChanged(msg)
	updateFocusFeedbackExtension()
end sub


sub onFocusFeedbackExtensionChanged()
	updateFocusFeedbackExtension()
end sub


' Recomputes how far the focus feedback extends past the content on each axis. Defaults to the
' poster's bitmapMargins (stretch markers) but honors m.top.focusFeedbackExtension when set, which
' is useful for 9-patches with a corner radius where bitmapMargins would over-expand.
sub updateFocusFeedbackExtension()
	bitmapMargins = m.focusFeedbackPoster.bitmapMargins

	focusFeedbackExtension = m.top.focusFeedbackExtension
	if focusFeedbackExtension <> invalid then
		m.focusFeedbackWidthExtension = focusFeedbackExtension[0]
		m.focusFeedbackHeightExtension = focusFeedbackExtension[1]
	else
		m.focusFeedbackWidthExtension = bitmapMargins.left + bitmapMargins.right
		m.focusFeedbackHeightExtension = bitmapMargins.top + bitmapMargins.bottom
	end if

	' Offset by half the extension on each axis so the feedback stays centered on the content.
	' Derived from the extension (not bitmapMargins) so an override like [0, 0] positions correctly.
	m.focusFeedbackPoster.translation = [-m.focusFeedbackWidthExtension / 2, -m.focusFeedbackHeightExtension / 2]
end sub


sub updateClippingRect()
	m.top.clippingRect = [0, 0, m.width, m.height]
end sub


sub onFocusXOffsetChanged()
	previousXOffset = m.focusXOffset
	m.focusXOffset = m.top.focusXOffset

	xOffsetDifference = m.focusXOffset - previousXOffset

	m.verticalScroll.translation = [m.verticalScroll.translation[0] + xOffsetDifference, m.verticalScroll.translation[1]]
	m.focusFeedback.translation = [m.focusFeedback.translation[0] + xOffsetDifference, m.focusFeedback.translation[1]]
end sub


sub onFocusYOffsetChanged()
	previousYOffset = m.focusYOffset

	m.focusYOffset = m.top.focusYOffset

	yOffsetDifference = m.focusYOffset - previousYOffset

	m.verticalScroll.translation = [m.verticalScroll.translation[0], m.verticalScroll.translation[1] + yOffsetDifference]
	m.focusFeedback.translation = [m.focusFeedback.translation[0], m.focusFeedback.translation[1] + yOffsetDifference]
end sub


sub onFocusedChildChanged()
	updatedFocus = false

	isInFocusChain = m.top.isInFocusChain()
	if isInFocusChain then
		if m.gridHasFocus = false then
			updatedFocus = true

			if m.currentRowHeaderIsFocused then
				focusHeader(m.rowHeaderNodes[m.currentRowIndex])
			else
				focusCurrentRowItem()
			end if
		end if
	else
		if m.gridHasFocus = true then
			updatedFocus = true
		end if
	end if

	if updatedFocus = true then
		m.gridHasFocus = isInFocusChain

		updateFocusFeedbackState()
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
sub createOnscreenNodes(focusedRowIndex as Integer, focusedRowItemIndex as Integer)
	' IMPROVEMENT Add optimization to only try to create nodes for the row that changed

	if focusedRowIndex < 0 then
		print "Focused row index is out of bounds: " focusedRowIndex
		return
	end if

	currentRowIndex = focusedRowIndex
	heightRendered = 0
	' Go forward from the focused row index
	while m.height - m.focusYOffset >= heightRendered AND currentRowIndex < m.content.count()
		renderRow(currentRowIndex, focusedRowIndex, focusedRowItemIndex, false)

		rowHeaderNode = m.rowHeaderNodes[currentRowIndex]
		if rowHeaderNode = invalid then
			headerHeight = 0
		else
			headerHeight = rowHeaderNode.height
		end if

		rowItemContainerNode = m.rowItemsContainerNodes[currentRowIndex]
		heightRendered += rowItemContainerNode.yOffset + headerHeight
		currentRowIndex = currentRowIndex + 1
	end while

	' Go backwards from the focused row index to fill the space above the focused row (focusYOffset)
    currentRowIndex = focusedRowIndex - 1
    heightRendered = 0
    while m.focusYOffset >= heightRendered AND currentRowIndex >= 0
        renderRow(currentRowIndex, focusedRowIndex, focusedRowItemIndex, false)

        rowHeaderNode = m.rowHeaderNodes[currentRowIndex]
        if rowHeaderNode = invalid then
            headerHeight = 0
        else
            headerHeight = rowHeaderNode.height
        end if

        rowItemContainerNode = m.rowItemsContainerNodes[currentRowIndex]
        heightRendered += rowItemContainerNode.yOffset + headerHeight
        currentRowIndex = currentRowIndex - 1
    end while

	' m.currentRowIndex is still the PREVIOUS focused row at this point (navigateToRowItem
	' updates it after this returns). The grid animates from the previous row to the new
	' focused row, scrolling every row in between through the viewport. Those swept rows
	' were not covered by the fill loops above (which only extend around the target), so
	' render them up front to avoid flashing empty space mid-animation.
	sweepStart = m.currentRowIndex
	sweepEnd = focusedRowIndex
	if sweepStart > sweepEnd then
		temp = sweepStart
		sweepStart = sweepEnd
		sweepEnd = temp
	end if

	for sweptRowIndex = sweepStart to sweepEnd
		if m.renderedRows[sweptRowIndex.toStr()] = invalid then
			renderRow(sweptRowIndex, focusedRowIndex, focusedRowItemIndex, false)
		end if
	end for
end sub


function renderRow(rowIndex as Integer, focusedRowIndex as Integer, focusedRowItemIndex as Integer, includeOffscreen as Boolean)
	' PREREQUISITES/SETUP START
	rowUpdated = false
	rowNode = m.rowNodes[rowIndex]

	if rowNode = invalid then
		' Should never happen
		print "row node invalid for row " rowIndex
		return false
	end if

	if rowIndex > m.rowItemsContainerNodes.count() then
		' We are missing row items container nodes for this row, we need to create it
		for i = m.rowItemsContainerNodes.count() to rowIndex - 1
			renderRow(i, focusedRowIndex, focusedRowItemIndex, false)
		end for
	end if

	previousRowNode = m.rowNodes[rowIndex - 1]
	if rowIndex = 0 then
		rowNode.translation = [0, 0]
	else if previousRowNode = invalid then
		conditionallyThrow("Previous row node invalid")
		return false
	else
		headerHeight = 0
		header = m.rowHeaderNodes[rowIndex - 1]
		if header <> invalid then
			headerHeight = header.height
		end if

		yOffset = m.rowItemsContainerNodes[rowIndex - 1].yOffset

		rowNode.translation = [0, previousRowNode.translation[1] + headerHeight + yOffset]
	end if

	rowConfig = m.content[rowIndex]
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
	rowHeaderNode = m.rowHeaderNodes[rowIndex]
	headerConfig = rowConfig.header
	if rowHeaderNode = invalid AND headerConfig <> invalid then
		componentName = headerConfig.componentName
		if componentName = invalid then
			conditionallyThrow("No header componentName included for row " + rowIndex.toStr())
		else
			rowHeaderNode = createObject("roSGNode", componentName)
		end if

		if rowHeaderNode = invalid then
			conditionallyThrow("Failed to create header component: " + componentName)
		else

			' Check if the header is focusable or not. If not then mark it as not focusable
			rowHeaderNode.focusable = (headerConfig.isFocusable = true)

			rowHeaderNode.setRef("content", rowConfig)
			rowHeaderNode.contentUpdated = true
			if rowHeaderNode.height = invalid then
				conditionallyThrow("Header node for row " + rowIndex.toStr() + " does not have a height field")
			else
				headerHeight = rowHeaderNode.height
				rowNode.insertChild(rowHeaderNode, 0)
				m.rowHeaderNodes[rowIndex] = rowHeaderNode
			end if
		end if
	end if
	' HEADER END

	' ROW ITEMS CONTAINER START
	rowItemContainerNode = m.rowItemsContainerNodes[rowIndex]
	if rowItemContainerNode = invalid then
		rowItemContainerNode = createObject("roSGNode", "Group")
		rowItemContainerNode.id = "rowItemsContainer"
		rowItemContainerNode.update({
			"yOffset": 0
		}, true)
		rowItemContainerNode.translation = [0, headerHeight]
		rowNode.appendChild(rowItemContainerNode)
		m.rowItemsContainerNodes[rowIndex] = rowItemContainerNode
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
			conditionallyThrow("Failed to create node")
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


	' Start steps for going backward from the focused item to create peek items
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
			widthRendered += rowItemNode.xOffset
			currentRowItemIndex = currentRowItemIndex - 1
			continue while
		end if

		rowItemNode = conditionallyCreateNodeAndAssignContent(rowIndex, currentRowItemIndex)

		if rowItemNode = invalid then
			conditionallyThrow("Failed to create node for row " + rowIndex.toStr() + " item " + currentRowItemIndex.toStr())
		else
			' Have to get the translation of the row to the right so we can calculate our translation
			reversePreviousRowItemIndex = currentRowItemIndex + 1
			reversePreviousRowItemNode = rowRenderedNodes[reversePreviousRowItemIndex.toStr()]
			if reversePreviousRowItemNode = invalid then
				conditionallyThrow("Previous row item node invalid")
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
	for each rowIndex in renderedRows.keys() ' Making keys array to avoid modifying the collection while iterating over it
		' First check if this is outside the vertical render area, if it is then we can recycle the entire row without needing to check each individual item
		translationDifference = calculateRowVerticalTranslationDifference(rowIndex.toInt())
		if translationDifference > m.height - m.focusYOffset + m.extraHeightToRender OR translationDifference + m.focusYOffset < -m.extraHeightToRender then
			' print "Recycling entire row " rowIndex " with vertical translation difference of " translationDifference

			' Recycle entire row
			for each rowItemIndex in renderedRows[rowIndex].keys() ' Making keys array to avoid modifying the collection while iterating over it
				recycleNode(rowIndex, rowItemIndex)
			end for

			renderedRows.delete(rowIndex)
			m.rowItemFocusPercents.delete(rowIndex)
			m.rowsRenderedNodesRanges[rowIndex.toInt()] = { "start": -1, "end": -1 }

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

	rowItemNodeSubtype = rowItemNode.subtype()
	nodeTypeAvailableRecycledNodes = m.availableRecycledNodes[rowItemNodeSubtype]
	if nodeTypeAvailableRecycledNodes = invalid then
		nodeTypeAvailableRecycledNodes = []
		m.availableRecycledNodes[rowItemNodeSubtype] = nodeTypeAvailableRecycledNodes
	end if
	nodeTypeAvailableRecycledNodes.push(rowItemNode)

	renderedRows[rowIndex].delete(rowItemIndex)

	' Drop any cached focus percent for this node so a node later recreated at the same index does not
	' inherit a stale value that would suppress its focusPercent/itemHasFocus update.
	rowItemFocusPercents = m.rowItemFocusPercents[rowIndex.toStr()]
	if rowItemFocusPercents <> invalid then
		rowItemFocusPercents.delete(rowItemIndex.toStr())
	end if

	trackingKey = "row" + rowIndex.toStr() + "item" + rowItemIndex.toStr()
	rowContent = m.content[rowIndex.toInt()].items
	rowItemContent = rowContent[rowItemIndex.toInt()]

	contentAssignedTracking = rowItemContent[m.contentAssignedKey]
	if contentAssignedTracking <> invalid then
		contentAssignedTracking.delete(trackingKey)
	end if
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

	currentRowIndex = m.currentRowIndex
	heightRendered = 0

	' Go forward from the focused row index
	while m.height - m.focusYOffset + m.extraHeightToRender >= heightRendered AND currentRowIndex < m.content.count() AND ts.totalMilliseconds() < timeBudget
		renderRow(currentRowIndex, m.currentRowIndex, m.lastFocusedItemIndexByRow[currentRowIndex], true)

		rowHeaderNode = m.rowHeaderNodes[currentRowIndex]
		if rowHeaderNode = invalid then
			headerHeight = 0
		else
			headerHeight = rowHeaderNode.height
		end if

		rowItemContainerNode = m.rowItemsContainerNodes[currentRowIndex]
		heightRendered += rowItemContainerNode.yOffset + headerHeight
		currentRowIndex += 1
	end while

	' Go backward from the focused row index
	heightRendered = 0
	currentRowIndex = m.currentRowIndex - 1

	while m.focusYOffset + m.extraHeightToRender >= heightRendered AND currentRowIndex >= 0 AND ts.totalMilliseconds() < timeBudget
		' print "Offscreen timer going backwards, currentRowIndex: " currentRowIndex " heightRendered: " heightRendered " focusYOffset: " m.focusYOffset
		renderRow(currentRowIndex, m.currentRowIndex, m.lastFocusedItemIndexByRow[currentRowIndex], true)

		rowHeaderNode = m.rowHeaderNodes[currentRowIndex]
		if rowHeaderNode = invalid then
			headerHeight = 0
		else
			headerHeight = rowHeaderNode.height
		end if

		rowItemContainerNode = m.rowItemsContainerNodes[currentRowIndex]
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

	rowContent = m.content[rowIndex]
	rowItemContent = rowContent.items[rowItemIndex]

	if rowItemContent.componentName <> invalid then
		itemComponentName = rowItemContent.componentName
	else if rowContent.componentName <> invalid then
		itemComponentName = rowContent.componentName
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
		end if
	end if

	if rowItemNode = invalid then
		print "Could not get node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName
		return invalid
	end if

	rowItemContent = rowContent.items[rowItemIndex]
	' Only set content if we have not already to improve performance. We add our own field to track this
	'TODO move to initial content ingestion instead
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


' Throws an exception when running sideloaded (dev mode) to surface bugs during development.
' In production this is a no-op so the app can attempt to continue without crashing.
function conditionallyThrow(message as String)
	if createObject("roAppInfo").isDev() then
		throw message
	end if

	return invalid
end function


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

	m.needsVerticalTranslationUpdate = true

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
	m.focusFeedbackWidthAnimateTo = rowItem.width + m.focusFeedbackWidthExtension

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

	' Only update the focus feedback height if the currently focused item changed
	m.focusFeedbackHeightAnimateTo = rowItem.height + m.focusFeedbackHeightExtension

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
	rowNode = m.rowNodes[rowIndex]
	rowYTranslation = rowNode.translation[1]
	translationDifference = m.verticalScroll.translation[1] + rowYTranslation - m.focusYOffset

	return translationDifference
end function


sub conditionallyStartAnimationTimer()
	if m.animationTimer.control <> "start" then
		m.animationTickTimeSpan.mark()
		m.animationTimer.control = "start"
	end if
end sub


sub onAnimationTimerFired()
	if m.disableAnimation = true then
		' We skip an animation by animating so much that it will always happen in one frame
		changeAmount = 100000
		m.disableAnimation = false
	else
		timeElapsed = m.animationTickTimeSpan.totalMicroseconds()
		changeAmount = m.animationRate * timeElapsed
	end if


	isFocusFeedbackAnimationCompleted = animateFocusFeedback(changeAmount)

	shouldUpdateRowFocusPercent = true
	isVerticalScrollTranslationYAnimationCompleted = true
	animateTo = m.verticalScrollTranslationYAnimateTo
	currentVerticalScrollYTranslation = m.verticalScroll.translation[1]
	if animateTo < currentVerticalScrollYTranslation then
		newTranslationY = currentVerticalScrollYTranslation - changeAmount
		if newTranslationY < animateTo then
			newTranslationY = animateTo
		else
			isVerticalScrollTranslationYAnimationCompleted = false
		end if

		m.verticalScroll.translation = [m.verticalScroll.translation[0], newTranslationY]
	else if animateTo > currentVerticalScrollYTranslation then
		newTranslationY = currentVerticalScrollYTranslation + changeAmount
		if newTranslationY > animateTo then
			newTranslationY = animateTo
		else
			isVerticalScrollTranslationYAnimationCompleted = false
		end if

		m.verticalScroll.translation = [m.verticalScroll.translation[0], newTranslationY]
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
				' The focused item needs no horizontal animation. We still run the item
				' focus block so the focused item gets focusPercent/itemHasFocus applied. This covers the
				' initial focus (nothing animates) and vertical-only navigation (row animates, item centered).
				' The per-item cache below suppresses redundant field writes so this stays cheap.
				shouldUpdateFocusPercent = true
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

	if m.needsVerticalTranslationUpdate then
		for i = m.currentRowIndex to m.rowItemsContainerNodes.count() - 2
			currentRowNodeYTranslation = m.rowNodes[i].translation[1]

			nextRowNode = m.rowNodes[i + 1]
			totalYOffset = m.rowItemsContainerNodes[i].yOffset

			headerNode = m.rowHeaderNodes[i]
			if headerNode <> invalid then
				totalYOffset = totalYOffset + headerNode.height
			end if

			nextRowNode.translation = [nextRowNode.translation[0], currentRowNodeYTranslation + totalYOffset]
		end for
	end if

	' Calculate our rowFocusPercent and rowHasFocus
	if shouldUpdateRowFocusPercent then
		' t = createObject("roTimespan")
		verticalScrollVerticalTranslation = m.verticalScroll.translation[1] - m.focusYOffset

		hasCalculatedFocusRow = false

		' AA keys can be in any order and we need to go in a deterministic order so we need to convert to a sorted array
		renderedRowsIndexes = []
		for each rowIndex in m.renderedRows
			renderedRowsIndexes.push(rowIndex.toInt())
		end for
		renderedRowsIndexes.sort()

		lastRowPercentage = 0

		for each rowIndexInt in renderedRowsIndexes
			' Possibly revisit in the future. Using current rowIndex for focus percent calculations makes things simpler but focus percent will be different than the actual with different size items
			rowIndex = rowIndexInt.toStr()
			rowNode = m.rowNodes[rowIndexInt]
			rowVerticalTranslation = rowNode.translation[1]

			previousRowFocusOffsetPercentage = m.rowFocusPercents[rowIndex]

			' verticalScrollVerticalTranslation is negative so we add to get the difference
			difference = verticalScrollVerticalTranslation + rowVerticalTranslation

			focusFieldUpdates = []

			' Set when a row transitions out of being fully focused. Its previously focused item still
			' has focusPercent/itemHasFocus set, and the current-row focus block below only processes the
			' new focused row, so we reset this row's item focus state here.
			rowLostFocus = false

			if difference = 0 then
				if previousRowFocusOffsetPercentage <> 1 then
					' 	' Row was not fully focused before so need to update to fully focused
					m.rowFocusPercents[rowIndex] = 1
					focusFieldUpdates.push(["rowFocusPercent", 1])
					focusFieldUpdates.push(["rowHasFocus", true])

					if hasCalculatedFocusRow = false then
						hasCalculatedFocusRow = true
						m.top.currFocusRow = rowIndexInt
					end if
				end if
			else
				rowItemsContainerNode = m.rowItemsContainerNodes[rowIndexInt]

				rowHeight = rowItemsContainerNode.yOffset

				rowHeaderNode = m.rowHeaderNodes[rowIndexInt]
				if rowHeaderNode <> invalid then
					rowHeight = rowHeight + rowHeaderNode.height
				end if

				' Will be negative if above the focus area and positive if below the focus area
				percentage = (difference / rowHeight)

				if hasCalculatedFocusRow = false AND difference > 0 then
					hasCalculatedFocusRow = true
					m.top.currFocusRow = rowIndexInt - 1 + lastRowPercentage * -1
				end if

				lastRowPercentage = percentage

				rowFocusPercent = 1 + percentage
				if rowFocusPercent < 0 then
					rowFocusPercent = 0
				else if rowFocusPercent > 2 then
					rowFocusPercent = 2
				end if

				if previousRowFocusOffsetPercentage <> rowFocusPercent then
					' TODO need to handle when we create nodes as well
					m.rowFocusPercents[rowIndex] = rowFocusPercent
					focusFieldUpdates.push(["rowFocusPercent", rowFocusPercent])
					if previousRowFocusOffsetPercentage = 1 then
						focusFieldUpdates.push(["rowHasFocus", false])
						rowLostFocus = true
					end if
				end if
			end if

			if focusFieldUpdates.isEmpty() = false then
				for each rowItemIndex in m.renderedRows[rowIndex]
					rowItemNode = m.renderedRows[rowIndex][rowItemIndex]
					if rowItemNode = invalid then
						print "Row item node invalid for row " rowIndex " item " rowItemIndex
						continue for
					end if

					for each focusFieldUpdate in focusFieldUpdates
						conditionallySetField(rowItemNode, focusFieldUpdate[0], focusFieldUpdate[1])
					end for
				end for
			end if

			' The row is no longer fully focused, so no item in it should read as focused. Reset any
			' item whose cached focusPercent is still non-zero (e.g. the item we just navigated away
			' from) so it collapses. Clearing the cache to 0 also lets it re-fire when we return.
			if rowLostFocus then
				rowItemFocusPercents = m.rowItemFocusPercents[rowIndex]
				if rowItemFocusPercents <> invalid then
					for each itemIndexKey in rowItemFocusPercents
						if rowItemFocusPercents[itemIndexKey] <> 0 then
							previousItemFocusPercent = rowItemFocusPercents[itemIndexKey]
							rowItemFocusPercents[itemIndexKey] = 0

							rowItemNode = m.renderedRows[rowIndex][itemIndexKey]
							if rowItemNode <> invalid then
								conditionallySetField(rowItemNode, "focusPercent", 0)
								if previousItemFocusPercent = 1 then
									conditionallySetField(rowItemNode, "itemHasFocus", false)
								end if
							end if
						end if
					end for
				end if
			end if
		end for
		' print "calculate rowFocusPercent and rowHasFocus took:" ; t.totalMicroseconds() / 1000000
	end if

	if shouldUpdateFocusPercent then
		' t = createObject("roTimespan")
		' Update focus percent values for current row
		rowItems = m.renderedRows[currentRowIndex.toStr()]

		rowItemFocusPercents = m.rowItemFocusPercents[currentRowIndex.toStr()]
		if rowItemFocusPercents = invalid then
			rowItemFocusPercents = {}
			m.rowItemFocusPercents[currentRowIndex.toStr()] = rowItemFocusPercents
		end if

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

			previousFocusPercent = rowItemFocusPercents[rowItemIndex]
			if previousFocusPercent <> focusPercent then
				' print "Row " currentRowIndex " item " rowItemIndex " horizontal translation difference from focus: " difference " focusPercent: " focusPercent
				rowItemFocusPercents[rowItemIndex] = focusPercent
				conditionallySetField(rowItemNode, "focusPercent", focusPercent)

				if focusPercent = 1 then
					conditionallySetField(rowItemNode, "itemHasFocus", true)
				else if previousFocusPercent = 1 then
					conditionallySetField(rowItemNode, "itemHasFocus", false)
				end if
			end if
		end for
		' print "calculate focusPercent and itemHasFocus took:" ; t.totalMicroseconds() / 1000000
	end if

	allAnimationsCompleted = isFocusFeedbackAnimationCompleted AND isVerticalScrollTranslationYAnimationCompleted AND isCurrentFocusedRowItemTranslationXAnimationCompleted AND isAllRowItemAnimationsCompleted

	' We are using control for knowing if the timer is already running so need to set it to stop so conditionallyStartAnimationTimer restarts properly
	m.animationTimer.control = "stop"

	if allAnimationsCompleted = false then
		conditionallyStartAnimationTimer()
	else
		' Do one final cleanup
		recycleOffscreenNodes()
		m.offscreenNodesTimer.control = "start"
	end if
end sub


function animateFocusFeedback(changeAmount) as Boolean
	isFocusFeedbackWidthAnimationCompleted = true
	currentFocusFeedbackWidth = m.focusFeedbackPoster.width
	animateTo = m.focusFeedbackWidthAnimateTo

	' If current width is 0 we just jump to the target width
	if currentFocusFeedbackWidth = 0 then
		currentFocusFeedbackWidth = animateTo
		m.focusFeedbackPoster.width = animateTo
	end if

	if animateTo > currentFocusFeedbackWidth then
		newWidth = currentFocusFeedbackWidth + changeAmount
		if newWidth > animateTo then
			newWidth = animateTo
		else
			isFocusFeedbackWidthAnimationCompleted = false
		end if

		m.focusFeedbackPoster.width = newWidth
	else if animateTo < currentFocusFeedbackWidth then
		newWidth = currentFocusFeedbackWidth - changeAmount
		if newWidth < animateTo then
			newWidth = animateTo
		else
			isFocusFeedbackWidthAnimationCompleted = false
		end if

		m.focusFeedbackPoster.width = newWidth
	end if

	isFocusFeedbackHeightAnimationCompleted = true
	currentFocusFeedbackHeight = m.focusFeedbackPoster.height
	animateTo = m.focusFeedbackHeightAnimateTo

	' If current height is 0 we just jump to the target height
	if currentFocusFeedbackHeight = 0 then
		currentFocusFeedbackHeight = animateTo
		m.focusFeedbackPoster.height = animateTo
	end if

	if animateTo > currentFocusFeedbackHeight then
		newHeight = currentFocusFeedbackHeight + changeAmount
		if newHeight > animateTo then
			newHeight = animateTo
		else
			isFocusFeedbackHeightAnimationCompleted = false
		end if

		m.focusFeedbackPoster.height = newHeight
	else if animateTo < currentFocusFeedbackHeight then
		newHeight = currentFocusFeedbackHeight - changeAmount
		if newHeight < animateTo then
			newHeight = animateTo
		else
			isFocusFeedbackHeightAnimationCompleted = false
		end if

		m.focusFeedbackPoster.height = newHeight
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

		m.focusFeedback.translation = [m.focusFeedback.translation[0], newTranslationY]
	else if animateTo > currentFocusFeedbackYTranslation then
		newTranslationY = currentFocusFeedbackYTranslation + changeAmount
		if newTranslationY > animateTo then
			newTranslationY = animateTo
		else
			isFocusFeedbackTranslationYAnimationCompleted = false
		end if

		m.focusFeedback.translation = [m.focusFeedback.translation[0], newTranslationY]
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
		conditionallyThrow("No currently focused item index for row " + rowIndex.toStr())
		return
	end if

	focusedRowItemNode = renderedRowItems[currentlyFocusedItemIndex.toStr()]
	if focusedRowItemNode = invalid then
		conditionallyThrow("Focused row item node invalid for row " + rowIndex.toStr() + " item " + currentlyFocusedItemIndex.toStr())
		return
	end if

	' For items before the currently focused item we need to subtract the xOffset changes from the item to the right of it recursively to get the new translation
	lastRowItemNode = focusedRowItemNode
	for i = currentlyFocusedItemIndex - 1 to m.rowsRenderedNodesRanges[rowIndex].start step -1
		currentRowItemNode = renderedRowItems[i.toStr()]
		if currentRowItemNode = invalid then
			' Gap in rendered nodes (e.g. after a jump). Narrow the range to the last
            ' contiguous valid index and let recycleOffscreenNodes clean up the orphans.
            m.rowsRenderedNodesRanges[rowIndex].start = i + 1
			exit for
		end if

		xTranslation = lastRowItemNode.translation[0] - currentRowItemNode.xOffset

		currentRowItemNode.translation = [xTranslation, currentRowItemNode.translation[1]]

		lastRowItemNode = currentRowItemNode
	end for

	' For items after the currently focused item we need to add the xOffset changes from the item to the left of it recursively to get the new translation
	lastRowItemNode = focusedRowItemNode
	for i = currentlyFocusedItemIndex + 1 to m.rowsRenderedNodesRanges[rowIndex].end
		currentRowItemNode = renderedRowItems[i.toStr()]
		if currentRowItemNode = invalid then
			' Gap in rendered nodes (e.g. after a jump). Narrow the range to the last
            ' contiguous valid index and let recycleOffscreenNodes clean up the orphans.
            m.rowsRenderedNodesRanges[rowIndex].end = i - 1
            exit for
		end if

		xTranslation = lastRowItemNode.translation[0] + lastRowItemNode.xOffset

		currentRowItemNode.translation = [xTranslation, currentRowItemNode.translation[1]]
		lastRowItemNode = currentRowItemNode
	end for
end sub


' Receives content supplied by the app through the render thread queue.
' The payload is an envelope AA of the shape:
'   {
'     "rowsStartIndex": <int, optional>   ' index at which the message's new rows are placed (append/insert)
'     "isAllRowsLoaded": <bool, optional> ' defaults to true when omitted; set false to have OpenGrid request more rows
'     "rows": [ rowConfig, ... ]          ' a full list, new rows, and/or per-row item updates
'   }
' How each rowConfig is handled depends on the keys it carries and the envelope:
'   - "startIndex" present -> item update: its items are spliced into an existing row (matched by "id",
'                             falling back to "rowIndex") starting at startIndex.
'   - no "startIndex"      -> a new row. It is placed at the next slot starting from the envelope's
'                             rowsStartIndex (or appended to the end when rowsStartIndex is absent).
' Because item updates and new rows are handled independently, a single message can mix both.
' When the envelope has no rowsStartIndex and none of the rows carry a startIndex, the message is a
' bare full list which is treated as a replacement: existing content is torn down and rebuilt.
sub onContentSuppliedMessageReceived(content, msgInfo)
	if content = invalid then
		conditionallyThrow("Content supplied was invalid")
		return
	end if

	rows = content.rows
	if rows = invalid then
		rows = []
	end if

	rowsStartIndex = content.rowsStartIndex

	' A bare list (no rowsStartIndex and no per-row item updates) is a full replacement
	isReplacement = (rowsStartIndex = invalid AND containsNoItemUpdates(rows))
	if isReplacement then
		tearDownContent()
	end if

	wasEmpty = isReplacement OR (m.content.count() = 0)

	' Running index used to place new rows. Starts from the envelope's rowsStartIndex, or the end of
	' the current content when not provided (or 0 for a replacement, since content was just cleared).
	if rowsStartIndex <> invalid then
		nextNewRowIndex = rowsStartIndex
	else
		nextNewRowIndex = m.content.count()
	end if

	for each rowConfig in rows
		if rowConfig.startIndex <> invalid then
			applyRowUpdate(rowConfig)
		else
			ingestRowConfig(rowConfig, nextNewRowIndex)
			nextNewRowIndex++
		end if
	end for

	' New content arrived so allow future row-item requests. isAllRowsLoaded defaults to true when the
	' envelope omits it, so a client that never opts in to row pagination won't be asked for more rows.
	m.rowsContentRequested = false
	isAllRowsLoaded = content.isAllRowsLoaded
	if isAllRowsLoaded = invalid then
		isAllRowsLoaded = true
	end if
	m.isAllRowsLoaded = isAllRowsLoaded

	if wasEmpty AND m.content.count() > 0 then
		' Initial load / replacement: focus the first item and reveal the focus feedback
		navigateToRowItem(0, 0, false)
		m.focusFeedback.visible = true
	else
		' Render anything newly available
		m.offscreenNodesTimer.control = "start"
	end if
end sub


' Returns true when none of the supplied rows carry a startIndex (item update), meaning the message is
' purely a list of rows rather than containing per-row item updates.
function containsNoItemUpdates(rows as Object) as Boolean
	for each rowConfig in rows
		if rowConfig.startIndex <> invalid then
			return false
		end if
	end for

	return true
end function


' Tears down all existing rows and rendering state so content can be rebuilt from scratch.
sub tearDownContent()
	m.verticalScroll.removeChildren(m.verticalScroll.getChildren(-1, 0))
	m.content = []
	m.renderedRows = {}
	m.top.setRef("renderedRowsRef", m.renderedRows)
	m.rowNodes = []
	m.rowHeaderNodes = []
	m.rowItemsContainerNodes = []
	m.rowsRenderedNodesRanges = []
	m.lastFocusedItemIndexByRow = []
	m.availableRecycledNodes = {}
	m.rowFocusPercents = {}
	m.rowItemFocusPercents = {}
	m.rowsContentRequested = false
	m.isAllRowsLoaded = true
end sub


' Sets up all the bookkeeping (row node, metadata, ranges) for a single row config at rowIndex.
sub ingestRowConfig(rowConfig as Object, rowIndex as Integer)
	m.content[rowIndex] = rowConfig
	initRowMetadata(rowConfig)

	if m.rowNodes[rowIndex] = invalid then
		rowNode = createObject("roSGNode", "Group")
		m.rowNodes[rowIndex] = rowNode
		m.verticalScroll.appendChild(rowNode)
	end if

	if m.lastFocusedItemIndexByRow[rowIndex] = invalid then
		m.lastFocusedItemIndexByRow[rowIndex] = 0
	end if

	if m.rowsRenderedNodesRanges[rowIndex] = invalid then
		m.rowsRenderedNodesRanges[rowIndex] = { "start": -1, "end": -1 }
	end if
end sub


' Initializes OpenGrid-managed pagination metadata on a row config. Assigns an id (using the
' client-supplied id when present, otherwise a generated UUID) and defaults isAllRowContentLoaded to
' true when the client does not supply it so we don't keep requesting content nobody is listening for.
sub initRowMetadata(rowConfig as Object)
	metadata = rowConfig[m.rowMetadataKey]
	if metadata <> invalid then
		return
	end if

	if rowConfig.id <> invalid then
		rowId = rowConfig.id
	else
		rowId = createObject("roDeviceInfo").getRandomUUID()
	end if

	isAllRowContentLoaded = rowConfig.isAllRowContentLoaded
	if isAllRowContentLoaded = invalid then
		isAllRowContentLoaded = true
	end if

	rowConfig[m.rowMetadataKey] = {
		"id": rowId
		"isAllRowContentLoaded": isAllRowContentLoaded
		"contentRequested": false
	}
end sub


' Applies a partial per-row item update (append or replace) matched by id, falling back to startIndex/index.
sub applyRowUpdate(rowConfig as Object)
	startIndex = rowConfig.startIndex
	if startIndex = invalid then
		conditionallyThrow("Row update missing startIndex")
		return
	end if

	rowIndex = findRowIndexForUpdate(rowConfig)
	if rowIndex = -1 then
		conditionallyThrow("Could not match row update to an existing row")
		return
	end if

	existingRowConfig = m.content[rowIndex]
	metadata = existingRowConfig[m.rowMetadataKey]

	newItems = rowConfig.items
	if newItems <> invalid then
		items = existingRowConfig.items
		for i = 0 to newItems.count() - 1
			items[startIndex + i] = newItems[i]
		end for
	end if

	' Update the loaded flag if the response provides one and clear the in-flight guard
	if rowConfig.isAllRowContentLoaded <> invalid then
		metadata.isAllRowContentLoaded = rowConfig.isAllRowContentLoaded
	end if
	metadata.contentRequested = false
end sub


' Finds the index of the row that a partial update targets, matching by id when present and falling
' back to the row's index. Returns -1 when no match is found.
function findRowIndexForUpdate(rowConfig as Object) as Integer
	rowId = rowConfig.id
	if rowId <> invalid then
		for i = 0 to m.content.count() - 1
			existingRowConfig = m.content[i]
			metadata = existingRowConfig[m.rowMetadataKey]
			if metadata <> invalid AND metadata.id = rowId then
				return i
			end if
		end for
		return -1
	end if

	rowIndex = rowConfig.rowIndex
	if rowIndex <> invalid AND rowIndex >= 0 AND rowIndex < m.content.count() then
		return rowIndex
	end if

	return -1
end function


' Navigate to a specific row and item index
' Returns true if navigation was successful, false if not (out of bounds or no composition loaded)
function navigateToRowItem(rowIndex as Integer, rowItemIndex as Integer, animate as Boolean) as Boolean
	rowContent = m.content[rowIndex]
	if rowContent = invalid then
		print "No content for row at index" rowIndex
		return false
	end if

	rowItemContent = rowContent.items[rowItemIndex]
	if rowItemContent = invalid then
		print "No content for row item at index" rowItemIndex " in row" rowIndex
		return false
	end if

	' We make the nodes that are showing onscreen or necessary for the transition up front. Nodes outside of teh onscreen view will be created by offscreenNodesTimer
	createOnscreenNodes(rowIndex, rowItemIndex)

	renderedRow = m.renderedRows[rowIndex.toStr()]
	if renderedRow = invalid then
		conditionallyThrow("No rendered row")
		return false
	end if

	rowItemNode = renderedRow[rowItemIndex.toStr()]
	if rowItemNode = invalid then
		conditionallyThrow("No loaded item")
		return false
	end if

	m.currentRowIndex = rowIndex
	m.lastFocusedItemIndexByRow[rowIndex] = rowItemIndex

	m.focusFeedbackWidthAnimateTo = rowItemNode.width + m.focusFeedbackWidthExtension
	m.focusFeedbackHeightAnimateTo = rowItemNode.height + m.focusFeedbackHeightExtension

	animateToRow(rowIndex, animate)

	m.currentRowHeaderIsFocused = false

	rowItemNode.setFocus(true)

	m.top.setRef("focusedRowItemInfo", {
		"rowIndex": rowIndex
		"rowItemIndex": rowItemIndex
		"content": rowItemContent
		"rowContent": rowContent
		"node": rowItemNode
	})
	m.top.focusedRowItemInfoChanged = true

	' Check if navigating here means we are close enough to the end of content to request more
	requestContentIfNeeded(rowIndex, rowItemIndex)

	' Stop offscreen timer if we are about to animate
	if animate = true then
		m.offscreenNodesTimer.control = "stop"
	end if

	return true
end function


' Centralized pagination check. Builds a single contentNeeded envelope describing any content that is
' needed based on the current focus position (more items for the focused row and/or more rows) and
' assigns it once so the app can fetch and supply it back through contentQueueId.
sub requestContentIfNeeded(rowIndex as Integer, rowItemIndex as Integer)
	requestRows = []

	' More items for the focused row
	rowRequest = checkRowContentNeeded(rowIndex, rowItemIndex)
	if rowRequest <> invalid then
		requestRows.push(rowRequest)
	end if

	' More rows for the grid
	rowsStartIndex = invalid
	if m.isAllRowsLoaded = false AND m.rowsContentRequested = false AND rowIndex >= m.content.count() - m.rowContentNeededThreshold then
		rowsStartIndex = m.content.count()
		m.rowsContentRequested = true
	end if

	if requestRows.isEmpty() AND rowsStartIndex = invalid then
		return
	end if

	envelope = { "rows": requestRows }
	if rowsStartIndex <> invalid then
		envelope.rowsStartIndex = rowsStartIndex
	end if

	m.top.contentNeeded = envelope
end sub


' Returns a minimal row request { "id": <string>, "startIndex": <int> } when the focused item is close
' enough to the end of the row's items to warrant loading more, or invalid otherwise. Guarded by the
' row's isAllContentLoaded flag and its contentRequested in-flight flag (which this sets when emitting).
function checkRowContentNeeded(rowIndex as Integer, rowItemIndex as Integer) as Object
	rowConfig = m.content[rowIndex]
	if rowConfig = invalid then
		return invalid
	end if

	metadata = rowConfig[m.rowMetadataKey]
	if metadata = invalid then
		return invalid
	end if

	if metadata.isAllRowContentLoaded = true OR metadata.contentRequested = true then
		return invalid
	end if

	itemCount = rowConfig.items.count()
	if rowItemIndex < itemCount - m.rowItemContentNeededThreshold then
		return invalid
	end if

	metadata.contentRequested = true

	return {
		"id": metadata.id
		"startIndex": itemCount
	}
end function


function animateToRow(rowIndex as Integer, animate as Boolean)
	currentRowHeaderHeight = 0
	header = m.rowHeaderNodes[rowIndex]
	if header <> invalid then
		currentRowHeaderHeight = header.height
	end if

	m.focusFeedbackTranslationYAnimateTo = currentRowHeaderHeight + m.focusYOffset

	m.verticalScrollTranslationYAnimateTo = -m.rowNodes[rowIndex].translation[1] + m.focusYOffset

	if animate AND m.disableAnimation <> true then
		conditionallyStartAnimationTimer()
	else
		tempDisableAnimation = m.disableAnimation
		m.disableAnimation = true
		onAnimationTimerFired()
		m.disableAnimation = tempDisableAnimation
	end if
end function


function navigateToLastFocusedRowItem(rowIndex as Integer) as Boolean
	currentItemIndex = m.lastFocusedItemIndexByRow[rowIndex]

	if currentItemIndex = invalid then
		return false
	end if

	return navigateToRowItem(rowIndex, currentItemIndex, true)
end function


function navigateToRelativeRowItem(rowIndex as Integer, itemIndexOffset as Integer) as Boolean
	currentItemIndex = m.lastFocusedItemIndexByRow[rowIndex]

	if currentItemIndex = invalid then
		return false
	end if

	newItemIndex = currentItemIndex + itemIndexOffset

	return navigateToRowItem(rowIndex, newItemIndex, true)
end function


function onKeyHoldTimerFired()
	' After initial key press we want to speed up the navigation so reduce the timer duration and trigger another key event with the same key to navigate again
	m.keyHoldTimer.duration = 0.25
	onKeyEvent(m.keyHoldTimer.id, true)
end function


function navigateUp()
	' See if we have a focusable header that we need to switch focus to
	headerNode = m.rowHeaderNodes[m.currentRowIndex]
	if headerNode <> invalid AND headerNode.focusable = true AND headerNode.isInFocusChain() = false then
		focusHeader(headerNode)
		return true
	end if

	m.focusFeedback.visible = true
	return navigateToLastFocusedRowItem(m.currentRowIndex - 1)
end function


function isHeaderFocused() as Boolean
	headerNode = m.rowHeaderNodes[m.currentRowIndex]
	if headerNode <> invalid AND headerNode.isInFocusChain() = true then
		return true
	end if

	return false
end function


function navigateDown()
	' See if we have are currently focused on a header and if so we want to navigate to the current row instead of the next
	if isHeaderFocused() then
		m.focusFeedback.visible = true
		return navigateToLastFocusedRowItem(m.currentRowIndex)
	end if

	nextRowHeaderNode = m.rowHeaderNodes[m.currentRowIndex + 1]
	if nextRowHeaderNode <> invalid AND nextRowHeaderNode.focusable = true then
		' We need to move focus down to the next row and animate to it
		m.currentRowIndex = m.currentRowIndex + 1
		animateToRow(m.currentRowIndex, true)
		focusHeader(nextRowHeaderNode)
		return true
	end if

	m.focusFeedback.visible = true
	return navigateToLastFocusedRowItem(m.currentRowIndex + 1)
end function


sub focusHeader(headerNode as Object)
	m.currentRowHeaderIsFocused = true
	headerNode.setFocus(true)

	' Need to hide the focus feedback since we are now focused on a header and not a row item
	m.focusFeedback.visible = false

	m.top.setRef("focusedHeaderInfo", {
		"rowIndex": m.currentRowIndex
		"rowContent": m.content[m.currentRowIndex]
	})
	m.top.focusedHeaderInfoChanged = true
end sub


sub focusCurrentRowItem()
	if m.lastFocusedItemIndexByRow.isEmpty() then
		return
	end if

	m.currentRowHeaderIsFocused = false
	currentRowIndex = m.currentRowIndex
	currentRowItemIndex = m.lastFocusedItemIndexByRow[currentRowIndex]

	renderedRow = m.renderedRows[currentRowIndex.toStr()]
	if renderedRow = invalid then
		conditionallyThrow("No rendered row")
		return
	end if

	rowItemNode = renderedRow[currentRowItemIndex.toStr()]
	if rowItemNode = invalid then
		conditionallyThrow("No loaded item")
		return
	end if

	rowItemNode.setFocus(true)
end sub


function onKeyEvent(key as String, press as Boolean) as Boolean
	if key = "up" OR key = "down" OR key = "left" OR key = "right"  then
		' Using existing id field for simplicity
		m.keyHoldTimer.id = key

		if press = false then
			' User released the key so reset the timer duration and stop it from triggering more events until the next key press
			m.keyHoldTimer.duration = 0.8
			m.keyHoldTimer.control = "stop"
			return false
		end if

		m.keyHoldTimer.control = "start"
	end if

	if press = false then
		return false
	end if

	if key = "up" then
		return navigateUp()
	else if key = "down" then
		return navigateDown()
	else if key = "left" then
		return navigateToRelativeRowItem(m.currentRowIndex, -1)
	else if key = "right" then
		return navigateToRelativeRowItem(m.currentRowIndex, 1)
	else if key = "OK" then
		if isHeaderFocused() then
			rowIndex = m.currentRowIndex
			rowContent = m.content[rowIndex]
			m.top.setRef("selectedHeaderInfo", {
				"rowIndex": rowIndex
				"rowContent": rowContent
			})
			m.top.selectedHeaderInfoChanged = true
		else
			m.top.setRef("selectedRowItemInfo", m.top.getRef("focusedRowItemInfo"))
			m.top.selectedRowItemInfoChanged = true
		end if

		return true
	else
		return false
	end if
end function
