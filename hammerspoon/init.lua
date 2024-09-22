require('hs.ipc')
require('hs.mouse')
require('spring')

hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "t", function()
  print("Hello World!")
  hs.osascript.applescript([[
    tell application "Vivaldi"
      if (count of windows) is 0 then
        activate
        tell application "System Events"
            keystroke "t" using command down
        end tell
      else
        make new window
      end if
    end tell
  ]])
end)

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
  focus_left = {{"ctrl", "alt", "cmd", "shift"}, "h"},
  focus_right = {{"ctrl", "alt", "cmd", "shift"}, "l"},

  -- untile window (make it floating)>ri
  untile_window_at_cursor  = { { "ctrl", "alt", "cmd", "shift" }, "f" },
  close_window = { { "ctrl", "alt", "cmd", "shift" }, "w" },
  tile_focused_app_by_default = { {"ctrl", "alt", "cmd", "shift"}, "a" },

  -- move windows around in tiled grid
  swap_left      = { { "ctrl", "alt", "cmd", "shift" }, "left" },
  swap_right     = { { "ctrl", "alt", "cmd", "shift" }, "right" },
  swap_up        = { { "ctrl", "alt", "cmd", "shift" }, "up" },
  swap_down      = { { "ctrl", "alt", "cmd", "shift" }, "down" },

  -- position and resize focused window
  cycle_width    = { { "ctrl", "alt", "cmd" }, "r" },

  -- move focused window into / out of a column
  --slurp_in       = { { "ctrl", "alt", "cmd", "shift" }, "s" },
  --barf_out       = { { "ctrl", "alt", "cmd", "shift" }, "b" },

  -- switch to a new Mission Control space
  switch_space_1 = { { "ctrl", "alt", "cmd" }, "1" },
  switch_space_2 = { { "ctrl", "alt", "cmd" }, "2" },
  switch_space_3 = { { "ctrl", "alt", "cmd" }, "3" },
  switch_space_4 = { { "ctrl", "alt", "cmd" }, "4" },
  switch_space_5 = { { "ctrl", "alt", "cmd" }, "5" },
  switch_space_6 = { { "ctrl", "alt", "cmd" }, "6" },
  switch_space_7 = { { "ctrl", "alt", "cmd" }, "7" },
  switch_space_8 = { { "ctrl", "alt", "cmd" }, "8" },
  switch_space_9 = { { "ctrl", "alt", "cmd" }, "9" },

  -- move focused window to a new space and tile
  move_window_1  = { { "ctrl", "alt", "cmd", "shift" }, "1" },
  move_window_2  = { { "ctrl", "alt", "cmd", "shift" }, "2" },
  move_window_3  = { { "ctrl", "alt", "cmd", "shift" }, "3" },
  move_window_4  = { { "ctrl", "alt", "cmd", "shift" }, "4" },
  move_window_5  = { { "ctrl", "alt", "cmd", "shift" }, "5" },
  move_window_6  = { { "ctrl", "alt", "cmd", "shift" }, "6" },
  move_window_7  = { { "ctrl", "alt", "cmd", "shift" }, "7" },
  move_window_8  = { { "ctrl", "alt", "cmd", "shift" }, "8" },
  move_window_9  = { { "ctrl", "alt", "cmd", "shift" }, "9" }
})

PaperWM.window_filter:rejectApp("carouselos")

PaperWM:start()

hs.mouse.getCurrentScreen()

local function shiftTilingBy(value, animate)
  local screen = hs.mouse.getCurrentScreen()

  if screen == nil then
    return
  end

  local space = hs.spaces.activeSpaceOnScreen(screen)

  PaperWM:tileSpace(space, value)
end

local shiftAmount = 0
local previousTime = 0
local velocity = 0
local momentumScroll = false
local minInitialVelocity = 500
local moveAmountX = 0
local moveAmountY = 0

local function shiftThrottled(value)
  shiftAmount = shiftAmount + value

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

  if shiftAmount ~= 0 then
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



local function resizeCurrentWindow(delta)
  PaperWM:resizeCursorWindow(delta)
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
    local horizontal_delta = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis2)

    if hs.eventtap.checkKeyboardModifiers()['cmd'] then
      handleScrollGesture(horizontal_delta * 10)
      return true
    end

    return
  end

  --print(hs.inspect(event))
  local touches = event:getTouches()

  -- matching a three finger gesture
  if #touches == 3 then
    local deltas = {}

    -- get the touches that have a previous value, add the delta to deltas
    for _, touch in ipairs(touches) do
      -- your code herg
      local prev = touchPrev[touch.identity]
      local current = touch.normalizedPosition

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
