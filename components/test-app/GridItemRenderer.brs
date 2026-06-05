sub init()
	m.poster = m.top.findNode("poster")
	m.label = m.top.findNode("label")

	m.collapsedPosterWidth = 160
	m.collapsedPosterHeight = 240

	m.posterWidth = 427
	m.posterHeight = 240

	m.top.width = m.posterWidth

	m.top.observeFieldScoped("contentUpdated", "onContentUpdated")
	m.top.observeFieldScoped("focusedChild", "onFocusedChildChanged")
	m.top.observeFieldScoped("itemHasFocus", "onItemHasFocusChanged")
	m.top.observeFieldScoped("xOffset", "onXOffsetChanged")
	m.top.observeFieldScoped("focusPercent", "onFocusPercentChanged")
	m.top.observeFieldScoped("rowFocusPercent", "onRowFocusPercentChanged")

	m.expandTimer = createObject("roSGNode", "Timer")
	m.expandTimer.duration = 0.2
	m.expandTimer.observeFieldScoped("fire", "onExpandTimerFire")

	m.collapseTimer = createObject("roSGNode", "Timer")
	m.collapseTimer.duration = 0.2
	m.collapseTimer.observeFieldScoped("fire", "onCollapseTimerFire")
end sub


sub onContentUpdated()
	if m.top.canGetRef("content") = false then
		print "can not get content ref"
		' Possibly could allow it to fallback in this case maybe
		return
	end if

	content = m.top.getRef("content")

	imageWidth = m.collapsedPosterWidth
	imageHeight = m.collapsedPosterHeight

	m.label.text = content.title

	m.sidePadding = 20
	m.verticalPadding = 48

	m.top.width = imageWidth
	m.top.height = imageHeight

	m.label.width = imageWidth

	m.top.xOffset = imageWidth + m.sidePadding
	m.top.yOffset = imageHeight + m.verticalPadding

	imageWidth = m.posterWidth
	imageHeight = m.posterHeight
	m.poster.width = imageWidth
	m.poster.height = imageHeight
	m.poster.uri = content.imageUrl + "/" + imageWidth.toStr() + "/" + imageHeight.toStr()
end sub


sub onXOffsetChanged(msg)
	xOffset = msg.getData()
	width = xOffset - m.sidePadding
	m.top.clippingRect = {
		x: 0,
		y: 0,
		width: width,
		height: m.posterHeight
	}

	' Go ahead and update width as well so it matches up
	m.top.width = width
end sub


' sub onFocusPercentChanged(msg)
' 	focusPercent = msg.getData()
' 	focusAmount = 1 - abs(focusPercent - 1)
' 	if m.top.rowItemIndex = 1
' 		print "focusPercent: " focusAmount
' 	end if

' 	' 1 = focused, 0 = left item focused, 2 = right item focused
'     ' Maps all three states to a 0->1 focus amount


'     targetWidth = m.collapsedPosterWidth + (m.posterWidth - m.collapsedPosterWidth) * focusAmount
'     m.top.xOffset = targetWidth + m.sidePadding
' end sub

sub onRowFocusPercentChanged(msg)
	rowFocusPercent = msg.getData()
end sub


' sub onFocusedChildChanged()
' 	if m.top.hasFocus() then
' 		m.collapseTimer.control = "stop"
' 		m.expandTimer.control = "start"
' 		' m.top.animate = {
' 		' 	"yOffset": {
' 		' 		"animateTo": m.top.height + 100
' 		' 	}
' 		' }
' 	else
' 		' m.top.animate = {
' 		' 	"yOffset": {
' 		' 		"animateTo": m.top.height
' 		' 	}
' 		' }
' 		m.expandTimer.control = "stop"
' 		m.collapseTimer.control = "start"
' 	end if
' end sub

sub onItemHasFocusChanged(msg)
	itemHasFocus = msg.getData()
	if itemHasFocus then
		m.collapseTimer.control = "stop"
		m.expandTimer.control = "start"
		' m.top.animate = {
		' 	"yOffset": {
		' 		"animateTo": m.top.height + 100
		' 	}
		' }
	else
		' m.top.animate = {
		' 	"yOffset": {
		' 		"animateTo": m.top.height
		' 	}
		' }
		m.expandTimer.control = "stop"
		m.collapseTimer.control = "start"
	end if
end sub


sub onExpandTimerFire()
	m.top.animate = {
		"xOffset": {
			"animateTo": m.sidePadding + m.posterWidth
		}
	}
end sub


sub onCollapseTimerFire()
	m.top.animate = {
		"xOffset": {
			"animateTo": m.sidePadding + m.collapsedPosterWidth
		}
	}
end sub
