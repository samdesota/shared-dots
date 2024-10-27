require('hs.ipc')
require('hs.mouse')
require('spring')

hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "t", function()
  hs.osascript.applescript([[
    tell application "Vivaldi"
      if (count of windows) is 0 then
        activate
        delay 0.1
        tell application "System Events"
            keystroke "t" using command down
        end tell
      else
        make new window
      end if
    end tell
  ]])
end)


hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
  local encodedURL = fullURL:gsub('"', '\\"')
  hs.osascript.applescript(string.format([[
    tell application "Vivaldi"
      if (count of windows) is 0 then
        activate
        delay 0.1
        tell application "System Events"
            keystroke "t" using command down
        end tell
        delay 0.1
        set URL of active tab of window 1 to "%s"
      else
        set URL of active tab of (make new window) to "%s"
      end if
    end tell
  ]], encodedURL, encodedURL))
end

hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "m", function()
  hs.application.launchOrFocus("Spotify")
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "h", function()
  hs.reload()
end)

local shell_binding = hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "s", function()
  hs.urlevent.openURL("warp://action/new_window?path=~")
end)

function applicationWatcher(appName, eventType, appObject)
  if (eventType == hs.application.watcher.activated) then
      if (appName == "Code - Insiders" or appName == "Code" or appName == "Cursor") then
        shell_binding:disable()
      end
  end
  if (eventType == hs.application.watcher.deactivated) then
      if (appName == "Code - Insiders" or appName == "Code" or appName == "Cursor") then
        print("Code is deactivated")
        shell_binding:enable()
      end
  end
end
appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

local time_start = 0
function TimeStart()
    time_start = hs.timer.secondsSinceEpoch()
end

function TimeEnd(label)
    local time_end = hs.timer.secondsSinceEpoch()
    local time_diff = time_end - time_start
    print(label, time_diff * 1000)
end

PaperWM = hs.loadSpoon("PaperWM")
PaperWM:bindHotkeys({
  -- switch to a new focused window in tiled grid
  focus_up       = { { "ctrl", "alt", "cmd" }, "up" },
  focus_down     = { { "ctrl", "alt", "cmd" }, "down" },
  focus_left = {{"ctrl", "alt", "cmd"}, "h"},
  focus_right = {{"ctrl", "alt", "cmd"}, "l"},

  -- untile window (make it floating)>ri
  untile_window_at_cursor  = { { "ctrl", "alt", "cmd", "shift" }, "f" },
  close_window = { { "ctrl", "alt", "cmd", "shift" }, "w" },
  tile_focused_app_by_default = { {"ctrl", "alt", "cmd", "shift"}, "a" },

  -- move windows around in tiled grid
  swap_left      = { { "ctrl", "alt", "cmd", "shift" }, "h" },
  swap_right     = { { "ctrl", "alt", "cmd", "shift" }, "l" },
  swap_up        = { { "ctrl", "alt", "cmd", "shift" }, "up" },
  swap_down      = { { "ctrl", "alt", "cmd", "shift" }, "down" },

  -- position and resize focused window
  cycle_width    = { { "ctrl", "alt", "cmd" }, "r" },

  -- move focused window into / out of a column
  --slurp_in       = { { "ctrl", "alt", "cmd", "shift" }, "s" },
  --barf_out       = { { "ctrl", "alt", "cmd", "shift" }, "b" },

  -- switch to a new Mission Control space
  switch_space_5 = { { "ctrl", "alt", "cmd", "shift" }, "5" },
  switch_space_6 = { { "ctrl", "alt", "cmd", "shift" }, "6" },
  switch_space_7 = { { "ctrl", "alt", "cmd", "shift" }, "7" },
  switch_space_8 = { { "ctrl", "alt", "cmd", "shift" }, "8" },
  switch_space_9 = { { "ctrl", "alt", "cmd", "shift" }, "9" },

  -- move focused window to a new space and tile
  move_window_1  = { { "ctrl", "alt", "cmd" }, "1" },
  move_window_2  = { { "ctrl", "alt", "cmd" }, "2" },
  move_window_3  = { { "ctrl", "alt", "cmd" }, "3" },
  move_window_4  = { { "ctrl", "alt", "cmd" }, "4" },
  move_window_5  = { { "ctrl", "alt", "cmd" }, "5" },
  move_window_6  = { { "ctrl", "alt", "cmd" }, "6" },
  move_window_7  = { { "ctrl", "alt", "cmd" }, "7" },
  move_window_8  = { { "ctrl", "alt", "cmd" }, "8" },
  move_window_9  = { { "ctrl", "alt", "cmd" }, "9" }
})

