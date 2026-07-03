require('hs.ipc')
require('hs.mouse')

hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "t", function()
  hs.osascript.applescript('tell application "Vivaldi" to make new window')
  local app = hs.application.find("Vivaldi")
  if app then
    local win = app:mainWindow()
    if win then
      local screen = hs.mouse.getCurrentScreen()
      if screen then
        win:moveToScreen(screen)
      end
      win:focus()
    end
  end

  -- run `bar fullscreen` to tile new window to full screen (shell) (log output)
  hs.execute("sleep 0.2 && bar fullscreen", function(stdout, stderr, exitCode, stdErr)
  end)
end)

hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
  local encodedURL = fullURL:gsub('"', '\\"')
  hs.osascript.applescript(string.format([[
    tell application "Firefox"
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

hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "s", function()
  hs.osascript.applescript([[
    tell application "Ghostty"
      if it is running then
        activate
        delay 0.1
        tell application "System Events"
          tell process "Ghostty"
            click menu item "New Window" of menu "File" of menu bar 1
          end tell
        end tell
      else
        activate
      end if
    end tell
  ]])
end)

function findWindowAtCursor()
  local mousePos = hs.mouse.absolutePosition()
  local screen = hs.mouse.getCurrentScreen()
  local windows = hs.window.orderedWindows()

  for _, window in ipairs(windows) do
      if window:screen() == screen then
          local window_frame = window:frame()
          local in_x = mousePos.x >= window_frame.x and mousePos.x <= window_frame.x2
          local in_y = mousePos.y >= window_frame.y and mousePos.y <= window_frame.y2

          if in_x and in_y then
              return window
          end
      end
  end
end

function closeWindow()
  local window = findWindowAtCursor()

  if (window) then
      window:close()
  end
end

hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "w", closeWindow)
