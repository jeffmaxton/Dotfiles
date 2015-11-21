local spaces      = require('hs._asm.undocumented.spaces')
local framed      = require('ext.framed')
local application = require('ext.application')

local cache = {
  windowPositions = {},
  mousePosition   = nil
}

local module = {}

-- get screen frame
function module.screenFrame(win)
  local funcName  = window.fullFrame and 'fullFrame' or 'frame'
  local winScreen = win:screen()

  return winScreen[funcName](winScreen)
end

-- set frame
function module.setFrame(win, frame, time)
  win:setFrame(frame, time or hs.window.animationDuration)
end

-- ugly fix for problem with window height when it's as big as screen
function module.fixFrame(win)
  if window.fixEnabled then
    local screen = module.screenFrame(win)
    local frame  = win:frame()

    if (frame.h > (screen.h - window.margin * 2)) then
      frame.h = screen.h - window.margin * 10
      window.setFrame(win, frame)
    end
  end
end

-- pushes window in direction
function module.push(win, direction, value)
  local screen = module.screenFrame(win)
  local frame

  frame = framed.push(screen, direction, value)

  module.fixFrame(win)
  module.setFrame(win, frame)
end

-- nudges window in direction
function module.nudge(win, direction)
  local screen = module.screenFrame(win)
  local frame  = win:frame()

  frame = framed.nudge(frame, screen, direction)
  module.setFrame(win, frame, 0.05)
end

-- push and nudge window in direction
function module.pushAndSend(win, options)
  local direction, value

  if type(options) == 'table' then
    direction = options[1]
    value     = options[2] or 1 / 2
  else
    direction = options
    value     = 1 / 2
  end

  module.push(win, direction, value)

  hs.timer.doAfter(hs.window.animationDuration * 3 / 2, function()
    module.send(win, direction)
  end)
end

-- sends window in direction
function module.send(win, direction)
  local screen = module.screenFrame(win)
  local frame  = win:frame()

  frame = framed.send(frame, screen, direction)

  module.fixFrame(win)
  module.setFrame(win, frame)
end

-- centers window
function module.center(win)
  local screen = module.screenFrame(win)
  local frame  = win:frame()

  frame = framed.center(frame, screen)
  module.setFrame(win, frame)
end

-- fullscreen window with margin
function module.fullscreen(win)
  local screen = module.screenFrame(win)
  local frame  = {
    x = window.margin + screen.x,
    y = window.margin + screen.y,
    w = screen.w - window.margin * 2,
    h = screen.h - window.margin * 2
  }

  module.fixFrame(win)
  module.setFrame(win, frame)

  -- center after setting frame, fixes terminal
  hs.timer.doAfter(hs.window.animationDuration * 3 / 2, function()
    module.center(win)
  end)
end

-- set window size and center
function module.setSize(win, size)
  local screen = module.screenFrame(win)
  local frame  = win:frame()

  frame.w = size.w
  frame.h = size.h

  frame = framed.fit(frame, screen)
  frame = framed.center(frame, screen)

  module.setFrame(win, frame)

  -- center after setting frame, fixes terminal
  hs.timer.doAfter(hs.window.animationDuration * 3 / 2, function()
    module.center(win)
  end)
end

-- focus window in direction
function module.focus(win, direction)
  local functions = {
    up    = 'focusWindowNorth',
    down  = 'focusWindowSouth',
    left  = 'focusWindowWest',
    right = 'focusWindowEast'
  }

  hs.window[functions[direction]](win)
end

-- throw to screen in direction, center and fit
function module.throwToScreen(win, direction)
  local winScreen       = win:screen()
  local frameFunc       = module.fullFrame and 'fullFrame' or 'frame'
  local throwScreenFunc = {
    up    = 'toNorth',
    down  = 'toSouth',
    left  = 'toWest',
    right = 'toEast'
  }

  local throwScreen = winScreen[throwScreenFunc[direction]](winScreen)

  if throwScreen == nil then return end

  local frame       = win:frame()
  local screenFrame = throwScreen[frameFunc](throwScreen)

  frame.x = screenFrame.x
  frame.y = screenFrame.y

  frame = framed.fit(frame, screenFrame)
  frame = framed.center(frame, screenFrame)

  module.fixFrame(win)
  module.setFrame(win, frame)

  win:focus()

  -- center after setting frame, fixes terminal
  hs.timer.doAfter(hs.window.animationDuration * 3 / 2, function()
    module.center(win)
  end)
end

-- move window to another space
function module.moveToSpace(win, space)
  local clickPoint    = win:zoomButtonRect()
  local sleepTime     = 1000

  if clickPoint == nil then return end

  cache.mousePosition = cache.mousePosition or hs.mouse.getAbsolutePosition()

  clickPoint.x = clickPoint.x + clickPoint.w + 5
  clickPoint.y = clickPoint.y + clickPoint.h / 2

  -- fix for Chrome UI
  if win:application():title() == 'Google Chrome' then
    clickPoint.y = clickPoint.y - clickPoint.h
  end

  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, clickPoint):post()

  hs.timer.usleep(sleepTime)

  hs.eventtap.keyStroke({ 'ctrl' }, space)

  -- wait to finish animation
  while (spaces.isAnimating()) do end

  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, clickPoint):post()

  hs.mouse.setAbsolutePosition(cache.mousePosition)

  cache.mousePosition = nil
end

-- cycle application windows
function module.cycleWindows(win, appWindowsOnly)
  local allWindows = appWindowsOnly and win:application():allWindows() or hs.window.allWindows()

  -- we only care about standard windows
  local standardWindows = hs.fnutils.filter(allWindows, function(win)
    return win:isStandard()
  end)

  if #standardWindows == 1 then
    -- if we have only one window - focus it
    standardWindows[1]:focus()
  elseif #standardWindows > 1 then
    -- if there are more than one, sort them first by id
    table.sort(standardWindows, function(a, b) return a:id() < b:id() end)

    -- check if one of them is active
    local activeWindowIndex = hs.fnutils.indexOf(standardWindows, win)

    if activeWindowIndex then
      -- if it is, then focus next one
      activeWindowIndex = activeWindowIndex + 1

      if activeWindowIndex > #standardWindows then activeWindowIndex = 1 end

      standardWindows[activeWindowIndex]:focus()
    else
      -- otherwise focus first one
      standardWindows[1]:focus()
    end
  end
end

-- save and restore window positions
function module.persistPosition(win, option)
  local id    = win:application():bundleID()
  local frame = win:frame()

  -- saves window position if not saved before
  if option == 'save' and not cache.windowPositions[id] then
    cache.windowPositions[id] = frame
  end

  -- force update saved window position
  if option == 'update' then
    cache.windowPositions[id] = frame
  end

  -- restores window position
  if option == 'load' and cache.windowPositions[id] then
    module.setFrame(win, cache.windowPositions[id])
  end
end

return module