PaperWM.window_filter:rejectApp("carouselos")

PaperWM:start()

hs.mouse.getCurrentScreen()

local function shiftTilingBy(value, animate, override_anchor)
  local screen = hs.mouse.getCurrentScreen()

  if screen == nil then
    return
  end

  local space = hs.spaces.activeSpaceOnScreen(screen)

  PaperWM:tileSpace(space, value, override_anchor)
end

local shiftAmount = 0
local previousTime = 0
local velocity = 0
local momentumScroll = false
local minInitialVelocity = 500
local moveAmountX = 0
local moveAmountY = 0
local windowResizeAmount = 0

local function shiftThrottled(value)
  shiftAmount = shiftAmount + value

  if not ShiftTimer:running() then
    ShiftTimer:start()
  end
end

local function resizeThrottled(value)
  windowResizeAmount = windowResizeAmount + value
  shiftAmount = shiftAmount + -value / 2

  if not ShiftTimer:running() then
    ShiftTimer:start()
  end
end


local function moveWindowThrottled(x, y)
  moveAmountX = moveAmountX + x
  moveAmountY = moveAmountY + y

  if not ShiftTimer:running() then
    ShiftTimer:start()
  end
end

local velocities = {}
local velocityIndex = 0
local maxVelocities = 3

local function startMomentumScroll()
  if math.abs(velocity) > minInitialVelocity then
    momentumScroll = true
    ShiftTimer:start()
  else
    momentumScroll = false
    velocity = 0
  end

  velocities = {}
  velocityIndex = 0
end



local function averageOfTable(table)
  local sum = 0

  for _, value in ipairs(table) do
    sum = sum + value
  end

  return sum / #table
end

local function handleScrollGesture(value)
  if momentumScroll then
    momentumScroll = false
    velocity = 0
  end

  local deltaTime = hs.timer.secondsSinceEpoch() - previousTime
  local newVelocity = math.min(math.max(value / deltaTime, -20000), 20000)

  velocities[velocityIndex + 1] = newVelocity
  velocityIndex = (velocityIndex + 1) % maxVelocities
  velocity = averageOfTable(velocities)

  previousTime = hs.timer.secondsSinceEpoch()

  shiftThrottled(value)
end

local previousFrameTime = nil
local windowAtCursor

ShiftTimer = hs.timer.doEvery(0.016, function()
  if momentumScroll and previousFrameTime and math.abs(velocity) > 10 then
    shiftAmount = velocity * (hs.timer.secondsSinceEpoch() - previousFrameTime)
    velocity = velocity * 0.95
  end

  previousFrameTime = hs.timer.secondsSinceEpoch()

  if windowResizeAmount ~= 0 then
    if windowAtCursor ~= nil then
      local frame = windowAtCursor:frame()
      frame.w = frame.w + windowResizeAmount
      frame.x = frame.x + shiftAmount
      PaperWM:moveWindow(windowAtCursor, frame)
      shiftTilingBy(0, false, windowAtCursor)
    end
    windowResizeAmount = 0
    shiftAmount = 0
  elseif shiftAmount ~= 0 then
    shiftTilingBy(shiftAmount)
    shiftAmount = 0
  elseif math.abs(moveAmountX) ~= 0 or math.abs(moveAmountY) > 0 then
    if windowAtCursor then
      local frame = windowAtCursor:frame()

      frame.x = frame.x + moveAmountX
      frame.y = frame.y + moveAmountY

      windowAtCursor:setTopLeft(frame)
      moveAmountX = 0
      moveAmountY = 0
    end
  else
    ShiftTimer:stop()
  end
end)

