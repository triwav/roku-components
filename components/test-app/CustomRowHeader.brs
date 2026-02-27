sub init()
	m.label = m.top.findNode("label")

	m.top.observeField("contentUpdated", "onContentUpdatedChanged")
end sub


sub onContentUpdatedChanged(msg)
	m.content = m.top.getRef("content")
	m.label.text = m.content.title
end sub
