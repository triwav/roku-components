sub init()
	currentDesignResolution = m.top.getScene().currentDesignResolution
	m.width = currentDesignResolution.width
	m.height = currentDesignResolution.height

	' TODO need to add observer for this so it can be changed
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

	' The actual content for the grid, an array of row configs where each row config has an array of item configs
	m.gridContent = []
	' IMPROVEMENT perhaps remove grid prefix from these variable names to make it less verbose

	' The nodes for each row that are currently in the grid, indexed by row index
	m.gridRowNodes = []

	m.gridRowHeaderNodes = []

	' We need to access the item containers quite often so we store them here after they are made
	m.gridRowItemsContainerNodes = []

	' key is row index as string
	m.renderedRows = {}

	m.availableRecycledNodes = {}

	m.renderThreadQueue = createObject("roRenderThreadQueue")
	contentSuppliedQueueId = "OGContentSuppliedQueue:" + createObject("roDeviceInfo").getRandomUUID()

	m.renderThreadQueue.addMessageHandler(contentSuppliedQueueId, "onContentSuppliedMessageReceived")
	m.top.contentSuppliedQueueId = contentSuppliedQueueId


	m.gridVerticalScroll = m.top.findNode("gridVerticalScroll")
	m.focusFeedback = m.top.findNode("focusFeedback")

	' Have to delay load probably due to weird main bug
	m.timer = createObject("roSGNode", "Timer")
	m.timer.duration = 0.1
	m.timer.observeField("fire", "onTimerFired")
	m.timer.control = "start"

	' Used to allow us to stop creating nodes while we are animating and to also avoid time outs
	m.offscreenNodesTimer = createObject("roSGNode", "Timer")
	m.offscreenNodesTimer.duration = 0.01
	m.offscreenNodesTimer.observeFieldScoped("fire", "onOffscreenNodesTimerFired")
	m.offscreenNodesTimer.control = "start"

	m.top.observeFieldScoped("focusXOffset", "onFocusXOffsetChanged")
	m.top.observeFieldScoped("focusYOffset", "onFocusYOffsetChanged")
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
	' FIXME Add optimization to only try to create nodes for the row that changed

	if focusedRowIndex < 0 then
		print "Focused row index is out of bounds: " focusedRowIndex
		return
	end if

	currentRowIndex = focusedRowIndex
	heightRendered = 0
	' Go forward from the focused index
	while m.height + m.extraHeightToRender - m.focusYOffset > heightRendered AND currentRowIndex < m.gridContent.count()
		currentRowConfig = m.gridContent[currentRowIndex]

		rowRenderedNodes = m.renderedRows[currentRowIndex.toStr()]
		if rowRenderedNodes = invalid then
			rowRenderedNodes = {}
			m.renderedRows[currentRowIndex.toStr()] = rowRenderedNodes
		end if

		rowNode = m.gridRowNodes[currentRowIndex]
		if rowNode = invalid then
			' Should never happen
			print "row node invalid for row " currentRowIndex
			return
		end if

		if currentRowIndex = 0 then
			translationY = 0
		else
			previousRowNode = m.gridRowNodes[currentRowIndex - 1]
			translationY = previousRowNode.translation[1] + previousRowNode.yOffset
		end if

		rowNode.translation = [0, translationY]
		rowItemContainerNode = invalid
		rowNodeFirstChild = rowNode.getChild(0)
		if rowNodeFirstChild <> invalid AND rowNodeFirstChild.id = "rowItemsContainer" then
			rowItemContainerNode = rowNodeFirstChild
		else
			rowNodeSecondChild = rowNode.getChild(1)
			if rowNodeSecondChild <> invalid AND rowNodeSecondChild.id = "rowItemsContainer" then
				rowItemContainerNode = rowNodeSecondChild
			end if
		end if

		if rowItemContainerNode = invalid then
			rowItemContainerNode = createObject("roSGNode", "Group")
			rowItemContainerNode.id = "rowItemsContainer"
			rowNode.appendChild(rowItemContainerNode)
		end if

		headerHeight = 0
		header = currentRowConfig.header
		if header <> invalid then
			firstChild = rowNode.getChild(0)
			if firstChild.id <> "rowItemsContainer" then
				' Don't readd the header if it's already been added
				headerHeight = firstChild.height
			else
				headerNode = invalid

				componentName = header.componentName
				if componentName = invalid then
					print "No header componentName included for row " currentRowIndex
				else
					headerNode = createObject("roSGNode", componentName)
				end if

				if headerNode = invalid then
					print "Failed to create header component: " componentName
				else
					headerNode.setRef("content", header)
					headerNode.contentUpdated = true
					rowNode.insertChild(headerNode, 0)
					if headerNode.height = invalid then
						print "Header height not provided for row " currentRowIndex
					else
						headerHeight = headerNode.height
						rowItemContainerNode.translation = [0, headerHeight]
					end if
				end if
			end if
		end if

		yOffset = 0
		currentRowWidthRendered = 0

		if focusedRowIndex = currentRowIndex then
			currentRowItemIndex = focusedRowItemIndex
		else
			currentRowItemIndex = m.lastFocusedItemIndexByRow[currentRowIndex]
		end if

		while currentRowWidthRendered < m.width - m.focusXOffset AND currentRowItemIndex < currentRowConfig.items.count()
			' See if we already made this node
			if rowRenderedNodes[currentRowItemIndex.toStr()] <> invalid then
				print "Node already rendered for row " currentRowIndex " item " currentRowItemIndex
				currentRowItemIndex = currentRowItemIndex + 1
				continue while
			end if

			print "currentRowIndex" currentRowIndex "currentRowItemIndex" currentRowItemIndex "currentRowWidthRendered" currentRowWidthRendered " m.width: " m.width "m.focusXOffset " m.focusXOffset
			rowItemNode = createNodeAndAssignContent(currentRowIndex, currentRowItemIndex)

			if rowItemNode <> invalid then
				if yOffset = 0 then
					if rowItemNode.hasField("yOffset") then
						yOffset = rowItemNode.yOffset
					end if
				end if

				translationX = 0
				if currentRowItemIndex <> 0
					previousRowItemNode = rowRenderedNodes[(currentRowItemIndex - 1).toStr()]
					if previousRowItemNode = invalid then
						' We get in this case when scrolling back left so we need to take our translation from the right item instead of the left
						nextNode = rowRenderedNodes[(currentRowItemIndex + 1).toStr()]
						translationX = nextNode.translation[0] - rowItemNode.xOffset

						rowItemNode.translation = [translationX, 0]
					else
						translationX = previousRowItemNode.translation[0] + previousRowItemNode.xOffset
						rowItemNode.translation = [translationX, 0]
					end if
				end if

				rowItemContainerNode.appendChild(rowItemNode)

				xOffset = rowItemNode.xOffset
				currentRowWidthRendered += xOffset
				currentRowItemIndex = currentRowItemIndex + 1
			end if
		end while

		' If we have a focusXOffset then we want to add one more before the focused row item if it does not already exist to keep the peek
		if m.focusXOffset > 0 AND focusedRowItemIndex > 0 then
			previousRowItemIndex = focusedRowItemIndex - 1
			if rowRenderedNodes[previousRowItemIndex.toStr()] = invalid then
				rowItemNode = createNodeAndAssignContent(currentRowIndex, previousRowItemIndex)

				focusedRowItem = rowRenderedNodes[(focusedRowItemIndex).toStr()]
				translationX = focusedRowItem.translation[0] - rowItemNode.xOffset

				rowItemNode.translation = [translationX, 0]

				rowItemContainerNode.insertChild(rowItemNode, 0)
			end if
		end if

		' Same thing for focusYOffset but for the whole row
		if m.focusYOffset > 0 AND focusedRowIndex > 0 then
			previousRowIndex = focusedRowIndex - 1

			currentRowItemIndex = m.lastFocusedItemIndexByRow[previousRowIndex]

			rowRenderedNodes = m.renderedRows[previousRowIndex.toStr()]
			if rowRenderedNodes = invalid OR rowRenderedNodes.count() = 0 then
				rowRenderedNodes = {}
				m.renderedRows[previousRowIndex.toStr()] = rowRenderedNodes

				' TODO figure out how to avoid duplication

				while currentRowWidthRendered < m.width - m.focusXOffset AND currentRowItemIndex < currentRowConfig.items.count()
					' See if we already made this node
					if rowRenderedNodes[currentRowItemIndex.toStr()] <> invalid then
						print "Node already rendered for row " currentRowIndex " item " currentRowItemIndex
						currentRowItemIndex = currentRowItemIndex + 1
						continue while
					end if

					print "currentRowIndex" currentRowIndex "currentRowItemIndex" currentRowItemIndex "currentRowWidthRendered" currentRowWidthRendered " m.width: " m.width "m.focusXOffset " m.focusXOffset
					rowItemNode = createNodeAndAssignContent(currentRowIndex, currentRowItemIndex)

					if rowItemNode <> invalid then
						if yOffset = 0 then
							if rowItemNode.hasField("yOffset") then
								yOffset = rowItemNode.yOffset
							end if
						end if

						translationX = 0
						if currentRowItemIndex <> 0
							previousRowItemNode = rowRenderedNodes[(currentRowItemIndex - 1).toStr()]
							if previousRowItemNode = invalid then
								' We get in this case when scrolling back left so we need to take our translation from the right item instead of the left
								nextNode = rowRenderedNodes[(currentRowItemIndex + 1).toStr()]
								translationX = nextNode.translation[0] - rowItemNode.xOffset

								rowItemNode.translation = [translationX, 0]
							else
								translationX = previousRowItemNode.translation[0] + previousRowItemNode.xOffset
								rowItemNode.translation = [translationX, 0]
							end if
						end if

						rowItemContainerNode.appendChild(rowItemNode)

						xOffset = rowItemNode.xOffset
						currentRowWidthRendered += xOffset
						currentRowItemIndex = currentRowItemIndex + 1
					end if
				end while
			else
				print "Row " previousRowIndex " already rendered" rowRenderedNodes.count()
			end if
		end if


		rowNode.headerHeight = headerHeight
		rowNode.yOffset = yOffset + headerHeight
		heightRendered += yOffset + headerHeight
		currentRowIndex = currentRowIndex + 1
	end while

	' Now go backward from the focused index to render content above the focused row
	currentRowIndex = focusedRowIndex - 1
	heightRendered = 0
	' while m.extraHeightToRender + m.focusYOffset > heightRendered AND currentRowIndex >= 0

	' 	yOffset = 0
	' 	currentRowWidthRendered = 0
	' 	currentRowItemIndex = m.lastFocusedItemIndexByRow[currentRowIndex]
	' 	reverseRowItemIndex = currentRowItemIndex - 1
	' 	while currentRowWidthRendered < m.width - m.focusXOffset AND currentRowItemIndex >= 0
	' 	end while
	' end while
