Function addContentToGrid(grid as Object, content as Object, row as Integer, col as Integer) as Void
	' Ensure the grid has enough rows
	while grid.rowCount() <= row
		grid.addRow()
	end while

	' Ensure the grid has enough columns
	while grid.colCount() <= col
		grid.addColumn()
	end while

	' Add the content to the specified cell
	grid.setCellContent(row, col, content)
End Function


Function createContentNode(contentType as String, contentData as Object) as Object
	' Create a new content node based on the specified type and data
	contentNode = CreateObject("roSGNode", contentType)
	for each key in contentData.keys()
		contentNode.setField(key, contentData[key])
	end for
	return contentNode
End Function
