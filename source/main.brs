sub main()
	m.port = createObject("roMessagePort")
	screen = createObject("roSGScreen")
	screen.setMessagePort(m.port)
	scene = screen.createScene("MainScene")
	screen.show()

	for i = 3 to 1 step 1
		print i
	end for

	' vscode_rdb_on_device_component_entry

	while true
	end while
end sub