end sub


sub renderRow(rowIndex as Integer, focusedRowIndex as Integer, focusedRowItemIndex as Integer)
	m.gridRowItemsContainerNodes[rowIndex] = createObject("roSGNode", "Group")

end sub


sub recycleOffscreenNodes()
	' Shallow clone so we can have different policies based on the row
	renderedRows = m.renderedRows

	' Next handle other rows
	for each rowIndex in renderedRows
		' First check if this is outside the vertical render area, if it is then we can recycle the entire row without needing to check each individual item
		translationDifference = calculateRowVerticalTranslationDifference(rowIndex.toInt())
		if translationDifference > m.height - m.focusYOffset + m.extraHeightToRender OR translationDifference + m.focusYOffset < -m.extraHeightToRender then
			print "Recycling entire row " rowIndex " with vertical translation difference of " translationDifference

			' Recycle entire row
			for each rowItemIndex in renderedRows[rowIndex]
				recycleNode(rowIndex, rowItemIndex)
			end for

			renderedRows.delete(rowIndex)

			continue for
		end if

		' Now handle rendered rows that are within the vertical render area but may have items that are outside the horizontal render area

		' Check if this is the currently focused row as we may want to have different horizontal render area thresholds for the focused row vs the non-focused rows

		if rowIndex.toInt() = m.currentRowIndex then
			' Focused row, use focused row render area thresholds
			print "Checking horizontal thresholds for focused row " rowIndex

			for each rowItemIndex in renderedRows[rowIndex]
				rowItemNode = renderedRows[rowIndex][rowItemIndex]

				translationDifference = calculateHorizontalTranslationDifference(rowItemNode, rowItemIndex)
				if translationDifference > m.width - m.focusXOffset + m.extraWidthToRenderFocusedRow OR translationDifference + rowItemNode.width < -m.focusXOffset - m.extraWidthToRenderFocusedRow then
					recycleNode(rowIndex, rowItemIndex)
				end if
			end for
		else
			' Non-focused row, use non-focused row render area thresholds
			print "Checking horizontal thresholds for non-focused row " rowIndex

			for each rowItemIndex in renderedRows[rowIndex]
				rowItemNode = renderedRows[rowIndex][rowItemIndex]

				translationDifference = calculateHorizontalTranslationDifference(rowItemNode, rowItemIndex)
				if translationDifference > m.width - m.focusXOffset + m.extraWidthToRenderNonFocusedRow OR translationDifference + rowItemNode.width < -m.focusXOffset - m.extraWidthToRenderNonFocusedRow then
					recycleNode(rowIndex, rowItemIndex)
				end if
			end for
		end if
	end for
