-- Per-workspace layouts (Omarchy 4.5's workspace modes): each workspace tiles
-- (dwindle), scrolls, or floats; `dots-layout` cycles and sets them (SUPER + T)
-- and the bar shows and picks them. Ported from basecamp/omarchy
-- default/hypr/workspace-modes.lua (MIT), without its titlebars and dock.
--
-- Hyprland has dwindle and scrolling as tiled layouts but nothing that floats
-- a whole workspace, so floating is applied to the windows themselves. Ending
-- the mode tiles again only the windows the mode floated, so each one is
-- tagged: the tag lives on the window, follows it between workspaces and
-- survives a config reload, none of which a table here would do.
--
-- The choices live in ~/.local/state/dots/workspace-layouts as `default=<mode>`
-- and `<workspace>=<mode>` lines, read as data (never run as code).

local M = {}

local FLOATED_TAG = "dots-mode-floated"
local OPENED_TAG = "dots-mode-opened"
local OPEN_RULE = "dots-floating-open-"
local LAST_WORKSPACE = 2147483647
local MODES = { dwindle = true, scrolling = true, floating = true }

local modes = {}
-- workspaces handed back to the default, whose layout rule follows it
local following = {}
local default_mode = nil
local watching = false
local cascade = 0
local open_rules = 0

local function state_file()
    local base = os.getenv("XDG_STATE_HOME")
    if not base or base == "" then
        base = (os.getenv("HOME") or "") .. "/.local/state"
    end
    return base .. "/dots/workspace-layouts"
end

local function set_floating(window, floating)
    hl.dispatch(hl.dsp.window.float({ action = floating and "on" or "off", window = window }))
end

local function set_claimed(window, claimed)
    hl.dispatch(hl.dsp.window.tag({ tag = (claimed and "+" or "-") .. FLOATED_TAG, window = window }))
end

local function claimed()
    local addresses = {}
    for _, window in ipairs(hl.get_windows({ tag = FLOATED_TAG })) do
        addresses[window.address] = true
    end
    return addresses
end

-- Special workspaces (the scratchpad) and named ones, which report a negative
-- id, keep whatever state a window arrived with.
local function floating_workspace(id)
    id = tonumber(id)
    if not id or id < 1 then
        return false
    end
    local mode = modes[tostring(id)]
    if mode then
        return mode == "floating"
    end
    return default_mode == "floating"
end

local function anything_floats()
    if default_mode == "floating" then
        return true
    end
    for _, mode in pairs(modes) do
        if mode == "floating" then
            return true
        end
    end
    return false
end

-- A window the mode floats takes a comfortable size in the middle of its
-- monitor, each stepped from the last so a workspace floated all at once
-- doesn't stack every window exactly on the one beneath.
local function place(window)
    local monitor = window.monitor
    if not monitor or not monitor.width then
        return
    end
    local width = math.floor(monitor.width / monitor.scale)
    local height = math.floor(monitor.height / monitor.scale)
    if (monitor.transform or 0) % 2 == 1 then
        width, height = height, width
    end
    local reserved = monitor.reserved or {}
    width = width - (reserved.left or 0) - (reserved.right or 0)
    height = height - (reserved.top or 0) - (reserved.bottom or 0)

    hl.dispatch(hl.dsp.window.resize({
        x = math.min(1100, math.floor(width * 0.64)),
        y = math.min(760, math.floor(height * 0.68)),
        relative = false,
        window = window,
    }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
    cascade = (cascade + 1) % 5
    hl.dispatch(hl.dsp.window.move({ x = cascade * 24 - 48, y = cascade * 24 - 48, relative = true, window = window }))
end

-- A window already floating on its own (a float rule, a dialog, one floated by
-- hand) is left unclaimed, so it still floats when the mode ends; a fullscreen
-- one is left as it is. Every tiled window is claimed before any is floated:
-- floating one member of a group floats the rest.
local function float_for_mode(windows)
    local claiming = {}
    for _, window in ipairs(windows) do
        if not window.floating and (window.fullscreen or 0) == 0 then
            set_claimed(window, true)
            table.insert(claiming, window)
        end
    end
    for _, window in ipairs(claiming) do
        set_floating(window, true)
        place(window)
    end
end

-- Tiling a pinned window would unpin it too, so the mode leaves it be.
local function tile_for_mode(window, mine)
    if not mine[window.address] or window.pinned then
        return
    end
    set_claimed(window, false)
    set_floating(window, false)
end

-- The floating workspaces as id ranges, for the open rules to match.
local function floating_ranges()
    local ranges = {}
    if default_mode == "floating" then
        local tiled = {}
        for id, mode in pairs(modes) do
            local n = tonumber(id)
            if n and n >= 1 and mode ~= "floating" then
                table.insert(tiled, n)
            end
        end
        table.sort(tiled)
        local from = 1
        for _, n in ipairs(tiled) do
            if n > from then
                table.insert(ranges, { from, n - 1 })
            end
            from = n + 1
        end
        table.insert(ranges, { from, LAST_WORKSPACE })
    else
        for id, mode in pairs(modes) do
            local n = tonumber(id)
            if n and n >= 1 and mode == "floating" then
                table.insert(ranges, { n, n })
            end
        end
        table.sort(ranges, function(a, b) return a[1] < b[1] end)
    end
    return ranges
end

-- The size a window opening on a floating workspace gets, and where: centred,
-- stepped from the last. Its own size isn't settled when the rule places it,
-- so the position is worked out from the size the rule gives it.
local OPEN_WIDTH = "min(1100,monitor_w*0.64)"
local OPEN_HEIGHT = "min(760,monitor_h*0.68)"

local function open_position()
    local step = cascade * 24 - 48
    return string.format("(monitor_w-%s)/2+(%d) (monitor_h-%s)/2+(%d)", OPEN_WIDTH, step, OPEN_HEIGHT, step)
end

-- A window opening on a floating workspace floats from its first frame instead
-- of opening tiled and shrinking into place. Modal dialogs are left to float
-- on their own account, at their own size.
local function sync_open_rules()
    local ranges = floating_ranges()
    for i, range in ipairs(ranges) do
        hl.window_rule({
            name = OPEN_RULE .. i,
            enabled = true,
            match = { workspace = string.format("r[%d-%d]", range[1], range[2]), modal = false },
            float = true,
            size = OPEN_WIDTH .. " " .. OPEN_HEIGHT,
            move = open_position(),
            tag = "+" .. OPENED_TAG,
        })
    end
    for i = #ranges + 1, open_rules do
        hl.window_rule({ name = OPEN_RULE .. i, enabled = false })
    end
    open_rules = math.max(open_rules, #ranges)
end

-- A rule's tag leaves with the rule, so a window the open rule floated is
-- claimed as it opens, and the mode tiles it again when it ends. (A rule's
-- tags are listed with a trailing "*".)
local function claim_opened(window)
    for _, tag in ipairs(window.tags or {}) do
        if tag == OPENED_TAG or tag == OPENED_TAG .. "*" then
            set_claimed(window, true)
            cascade = (cascade + 1) % 5
            sync_open_rules()
            return
        end
    end
end

-- The workspace is passed in when a window is still on its way to it.
local function arrange(windows, workspace)
    local floating = {}
    local mine = claimed()
    for _, window in ipairs(windows) do
        local id = tonumber(workspace and workspace.id or (window.workspace and window.workspace.id))
        if id and id >= 1 then
            if floating_workspace(id) then
                table.insert(floating, window)
            else
                tile_for_mode(window, mine)
            end
        end
    end
    float_for_mode(floating)
end

-- Overlapping windows are placed with the pointer, so a floating workspace
-- focuses on click rather than hover; every other workspace keeps your own
-- follow_mouse.
local input = {}

local function update_input()
    local workspace = hl.get_active_workspace()
    local active = workspace ~= nil and floating_workspace(workspace.id)
    if active == input.floating then
        return
    end
    input.floating = active
    hl.config({ input = { follow_mouse = active and 0 or input.follow_mouse } })
end

-- Windows arrive by opening and by being carried in, and a window rule only
-- fires for the first. One carried back out gives up the floating the mode
-- gave it.
local function watch()
    if watching then
        return
    end
    watching = true
    input.follow_mouse = hl.get_config("input.follow_mouse")

    hl.on("window.open", function(window)
        claim_opened(window)
        arrange({ window })
    end)
    -- the move is still being committed when this fires: let it land first
    hl.on("window.move_to_workspace", function(window, workspace)
        hl.timer(function() arrange({ window }, workspace) end, { type = "oneshot", timeout = 1 })
    end)
    hl.on("window.fullscreen", function(window)
        hl.timer(function() arrange({ window }) end, { type = "oneshot", timeout = 1 })
    end)
    hl.on("workspace.active", update_input)
    hl.on("monitor.focused", update_input)
end

-- One workspace's mode, or the default (workspace = nil).
function M.set(workspace, mode)
    if not MODES[mode] then
        return
    end
    watch()
    if workspace == nil then
        default_mode = mode
        if mode ~= "floating" then
            hl.config({ general = { layout = mode } })
        end
        -- a workspace handed back to the default got a rule naming the old
        -- one (workspace rules can't be removed): point those at the new one
        local tiled = (mode ~= "floating" and mode) or hl.get_config("general.layout")
        for ws in pairs(following) do
            hl.workspace_rule({ workspace = ws, layout = tiled })
        end
        sync_open_rules()
        arrange(hl.get_windows())
        update_input()
        return
    end
    workspace = tostring(workspace)
    -- floating keeps the tiled layout the workspace had, for the way back out
    if mode ~= "floating" then
        hl.workspace_rule({ workspace = workspace, layout = mode })
    end
    modes[workspace] = mode
    following[workspace] = nil
    arrange(hl.get_workspace_windows(workspace))
    sync_open_rules()
    update_input()
end

-- A workspace given back to the default.
function M.clear(workspace)
    workspace = tostring(workspace)
    modes[workspace] = nil
    following[workspace] = true
    hl.workspace_rule({ workspace = workspace, layout = (default_mode ~= "floating" and default_mode) or hl.get_config("general.layout") })
    watch()
    arrange(hl.get_workspace_windows(workspace))
    sync_open_rules()
    update_input()
end

-- At config load: read the saved choices and bring the open windows in line.
-- A reload is a fresh start here but not for the windows, so a default that no
-- longer floats still has to give back what it floated.
function M.load()
    local file = io.open(state_file(), "r")
    if file then
        for line in file:lines() do
            local key, mode = line:match("^%s*([%w]+)%s*=%s*(%a+)%s*$")
            if key and MODES[mode] then
                if key == "default" then
                    default_mode = mode
                elseif tonumber(key) and tonumber(key) >= 1 then
                    modes[key] = mode
                end
            end
        end
        file:close()
    end
    if default_mode and default_mode ~= "floating" then
        hl.config({ general = { layout = default_mode } })
    end
    for workspace, mode in pairs(modes) do
        if mode ~= "floating" then
            hl.workspace_rule({ workspace = workspace, layout = mode })
        end
    end
    local leftovers = #hl.get_windows({ tag = FLOATED_TAG }) > 0
    if anything_floats() or leftovers then
        watch()
        sync_open_rules()
        arrange(hl.get_windows())
        update_input()
    end
end

return M
