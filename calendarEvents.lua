local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")

local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/calendarEvents/"
kr0mCalendarEventsIcon = wibox.widget.imagebox(icon_base_path .. "calendar-none.png")

local function has_events(range)
    local handle = io.popen("khal list " .. range .. " 2>/dev/null")
    local output = handle:read("*a")
    handle:close()
    return output ~= nil and output:match("%S") ~= nil and not output:match("No events")
end

local function update_calendar_icon()
    if has_events("today today") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-today.png")
    elseif has_events("tomorrow tomorrow") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-tomorrow.png")
    elseif has_events("today 7d") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-week.png")
    elseif has_events("today 30d") then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-month.png")
    else
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-none.png")
    end
end

-- Event list
local event_list = wibox.layout.fixed.vertical()

-- Scroll wrapper
local scroll_margin = wibox.container.margin(event_list, 0, 0, 0, 0)
local scroll_container = wibox.widget {
    scroll_margin,
    forced_width = 380,
    forced_height = 300,
    clip = true,
    widget = wibox.container.background,
}
local scroll_offset = 0
local scroll_step = 40
local visible_height = 300

local function get_total_height()
    local height = 0
    for _, widget in ipairs(event_list.children) do
        if widget.get_height_for_width then
            height = height + widget:get_height_for_width(380)
        elseif widget.forced_height then
            height = height + widget.forced_height
        else
            height = height + 20
        end
    end
    return height
end

-- Mouse wheel scroll
scroll_container:buttons(gears.table.join(
    awful.button({}, 4, function()
        scroll_offset = math.max(0, scroll_offset - scroll_step)
        scroll_margin.top = -scroll_offset
    end),
    awful.button({}, 5, function()
        local total_height = get_total_height()
        local max_offset = math.max(0, total_height - visible_height + 30)
        scroll_offset = math.min(max_offset, scroll_offset + scroll_step)
        scroll_margin.top = -scroll_offset
    end)
))

-- Popup
local calendar_popup = awful.popup {
    widget = {
        scroll_container,
        margins = 8,
        widget = wibox.container.margin
    },
    border_color = "#666666",
    border_width = 1,
    ontop = true,
    visible = false,
    shape = gears.shape.rounded_rect,
    maximum_width = 400,
    maximum_height = 300,
}

-- Update popup content
local function update_calendar_popup()
    awful.spawn.easy_async_with_shell("LC_TIME=en_US.UTF-8 khal list today 30d", function(stdout)
        event_list:reset()
        scroll_offset = 0
        scroll_margin.top = 0
        if stdout == "" or stdout:match("^%s*$") then
            event_list:add(wibox.widget.textbox("No upcoming events."))
            return
        end

        local current_day = nil
        local day_events = {}
        local first_day = true
        local current_event = nil

        for line in stdout:gmatch("[^\r\n]+") do
            if line:match("^%s*$") then goto continue end

            if not line:match("^%s") and line:match("%d%d/%d%d/%d%d%d%d") then
                -- New day
                if current_day then
                    if not first_day then
                        event_list:add(wibox.widget {
                            widget = wibox.widget.separator,
                            forced_height = 1,
                            color = "#888888",
                            opacity = 0.6
                        })
                    end
                    local tb_day = wibox.widget.textbox(current_day)
                    tb_day.font = "Sans Bold 11"
                    event_list:add(tb_day)
                    for _, ev in ipairs(day_events) do
                        for _, w in ipairs(ev) do
                            event_list:add(w)
                        end
                    end
                    first_day = false
                    day_events = {}
                end
                current_day = line
                current_event = nil
            else
                local cleaned_line = line:match("^%s*(.+)$")
                if cleaned_line and cleaned_line ~= "" then
                    if cleaned_line:match("%d%d:%d%d") or cleaned_line:match("⏰") or cleaned_line:match("⟳") then
                        current_event = {}
                        local title, desc = cleaned_line:match("^(.-)::%s*(.*)$")
                        if title then
                            table.insert(current_event, wibox.widget.textbox(title .. (desc and desc ~= "" and ":" or "")))
                            if desc and desc ~= "" then
                                for desc_line in desc:gmatch("[^\r\n]+") do
                                    local line_widget = wibox.widget.textbox("    - " .. desc_line)
                                    -- Detectar URL
                                    local url = desc_line:match("(https?://[%w-_%.%?%.:/%+=&]+)")
                                    if url then
                                        line_widget.markup = "    - <u><span foreground='#00afff'>" .. desc_line .. "</span></u>"
                                        line_widget:buttons(
                                            gears.table.join(
                                                awful.button({}, 1, function()
                                                    awful.spawn("xdg-open '" .. url .. "'")
                                                end)
                                            )
                                        )
                                    end
                                    table.insert(current_event, line_widget)
                                end
                            end
                        else
                            table.insert(current_event, wibox.widget.textbox(cleaned_line))
                        end
                        table.insert(day_events, current_event)
                    elseif current_event then
                        for desc_line in cleaned_line:gmatch("[^\r\n]+") do
                            local line_widget = wibox.widget.textbox("    - " .. desc_line)
                            local url = desc_line:match("(https?://[%w-_%.%?%.:/%+=&]+)")
                            if url then
                                line_widget.markup = "    - <u><span foreground='#00afff'>" .. desc_line .. "</span></u>"
                                line_widget:buttons(
                                    gears.table.join(
                                        awful.button({}, 1, function()
                                            awful.spawn("xdg-open '" .. url .. "'")
                                        end)
                                    )
                                )
                            end
                            table.insert(current_event, line_widget)
                        end
                    else
                        table.insert(day_events, { wibox.widget.textbox("  " .. cleaned_line) })
                    end
                end
            end
            ::continue::
        end

        if current_day then
            if not first_day then
                event_list:add(wibox.widget {
                    widget = wibox.widget.separator,
                    forced_height = 1,
                    color = "#888888",
                    opacity = 0.6
                })
            end
            local tb_day = wibox.widget.textbox(current_day)
            tb_day.font = "Sans Bold 11"
            event_list:add(tb_day)
            for _, ev in ipairs(day_events) do
                for _, w in ipairs(ev) do
                    event_list:add(w)
                end
            end
        end
    end)
end

local first_popup_show = true
local function toggle_calendar_popup()
    if calendar_popup.visible then
        calendar_popup.visible = false
    else
        update_calendar_popup()
        gears.timer.delayed_call(function()
            if first_popup_show then
                awful.placement.top_right(calendar_popup, { parent = mouse.screen, margins = { top = 40, right = 408 } })
                first_popup_show = false
            else
                awful.placement.top_right(calendar_popup, { parent = mouse.screen, margins = { top = 40, right = 8 } })
            end
            calendar_popup.visible = true
        end)
    end
end

kr0mCalendarEventsIcon:buttons(
    gears.table.join(
        awful.button({}, 1, toggle_calendar_popup)
    )
)

local calendar_timer = gears.timer({ timeout = 60 })
calendar_timer:connect_signal("timeout", update_calendar_icon)
calendar_timer:start()
update_calendar_icon()

