--- === PaperWM.spoon ===
---
--- Tile windows horizontally. Inspired by PaperWM Gnome extension.
---
--- # Usage
---
--- `PaperWM:start()` will begin automatically tiling new and existing windows.
--- `PaperWM:stop()` will release control over windows.
---
--- Set `PaperWM.window_gap` to the number of pixels to space between windows and
--- the top and bottom screen edges.
---
--- Overwrite `PaperWM.window_filter` to ignore specific applications. For example:
---
--- ```
--- PaperWM.window_filter = PaperWM.window_filter:setAppFilter("Finder", false)
--- PaperWM:start() -- restart for new window filter to take effect
--- ```
---
--- # Limitations
---
--- MacOS does not allow a window to be moved fully off-screen. Windows that would
--- be tiled off-screen are placed in a margin on the left and right edge of the
--- screen. They are still visible and clickable.
---
--- It's difficult to detect when a window is dragged from one space or screen to
--- another. Use the move_window_N commands to move windows between spaces and
--- screens.
---
--- Arrange screens vertically to prevent windows from bleeding into other screens.
---
---
--- Download: [https://github.com/mogenson/PaperWM.spoon](https://github.com/mogenson/PaperWM.spoon)
local WindowFilter<const> = hs.window.filter
local Window<const> = hs.window
local Spaces<const> = hs.spaces
local Screen<const> = hs.screen
local Timer<const> = hs.timer
local Rect<const> = hs.geometry.rect
local Watcher<const> = hs.uielement.watcher

local PaperWM = {}
PaperWM.__index = PaperWM

-- Metadata
PaperWM.name = "PaperWM"
PaperWM.version = "0.4"
PaperWM.author = "Michael Mogenson"
PaperWM.homepage = "https://github.com/mogenson/PaperWM.spoon"
PaperWM.license = "MIT - https://opensource.org/licenses/MIT"

PaperWM.default_hotkeys = {
    stop_events = {{"ctrl", "alt", "cmd", "shift"}, "q"},
    refresh_windows = {{"ctrl", "alt", "cmd", "shift"}, "r"},
    focus_left = {{"ctrl", "alt", "cmd", "shift"}, "h"},
    focus_right = {{"ctrl", "alt", "cmd", "shift"}, "l"},
    focus_up = {{"ctrl", "alt", "cmd"}, "up"},
    focus_down = {{"ctrl", "alt", "cmd"}, "down"},
    swap_left = {{"ctrl", "alt", "cmd", "shift"}, "left"},
    swap_right = {{"ctrl", "alt", "cmd", "shift"}, "right"},
    swap_up = {{"ctrl", "alt", "cmd", "shift"}, "up"},
    swap_down = {{"ctrl", "alt", "cmd", "shift"}, "down"},
    cycle_width = {{"ctrl", "alt", "cmd"}, "r"},
    cycle_height = {{"ctrl", "alt", "cmd", "shift"}, "r"},
    slurp_in = {{"ctrl", "alt", "cmd"}, "i"},
    barf_out = {{"ctrl", "alt", "cmd"}, "o"},
    switch_space_1 = {{"ctrl", "alt", "cmd"}, "1"},
    switch_space_2 = {{"ctrl", "alt", "cmd"}, "2"},
    switch_space_3 = {{"ctrl", "alt", "cmd"}, "3"},
    switch_space_4 = {{"ctrl", "alt", "cmd"}, "4"},
    switch_space_5 = {{"ctrl", "alt", "cmd"}, "5"},
    switch_space_6 = {{"ctrl", "alt", "cmd"}, "6"},
    switch_space_7 = {{"ctrl", "alt", "cmd"}, "7"},
    switch_space_8 = {{"ctrl", "alt", "cmd"}, "8"},
    switch_space_9 = {{"ctrl", "alt", "cmd"}, "9"},
    move_window_1 = {{"ctrl", "alt", "cmd", "shift"}, "1"},
    move_window_2 = {{"ctrl", "alt", "cmd", "shift"}, "2"},
    move_window_3 = {{"ctrl", "alt", "cmd", "shift"}, "3"},
    move_window_4 = {{"ctrl", "alt", "cmd", "shift"}, "4"},
    move_window_5 = {{"ctrl", "alt", "cmd", "shift"}, "5"},
    move_window_6 = {{"ctrl", "alt", "cmd", "shift"}, "6"},
    move_window_7 = {{"ctrl", "alt", "cmd", "shift"}, "7"},
    move_window_8 = {{"ctrl", "alt", "cmd", "shift"}, "8"},
    move_window_9 = {{"ctrl", "alt", "cmd", "shift"}, "9"}
}

-- filter for windows to manage
PaperWM.window_filter = WindowFilter.new():setOverrideFilter({
    visible = true,
    fullscreen = false,
    hasTitlebar = true,
    rejectTitles = {"^sams notes app$"},
    allowRoles = "AXStandardWindow"
})

-- number of pixels between windows
PaperWM.window_gap = 8

-- ratios to use when cycling widths and heights, golden ratio by default
PaperWM.window_ratios = {0.23607, 0.38195, 0.61804}

-- size of the on-screen margin to place off-screen windows
PaperWM.screen_margin = 1

-- logger
PaperWM.logger = hs.logger.new(PaperWM.name)
--PaperWM.logger.setLogLevel("debug")

PaperWM.animate = false

-- constants
local Direction<const> = {
    LEFT = -1,
    RIGHT = 1,
    UP = -2,
    DOWN = 2,
    WIDTH = 3,
    HEIGHT = 4
}

-- array of windows sorted from left to right
local window_list = {} -- 3D array of tiles in order of [space][x][y]
local index_table = {} -- dictionary of {space, x, y} with window id for keys
local ui_watchers = {} -- dictionary of uielement watchers with window id for keys
local disable_watch = {}
local pinned_windows = {}

local function debounce(func, wait)
    local timer
    return function()
        if timer ~= nil then
            timer:stop()
        end
        timer = hs.timer.doAfter(wait, function()
            func()
        end)
    end
end

local saveIndexTable = debounce(function()
    local encodable_table = {}

    for k, v in pairs(index_table) do
        encodable_table[tostring(k)] = v
    end

    hs.settings.set("index_table", encodable_table)
end, 0.2)

local function setWindowIndex(id, index)
    if index == nil then
        index_table[id] = nil
        saveIndexTable()
        return
    end

    if index_table[id] == nil then
        index_table[id] = {}
    end

    for key, value in pairs(index) do
        index_table[id][key] = value
    end

    saveIndexTable()
end

local function getWindowIndex(id)
    return index_table[id]
end

-- current focused window
local focused_window = nil

local function getSpace(index)
    local layout = Spaces.allSpaces()
    for _, screen in ipairs(Screen.allScreens()) do
        local screen_uuid = screen:getUUID()
        local num_spaces = #layout[screen_uuid]
        if num_spaces >= index then
            return layout[screen_uuid][index]
        end
        index = index - num_spaces
    end
end

local function getWindowVisibilityPercent(screen, window)
    local screen_frame = screen:frame()
    local window_frame = window:frame()

    local off_screen_left = 0

    if window_frame.x < screen_frame.x then
        off_screen_left = math.min(screen_frame.x - window_frame.x, screen_frame.w)
    end

    local off_screen_right = 0
    local window_end = window_frame.x + window_frame.w
    local screen_end = screen_frame.x + screen_frame.w

    if window_end > screen_end then
        off_screen_right = math.min(window_end - screen_end, screen_frame.w)
    end

    local off_screen_pct = (screen_frame.w - (off_screen_right + off_screen_left)) / screen_frame.w

    return off_screen_pct
end

-- Anchor window is the center-most window on the screen
local function getNearestWindowToMouse(columns, screen, mousePos)
    if columns == nil then
        return
    end

    local mouse_x = mousePos.x
    local closest_window = nil

    for _, column in ipairs(columns) do
        -- check the first window in the column
        local window = column[1]
        local window_frame = window:frame()
        local window_x = window_frame.x

        if mouse_x > window_x then
            closest_window = window
        end

        ::next::
    end

    return closest_window
end

-- Anchor window is the center-most window on the screen
local function getAnchorWindow(columns, screen, no_new_windows)
    if columns == nil then
        return
    end

    local screen_frame = screen:frame()
    local screen_cx = screen_frame.x + (screen_frame.w // 2)
    local closest_window = nil
    local min_distance = math.huge

    for _, column in ipairs(columns) do
        -- check the first window in the column
        local window = column[1]

        if no_new_windows and index_table[window:id()].tile_type == 'new' then
           goto next
        end

        if index_table[window:id()].tile_type == 'pinned' then
           goto next
        end

        local window_frame = window:frame()
        local window_cx = window_frame.x + (window_frame.w // 2)
        local distance = math.abs(window_cx - screen_cx)

        if distance < min_distance then
            closest_window = window
            min_distance = distance
        end

        ::next::
    end

    return closest_window
end

local function getColumn(space, col)
    return (window_list[space] or {})[col]
end

local function getWindow(space, col, row)
    return (getColumn(space, col) or {})[row]
end

local function getCanvas(screen)
    local screen_frame = screen:frame()
    return Rect(screen_frame.x + PaperWM.window_gap, screen_frame.y + PaperWM.window_gap,
        screen_frame.w - (2 * PaperWM.window_gap), screen_frame.h - (2 * PaperWM.window_gap))
end

local function updateIndexTable(space, column)
    local columns = window_list[space] or {}
    for col = column, #columns do
        for row, window in ipairs(getColumn(space, col)) do
            setWindowIndex(window:id(), {
                space = space,
                col = col,
                row = row
            })
        end
    end
end

local pending_window = nil
local skip_move_into_frame = false

local function windowEventHandler(window, event, self)
    self.logger.df("%s for %s", event, window)
    local space = nil

    --[[ When a new window is created, We first get a windowVisible event but
    without a Space. Next we receive a windowFocused event for the window, but
    this also sometimes lacks a Space. Our approach is to store the window
    pending a Space in the pending_window variable and set a timer to try to add
    the window again later. Also schedule the windowFocused handler to run later
    after the window was added ]]
    --

    if event == "windowFocused" then
        space = Spaces.windowSpaces(window)[1]

        if pending_window and window == pending_window then
            Timer.doAfter(Window.animationDuration, function()
                windowEventHandler(window, event, self)
            end)
            return
        end

        Timer.doAfter(0.05, function()
            if Window.focusedWindow() == window then
                focused_window = window
                space = Spaces.windowSpaces(window)[1]
                if not skip_move_into_frame then
                    PaperWM:moveIntoFrame()
                end
            end
        end)
    elseif event == "windowCreated" then
        if not self:shouldTileApp(window:application()) then
            return
        end

       if window:isVisible() and window:isStandard() and not window:isFullScreen() then
           space = self:addWindow(window, true)
       end
    elseif event == "windowVisible" or event == "windowUnfullscreened" then
        if not self:shouldTileApp(window:application()) then
            return
        end

        space = self:addWindow(window, true)
        if pending_window and window == pending_window then
            pending_window = nil -- tried to add window for the second time
        elseif not space then
            pending_window = window
            Timer.doAfter(Window.animationDuration, function()
                windowEventHandler(window, event, self)
            end)
            return
        end
    elseif event == "windowNotVisible" then
        -- when a window is closed this event is triggered. sometimes
        -- the app will choose to focus another window, but that will
        -- cause that window to be brought into the frame (above), which
        -- can cause jerky movement. So we skip moving into a frame
        -- if a window was just closed.
        skip_move_into_frame = true

        Timer.doAfter(0.1, function()
            skip_move_into_frame = false
        end)

        Timer.doAfter(0.05, function()
            local destroyed = Window.get(window:id()) == nil

            if window:isVisible() and not destroyed then
                self.logger("window visible, canceling remove window")
                return
            end

            local space = self:removeWindow(window)
            if space then
                if Spaces.activeSpaceOnScreen(Spaces.spaceDisplay(space)) == space then
                   self:tileSpace(space)
                end
            else
                -- destroyed windows don't have a space, retile all active spaces
                for _, screen in ipairs(Screen.allScreens()) do
                    local space = Spaces.activeSpaceOnScreen(screen:getUUID())

                    if space then
                        self:tileSpace(space)
                    end
                end
            end
        end)
    elseif event == "windowFullscreened" then
        space = self:removeWindow(window, true) -- don't focus new window if fullscreened
    elseif event == "AXWindowMoved" or event == "AXWindowResized" then
        --space = Spaces.windowSpaces(window)[1]
    end

    if space and Spaces.activeSpaceOnScreen(Spaces.spaceDisplay(space)) == space then
      self:tileSpace(space)
    end
end

function PaperWM:raiseTiledWindows(space)
    local windows = self.window_filter:getWindows()
    local space_windows_table = {}
    local space_windows = Spaces.windowsForSpace(space)

    for _, window in ipairs(space_windows) do
        space_windows_table[window:id()] = true
    end

    local tiled_window_above = false

    for _, window in ipairs(windows) do
        if Window.focusedWindow() ~= window and space_windows_table[window:id()] then
            if index_table[window:id()] then
                tiled_window_above = true
            elseif tiled_window_above then
                window:raise()
            end
        end
    end
end

function PaperWM:untileWindowAtCursor()

    local window = self:findWindowAtCursor()
    local space

    if window then
        if index_table[window:id()] then
            space = PaperWM:removeWindow(window, true)

            local frame = window:frame()

            frame.y = frame.y + 50
            frame.h = frame.h - 100
            focused_window:setFrame(frame)
        else
            space = PaperWM:addWindow(window, true, true)
        end

        if space then
            PaperWM:tileSpace(space)
        end
    end
end

function PaperWM:untileWindow()
    local focused = Window.focusedWindow()
    local space

    if focused then
        if index_table[focused:id()] then
            space = PaperWM:removeWindow(focused, true)

            local frame = focused:frame()

            frame.y = frame.y + 50
            frame.h = frame.h - 100
            focused_window:setFrame(frame)
        else
            space = PaperWM:addWindow(focused, true, true)
        end

        if space then
            PaperWM:tileSpace(space)
        end
    end
end

function PaperWM:pinWindow()
    local focused = Window.focusedWindow()
    local window_index = index_table[focused:id()]

    if window_index ~= nil then
        if window_index.tile_type == 'pinned' then
            table.remove(pinned_windows[window_index.space].left, window_index.col)
            PaperWM:removeWindow(focused, true)
            PaperWM:addWindow(focused, true)
           return
        end

        local column = window_list[window_index.space][window_index.col]
        table.remove(column, window_index.row)

        if #column == 0 then
            table.remove(window_list[window_index.space], window_index.col)
        end

        updateIndexTable(window_index.space, window_index.col)


        if pinned_windows[window_index.space] == nil then
           pinned_windows[window_index.space] = {
            left = {},
            right = {}
           }
        end

        table.insert(pinned_windows[window_index.space].left, focused)

        local pinned_column = pinned_windows[window_index.space].left

        setWindowIndex(focused:id(), {
            tile_type = 'pinned',
            space = window_index.space,
            col = #pinned_column
        })

        PaperWM:tileSpace(window_index.space)
        hs.eventtap.keyStroke({"cmd", "shift", "ctrl", "alt"}, "f6")
    end
end

function PaperWM:bindHotkeys(mapping)
    local partial = hs.fnutils.partial
    local spec = {
        stop_events = partial(self.stop, self),
        refresh_windows = partial(self.refreshWindows, self),
        focus_left = partial(self.focusWindow, self, Direction.LEFT),
        untile_window = partial(self.untileWindow, self),
        pin_window = partial(self.pinWindow, self),
        focus_right = partial(self.focusWindow, self, Direction.RIGHT),
        focus_up = partial(self.focusWindow, self, Direction.UP),
        focus_down = partial(self.focusWindow, self, Direction.DOWN),
        swap_left = partial(self.swapWindows, self, Direction.LEFT),
        swap_right = partial(self.swapWindows, self, Direction.RIGHT),
        swap_up = partial(self.swapWindows, self, Direction.UP),
        swap_down = partial(self.swapWindows, self, Direction.DOWN),
        center_window = partial(self.centerWindow, self),
        tile_focused_app_by_default = partial(self.tileFocusedAppByDefault, self),
        full_width = partial(self.setWindowFullWidth, self),
        cycle_width = partial(self.cycleWindowSize, self, Direction.WIDTH),
        cycle_height = partial(self.cycleWindowSize, self, Direction.HEIGHT),
        slurp_in = partial(self.slurpWindow, self),
        barf_out = partial(self.barfWindow, self),
        close_window = partial(self.closeWindow, self),
        untile_window_at_cursor = partial(self.untileWindowAtCursor, self),
        switch_space_1 = partial(self.switchToSpace, self, 1),
        switch_space_2 = partial(self.switchToSpace, self, 2),
        switch_space_3 = partial(self.switchToSpace, self, 3),
        switch_space_4 = partial(self.switchToSpace, self, 4),
        switch_space_5 = partial(self.switchToSpace, self, 5),
        switch_space_6 = partial(self.switchToSpace, self, 6),
        switch_space_7 = partial(self.switchToSpace, self, 7),
        switch_space_8 = partial(self.switchToSpace, self, 8),
        switch_space_9 = partial(self.switchToSpace, self, 9),
        move_window_1 = partial(self.moveWindowToSpace, self, 1),
        move_window_2 = partial(self.moveWindowToSpace, self, 2),
        move_window_3 = partial(self.moveWindowToSpace, self, 3),
        move_window_4 = partial(self.moveWindowToSpace, self, 4),
        move_window_5 = partial(self.moveWindowToSpace, self, 5),
        move_window_6 = partial(self.moveWindowToSpace, self, 6),
        move_window_7 = partial(self.moveWindowToSpace, self, 7),
        move_window_8 = partial(self.moveWindowToSpace, self, 8),
        move_window_9 = partial(self.moveWindowToSpace, self, 9)
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
end

local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function PaperWM:findWindowAtCursor()
    local mousePos = hs.mouse.absolutePosition()
    local screen = hs.mouse.getCurrentScreen()
    local windows = Window.orderedWindows()

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

function PaperWM:closeWindow()
    local window = self:findWindowAtCursor()

    if (window) then
        window:close()
    end
end

function PaperWM:start()
    -- check for some settings
    if not Spaces.screensHaveSeparateSpaces() then
        self.logger.e("please check 'Displays have separate Spaces' in System Preferences -> Mission Control")
    end

    -- clear state
    window_list = {}
    index_table = {}
    ui_watchers = {}
    disable_watch = {}

    focused_window = Window.focusedWindow()

    -- populate saved windows state
    PaperWM:loadSerializedIndexTable()

    -- populate window list, index table, ui_watchers, and set initial layout
    self:refreshWindows()

    -- listen for window events
    self.window_filter:subscribe(
        {WindowFilter.windowFocused, WindowFilter.windowCreated, WindowFilter.windowVisible, WindowFilter.windowNotVisible,
         WindowFilter.windowFullscreened, WindowFilter.windowUnfullscreened}, function(window, _, event)
            windowEventHandler(window, event, self)
        end)

    hs.timer.doAfter(1, function()
        -- 1. set the finder application to front most
        local finder = hs.appfinder.appFromName("Finder")
        finder:setFrontmost(false)

        hs.timer.doAfter(1, function()
            -- 2. Re-focus the focus window
            focused_window:focus()
        end)
    end)

    return self
end

function PaperWM:resizeCursorWindow(delta)
    local cursor_window = self:findWindowAtCursor()

    if cursor_window then
        local frame = cursor_window:frame()
        frame.w = frame.w + delta
        self:moveWindow(cursor_window, frame)
    end
end

function PaperWM:loadSerializedIndexTable()
    -- get all spaces
    local spaces = {}
    local screens = Screen.allScreens()
    for _, screen in ipairs(screens) do
        screen_spaces = Spaces.allSpaces()[screen:getUUID()]

        for _, space in ipairs(screen_spaces) do
            table.insert(spaces, space)
        end
    end



    -- add serialized windows to window_list in the correct order
    local load_index_table = hs.settings.get('index_table')

    if not load_index_table then
        return
    end

    for _, window in ipairs(self.window_filter:getWindows()) do
        local load_index = load_index_table[tostring(window:id())]


        if load_index and tableContains(spaces, load_index.space) and load_index.tile_type == 'tiled' then
            if (window_list[load_index.space] == nil) then
                window_list[load_index.space] = {}
            end

            local columns = window_list[load_index.space]
            local insertAt = 1
             for i = 1, #columns do
                local other_win_index = load_index_table[tostring(columns[i][1]:id())]

                if load_index.col > other_win_index.col then
                    insertAt = insertAt + 1
                elseif load_index.col == other_win_index.col then
                    local insertRow = 1
                    for j = 1, #columns[i] do
                        local other_win_index = load_index_table[tostring(columns[i][j]:id())]

                        if load_index.row > other_win_index.row then
                            insertRow = insertRow + 1
                        else
                            break
                        end
                    end

                    table.insert(window_list[load_index.space][load_index.col], insertRow, window)

                    goto next_window
                else
                    break
                end
            end

            table.insert(window_list[load_index.space], insertAt, {window})
        end
        ::next_window::
    end


    -- update index table & add window watchers
    for space, column in pairs(window_list) do
        updateIndexTable(space, 1)

        for _, row in ipairs(column) do
            for _, window in ipairs(row) do
                self:addWatcher(window)
            end
        end
    end
end

function PaperWM:stop()
    -- stop events
    self.window_filter:unsubscribeAll()
    for _, watcher in pairs(ui_watchers) do
        watcher:stop()
    end

    return self
end

function PaperWM:tileColumn(windows, bounds, h, w, id, h4id)
    local last_window, frame
    for _, window in ipairs(windows) do

        if (index_table[window:id()].tile_type == 'new') then
            setWindowIndex(window:id(), {
                tile_type = 'tiled'
            })
        end

        -- sometimes windows don't trigger the exit event
        -- TODO probably need a better way to detect this
        if window:frame().w == nil or window:frame().w == 0 then
            print('detected ghost window?', window:id(), window:isVisible(), window:title())
            PaperWM:removeWindow(window, true)
        end

        frame = window:frame()
        w = w or frame.w -- take given width or width of first window
        if bounds.x then -- set either left or right x coord
            frame.x = bounds.x
        elseif bounds.x2 then
            frame.x = bounds.x2 - w
        end
        if h then -- set height if given
            if id and h4id and window:id() == id then
                frame.h = h4id -- use this height for window with id
            else
                frame.h = h -- use this height for all other windows
            end
        end
        frame.y = bounds.y
        frame.w = w
        frame.y2 = math.min(frame.y2, bounds.y2) -- don't overflow bottom of bounds
        self:moveWindow(window, frame)
        bounds.y = math.min(frame.y2 + self.window_gap, bounds.y2)
        last_window = window
    end
    -- expand last window height to bottom
    if frame.y2 ~= bounds.y2 then
        frame.y2 = bounds.y2
        self:moveWindow(last_window, frame)
    end
    return w -- return width of column
end

local function clamp(min, max, x)
    return math.min(math.max(x, min), max)
end

function PaperWM:tileSpace(space, deltaX, override_anchor)
    if not space or Spaces.spaceType(space) ~= "user" then
        self.logger.e("current space invalid")
        return
    end

    -- find screen for space
    local screen = Screen(Spaces.spaceDisplay(space))
    if not screen then
        self.logger.e("no screen for space")
        return
    end

    -- if focused window is in space, tile from that
    focused_window = focused_window or Window.focusedWindow()
    local anchor_window = override_anchor or getAnchorWindow(window_list[space], screen, true) or getAnchorWindow(window_list[space], screen, false)

    if not anchor_window then
        self.logger.e("no anchor window in space")
        return
    end

    local anchor_index = index_table[anchor_window:id()]
    if not anchor_index then
        self.logger.e("anchor index not found")
        if self:addWindow(anchor_window) == space then
            self.logger.d("added missing window")
            anchor_index = index_table[anchor_window:id()]
        else
            return -- bail
        end
    end

    -- get some global coordinates
    local screen_frame<const> = screen:frame()
    local left_margin<const> = screen_frame.x + self.screen_margin
    local right_margin<const> = screen_frame.x2 - self.screen_margin
    local canvas<const> = getCanvas(screen)

    -- tile pinned windows
    local pinned = pinned_windows[space]

    if pinned ~= nil then
        local x = left_margin;

        for _, pinned_window in ipairs(pinned.left) do
            local frame = pinned_window:frame()
            frame.x = x + self.window_gap
            frame.y = canvas.y
            frame.h = canvas.h
            x = x + frame.w + self.window_gap
            self:moveWindow(pinned_window, frame)
        end

        canvas.x = x
    end


    -- the anchor window

    -- make sure anchor window is on screen
    local anchor_frame = anchor_window:frame()

    -- we don't the last window to be able to go fully off the screen
    local anchor_padding = 50
    anchor_frame.x = clamp(
        left_margin + anchor_padding - anchor_frame.w,
        right_margin - anchor_padding,
        anchor_frame.x + (deltaX or 0)
    )


    -- adjust anchor window column
    local column = getColumn(space, anchor_index.col)
    if not column then
        self.logger.e("no anchor window column")
        return
    end

    -- TODO: need a minimum window height
    if #column == 1 then
        anchor_frame.y, anchor_frame.h = canvas.y, canvas.h
        self:moveWindow(anchor_window, anchor_frame)
        if index_table[anchor_window:id()].tile_type == 'new' then
            setWindowIndex(anchor_window:id(), {
                tile_type = 'tiled'
            })
        end
    else
        local n = #column - 1 -- number of other windows in column
        local h = math.max(0, canvas.h - anchor_frame.h - (n * self.window_gap)) // n
        local bounds = {
            x = anchor_frame.x,
            x2 = nil,
            y = canvas.y,
            y2 = canvas.y2
        }
        self:tileColumn(column, bounds, h, anchor_frame.w, anchor_window:id(), anchor_frame.h)
    end

    -- tile windows from anchor right
    local x = math.min(anchor_frame.x2 + self.window_gap, right_margin)
    for col = anchor_index.col + 1, #(window_list[space] or {}) do
        local bounds = {
            x = x,
            x2 = nil,
            y = canvas.y,
            y2 = canvas.y2
        }
        local column_width = self:tileColumn(getColumn(space, col), bounds)
        x = math.min(x + column_width + self.window_gap, right_margin)
    end

    -- tile windows from anchor left
    local x2 = math.max(anchor_frame.x - self.window_gap, left_margin)
    for col = anchor_index.col - 1, 1, -1 do
        local bounds = {
            x = nil,
            x2 = x2,
            y = canvas.y,
            y2 = canvas.y2
        }
        local column_width = self:tileColumn(getColumn(space, col), bounds)
        x2 = math.max(x2 - column_width - self.window_gap, left_margin)
    end
end

local tile_by_default_apps = hs.settings.get("tile_by_default_apps") or {}

function PaperWM:tileFocusedAppByDefault()
    local app = hs.application.frontmostApplication()

    if not app then
        return
    end

    if tile_by_default_apps[app:name()] then
        return self:untileFocusedAppByDefault()
    end

    tile_by_default_apps[app:name()] = true
    hs.settings.set("tile_by_default_apps", tile_by_default_apps)

    self:refreshWindows()
end

function PaperWM:untileFocusedAppByDefault()
    local app = hs.application.frontmostApplication()

    if not app then
        return
    end

    tile_by_default_apps[app:name()] = nil
    hs.settings.set("tile_by_default_apps", tile_by_default_apps)

    self:refreshWindows()
end

function PaperWM:shouldTileApp(app)
    return tile_by_default_apps[app:name()]
end

function PaperWM:getTilableWindows()
    local all_windows = self.window_filter:getWindows()
    local tiled_windows = {}

    for _, window in ipairs(all_windows) do
        if self:shouldTileApp(window:application()) then
            table.insert(tiled_windows, window)
        end

        if index_table[window:id()] ~= nil then
            table.insert(tiled_windows, window)
        end
    end

    return tiled_windows
end

function PaperWM:isWindowTiled(window)
    return index_table[window:id()] ~= nil
end

function PaperWM:refreshWindows()
    -- get all windows across spaces
    local all_windows = self:getTilableWindows()

    local retile_spaces = {} -- spaces that need to be retiled
    for _, window in ipairs(all_windows) do
        local index = index_table[window:id()]
        if not index then
            -- add window
            local space = self:addWindow(window)
            if space then
                retile_spaces[space] = true
            end
        elseif index.space ~= Spaces.windowSpaces(window)[1] then
            -- move to window list in new space
            self:removeWindow(window)
            local space = self:addWindow(window)
            if space then
                retile_spaces[space] = true
            end
        end
    end

    -- retile spaces
    for space, _ in pairs(retile_spaces) do
        self:tileSpace(space)
    end
end

function PaperWM:findWindowToInsertNewWindowAfterByMousePosition(columns, screen)
    local mousePos = hs.mouse.absolutePosition()
    local anchor = nil

    for _, col in ipairs(columns) do
        local first = col[1]

        if first then
            local col_frame = first:frame()
            local col_cx = col_frame.x

            if mousePos.x > col_cx then
                anchor = first
            end
        end
    end

    return anchor
end


function PaperWM:findWindowToInsertNewWindowAfter(columns, screen, window)
    local mousePos = hs.mouse.absolutePosition()
    local wframe = window:frame()
    local wcx = wframe.x + wframe.w / 2
    local anchor = nil

    for _, col in ipairs(columns) do
        local first = col[1]

        if first then
            local col_frame = first:frame()
            local col_cx = col_frame.x + col_frame.w / 2

            if wcx > col_cx then
                anchor = first
            end
        end
    end

    return anchor
end

function PaperWM:addWindow(add_window, add_to_mouse_space, insert_at_nearest_column)
    local space = Spaces.windowSpaces(add_window)[1]
    if not space then
        self.logger.e("add window does not have a space")
        return
    end

    -- check if window is already in window list
    if index_table[add_window:id()] then
        return space
    end

    local space = Spaces.windowSpaces(add_window)[1]
    if not space then
        self.logger.e("add window does not have a space")
        return
    end

    local screen = hs.mouse.getCurrentScreen()
    if add_to_mouse_space then
        if screen ~= nil then
            local mouseSpace = hs.spaces.activeSpaceOnScreen(screen)
            space = mouseSpace

            Spaces.moveWindowToSpace(add_window, mouseSpace)
        end
    end

    if not window_list[space] then
        window_list[space] = {}
    end

    -- find where to insert window
    local add_column = 1
    local anchor_window = getAnchorWindow(window_list[space], screen)


    anchor_window = self:findWindowToInsertNewWindowAfterByMousePosition(window_list[space], screen)
    --focused_window and getWindowVisibilityPercent(screen, focused_window) > 0.5 then
     --   anchor_window = focused_window
    --end

    if insert_at_nearest_column then
       anchor_window = self:findWindowToInsertNewWindowAfter(window_list[space], screen, add_window)
    end

    -- when addWindow() is called from a window created event:
    -- focused_window from previous window focused event will not be add_window
    -- hs.window.focusedWindow() will return add_window
    -- new window focused event for add_window has not happened yet
    if anchor_window == nil and add_to_mouse_space then
        add_column = 1
    elseif anchor_window and ((index_table[anchor_window:id()] or {}).space == space) and
        (anchor_window:id() ~= add_window:id()) then
        add_column = index_table[anchor_window:id()].col + 1 -- insert to the right
    else
        local x = add_window:frame().center.x
        for col, windows in ipairs(window_list[space]) do
            if x < windows[1]:frame().center.x then
                add_column = col
                break
            end
        end
    end

    -- add window
    table.insert(window_list[space], add_column, {add_window})

    -- update index table
    updateIndexTable(space, add_column)

    -- subscribe to window moved events
    self:addWatcher(add_window)

    setWindowIndex(add_window:id(), {
        tile_type = 'new'
    })

    return space
end

function PaperWM:addWatcher(add_window)
    local watcher = add_window:newWatcher(function(window, event, _, self)
        if disable_watch[window:id()] then
            return
        end
        windowEventHandler(window, event, self)
    end, self)
    watcher:start({Watcher.windowMoved, Watcher.windowResized})
    ui_watchers[add_window:id()] = watcher
    disable_watch[add_window:id()] = false
end

local function spaceActive(space)
    return Spaces.activeSpaceOnScreen(Spaces.spaceDisplay(space)) == space
end

function PaperWM:removeWindow(remove_window, skip_new_window_focus)
    -- get index of window
    local remove_index = index_table[remove_window:id()]
    if not remove_index then
        self.logger.e("remove index not found")
        return
    end

    if not skip_new_window_focus and spaceActive(remove_index.space) then -- find nearby window to focus
        for _, direction in ipairs({Direction.DOWN, Direction.UP, Direction.LEFT, Direction.RIGHT}) do
            if self:focusWindow(direction, remove_index) then
                break
            end
        end
    end

    -- remove window
    table.remove(window_list[remove_index.space][remove_index.col], remove_index.row)
    if #window_list[remove_index.space][remove_index.col] == 0 then
        table.remove(window_list[remove_index.space], remove_index.col)
    end

    -- remove watcher
    ui_watchers[remove_window:id()] = nil
    disable_watch[remove_window:id()] = nil

    -- update index table
    setWindowIndex(remove_window:id(), nil)
    updateIndexTable(remove_index.space, remove_index.col)

    -- remove if space is empty
    if #window_list[remove_index.space] == 0 then
        window_list[remove_index.space] = nil
    end

    return remove_index.space -- return space for removed window
end

function PaperWM:focusWindow(direction, focused_index)
    if not focused_index then
        -- get current focused window
        focused_window = focused_window or Window.focusedWindow()
        if not focused_window then
            return false
        end

        -- get focused window index
        focused_index = index_table[focused_window:id()]
    end

    if not focused_index then
        self.logger.e("focused index not found")
        return false
    end

    -- get new focused window
    local new_focused_window
    if direction == Direction.LEFT or direction == Direction.RIGHT then
        -- walk down column, looking for match in neighbor column
        for row = focused_index.row, 1, -1 do
            new_focused_window = getWindow(focused_index.space, focused_index.col + direction, row)
            if new_focused_window then
                break
            end
        end
    elseif direction == Direction.UP or direction == Direction.DOWN then
        new_focused_window = getWindow(focused_index.space, focused_index.col, focused_index.row + (direction // 2))
    end

    if not new_focused_window then
        self.logger.d("new focused window not found")
        return false
    end

    -- focus new window, windowFocused event will be emited immediately
    new_focused_window:focus()
    return true
end

function PaperWM:focusedSpace()
    local focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    return focused_index.space
end

function PaperWM:swapWindows(direction)
    -- use focused window as source window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    -- get focused window index
    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    if direction == Direction.LEFT or direction == Direction.RIGHT then
        -- get target windows
        local target_index = {
            col = focused_index.col + direction
        }
        local target_column = window_list[focused_index.space][target_index.col]
        if not target_column then
            self.logger.d("target column not found")
            return
        end

        -- swap place in window list
        local focused_column = window_list[focused_index.space][focused_index.col]
        window_list[focused_index.space][target_index.col] = focused_column
        window_list[focused_index.space][focused_index.col] = target_column

        -- update index table
        for row, window in ipairs(target_column) do
            setWindowIndex(window:id(), {
                space = focused_index.space,
                col = focused_index.col,
                row = row
            })
        end
        for row, window in ipairs(focused_column) do
            setWindowIndex(window:id(), {
                space = focused_index.space,
                col = target_index.col,
                row = row
            })
        end

        -- swap frames
        local focused_frame = focused_window:frame()
        local target_frame = target_column[1]:frame()
        if direction == Direction.LEFT then
            focused_frame.x = target_frame.x
            target_frame.x = focused_frame.x2 + self.window_gap
        else -- Direction.RIGHT
            target_frame.x = focused_frame.x
            focused_frame.x = target_frame.x2 + self.window_gap
        end
        for _, window in ipairs(target_column) do
            local frame = window:frame()
            frame.x = target_frame.x
            self:moveWindow(window, frame)
            self:moveIntoFrame(100)
        end
        for _, window in ipairs(focused_column) do
            local frame = window:frame()
            frame.x = focused_frame.x
            self:moveWindow(window, frame)
            self:moveIntoFrame(100)
        end
    elseif direction == Direction.UP or direction == Direction.DOWN then
        -- get target window
        local target_index = {
            space = focused_index.space,
            col = focused_index.col,
            row = focused_index.row + (direction // 2)
        }
        local target_window = getWindow(target_index.space, target_index.col, target_index.row)
        if not target_window then
            self.logger.d("target window not found")
            return
        end

        -- swap places in window list
        window_list[target_index.space][target_index.col][target_index.row] = focused_window
        window_list[focused_index.space][focused_index.col][focused_index.row] = target_window

        -- update index table
        setWindowIndex(target_window:id(), focused_index)
        setWindowIndex(focused_window:id(), target_index)

        -- swap frames
        local focused_frame = focused_window:frame()
        local target_frame = target_window:frame()
        if direction == Direction.UP then
            focused_frame.y = target_frame.y
            target_frame.y = focused_frame.y2 + self.window_gap
        else -- Direction.DOWN
            target_frame.y = focused_frame.y
            focused_frame.y = target_frame.y2 + self.window_gap
        end
        self:moveWindow(focused_window, focused_frame)
        self:moveWindow(target_window, target_frame)
    end

    -- update layout
    self:tileSpace(focused_index.space)
end

function PaperWM:moveIntoFrame()

    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    -- get global coordinates
    local screen = focused_window:screen()
    local focused_frame = focused_window:frame()
    local screen_frame = screen:frame()

    local maxX = 0
    local minX = screen_frame.x

    -- if the window is wider then the screen, center the window
    if focused_frame.w > screen_frame.w then
        maxX = (screen_frame.x - (focused_frame.w - screen_frame.w) / 2)

        -- otherwise, maxX should be the max x that allows the
        -- window to be fully on the screen, minus the padding
    else
        maxX = ((screen_frame.x + screen_frame.w) - focused_frame.w)
    end


    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    local newFocusedFrameX

    if focused_frame.x < minX then
        newFocusedFrameX = minX

        -- add padding if there's a window to the left
        if window_list[focused_index.space][focused_index.col - 1] then
           newFocusedFrameX = newFocusedFrameX + 50
        end
    end

    if focused_frame.x > maxX then
        newFocusedFrameX = maxX

        -- add padding if there's a window to the right
        if window_list[focused_index.space][focused_index.col + 1] then
           newFocusedFrameX = newFocusedFrameX - 50
        end
    end

    if newFocusedFrameX == nil then
        return
    end

    local delta = newFocusedFrameX - focused_frame.x

    -- update layout
    local space = Spaces.windowSpaces(focused_window)[1]
    PaperWM:tileSpace(space, delta, focused_window)
end

function PaperWM:centerWindow()
    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    -- get global coordinates
    local focused_frame = focused_window:frame()
    local screen_frame = focused_window:screen():frame()

    -- center window
    focused_frame.x = screen_frame.x + (screen_frame.w // 2) - (focused_frame.w // 2)
    self:moveWindow(focused_window, focused_frame)

    -- update layout
    local space = Spaces.windowSpaces(focused_window)[1]
    self:tileSpace(space)
end

function PaperWM:setWindowFullWidth()
    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    -- fullscreen window width
    local canvas = getCanvas(focused_window:screen())
    local focused_frame = focused_window:frame()
    focused_frame.x, focused_frame.w = canvas.x, canvas.w
    self:moveWindow(focused_window, focused_frame)

    -- update layout
    local space = Spaces.windowSpaces(focused_window)[1]
    self:tileSpace(space)
end

function PaperWM:cycleWindowSize(direction)
    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    local function findNewSize(area_size, frame_size)
        local sizes = {}
        for index, ratio in ipairs(self.window_ratios) do
            sizes[index] = ratio * (area_size + self.window_gap) - self.window_gap
        end

        -- find new size
        local new_size = sizes[1]
        for _, size in ipairs(sizes) do
            if size > frame_size + 10 then
                new_size = size
                break
            end
        end

        return new_size
    end

    local canvas = getCanvas(focused_window:screen())
    local focused_frame = focused_window:frame()

    if direction == Direction.WIDTH then
        local new_width = findNewSize(canvas.w, focused_frame.w)
        focused_frame.x = focused_frame.x + ((focused_frame.w - new_width) // 2)
        focused_frame.w = new_width
    elseif direction == Direction.HEIGHT then
        local new_height = findNewSize(canvas.h, focused_frame.h)
        focused_frame.y = math.max(canvas.y, focused_frame.y + ((focused_frame.h - new_height) // 2))
        focused_frame.h = new_height
        focused_frame.y = focused_frame.y - math.max(0, focused_frame.y2 - canvas.y2)
    end

    -- apply new size
    self:moveWindow(focused_window, focused_frame)

    -- update layout
    local space = Spaces.windowSpaces(focused_window)[1]
    self:tileSpace(space)
end

function PaperWM:slurpWindow()
    -- TODO paperwm behavior:
    -- add top window from column to the right to bottom of current column
    -- if no colum to the right and current window is only window in current column,
    -- add current window to bottom of column to the left

    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    -- get window index
    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    -- get column to left
    local column = window_list[focused_index.space][focused_index.col - 1]
    if not column then
        self.logger.d("column not found")
        return
    end

    -- remove window
    table.remove(window_list[focused_index.space][focused_index.col], focused_index.row)
    if #window_list[focused_index.space][focused_index.col] == 0 then
        table.remove(window_list[focused_index.space], focused_index.col)
    end

    -- append to end of column
    table.insert(column, focused_window)

    -- update index table
    local num_windows = #column
    setWindowIndex(focused_window:id(), {
        space = focused_index.space,
        col = focused_index.col - 1,
        row = num_windows
    })
    updateIndexTable(focused_index.space, focused_index.col)

    -- adjust window frames
    local canvas = getCanvas(focused_window:screen())
    local bounds = {
        x = column[1]:frame().x,
        x2 = nil,
        y = canvas.y,
        y2 = canvas.y2
    }
    local h = math.max(0, canvas.h - ((num_windows - 1) * self.window_gap)) // num_windows
    self:tileColumn(column, bounds, h)

    -- update layout
    self:tileSpace(focused_index.space)
end

function PaperWM:barfWindow()
    -- TODO paperwm behavior:
    -- remove bottom window of current column
    -- place window into a new column to the right--

    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        return
    end

    -- get window index
    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    -- get column
    local column = window_list[focused_index.space][focused_index.col]
    if #column == 1 then
        self.logger.d("only window in column")
        return
    end

    -- remove window and insert in new column
    table.remove(column, focused_index.row)
    table.insert(window_list[focused_index.space], focused_index.col + 1, {focused_window})

    -- update index table
    updateIndexTable(focused_index.space, focused_index.col)

    -- adjust window frames
    local num_windows = #column
    local canvas = getCanvas(focused_window:screen())
    local focused_frame = focused_window:frame()
    local bounds = {
        x = focused_frame.x,
        x2 = nil,
        y = canvas.y,
        y2 = canvas.y2
    }
    local h = math.max(0, canvas.h - ((num_windows - 1) * self.window_gap)) // num_windows
    focused_frame.y = canvas.y
    focused_frame.x = focused_frame.x2 + self.window_gap
    focused_frame.h = canvas.h
    self:moveWindow(focused_window, focused_frame)
    self:tileColumn(column, bounds, h)

    -- update layout
    self:tileSpace(focused_index.space)
end

function PaperWM:switchToSpace(index)
    local space = getSpace(index)
    if not space then
        self.logger.d("space not found")
        return
    end

    -- find a window to focus in new space
    local windows = Spaces.windowsForSpace(space)
    for _, id in ipairs(windows) do
        local index = index_table[id]
        if index then
            -- https://github.com/Hammerspoon/hammerspoon/issues/370
            -- raise app before focusing window
            local window = getWindow(index.space, index.col, index.row)
            local app = window:application()
            app:activate()
            Timer.usleep(10000)
            window:focus()
            break
        end
    end

    Spaces.gotoSpace(space)
end

function PaperWM:moveWindowToSpace(index)
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        self.logger.d("focused window not found")
        return
    end

    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    local new_space = getSpace(index)
    if not new_space then
        self.logger.d("space not found")
        return
    end

    if Spaces.spaceType(new_space) ~= "user" then
        self.logger.d("space is invalid")
        return
    end

    local screen = Screen(Spaces.spaceDisplay(new_space))
    if not screen then
        self.logger.d("screen not found")
        return
    end

    -- cache a local copy, removeWindow() will clear global focused_window
    local focused_window = focused_window
    local old_space = self:removeWindow(focused_window)
    if not old_space then
        self.logger.e("can't remove focused window")
        return
    end

    Spaces.moveWindowToSpace(focused_window, new_space)
    self:addWindow(focused_window)
    self:tileSpace(old_space)
    self:tileSpace(new_space)
    Spaces.gotoSpace(new_space)
end

function PaperWM:moveWindow(window, frame)
    local watcher = ui_watchers[window:id()]
    if not watcher then
        self.logger.e("window does not have ui watcher")
        return
    end

    -- don't re-enable watch if it's already disabled
    local should_enable_watch = disable_watch[window:id()] == false
    disable_watch[window:id()] = true

    local window_frame = window:frame()

    if frame == window_frame then
        self.logger.v("no change in window frame")
        return
    end

    if PaperWM.animate then
        window:setFrame(frame)

        -- greater than 0.017 hs.window animation step time
        local padding<const> = 0.02
        hs.timer.doAfter(Window.animationDuration + padding, function()
            if should_enable_watch then
                disable_watch[window:id()] = false
            end
        end)
    else
        if frame.x ~= window_frame.x or frame.y ~= window_frame.y then
            window:setTopLeft(frame)
        end

        if frame.w ~= window_frame.w or frame.h ~= window_frame.h then
            window:setSize(frame)
        end

        if should_enable_watch then
            disable_watch[window:id()] = false
        end
    end
end

return PaperWM
