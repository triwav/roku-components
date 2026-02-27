sub init()
	m.loadedRows = {}

	' stop
	m.renderThreadQueue = createObject("roRenderThreadQueue")
	contentSuppliedQueueId = "OGContentSuppliedQueue:" + createObject("roDeviceInfo").getRandomUUID()

	m.renderThreadQueue.addMessageHandler(contentSuppliedQueueId, "onContentSuppliedMessageReceived")
	m.top.contentSuppliedQueueId = contentSuppliedQueueId

	' Variable default setup
	m.currentRowIndex = 0
	m.rowsCurrentRowItemIndexes = []

	m.gridContent = m.top.findNode("gridContent")
	m.focusFeedback = m.top.findNode("focusFeedback")

	' key is row index as string
	m.gridRenderedNodes = {}

	m.gridRowNodes = []



	m.timer = createObject("roSGNode", "Timer")
	m.timer.duration = 0.1
	m.timer.observeField("fire", "onTimerFired")
	m.timer.control = "start"
end sub

sub onTimerFired()
	m.top.setRef("loadedRowsRef", m.loadedRows)
	addGridContent()
end sub

sub addGridContent()
	rows = [
		{
			"rowIndex": 0
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Popular Movies"
			}
			items: [
				{ "title": "Avatar The Way of Water", "imageUrl": "https://picsum.photos/seed/avatar-the-way-of-water/210/300" },
				{ "title": "Top Gun Maverick", "imageUrl": "https://picsum.photos/seed/top-gun-maverick/210/300" },
				{ "title": "Avengers Endgame", "imageUrl": "https://picsum.photos/seed/avengers-endgame/210/300" },
				{ "title": "Black Panther Wakanda Forever", "imageUrl": "https://picsum.photos/seed/black-panther-wakanda-forever/210/300" },
				{ "title": "Spider-Man No Way Home", "imageUrl": "https://picsum.photos/seed/spider-man-no-way-home/210/300" },
				{ "title": "Jurassic World Dominion", "imageUrl": "https://picsum.photos/seed/jurassic-world-dominion/210/300" },
				{ "title": "The Batman", "imageUrl": "https://picsum.photos/seed/the-batman/210/300" },
				{ "title": "Dune", "imageUrl": "https://picsum.photos/seed/dune/210/300" },
				{ "title": "Mission Impossible Fallout", "imageUrl": "https://picsum.photos/seed/mission-impossible-fallout/210/300" },
				{ "title": "Titanic", "imageUrl": "https://picsum.photos/seed/titanic-movie/210/300" },
				{ "title": "Inception", "imageUrl": "https://picsum.photos/seed/inception/210/300" },
				{ "title": "Interstellar", "imageUrl": "https://picsum.photos/seed/interstellar/210/300" },
				{ "title": "The Dark Knight", "imageUrl": "https://picsum.photos/seed/the-dark-knight/210/300" },
				{ "title": "Guardians of the Galaxy Vol 3", "imageUrl": "https://picsum.photos/seed/guardians-vol-3/210/300" },
				{ "title": "Frozen II", "imageUrl": "https://picsum.photos/seed/frozen-ii/210/300" },
				{ "title": "Toy Story 4", "imageUrl": "https://picsum.photos/seed/toy-story-4/210/300" },
				{ "title": "The Irishman", "imageUrl": "https://picsum.photos/seed/the-irishman/210/300" },
				{ "title": "Star Wars The Rise of Skywalker", "imageUrl": "https://picsum.photos/seed/star-wars-rise/210/300" },
				{ "title": "Parasite", "imageUrl": "https://picsum.photos/seed/parasite-movie/210/300" },
				{ "title": "Joker", "imageUrl": "https://picsum.photos/seed/joker-movie/210/300" }
			]
		},
		{
			"rowIndex": 1
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Top Rated"
			}
			items: [
				{ "title": "The Shawshank Redemption", "imageUrl": "https://picsum.photos/seed/shawshank-redemption/210/300" },
				{ "title": "The Godfather", "imageUrl": "https://picsum.photos/seed/the-godfather/210/300" },
				{ "title": "The Godfather Part II", "imageUrl": "https://picsum.photos/seed/godfather-part-ii/210/300" },
				{ "title": "Pulp Fiction", "imageUrl": "https://picsum.photos/seed/pulp-fiction/210/300" },
				{ "title": "Schindlers List", "imageUrl": "https://picsum.photos/seed/schindlers-list/210/300" },
				{ "title": "12 Angry Men", "imageUrl": "https://picsum.photos/seed/12-angry-men/210/300" },
				{ "title": "The Return of the King", "imageUrl": "https://picsum.photos/seed/return-of-the-king/210/300" },
				{ "title": "Fight Club", "imageUrl": "https://picsum.photos/seed/fight-club/210/300" },
				{ "title": "Forrest Gump", "imageUrl": "https://picsum.photos/seed/forrest-gump/210/300" },
				{ "title": "The Fellowship of the Ring", "imageUrl": "https://picsum.photos/seed/fellowship-of-the-ring/210/300" },
				{ "title": "The Two Towers", "imageUrl": "https://picsum.photos/seed/the-two-towers/210/300" },
				{ "title": "Goodfellas", "imageUrl": "https://picsum.photos/seed/goodfellas/210/300" },
				{ "title": "The Matrix", "imageUrl": "https://picsum.photos/seed/the-matrix/210/300" },
				{ "title": "One Flew Over the Cuckoos Nest", "imageUrl": "https://picsum.photos/seed/one-flew-over/210/300" },
				{ "title": "Se7en", "imageUrl": "https://picsum.photos/seed/se7en/210/300" },
				{ "title": "City of God", "imageUrl": "https://picsum.photos/seed/city-of-god/210/300" },
				{ "title": "The Silence of the Lambs", "imageUrl": "https://picsum.photos/seed/silence-of-the-lambs/210/300" },
				{ "title": "Its a Wonderful Life", "imageUrl": "https://picsum.photos/seed/its-a-wonderful-life/210/300" },
				{ "title": "The Green Mile", "imageUrl": "https://picsum.photos/seed/the-green-mile/210/300" },
				{ "title": "Life Is Beautiful", "imageUrl": "https://picsum.photos/seed/life-is-beautiful/210/300" }
			]
		},
		{
			"rowIndex": 2
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Action"
			}
			items: [
				{ "title": "John Wick", "imageUrl": "https://picsum.photos/seed/john-wick/210/300" },
				{ "title": "Mad Max Fury Road", "imageUrl": "https://picsum.photos/seed/mad-max-fury-road/210/300" },
				{ "title": "Gladiator", "imageUrl": "https://picsum.photos/seed/gladiator/210/300" },
				{ "title": "Die Hard", "imageUrl": "https://picsum.photos/seed/die-hard/210/300" },
				{ "title": "Casino Royale", "imageUrl": "https://picsum.photos/seed/casino-royale/210/300" },
				{ "title": "Skyfall", "imageUrl": "https://picsum.photos/seed/skyfall/210/300" },
				{ "title": "The Bourne Ultimatum", "imageUrl": "https://picsum.photos/seed/bourne-ultimatum/210/300" },
				{ "title": "The Raid Redemption", "imageUrl": "https://picsum.photos/seed/the-raid-redemption/210/300" },
				{ "title": "Logan", "imageUrl": "https://picsum.photos/seed/logan/210/300" },
				{ "title": "The Avengers", "imageUrl": "https://picsum.photos/seed/the-avengers/210/300" },
				{ "title": "Terminator 2 Judgment Day", "imageUrl": "https://picsum.photos/seed/terminator-2/210/300" },
				{ "title": "Oldboy", "imageUrl": "https://picsum.photos/seed/oldboy/210/300" },
				{ "title": "Atomic Blonde", "imageUrl": "https://picsum.photos/seed/atomic-blonde/210/300" },
				{ "title": "Heat", "imageUrl": "https://picsum.photos/seed/heat-movie/210/300" },
				{ "title": "Leon The Professional", "imageUrl": "https://picsum.photos/seed/leon-the-professional/210/300" },
				{ "title": "FaceOff", "imageUrl": "https://picsum.photos/seed/faceoff/210/300" },
				{ "title": "Taken", "imageUrl": "https://picsum.photos/seed/taken/210/300" },
				{ "title": "The Dark Knight Rises", "imageUrl": "https://picsum.photos/seed/dark-knight-rises/210/300" },
				{ "title": "Crouching Tiger Hidden Dragon", "imageUrl": "https://picsum.photos/seed/crouching-tiger-hidden-dragon/210/300" }
			]
		},
		{
			"rowIndex": 3
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Comedy"
			}
			items: [
				{ "title": "The Grand Budapest Hotel", "imageUrl": "https://picsum.photos/seed/grand-budapest-hotel/210/300" },
				{ "title": "Superbad", "imageUrl": "https://picsum.photos/seed/superbad/210/300" },
				{ "title": "Step Brothers", "imageUrl": "https://picsum.photos/seed/step-brothers/210/300" },
				{ "title": "Bridesmaids", "imageUrl": "https://picsum.photos/seed/bridesmaids/210/300" },
				{ "title": "The Hangover", "imageUrl": "https://picsum.photos/seed/the-hangover/210/300" },
				{ "title": "Anchorman The Legend of Ron Burgundy", "imageUrl": "https://picsum.photos/seed/anchorman/210/300" },
				{ "title": "Groundhog Day", "imageUrl": "https://picsum.photos/seed/groundhog-day/210/300" },
				{ "title": "Monty Python and the Holy Grail", "imageUrl": "https://picsum.photos/seed/monty-python-holy-grail/210/300" },
				{ "title": "Some Like It Hot", "imageUrl": "https://picsum.photos/seed/some-like-it-hot/210/300" },
				{ "title": "Mean Girls", "imageUrl": "https://picsum.photos/seed/mean-girls/210/300" },
				{ "title": "Airplane", "imageUrl": "https://picsum.photos/seed/airplane-movie/210/300" },
				{ "title": "Shaun of the Dead", "imageUrl": "https://picsum.photos/seed/shaun-of-the-dead/210/300" },
				{ "title": "Hot Fuzz", "imageUrl": "https://picsum.photos/seed/hot-fuzz/210/300" },
				{ "title": "Ghostbusters", "imageUrl": "https://picsum.photos/seed/ghostbusters/210/300" },
				{ "title": "The Big Lebowski", "imageUrl": "https://picsum.photos/seed/big-lebowski/210/300" },
				{ "title": "Ferris Buellers Day Off", "imageUrl": "https://picsum.photos/seed/ferris-buellers-day-off/210/300" },
				{ "title": "Mrs Doubtfire", "imageUrl": "https://picsum.photos/seed/mrs-doubtfire/210/300" },
				{ "title": "The 40 Year Old Virgin", "imageUrl": "https://picsum.photos/seed/40-year-old-virgin/210/300" },
				{ "title": "Tropic Thunder", "imageUrl": "https://picsum.photos/seed/tropic-thunder/210/300" },
				{ "title": "Borat", "imageUrl": "https://picsum.photos/seed/borat/210/300" }
			]
		},
		{
			"rowIndex": 4
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "New Releases"
			}
			items: [
				{ "title": "Oppenheimer", "imageUrl": "https://picsum.photos/seed/oppenheimer/210/300" },
				{ "title": "Barbie", "imageUrl": "https://picsum.photos/seed/barbie-movie/210/300" },
				{ "title": "Mission Impossible Dead Reckoning", "imageUrl": "https://picsum.photos/seed/mission-impossible-dead-reckoning/210/300" },
				{ "title": "Indiana Jones Dial of Destiny", "imageUrl": "https://picsum.photos/seed/indiana-jones-dial-of-destiny/210/300" },
				{ "title": "The Little Mermaid", "imageUrl": "https://picsum.photos/seed/the-little-mermaid/210/300" },
				{ "title": "John Wick Chapter 4", "imageUrl": "https://picsum.photos/seed/john-wick-chapter-4/210/300" },
				{ "title": "Spider-Man Across the Spider-Verse", "imageUrl": "https://picsum.photos/seed/spider-man-across-the-spider-verse/210/300" },
				{ "title": "The Super Mario Bros Movie", "imageUrl": "https://picsum.photos/seed/super-mario-bros-movie/210/300" },
				{ "title": "Everything Everywhere All At Once", "imageUrl": "https://picsum.photos/seed/everything-everywhere-all-at-once/210/300" },
				{ "title": "The Creator", "imageUrl": "https://picsum.photos/seed/the-creator/210/300" },
				{ "title": "Ant-Man and the Wasp Quantumania", "imageUrl": "https://picsum.photos/seed/ant-man-quantumania/210/300" },
				{ "title": "Shazam Fury of the Gods", "imageUrl": "https://picsum.photos/seed/shazam-fury-of-the-gods/210/300" },
				{ "title": "Creed III", "imageUrl": "https://picsum.photos/seed/creed-iii/210/300" },
				{ "title": "Haunted Mansion", "imageUrl": "https://picsum.photos/seed/haunted-mansion/210/300" },
				{ "title": "The Flash", "imageUrl": "https://picsum.photos/seed/the-flash/210/300" },
				{ "title": "Dune Part Two", "imageUrl": "https://picsum.photos/seed/dune-part-two/210/300" },
				{ "title": "Wonka", "imageUrl": "https://picsum.photos/seed/wonka-movie/210/300" },
				{ "title": "Napoleon", "imageUrl": "https://picsum.photos/seed/napoleon-movie/210/300" },
				{ "title": "Killers of the Flower Moon", "imageUrl": "https://picsum.photos/seed/killers-of-the-flower-moon/210/300" },
				{ "title": "Poor Things", "imageUrl": "https://picsum.photos/seed/poor-things/210/300" }
			]
		}
	]

	m.renderThreadQueue.postMessage(m.top.contentSuppliedQueueId, rows)
