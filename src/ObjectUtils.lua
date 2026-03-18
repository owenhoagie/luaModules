-- ObjectUtils.lua
-- A utility module for getting Roblox objects by their full path string

local ObjectUtils = {}

--[[
	Gets an object from the game hierarchy using a dot-separated path string
	
	Parameters:
		fullName (string): The full path to the object (e.g., "workspace.Circle", "game.Players.PlayerName")
	
	Returns:
		success (boolean): Whether the operation succeeded
		object (Instance): The found object (or the last successfully found parent on failure)
		error (string, optional): Error message if the operation failed
		
	Example:
		local success, obj, err = ObjectUtils.GetObject("workspace.Circle")
		if success then
			print("Found object:", obj.Name)
		else
			print("Failed to find object:", err)
		end
--]]

function ObjectUtils.GetObject(fullName)
	local segments = fullName:split(".")
	local current = game

	local succ, err = pcall(function()
		for _, location in pairs(segments) do
			current = current[location]
		end
	end)

	if not succ then
		-- Object detected on client but doesn't exist on server, or path is invalid
		return succ, current, err
	end

	return succ, current
end

--[[
	Gets an object and returns a specific property value
	
	Parameters:
		fullName (string): The full path to the object
		propertyName (string): The name of the property to get
	
	Returns:
		success (boolean): Whether the operation succeeded
		value (any): The property value
		error (string, optional): Error message if failed
--]]
function ObjectUtils.GetObjectProperty(fullName, propertyName)
	local success, object, err = ObjectUtils.GetObject(fullName)

	if not success then
		return false, nil, err
	end

	local propSuccess, propErr = pcall(function()
		return object[propertyName]
	end)

	if not propSuccess then
		return false, nil, propErr
	end

	return true, object[propertyName]
end

--[[
	Checks if an object exists at the given path
	
	Parameters:
		fullName (string): The full path to check
	
	Returns:
		exists (boolean): Whether the object exists
--]]
function ObjectUtils.ObjectExists(fullName)
	local success, _ = ObjectUtils.GetObject(fullName)
	return success
end

return ObjectUtils
