-- playtag_lib.lua
-- Shared library for Playtag functionality in media players
-- Copyright (c) 2025 Johan Grande
-- License: MIT

local playtag = {}

-- Parse time in format like 1:26:03.14159 to seconds
function playtag.parse_time(time_str)
    if not time_str then return nil end

    local hours, minutes, seconds = time_str:match("^(%d+):(%d+):(%d+%.?%d*)")
    if hours and minutes and seconds then
        return tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds)
    end

    minutes, seconds = time_str:match("^(%d+):(%d+%.?%d*)")
    if minutes and seconds then
        return tonumber(minutes) * 60 + tonumber(seconds)
    end

    return tonumber(time_str)
end

-- Parse volume adjust in the format "-3.2 dB" or similar
function playtag.parse_volume_adjust(vol_str)
    if not vol_str then return nil end

    local value, unit = vol_str:match("^([%+%-]?%d+%.?%d*)%s*(%a+)$")
    if not value or not unit then return nil end

    local num_value = tonumber(value)
    if not num_value then return nil end

    unit = unit:lower()

    if unit == "db" or unit == "decibel" then
        return num_value  -- dB value is used directly
    elseif unit == "vg" or unit == "volt gain" or unit == "g" or unit == "gain" then
        -- Convert volt gain to dB
        if num_value <= 0 then return -1000 end
        return 20 * math.log(num_value, 10)
    elseif unit == "sg" or unit == "sone gain" or unit == "s" or unit == "sone" then
        -- Convert sone gain to dB
        if num_value <= 0 then return -1000 end
        return 10 * math.log(num_value, 2)
    else
        -- Unknown unit
        return nil
    end
end

-- Parse a playtag parameter (string key, optional string value)
function playtag.parse_value(key, value)
    -- "mirror" is a boolean flag
    if key == "mirror" then
        local bool_val = tostring(value):lower()
        return bool_val == "true"

    elseif key == "aspect-ratio" then
        return value

    elseif key == "av-delay" then
        return tonumber(value)

    elseif key == "t" then
        if not value or value == "" then return nil end

        -- Range specified with a dash (start-stop)
        if value:find("-") then
            -- Check if it starts with a dash (only stop time specified)
            if value:match("^%-") then
                local stop_str = value:sub(2)  -- Remove the leading dash
                local stop_time = stop_str and #stop_str > 0 and playtag.parse_time(stop_str) or nil
                return {start = nil, stop = stop_time}
            else
                -- Normal range with both start and stop
                local start_str, stop_str = value:match("^([^-]*)%-([^-]*)$")
                local start_time = start_str and #start_str > 0 and playtag.parse_time(start_str) or nil
                local stop_time  = stop_str  and #stop_str  > 0 and playtag.parse_time(stop_str)  or nil
                return {start = start_time, stop = stop_time}
            end
        else
            -- Only start time specified
            return {start = playtag.parse_time(value), stop = nil}
        end

    elseif key == "vol" then
        return playtag.parse_volume_adjust(value)

    else
        return value
    end
end

-- Parse a tag string into a table of options
function playtag.parse_tag(tag_str)
    if not tag_str or tag_str == "" then return {} end

    local opts = {}

    -- The tag string is semicolon separated (e.g., "v1; mirror; t=10-20")
    for token in tag_str:gmatch("[^;]+") do
        -- Trim leading/trailing whitespace
        token = token:gsub("^%s+", ""):gsub("%s+$", "")

        -- Skip empty tokens and the version token (v1)
        if token ~= "" and token ~= "v1" then
            local key, value = token:match("^([^=]+)=(.*)$")
            if key then
                key   = key:gsub("^%s+", ""):gsub("%s+$", "")
                value = value:gsub("^%s+", ""):gsub("%s+$", "")
                opts[key] = playtag.parse_value(key, value)
            else
                -- Bare flag (e.g., "mirror")
                token = token:gsub("^%s+", ""):gsub("%s+$", "")
                opts[token] = playtag.parse_value(token, nil)
            end
        end
    end

    return opts
end

return playtag