end sub


sub recycleNode(rowIndex as String, rowItemIndex as String)
	print "Recycling node for row " rowIndex " item " rowItemIndex
	renderedRows = m.renderedRows
	rowItemNode = renderedRows[rowIndex.toStr()][rowItemIndex.toStr()]

	nodeTypeAvailableRecycledNodes = m.availableRecycledNodes[rowItemNode.subtype()]
	if nodeTypeAvailableRecycledNodes = invalid then
		nodeTypeAvailableRecycledNodes = []
		m.availableRecycledNodes[rowItemNode.subtype()] = nodeTypeAvailableRecycledNodes
	end if
	nodeTypeAvailableRecycledNodes.push(rowItemNode)

	renderedRows[rowIndex].delete(rowItemIndex)

	m.gridContent[rowIndex.toInt()].items[rowItemIndex.toInt()].contentAssigned = false

	rowItemContainerNode = rowItemNode.getParent()
	rowItemContainerNode.removeChild(rowItemNode)
end sub


sub onOffscreenNodesTimerFired()
	' If we successfully made a node then start the timer again to keep making nodes until we have rendered everything within the render area, if we did not successfully make a node then that means we have rendered everything we can for the current render area
	if createOffscreenNode() then
		m.offscreenNodesTimer.control = "start"
	end if
