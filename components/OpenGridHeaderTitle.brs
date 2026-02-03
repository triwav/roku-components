sub init()
	m.top.observeField("content", "onContentChanged")
end sub

sub onContentChanged(msg)
	content = msg.getData()

	m.top.findNode("label").text = "Row Header"
end sub
