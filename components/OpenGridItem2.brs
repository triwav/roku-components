sub init()
	m.top.observeField("content", "onContentChanged")
end sub

sub onContentChanged(msg)
	content = msg.getData()

	label = m.top.findNode("label")
	label.text = "Label " + content.title + " OpenGridItem2"

	' stop
end sub