end sub


sub onContentSuppliedMessageReceived(rows, msgInfo)
	currentVerticalTranslation = 0
	previousRowIndex = -1
	rowIndex = 0
	for each rowConfig in rows
		' We use the row index as the way to know if we are making a new row or updating an existing one
		rowIndex = rowConfig.rowIndex
		' if rowIndex <> invalid then
		' 	rowNode = m.top.getChild(rowIndex)

		' 	previousRowIndex = rowIndex
		' 	isUpdate = true
		' else
			' IMPROVEMENT could reuse these in the future although pretty cheap to make
			rowNode = createObject("roSGNode", "Group")
			m.rowsCurrentRowItemIndexes[rowIndex] = 0

			previousRowIndex = previousRowIndex + 1
			rowIndex = previousRowIndex
			isUpdate = false
		' end if

		m.gridRowNodes[rowIndex] = rowNode

		header = rowConfig.header
		if header <> invalid then
			headerNode = invalid

			componentName = header.componentName
			if componentName = invalid then
				print "No header componentName included for row " rowIndex
			else
				' Improvement currently don't support updating header component type
				if isUpdate = false then
					headerNode = createObject("roSGNode", componentName)
				else
					' ' See if we had a header already
					' firstNode = rowNode.getChild(0)
					' ' Item nodes should always have xOffset field but header container should not, so we can use that to determine if the first node is a header or not
					' if firstNode.hasField("xOffset") = false then
					' 	headerNode = firstNode
					' else
					' 	headerNode = createObject("roSGNode", componentName)
					' end if
				end if
			end if

			if headerNode = invalid then
				print "Failed to create header component: " + componentName
			else
				headerNode.translation = [0, currentVerticalTranslation]
				headerNode.setRef("content", header)
				headerNode.contentUpdated = true
				rowNode.insertChild(headerNode, 0)
				headerHeight = headerNode.height
				if headerHeight = invalid then
					print "Header height not provided for row " rowIndex
				else
					currentVerticalTranslation += headerHeight
				end if
			end if
		end if

		' IMPROVEMENT could reuse these in the future although pretty cheap to make
		' We wrap our row items in a container so that we can move the whole row of items together when navigating left and right
		rowItemContainerNode = createObject("roSGNode", "Group")
		rowItemContainerNode.id = "rowItemsContainer"
		rowItemContainerNode.translation = [0, currentVerticalTranslation]

		componentName = rowConfig.componentName
		rowItemIndex = 0
		yOffset = 0
		currentHorizontalTranslation = 0
		for each item in rowConfig.items
			itemNode = invalid
			if item.componentName <> invalid then
				itemNode = createObject("roSGNode", item.componentName)
			else if componentName <> invalid then
				itemNode = createObject("roSGNode", componentName)
			else
				print "No componentName included for item in row " rowIndex
			end if

			if itemNode = invalid then
				print "Failed to create row item component: " item.componentName
			else
				itemNode.translation = [currentHorizontalTranslation, 0]
				itemNode.setRef("content", item)
				itemNode.contentUpdated = true
				if itemNode.hasField("xOffset") then
					currentHorizontalTranslation += itemNode.xOffset
				else
					print "Row item missing xOffset field for row " rowIndex " item " rowItemIndex
				end if

				rowItemContainerNode.appendChild(itemNode)
				loadedRow = m.loadedRows[rowIndex.toStr()]
				if loadedRow = invalid then
					loadedRow = {}
					m.loadedRows[rowIndex.toStr()] = loadedRow
				end if
				loadedRow[rowItemIndex.toStr()] = itemNode

				if yOffset = 0 then
					if itemNode.hasField("yOffset") then
						yOffset = itemNode.yOffset
					end if
				end if
			end if

			rowItemIndex++
		end for

		if yOffset > 0 then
			currentVerticalTranslation += yOffset
		else
			print "Row item height not provided for row " rowIndex
		end if

		rowNode.appendChild(rowItemContainerNode)
		m.gridContent.appendChild(rowNode)
		rowIndex++
	end for

	navigateToRowItem(0, 0)