end sub


' Tries to create an offscreen node if one has not been rendered yet
function createOffscreenNode() as Boolean
	return true

end function


function createNodeAndAssignContent(rowIndex as Integer, rowItemIndex as Integer)
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
			print "Reusing node from recycled pool for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName
			rowItemNode = m.availableRecycledNodes[itemComponentName].pop()
		else
			print "Creating node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName
			rowItemNode = createObject("roSGNode", itemComponentName)
		end if
		rowRenderedNodes[rowItemIndex.toStr()] = rowItemNode
	end if

	if rowItemNode = invalid then
		print "Could not get node for row " rowIndex " item " rowItemIndex " with componentName: " + itemComponentName
	else
		rowItemContent = rowGridContent.items[rowItemIndex]
		' Only set content if we have not already to improve performance
		if rowItemContent.contentAssigned <> true then
			rowItemNode.rowIndex = rowIndex
			rowItemNode.rowItemIndex = rowItemIndex
			rowItemNode.setRef("content", rowItemContent)
			rowItemNode.contentUpdated = true
			rowItemContent.contentAssigned = true
		else
			' print "Content already assigned for row " currentRowIndex " item " currentRowItemIndex
		end if
	end if

	return rowItemNode
end function


' Calculates the horizontal distance from the currently focused node to this node
function calculateHorizontalTranslationDifference(rowItemNode, rowItemIndex as String) as Float
	rowItemContainerNode = rowItemNode.getParent()
	rowXTranslation = rowItemContainerNode.translation[0]

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


