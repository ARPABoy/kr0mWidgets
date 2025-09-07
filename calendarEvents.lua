local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")

-- Base path for calendar icons
local icon_base_path = os.getenv("HOME") .. "/.config/awesome/kr0mWidgets/media_files/calendarEvents/"
kr0mCalendarEventsIcon = wibox.widget.imagebox(icon_base_path .. "calendar-none.png")

-- Debug logging configuration
local log_file = os.getenv("HOME") .. "/.cache/awesome/calendar_debug.log"
local log_enabled = false

-- Write debug messages to a file
local function debug_log(message)
    if not log_enabled then return end
    os.execute("mkdir -p " .. os.getenv("HOME") .. "/.cache/awesome/")
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_message = "[" .. timestamp .. "] " .. message .. "\n"
    local file = io.open(log_file, "a")
    if file then
        file:write(log_message)
        file:close()
    end
end

-- Escape special characters for Pango markup
local function escape_markup(text)
    return text
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub("\"", "&quot;")
        :gsub("'", "&apos;")
end

-- Create a clickable line (with URL)
local function make_clickable_line(desc_line, url)
    local safe_line = escape_markup(desc_line)
    local w = wibox.widget.textbox()
    w.markup = "    - <u><span foreground='#55ff55'>" .. safe_line .. "</span></u>"
    w:buttons(gears.table.join(
        awful.button({}, 1, function()
            debug_log("Opening URL: " .. url)
            awful.spawn("xdg-open '" .. url .. "'")
        end)
    ))
    return w
end

-- Create a normal non-clickable line
local function make_normal_line(desc_line)
    return wibox.widget.textbox("    - " .. escape_markup(desc_line))
end

debug_log("=== CALENDAR WIDGET STARTED ===")

-- Get the number of days until the next non-Guard event
local function get_next_event_diff()
    local handle = io.popen("LC_TIME=en_US.UTF-8 khal list today 30d 2>/dev/null")
    if not handle then return nil end
    local output = handle:read("*a")
    handle:close()

    if not output or output:match("^%s*$") or output:match("No events") then
        return nil
    end

    local current_day = nil
    for line in output:gmatch("[^\r\n]+") do
        if not line:match("^%s*$") then
            -- Detect day header
            if not line:match("^%s") and line:match("%d%d/%d%d/%d%d%d%d") then
                current_day = line
            else
                -- Check for event title
                local cleaned_line = line:match("^%s*(.+)$")
                if cleaned_line then
                    local title = cleaned_line:match("^(.-)::")
                    if not title then title = cleaned_line end
                    if title ~= "Guard" then
                        -- Found a non-Guard event
                        local d, m, y = current_day:match("(%d%d)/(%d%d)/(%d%d%d%d)")
                        if d then
                            local event_time = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour=0})
                            local now_date = os.date("*t")
                            local today_time = os.time({year=now_date.year, month=now_date.month, day=now_date.day, hour=0})
                            local diff_days = math.floor((event_time - today_time) / (24*60*60))
                            return diff_days
                        end
                    end
                end
            end
        end
    end

    -- If all events are Guard or no valid events
    return nil
end

-- Update the icon based on the closest non-Guard event
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

-- List of events
local event_list = wibox.layout.fixed.vertical()

-- Scroll wrapper
local scroll_margin = wibox.container.margin(event_list, 0, 0, 0, 0)
local scroll_container = wibox.widget {
    scroll_margin,
    forced_width = 380,
    clip = true,
    widget = wibox.container.background,
}

-- Scroll config
local scroll_offset = 0
local scroll_step = 40
local visible_height_max = 300
local popup_margin = 8

-- Calculate total height of the list
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

-- Adjust scroll container height
local function update_scroll_container_height()
    local total_height = get_total_height()
    scroll_container.height = math.min(total_height, visible_height_max)
end

-- Mouse scroll support
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

-- Popup window
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

-- Format day header with weekday and remaining days
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