end sub


' Navigate to a specific row and item index
' Returns true if navigation was successful, false if not (out of bounds or no composition loaded)
Function navigateToRowItem(rowIndex as integer, rowItemIndex as integer) as boolean
	' TODO needs to be updated to handle navigating to rows/items that haven't been loaded yet, for now just return false if we try to navigate to something that hasn't been loaded yet

	loadedRow = m.loadedRows[rowIndex.toStr()]
	if loadedRow = invalid then
		print "No loaded row at index" rowIndex
		return false
	end if

	rowItemNode = loadedRow[rowItemIndex.toStr()]
	if rowItemNode = invalid then
		print "No loaded item at index" rowItemIndex " in row" rowIndex
		return false
	end if


' 	previousRowIndex = m.currentRowIndex
' 	previousItemIndex = rowItemRow.currentItemIndex

	m.currentRowIndex = rowIndex
	m.rowsCurrentRowItemIndexes[rowIndex] = rowItemIndex

' 	verticalTranslationOffset = 0

' 	direction = 1
' 	if rowIndex < previousRowIndex then
' 		direction = -1
' 	end if

' 	for i = previousRowIndex to rowIndex - direction step direction
' 		verticalTranslationOffset += compositionRows[i].height * direction
' 	end for

' 	translation = m.gridContent.translation
' 	m.gridContent.translation = [
' 		translation[0],
' 		translation[1] - verticalTranslationOffset
' 	]