ShiftTimer:start()


local touchPrev = {}

local function maxOfTable(table)
  local max = nil
  for _, value in ipairs(table) do
    if max == nil or value > max then
      max = value
    end
  end
  return max
end

SlideWithMouseTap = hs.eventtap.new({ hs.eventtap.event.types.mouseMoved }, function(event)
  local whichFlags = event:getFlags()
  if whichFlags['cmd'] and whichFlags['ctrl'] and whichFlags['alt'] and whichFlags['shift'] then
    local dx = event:getProperty(hs.eventtap.event.properties.mouseEventDeltaX)
    local dy = event:getProperty(hs.eventtap.event.properties.mouseEventDeltaY)

    if windowAtCursor == nil or PaperWM:isWindowTiled(windowAtCursor) then
      if math.abs(dx) > math.abs(dy) then
        shiftThrottled(dx * 4)
        return true
      end
    else
      moveWindowThrottled(dx, dy)

      return true
    end
  end

  return false
end)


HyperDownTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
  local whichFlags = event:getFlags()
  if whichFlags['cmd'] and whichFlags['ctrl'] and whichFlags['alt'] and whichFlags['shift'] then
    windowAtCursor = PaperWM:findWindowAtCursor()
    SlideWithMouseTap:start()
  else
    windowAtCursor = nil
    SlideWithMouseTap:stop()
  end
  return false
end):start()

SwipeGestureTap = hs.eventtap.new({ hs.eventtap.event.types.gesture, hs.eventtap.event.types.scrollWheel }, function(event)
  if event:getType() == hs.eventtap.event.types.scrollWheel then
    local horizontal_delta = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1)

    if windowAtCursor ~= nil then
      resizeThrottled(-horizontal_delta * 50)
      return true
    end

    return
  end

  --print(hs.inspect(event))
  local touches = event:getTouches()
  -- matching a three finger gesture
  if #touches == 3 then
    local deltas = {}
    local xMax = nil
    local xMin = nil

    -- get the touches that have a previous value, add the delta to deltas
    for _, touch in ipairs(touches) do
      -- your code herg
      local prev = touchPrev[touch.identity]
      local current = touch.normalizedPosition
      xMax = xMax and math.max(xMax, current.x) or current.x
      xMin = xMin and math.min(xMin, current.x) or current.x

      if prev ~= nil then
        local deltaX = current.x - prev.x

        table.insert(deltas, deltaX)
      end

      touchPrev[touch.identity] = touch.normalizedPosition
    end

    -- make sure we have three deltas
    if #deltas ~= 3 then
      return
    end

    -- If one of the touches has 30% the movement of the maxDelta, we
    -- won't consider this three-finger swipe (the touches aren't
    -- moving at the same speed)
    local deltaEquivalenceThreshold = 0.3
    local maxDelta = maxOfTable(deltas)

    for _, delta in ipairs(deltas) do
      if (delta / maxDelta) < deltaEquivalenceThreshold then
        return
      end
    end

    local xDelta = xMax - xMin

    -- Prevent accidental swipes whild hands are resting
    if (xDelta > 0.65) then
      return
    end

    -- shift the windows the average delta
    shiftThrottled(averageOfTable(deltas) * 8000)

  else
    touchPrev = {}
  end
end)

SwipeGestureTap:start()

function SetFrontmost(appName)
  local app = hs.application.find(appName)
  if app then
    app:setFrontmost(false)
  end
end