sub onTimerFired()
	m.top.setRef("renderedRowsRef", m.renderedRows)
	addGridContent()
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
			' IMPROVEMENT could reuse these in the future although pretty cheap to make
			rowNode = createObject("roSGNode", "Group")
			rowNode.update({
				"yOffset": 0
				"headerHeight": 0
			}, true)
			m.lastFocusedItemIndexByRow[rowIndex] = 0

			previousRowIndex = previousRowIndex + 1
			rowIndex = previousRowIndex
			isUpdate = false
		' end if

		m.gridRowNodes[rowIndex] = rowNode

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
	' TODO needs to be updated to handle navigating to rows/items that haven't been loaded yet, for now just return false if we try to navigate to something that hasn't been loaded yet
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
		stop
		print "No loaded item at index" rowItemIndex " in row" rowIndex
		return false
	end if

	m.currentRowIndex = rowIndex
	m.lastFocusedItemIndexByRow[rowIndex] = rowItemIndex
	m.focusFeedback.width = rowItemNode.width
	m.focusFeedback.height = rowItemNode.height

	gridRowNode = m.gridRowNodes[rowIndex]

	m.focusFeedback.translation = [m.focusFeedback.translation[0], m.focusYOffset + gridRowNode.headerHeight]

	rowFirstChild = m.gridRowNodes[rowIndex].getChild(0)

	rowItemsContainerNode = invalid
	if rowFirstChild.id = "rowItemsContainer" then
		rowItemsContainerNode = rowFirstChild
	else
		secondChild = m.gridRowNodes[rowIndex].getChild(1)
		if secondChild.id = "rowItemsContainer" then
			rowItemsContainerNode = secondChild
		end if
	end if

	if rowItemsContainerNode = invalid then
		print "Could not find row items container for row " rowIndex
		return false
	end if

	containerTranslationY = gridRowNode.translation[1]
	m.gridVerticalScroll.translation = [m.focusXOffset, -containerTranslationY + m.focusYOffset]

	rowItemsContainerNode.translation = [-rowItemNode.translation[0], rowItemsContainerNode.translation[1]]

	rowItemNode.setFocus(true)

	' ' Next go ahead and cleanup any nodes that are now outside the renderer area due to this navigation
	recycleOffscreenNodes()

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





























