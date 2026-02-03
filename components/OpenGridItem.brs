sub init()
	m.top.observeField("content", "onContentChanged")
end sub

sub onContentChanged(msg)
	content = msg.getData()

	m.top.findNode("label").text = "Label " + content.title
end sub
