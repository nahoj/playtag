-- playtag.lua
-- An mpv script to read and apply Playtag tags in media files
-- Copyright (c) 2025 Johan Grande
-- License: MIT

local msg = require "mp.msg"

-- Load the shared playtag library
local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)")
package.path = script_dir .. "?.lua;" .. package.path
local playtag = require("playtag_lib")

-- Extract playtag from media file metadata
local function get_playtag()
    local path = mp.get_property("path")
    if not path then return nil end

    -- Get metadata from mpv
    local metadata = mp.get_property_native("metadata")
    if not metadata then return nil end

    -- Try to find playtag in various metadata fields
    local tag = metadata.PLAYTAG or metadata.playtag

    -- Try ID3 TXXX fields (capitalization variants)
    if not tag then
        tag = metadata.TXXX_PLAYTAG or metadata.TXXX_Playtag or metadata.TXXX_playtag
    end

    -- Try MP4/M4A custom tags
    if not tag then
        -- For MP4 files the tag might be under '----:com.apple.iTunes:PlayTag'
        for key, value in pairs(metadata) do
            if key:match("PlayTag$") then
                tag = value
                break
            end
        end
    end

    return tag
end

-- Apply playtag settings to mpv
local function apply_playtag_settings()
    local tag_str = get_playtag()
    if not tag_str then return end

    msg.info("Found playtag: " .. tag_str)
    local opts = playtag.parse_tag(tag_str)

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
