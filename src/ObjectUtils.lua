-- ObjectUtils.lua
-- A utility module for getting Roblox objects by their full path string

local ObjectUtils = {}

local function getPathSegments(fullName)
	if type(fullName) ~= "string" or fullName == "" then
		return nil, "fullName must be a non-empty string"
	end

	local segments = {}
	for segment in string.gmatch(fullName, "[^%.]+") do
		table.insert(segments, segment)
	end

	if #segments == 0 then
		return nil, "fullName must include at least one path segment"
	end

	return segments
end

local function findChildCaseInsensitive(parent, name)
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end

	local lowercaseName = string.lower(name)
	for _, candidate in ipairs(parent:GetChildren()) do
		if string.lower(candidate.Name) == lowercaseName then
			return candidate
		end
	end

	return nil
end

local function resolveRootSegment(segment)
	if string.lower(segment) == "game" then
		return game
	end

	local serviceSuccess, service = pcall(game.GetService, game, segment)
	if serviceSuccess and service then
		return service
	end

	local propertySuccess, propertyValue = pcall(function()
		return game[segment]
	end)
	if propertySuccess and typeof(propertyValue) == "Instance" then
		return propertyValue
	end

	return findChildCaseInsensitive(game, segment)
end

--[[
	Gets an object from the game hierarchy using a dot-separated path string
	
	Parameters:
		fullName (string): The full path to the object (e.g., "Workspace.Circle", "game.Players.PlayerName")
	
	Returns:
		success (boolean): Whether the operation succeeded
		object (Instance): The found object (or the last successfully found parent on failure)
		error (string, optional): Error message if the operation failed
		
	Example:
		local success, obj, err = ObjectUtils.GetObject("Workspace.Circle")
		if success then
			print("Found object:", obj.Name)
		else
			print("Failed to find object:", err)
		end
--]]
function ObjectUtils.GetObject(fullName)
	local segments, pathError = getPathSegments(fullName)
	if not segments then
		return false, nil, pathError
	end

	local current

	for index, segment in ipairs(segments) do
		local nextObject
		if index == 1 then
			nextObject = resolveRootSegment(segment)
			if not nextObject then
				return false, game, string.format("Could not resolve root path segment '%s'", segment)
			end
		else
			nextObject = findChildCaseInsensitive(current, segment)
			if not nextObject then
				return false, current, string.format("Could not resolve path segment '%s' under '%s'", segment, current:GetFullName())
			end
		end

		current = nextObject
	end

	return true, current
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
	if type(propertyName) ~= "string" or propertyName == "" then
		return false, nil, "propertyName must be a non-empty string"
	end

	local success, object, err = ObjectUtils.GetObject(fullName)
	if not success then
		return false, nil, err
	end

	local propertySuccess, propertyValue = pcall(function()
		return object[propertyName]
	end)
	if not propertySuccess then
		return false, nil, propertyValue
	end

	return true, propertyValue
end

--[[
	Checks if an object exists at the given path
	
	Parameters:
		fullName (string): The full path to check
	
	Returns:
		exists (boolean): Whether the object exists
--]]
function ObjectUtils.ObjectExists(fullName)
	local success = ObjectUtils.GetObject(fullName)
	return success
end

return ObjectUtils
