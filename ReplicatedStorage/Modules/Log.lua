--[[
	Log: gated debug logging.

	Debug lines are OFF by default so the Output window stays readable.
	Turn them on at runtime (e.g. from the command bar, server side):
	    game.ReplicatedStorage:SetAttribute("DebugLogs", true)
	or set it permanently in Studio via the ReplicatedStorage > Attributes panel.

	  Log.debug("Tag", "message %d", 5)   -- only prints when DebugLogs is true
	  Log.info("Tag", "message")          -- always prints (use sparingly)
	  Log.warn("Tag", "message")          -- always warns
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = {}

local function fmt(tag, message, ...)
	if select("#", ...) > 0 then
		message = string.format(message, ...)
	end
	return ("[%s] %s"):format(tag, tostring(message))
end

function Log.enabled()
	return ReplicatedStorage:GetAttribute("DebugLogs") == true
end

function Log.debug(tag, message, ...)
	if Log.enabled() then
		print(fmt(tag, message, ...))
	end
end

function Log.info(tag, message, ...)
	print(fmt(tag, message, ...))
end

function Log.warn(tag, message, ...)
	warn(fmt(tag, message, ...))
end

return Log
