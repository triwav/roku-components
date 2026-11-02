sub init()
	m.label = m.top.findNode("label")

	m.top.observeField("contentUpdated", "onContentUpdatedChanged")
end sub


sub onContentUpdatedChanged(msg)
	content = m.top.getRef("content")
	m.label.text = content.header.title
end sub