-- Extract URLs from text
local function extract_urls(text)
    local urls = {}
    debug_log("Extracting URLs from text: " .. text:sub(1, 100) .. "...")
    for url in text:gmatch("(https?://%S+)") do
        local clean_url = url:gsub("[%,%.%)%]%}%>%\"%'%s]+$", "")
        if clean_url ~= "" then
            table.insert(urls, clean_url)
            debug_log("Found URL: " .. clean_url)
        end
    end
    debug_log("Total URLs extracted: " .. #urls)
    return urls
end

-- Check if a line contains a URL
local function line_contains_url(line, urls)
    for _, url in ipairs(urls) do
        local escaped_url = url:gsub("[%-%.%+%*%?%^%$%(%)%[%]%%]", "%%%0")
        if line:find(escaped_url, 1, false) then
            debug_log("Line contains URL: " .. url)
            return url
        end
    end
    return nil
end

-- Update popup content with events
local function update_calendar_popup()
    debug_log("Updating calendar popup...")

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
        local last_desc_event = nil

        for line in stdout:gmatch("[^\r\n]+") do
            if line:match("^%s*$") then goto continue end

            if not line:match("^%s") and line:match("%d%d/%d%d/%d%d%d%d") then
                -- Day header
                if current_day then
                    if not first_day then
                        event_list:add(wibox.widget { widget = wibox.widget.separator, forced_height = 1, color = "#888888", opacity = 0.6 })
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
                last_desc_event = nil
            else
                local cleaned_line = line:match("^%s*(.+)$")
                if cleaned_line then
                    local title, desc = cleaned_line:match("^(.-)::%s*(.*)$")
                    if title then
                        current_event = {}
                        table.insert(current_event, wibox.widget.textbox(escape_markup(title .. (desc and desc ~= "" and ":" or ""))))
                        if desc and desc ~= "" then
                            local urls = extract_urls(desc)
                            local desc_lines = {}
                            for desc_line in desc:gmatch("[^\r\n]+") do
                                table.insert(desc_lines, desc_line)
                            end

                            if #urls > 0 then
                                for _, desc_line in ipairs(desc_lines) do
                                    local matched_url = line_contains_url(desc_line, urls)
                                    if matched_url then
                                        table.insert(current_event, make_clickable_line(desc_line, matched_url))
                                    else
                                        table.insert(current_event, make_normal_line(desc_line))
                                    end
                                end
                            else
                                for desc_line in desc:gmatch("[^\r\n]+") do
                                    table.insert(current_event, make_normal_line(desc_line))
                                end
                            end
                        end
                        table.insert(day_events, current_event)
                        last_desc_event = current_event
                    elseif last_desc_event then
                        for desc_line in cleaned_line:gmatch("[^\r\n]+") do
                            local urls = extract_urls(desc_line)
                            if #urls > 0 then
                                for _, url in ipairs(urls) do
                                    local escaped_url = url:gsub("[%-%.%+%*%?%^%$%(%)%[%]%%]", "%%%0")
                                    if desc_line:find(escaped_url, 1, false) then
                                        table.insert(last_desc_event, make_clickable_line(desc_line, url))
                                        break
                                    end
                                end
                            else
                                table.insert(last_desc_event, make_normal_line(desc_line))
                            end
                        end
                    else
                        table.insert(day_events, { wibox.widget.textbox(escape_markup(cleaned_line)) })
                    end
                end
            end
            ::continue::
        end

        if current_day then
            if not first_day then
                event_list:add(wibox.widget { widget = wibox.widget.separator, forced_height = 1, color = "#888888", opacity = 0.6 })
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

-- Toggle popup visibility
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

-- Bind left-click on icon to toggle popup
kr0mCalendarEventsIcon:buttons(
    gears.table.join(
        awful.button({}, 1, toggle_calendar_popup)
    )
)

-- Refresh icon every 30 seconds
local calendar_timer = gears.timer({ timeout = 30 })
calendar_timer:connect_signal("timeout", function()
    update_calendar_icon()
end)
calendar_timer:start()
update_calendar_icon()

return kr0mCalendarEventsIcon