' 	horizontalTranslationOffset = 0

' 	direction = 1
' 	if itemIndex < previousItemIndex then
' 		direction = -1
' 	end if


' 	translation = rowItemRow.translation
' 	rowItemRow.translation = [
' 		translation[0] - horizontalTranslationOffset,
' 		translation[1]
' 	]
' 	rowItemRow.currentItemIndex = itemIndex

print "rowIndex: " rowIndex " itemIndex: " rowItemIndex
' 	print "m.gridContent.translation = " m.gridContent.translation
print "itemNode.translation[0]" rowItemNode.translation[0]
' stop
	m.focusFeedback.width = rowItemNode.width
	m.focusFeedback.height = rowItemNode.height

	gridRowNode = m.gridRowNodes[rowIndex]
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

	containerTranslationY = rowItemsContainerNode.translation[1]
	m.gridContent.translation = [0, -containerTranslationY]

	rowItemsContainerNode.translation = [-rowItemNode.translation[0], containerTranslationY]

	rowItemNode.setFocus(true)

	return true
End Function


Function navigateToRow(rowIndex as integer) as boolean
	currentItemIndex = m.rowsCurrentRowItemIndexes[rowIndex]

	if currentItemIndex = invalid then
		print "No row at index" rowIndex
		return false
	end if

	return navigateToRowItem(rowIndex, currentItemIndex)
End Function


Function navigateToRelativeRowItem(rowIndex as integer, itemIndexOffset as integer) as boolean
	currentItemIndex = m.rowsCurrentRowItemIndexes[rowIndex]

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