sub addGridContent()
	rows = [
		{
			' "rowIndex": 0
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Popular Movies"
			}
			items: [
				{ "title": "Avatar The Way of Water", "imageUrl": "https://picsum.photos/seed/avatar-the-way-of-water" },
				{ "componentName": "GridItemRenderer", "title": "Top Gun Maverick", "imageUrl": "https://picsum.photos/seed/top-gun-maverick" },
				{ "title": "Avengers Endgame", "imageUrl": "https://picsum.photos/seed/avengers-endgame" },
				{ "title": "Black Panther Wakanda Forever", "imageUrl": "https://picsum.photos/seed/black-panther-wakanda-forever" },
				{ "title": "Spider-Man No Way Home", "imageUrl": "https://picsum.photos/seed/spider-man-no-way-home" },
				{ "title": "Jurassic World Dominion", "imageUrl": "https://picsum.photos/seed/jurassic-world-dominion" },
				{ "title": "The Batman", "imageUrl": "https://picsum.photos/seed/the-batman" },
				{ "title": "Dune", "imageUrl": "https://picsum.photos/seed/dune" },
				{ "title": "Mission Impossible Fallout", "imageUrl": "https://picsum.photos/seed/mission-impossible-fallout" },
				{ "title": "Titanic", "imageUrl": "https://picsum.photos/seed/titanic-movie" },
				{ "title": "Inception", "imageUrl": "https://picsum.photos/seed/inception" },
				{ "title": "Interstellar", "imageUrl": "https://picsum.photos/seed/interstellar" },
				{ "title": "The Dark Knight", "imageUrl": "https://picsum.photos/seed/the-dark-knight" },
				{ "title": "Guardians of the Galaxy Vol 3", "imageUrl": "https://picsum.photos/seed/guardians-vol-3" },
				{ "title": "Frozen II", "imageUrl": "https://picsum.photos/seed/frozen-ii" },
				{ "title": "Toy Story 4", "imageUrl": "https://picsum.photos/seed/toy-story-4" },
				{ "title": "The Irishman", "imageUrl": "https://picsum.photos/seed/the-irishman" },
				{ "title": "Star Wars The Rise of Skywalker", "imageUrl": "https://picsum.photos/seed/star-wars-rise" },
				{ "title": "Parasite", "imageUrl": "https://picsum.photos/seed/parasite-movie" },
				{ "title": "Joker", "imageUrl": "https://picsum.photos/seed/joker-movie" }
			]
		},
		{
			' "rowIndex": 1
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Top Rated"
			}
			items: [
				{ "title": "The Shawshank Redemption", "imageUrl": "https://picsum.photos/seed/shawshank-redemption" },
				{ "title": "The Godfather", "imageUrl": "https://picsum.photos/seed/the-godfather" },
				{ "title": "The Godfather Part II", "imageUrl": "https://picsum.photos/seed/godfather-part-ii" },
				{ "title": "Pulp Fiction", "imageUrl": "https://picsum.photos/seed/pulp-fiction" },
				{ "title": "Schindlers List", "imageUrl": "https://picsum.photos/seed/schindlers-list" },
				{ "title": "12 Angry Men", "imageUrl": "https://picsum.photos/seed/12-angry-men" },
				{ "title": "The Return of the King", "imageUrl": "https://picsum.photos/seed/return-of-the-king" },
				{ "title": "Fight Club", "imageUrl": "https://picsum.photos/seed/fight-club" },
				{ "title": "Forrest Gump", "imageUrl": "https://picsum.photos/seed/forrest-gump" },
				{ "title": "The Fellowship of the Ring", "imageUrl": "https://picsum.photos/seed/fellowship-of-the-ring" },
				{ "title": "The Two Towers", "imageUrl": "https://picsum.photos/seed/the-two-towers" },
				{ "title": "Goodfellas", "imageUrl": "https://picsum.photos/seed/goodfellas" },
				{ "title": "The Matrix", "imageUrl": "https://picsum.photos/seed/the-matrix" },
				{ "title": "One Flew Over the Cuckoos Nest", "imageUrl": "https://picsum.photos/seed/one-flew-over" },
				{ "title": "Se7en", "imageUrl": "https://picsum.photos/seed/se7en" },
				{ "title": "City of God", "imageUrl": "https://picsum.photos/seed/city-of-god" },
				{ "title": "The Silence of the Lambs", "imageUrl": "https://picsum.photos/seed/silence-of-the-lambs" },
				{ "title": "Its a Wonderful Life", "imageUrl": "https://picsum.photos/seed/its-a-wonderful-life" },
				{ "title": "The Green Mile", "imageUrl": "https://picsum.photos/seed/the-green-mile" },
				{ "title": "Life Is Beautiful", "imageUrl": "https://picsum.photos/seed/life-is-beautiful" }
			]
		},
		{
			' "rowIndex": 2
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Action"
			}
			items: [
				{ "title": "John Wick", "imageUrl": "https://picsum.photos/seed/john-wick" },
				{ "title": "Mad Max Fury Road", "imageUrl": "https://picsum.photos/seed/mad-max-fury-road" },
				{ "title": "Gladiator", "imageUrl": "https://picsum.photos/seed/gladiator" },
				{ "title": "Die Hard", "imageUrl": "https://picsum.photos/seed/die-hard" },
				{ "title": "Casino Royale", "imageUrl": "https://picsum.photos/seed/casino-royale" },
				{ "title": "Skyfall", "imageUrl": "https://picsum.photos/seed/skyfall" },
				{ "title": "The Bourne Ultimatum", "imageUrl": "https://picsum.photos/seed/bourne-ultimatum" },
				{ "title": "The Raid Redemption", "imageUrl": "https://picsum.photos/seed/the-raid-redemption" },
				{ "title": "Logan", "imageUrl": "https://picsum.photos/seed/logan" },
				{ "title": "The Avengers", "imageUrl": "https://picsum.photos/seed/the-avengers" },
				{ "title": "Terminator 2 Judgment Day", "imageUrl": "https://picsum.photos/seed/terminator-2" },
				{ "title": "Oldboy", "imageUrl": "https://picsum.photos/seed/oldboy" },
				{ "title": "Atomic Blonde", "imageUrl": "https://picsum.photos/seed/atomic-blonde" },
				{ "title": "Heat", "imageUrl": "https://picsum.photos/seed/heat-movie" },
				{ "title": "Leon The Professional", "imageUrl": "https://picsum.photos/seed/leon-the-professional" },
				{ "title": "FaceOff", "imageUrl": "https://picsum.photos/seed/faceoff" },
				{ "title": "Taken", "imageUrl": "https://picsum.photos/seed/taken" },
				{ "title": "The Dark Knight Rises", "imageUrl": "https://picsum.photos/seed/dark-knight-rises" },
				{ "title": "Crouching Tiger Hidden Dragon", "imageUrl": "https://picsum.photos/seed/crouching-tiger-hidden-dragon" }
			]
		},
		{
			' "rowIndex": 3
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Comedy"
			}
			items: [
				{ "title": "The Grand Budapest Hotel", "imageUrl": "https://picsum.photos/seed/grand-budapest-hotel" },
				{ "title": "Superbad", "imageUrl": "https://picsum.photos/seed/superbad" },
				{ "title": "Step Brothers", "imageUrl": "https://picsum.photos/seed/step-brothers" },
				{ "title": "Bridesmaids", "imageUrl": "https://picsum.photos/seed/bridesmaids" },
				{ "title": "The Hangover", "imageUrl": "https://picsum.photos/seed/the-hangover" },
				{ "title": "Anchorman The Legend of Ron Burgundy", "imageUrl": "https://picsum.photos/seed/anchorman" },
				{ "title": "Groundhog Day", "imageUrl": "https://picsum.photos/seed/groundhog-day" },
				{ "title": "Monty Python and the Holy Grail", "imageUrl": "https://picsum.photos/seed/monty-python-holy-grail" },
				{ "title": "Some Like It Hot", "imageUrl": "https://picsum.photos/seed/some-like-it-hot" },
				{ "title": "Mean Girls", "imageUrl": "https://picsum.photos/seed/mean-girls" },
				{ "title": "Airplane", "imageUrl": "https://picsum.photos/seed/airplane-movie" },
				{ "title": "Shaun of the Dead", "imageUrl": "https://picsum.photos/seed/shaun-of-the-dead" },
				{ "title": "Hot Fuzz", "imageUrl": "https://picsum.photos/seed/hot-fuzz" },
				{ "title": "Ghostbusters", "imageUrl": "https://picsum.photos/seed/ghostbusters" },
				{ "title": "The Big Lebowski", "imageUrl": "https://picsum.photos/seed/big-lebowski" },
				{ "title": "Ferris Buellers Day Off", "imageUrl": "https://picsum.photos/seed/ferris-buellers-day-off" },
				{ "title": "Mrs Doubtfire", "imageUrl": "https://picsum.photos/seed/mrs-doubtfire" },
				{ "title": "The 40 Year Old Virgin", "imageUrl": "https://picsum.photos/seed/40-year-old-virgin" },
				{ "title": "Tropic Thunder", "imageUrl": "https://picsum.photos/seed/tropic-thunder" },
				{ "title": "Borat", "imageUrl": "https://picsum.photos/seed/borat" }
			]
		},
		{
			' "rowIndex": 4
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "New Releases"
			}
			items: [
				{ "title": "Oppenheimer", "imageUrl": "https://picsum.photos/seed/oppenheimer" },
				{ "title": "Barbie", "imageUrl": "https://picsum.photos/seed/barbie-movie" },
				{ "title": "Mission Impossible Dead Reckoning", "imageUrl": "https://picsum.photos/seed/mission-impossible-dead-reckoning" },
				{ "title": "Indiana Jones Dial of Destiny", "imageUrl": "https://picsum.photos/seed/indiana-jones-dial-of-destiny" },
				{ "title": "The Little Mermaid", "imageUrl": "https://picsum.photos/seed/the-little-mermaid" },
				{ "title": "John Wick Chapter 4", "imageUrl": "https://picsum.photos/seed/john-wick-chapter-4" },
				{ "title": "Spider-Man Across the Spider-Verse", "imageUrl": "https://picsum.photos/seed/spider-man-across-the-spider-verse" },
				{ "title": "The Super Mario Bros Movie", "imageUrl": "https://picsum.photos/seed/super-mario-bros-movie" },
				{ "title": "Everything Everywhere All At Once", "imageUrl": "https://picsum.photos/seed/everything-everywhere-all-at-once" },
				{ "title": "The Creator", "imageUrl": "https://picsum.photos/seed/the-creator" },
				{ "title": "Ant-Man and the Wasp Quantumania", "imageUrl": "https://picsum.photos/seed/ant-man-quantumania" },
				{ "title": "Shazam Fury of the Gods", "imageUrl": "https://picsum.photos/seed/shazam-fury-of-the-gods" },
				{ "title": "Creed III", "imageUrl": "https://picsum.photos/seed/creed-iii" },
				{ "title": "Haunted Mansion", "imageUrl": "https://picsum.photos/seed/haunted-mansion" },
				{ "title": "The Flash", "imageUrl": "https://picsum.photos/seed/the-flash" },
				{ "title": "Dune Part Two", "imageUrl": "https://picsum.photos/seed/dune-part-two" },
				{ "title": "Wonka", "imageUrl": "https://picsum.photos/seed/wonka-movie" },
				{ "title": "Napoleon", "imageUrl": "https://picsum.photos/seed/napoleon-movie" },
				{ "title": "Killers of the Flower Moon", "imageUrl": "https://picsum.photos/seed/killers-of-the-flower-moon" },
				{ "title": "Poor Things", "imageUrl": "https://picsum.photos/seed/poor-things" }
			]
		}
	]

	rows = [rows[0], rows[1], rows[3], rows[4],rows[0], rows[1], rows[3], rows[4], rows[0], rows[1], rows[3], rows[4], rows[0], rows[1], rows[3], rows[4], rows[0], rows[1], rows[3], rows[4]]

	' rows = [rows[0]]

	' Programmatically alternate every other item component to use GridItemRenderer2
	for each row in rows
		if row.items <> invalid then
			idx = 0
			for each item in row.items
				if (idx mod 2) = 1 then
					item.componentName = "GridItemRenderer2"
				end if
				idx = idx + 1
			end for
		end if
	end for

	m.renderThreadQueue.postMessage(m.top.contentSuppliedQueueId, rows)
end sub
