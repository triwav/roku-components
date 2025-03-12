Function init()
  m.top.observeFieldScoped("focusedChild", "onFocusedChildChange")
  m.top.observeFieldScoped("jumpToIndex", "onJumpToIndexChange")

  m.top.focusable = true
End Function


Function onFocusedChildChange(_msg)
  ' We only care if the component itself has focus
  if m.top.hasFocus() = true then
    index = m.top.focusedIndex
    startingIndex = index
    node = invalid
    ' If we have an existing index then go ahead and try to set focus back to that
    if index >= 0 then
      node = m.top.getChild(index)
      if canBeFocused(node) = false then
        ' If the existing index is not focusable then we subtract 1 and then increment through the remaining children
        index = findFirstFocusableNodeIndex(index - 1, false)

        if index = -1 then
          ' If we couldn't find a focusable node going forward then try to find one going in reverse
          index = findFirstFocusableNodeIndex(startingIndex - 1, true)
        end if
      end if
    else
      ' If we don't have an existing index we want to find the first item we can focus on
      index = findFirstFocusableNodeIndex(0)
    end if

    updateFocus(index)
  end if
End Function


Function onJumpToIndexChange(msg)
  index = msg.getData()
  node = m.top.getChild(index)
  if canBeFocused(node) = false then
    index = findFirstFocusableNodeIndex(index - 1)
  end if

  updateFocus(index)
End Function


Function updateFocus(index)
  componentLosingFocus = m.top.getChild(m.top.focusedIndex)
  componentGainingFocus = m.top.getChild(index)

  if componentGainingFocus <> invalid then
    m.top.componentGainingFocus = componentGainingFocus
    m.top.componentLosingFocus = componentLosingFocus

    m.top.focusedIndex = index
    setFocus(componentGainingFocus)
  end if
End Function


' Tries to find the first index that is focusable. If none can be be found returns -1
' @startIndex: Integer, the index that we will start looking for a focusable node at first child
' @reverse: Boolean, if true then we go from startIndex to 0 else we go from startIndex to the last child
Function findFirstFocusableNodeIndex(startIndex, reverse = false)
  if reverse = false then
    endIndex = m.top.getChildCount() - 1
    stepIncrement = 1
  else
    endIndex = 0
    stepIncrement = -1
  end if

  for index = startIndex to endIndex step stepIncrement
    node = m.top.getChild(index)
    if canBeFocused(node) = true then
      return index
    end if
  end for

  return -1
End Function


' Determines whether a node is able to be focused or not
Function canBeFocused(node)
  return node <> invalid AND node.visible = true AND node.focusable = true
End Function


Function setFocus(node, focus = true)
  if node <> invalid then
    node.setFocus(focus)
  end if
End Function


Function onKeyEvent(key as String, press as Boolean) as Boolean
  if press = false then
    return false
  end if

  index = -1

  if m.top.childDirection = "horiz" then
    if key = "left" then
      index = findFirstFocusableNodeIndex(m.top.focusedIndex - 1, true)
    else if key = "right" then
      index = findFirstFocusableNodeIndex(m.top.focusedIndex + 1, false)
    end if
  else
    if key = "up" then
      index = findFirstFocusableNodeIndex(m.top.focusedIndex - 1, true)
    else if key = "down" then
      index = findFirstFocusableNodeIndex(m.top.focusedIndex + 1, false)
    end if
  end if

  if index <> -1 then
    updateFocus(index)
    return true
  end if

  return false
End Function
