-- playtag.lua
-- An mpv plugin to read and apply Playtag tags in media files
-- Copyright (c) 2025 Johan Grande
-- License: MIT

-- Utility functions
local msg = require "mp.msg"

-- Parse time in format like 1:26:03.14159 to seconds
local function parse_time(time_str)
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
local function parse_volume_adjust(vol_str)
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
        msg.warn("Unknown volume unit: " .. unit)
        return nil
    end
end

-- Parse a playtag parameter (string key, optional string value)
local function parse_value(key, value)
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
                local stop_time = stop_str and #stop_str > 0 and parse_time(stop_str) or nil
                return {start = nil, stop = stop_time}
            else
                -- Normal range with both start and stop
                local start_str, stop_str = value:match("^([^-]*)%-([^-]*)$")
                local start_time = start_str and #start_str > 0 and parse_time(start_str) or nil
                local stop_time  = stop_str  and #stop_str  > 0 and parse_time(stop_str)  or nil
                return {start = start_time, stop = stop_time}
            end
        else
            -- Only start time specified
            return {start = parse_time(value), stop = nil}
        end

    elseif key == "vol" then
        return parse_volume_adjust(value)

    else
        return value
    end
end

-- Parse a tag string into a table of options
local function parse_tag(tag_str)
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
                opts[key] = parse_value(key, value)
            else
                -- Bare flag (e.g., "mirror")
                token = token:gsub("^%s+", ""):gsub("%s+$", "")
                opts[token] = parse_value(token, nil)
            end
        end
    end

    return opts
end

-- Extract playtag from media file metadata
local function get_playtag()
    local path = mp.get_property("path")
    if not path then return nil end

    -- Get metadata from mpv
    local metadata = mp.get_property_native("metadata")
    if not metadata then return nil end

    -- Try to find playtag in various metadata fields
    local playtag = metadata.PLAYTAG or metadata.playtag

    -- Try ID3 TXXX fields (capitalization variants)
    if not playtag then
        playtag = metadata.TXXX_PLAYTAG or metadata.TXXX_Playtag or metadata.TXXX_playtag
    end

    -- Try MP4/M4A custom tags
    if not playtag then
        -- For MP4 files the tag might be under '----:com.apple.iTunes:PlayTag'
        for key, value in pairs(metadata) do
            if key:match("PlayTag$") then
                playtag = value
                break
            end
        end
    end

    return playtag
end

-- Apply playtag settings to mpv
local function apply_playtag_settings()
    local tag_str = get_playtag()
    if not tag_str then return end

    msg.info("Found playtag: " .. tag_str)
    local opts = parse_tag(tag_str)

    -- Mirror (video flip)
    if opts["mirror"] then
        mp.command("vf add hflip")
        mp.set_property("hwdec", "no")
    end

    -- Aspect ratio override
    if opts["aspect-ratio"] then
        mp.set_property("video-aspect-override", opts["aspect-ratio"])
    end

    -- AV delay
    if opts["av-delay"] then
        mp.set_property_number("audio-delay", opts["av-delay"])
    end

    -- Volume gain
    if opts["vol"] then
        mp.set_property_number("volume-gain", opts["vol"])
    end

    -- Start/stop times
    local range = opts["t"]
    if range then
        -- Seek to start if specified
        if range.start then
            mp.commandv("seek", tostring(range.start), "absolute", "exact")
        end
        -- Set up stop time handler if specified
        if range.stop then
            local stop_time = range.stop
            mp.observe_property("time-pos", "number", function(_, value)
                if value and value >= stop_time then
                    mp.commandv("playlist-next", "force")
                end
            end)
        end
    end
end

mp.register_event("file-loaded", apply_playtag_settings)

msg.debug("playtag.lua script loaded")
