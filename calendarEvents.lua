local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")

local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/calendarEvents/"
kr0mCalendarEventsIcon = wibox.widget.imagebox(icon_base_path .. "calendar-none.png")

local function get_next_event_diff()
    local handle = io.popen("LC_TIME=en_US.UTF-8 khal list today 30d 2>/dev/null")
    if not handle then return nil end
    local output = handle:read("*a")
    handle:close()

    if not output or output:match("^%s*$") or output:match("No events") then
        return nil
    end

    -- Buscar la primera fecha en la salida (DD/MM/YYYY)
    local first_date = output:match("(%d%d/%d%d/%d%d%d%d)")
    if not first_date then return nil end

    local d, m, y = first_date:match("(%d%d)/(%d%d)/(%d%d%d%d)")
    if not d then return nil end

    local event_time = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour=0})
    local now_date = os.date("*t")
    local today_time = os.time({year=now_date.year, month=now_date.month, day=now_date.day, hour=0})

    local diff_days = math.floor((event_time - today_time) / (24*60*60))
    return diff_days
end

local function update_calendar_icon()
    local diff_days = get_next_event_diff()

    if not diff_days or diff_days > 30 then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-none.png")
    elseif diff_days == 0 then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-today.png")
    elseif diff_days >= 1 and diff_days <= 30 then
        kr0mCalendarEventsIcon:set_image(icon_base_path .. "calendar-" .. diff_days .. ".png")
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
    clip = true,
    widget = wibox.container.background,
}

local scroll_offset = 0
local scroll_step = 40
local visible_height_max = 300
local popup_margin = 8

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

local function update_scroll_container_height()
    local total_height = get_total_height()
    scroll_container.height = math.min(total_height, visible_height_max)
end

scroll_container:buttons(gears.table.join(
    awful.button({}, 4, function()
        local total_height = get_total_height()
        if total_height <= scroll_container.height then return end
        scroll_offset = math.max(0, scroll_offset - scroll_step)
        scroll_margin.top = -scroll_offset
    end),
    awful.button({}, 5, function()
        local total_height = get_total_height()
        if total_height <= scroll_container.height then return end
        local max_offset = math.max(0, total_height - scroll_container.height + popup_margin)
        scroll_offset = math.min(max_offset, scroll_offset + scroll_step)
        scroll_margin.top = -scroll_offset
    end)
))

-- Popup
local calendar_popup = awful.popup {
    widget = {
        scroll_container,
        margins = popup_margin,
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

-- Función corregida para mostrar días restantes y día de la semana
local function format_day_with_diff(day_str)
    local date_only = day_str:match("(%d%d/%d%d/%d%d%d%d)")
    if not date_only then return day_str end

    local d, m, y = date_only:match("(%d%d)/(%d%d)/(%d%d%d%d)")
    local event_time = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour=0, min=0, sec=0})
    local now_date = os.date("*t")
    local today_time = os.time({year=now_date.year, month=now_date.month, day=now_date.day, hour=0, min=0, sec=0})

    local diff_days = math.floor((event_time - today_time) / (24*60*60))

    local weekday_name = os.date("%A", event_time)

    local suffix = ""
    local color = "#ffffff"

    if diff_days == 0 then
        suffix = " (today)"
        color = "#00ff00"
    elseif diff_days == 1 then
        suffix = " (tomorrow)"
        color = "#00afff"
    elseif diff_days > 1 then
        suffix = " (in " .. diff_days .. " days)"
        color = "#ffaa00"
    end

    return "<span foreground='" .. color .. "'>" .. weekday_name .. " " .. date_only .. suffix .. "</span>"
end

-- Update popup content
local function update_calendar_popup()
    awful.spawn.easy_async_with_shell("LC_TIME=en_US.UTF-8 khal list today 30d", function(stdout)
        event_list:reset()
        scroll_offset = 0
        scroll_margin.top = 0

        if stdout == "" or stdout:match("^%s*$") then
            event_list:add(wibox.widget.textbox("No upcoming events."))
            update_scroll_container_height()
            return
        end

        local current_day = nil
        local day_events = {}
        local first_day = true
        local current_event = nil

        for line in stdout:gmatch("[^\r\n]+") do
            if line:match("^%s*$") then goto continue end

            if not line:match("^%s") and line:match("%d%d/%d%d/%d%d%d%d") then
                if current_day then
                    if not first_day then
                        event_list:add(wibox.widget {
                            widget = wibox.widget.separator,
                            forced_height = 1,
                            color = "#888888",
                            opacity = 0.6
                        })
                    end
                    local tb_day = wibox.widget.textbox()
                    tb_day.font = "Sans Bold 11"
                    tb_day.markup = format_day_with_diff(current_day)
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
                                    local url = desc_line:match("(https?://[%w-_%.%?%.:/%+=&]+)")
                                    if url then
                                        line_widget.markup = "    - <u><span foreground='#55ff55'>" .. desc_line .. "</span></u>"
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
                                line_widget.markup = "    - <u><span foreground='#55ff55'>" .. desc_line .. "</span></u>"
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
                        table.insert(day_events, { wibox.widget.textbox(cleaned_line) })
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
            local tb_day = wibox.widget.textbox()
            tb_day.font = "Sans Bold 11"
            tb_day.markup = format_day_with_diff(current_day)
            event_list:add(tb_day)
            for _, ev in ipairs(day_events) do
                for _, w in ipairs(ev) do
                    event_list:add(w)
                end
            end
        end

        update_scroll_container_height()
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

