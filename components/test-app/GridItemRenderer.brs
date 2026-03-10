sub init()
	m.poster = m.top.findNode("poster")
	m.label = m.top.findNode("label")

	m.top.observeField("contentUpdated", "onContentUpdated")
end sub

sub onContentUpdated()
	if m.top.canGetRef("content") = false then
		print "can not get content ref"
		' Possibly could allow it to fallback in this case maybe
		return
	end if

	content = m.top.getRef("content")

	if m.top.subtype() = "GridItemRenderer" then
		imageWidth = 160
		imageHeight = 240
	else
		imageWidth = 427
		imageHeight = 240
	end if

	m.poster.uri = content.imageUrl + "/" + imageWidth.toStr() + "/" + imageHeight.toStr()
	m.label.text = content.title

	m.top.width = imageWidth
	m.top.height = imageHeight
	m.top.xOffset = imageWidth + 20
	m.top.yOffset = imageHeight + 48
end sub
