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

	m.poster.uri = content.imageUrl
	m.label.text = content.title

	m.top.width = 210
	m.top.height = 300
	m.top.xOffset = 210 + 20
	m.top.yOffset = 300 + 48
end sub
