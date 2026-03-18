--!strict

--[[
	ObjectUtils

	A utility module for resolving Roblox instances from their full path strings,
	reading properties, and comparing property values safely.

	Numeric values are truncated to 2 decimal places without rounding when using
	`GetObjectProperty()` or `CompareObjectProperty()`. This helps avoid false
	negatives caused by tiny floating-point precision differences such as
	`0.00000002`.
]]

local ObjectUtils = {}

type CompareResult = (boolean, boolean?, unknown?, string?)
type GetObjectResult = (boolean, Instance, string?)
type GetPropertyResult = (boolean, unknown, string?)

-- Truncates numbers to 2 decimal places without rounding.
-- Positive numbers use floor; negative numbers use ceil so both truncate toward zero.
local function truncateNumber(value: number): number
	if value >= 0 then
		return math.floor(value * 100) / 100
	end

	return math.ceil(value * 100) / 100
end

-- Normalizes supported value types so comparisons are resilient to tiny float noise.
local function normalizeValue(value: unknown): unknown
	local valueType = typeof(value)

	if valueType == "number" then
		return truncateNumber(value :: number)
	end

	if valueType == "Vector2" then
		local vector = value :: Vector2
		return Vector2.new(truncateNumber(vector.X), truncateNumber(vector.Y))
	end

	if valueType == "Vector3" then
		local vector = value :: Vector3
		return Vector3.new(truncateNumber(vector.X), truncateNumber(vector.Y), truncateNumber(vector.Z))
	end

	if valueType == "Color3" then
		local color = value :: Color3
		return Color3.new(truncateNumber(color.R), truncateNumber(color.G), truncateNumber(color.B))
	end

	if valueType == "UDim" then
		local udim = value :: UDim
		return UDim.new(truncateNumber(udim.Scale), udim.Offset)
	end

	if valueType == "UDim2" then
		local udim2 = value :: UDim2
		return UDim2.new(
			truncateNumber(udim2.X.Scale),
			udim2.X.Offset,
			truncateNumber(udim2.Y.Scale),
			udim2.Y.Offset
		)
	end

	return value
end

--[[
	Gets an object from the game hierarchy using a dot-separated path string.

	Parameters:
		fullName (string): The full path to the object
			Examples: "Workspace.Part", "Players.PlayerName"

	Returns:
		success (boolean): Whether the operation succeeded
		object (Instance): The found object, or the last successfully found parent
		error (string, optional): Error message if the operation failed
]]
function ObjectUtils.GetObject(fullName: string): GetObjectResult
	local segments = string.split(fullName, ".")
	local current: Instance = game

	for _, segment in ipairs(segments) do
		if segment == "game" then
			continue
		end

		local nextObject = current:FindFirstChild(segment)

		if nextObject == nil then
			return false, current, string.format("Could not resolve '%s' from '%s'", segment, current:GetFullName())
		end

		current = nextObject
	end

	return true, current
end

--[[
	Gets an object and returns a specific property value.

	Parameters:
		fullName (string): The full path to the object
		propertyName (string): The name of the property to get

	Returns:
		success (boolean): Whether the operation succeeded
		value (unknown): The property value, normalized for float safety when applicable
		error (string, optional): Error message if the operation failed
]]
function ObjectUtils.GetObjectProperty(fullName: string, propertyName: string): GetPropertyResult
	local success, object, err = ObjectUtils.GetObject(fullName)

	if not success then
		return false, nil, err
	end

	local propertyValue: unknown = nil
	local propertySuccess, propertyError = pcall(function()
		propertyValue = (object :: any)[propertyName]
	end)

	if not propertySuccess then
		return false, nil, propertyError
	end

	return true, normalizeValue(propertyValue)
end

--[[
	Compares an object's property against an expected value.

	Parameters:
		fullName (string): The full path to the object
		propertyName (string): The name of the property to compare
		expectedValue (unknown): The value to compare against

	Returns:
		success (boolean): Whether the lookup/property access succeeded
		matches (boolean, optional): Whether the normalized values match
		actualValue (unknown, optional): The normalized property value
		error (string, optional): Error message if the operation failed
]]
function ObjectUtils.CompareObjectProperty(
	fullName: string,
	propertyName: string,
	expectedValue: unknown
): CompareResult
	local success, propertyValue, err = ObjectUtils.GetObjectProperty(fullName, propertyName)

	if not success then
		return false, nil, nil, err
	end

	local normalizedExpected = normalizeValue(expectedValue)
	local matches = propertyValue == normalizedExpected

	return true, matches, propertyValue
end

--[[
	Checks if an object exists at the given path.

	Parameters:
		fullName (string): The full path to check

	Returns:
		exists (boolean): Whether the object exists
]]
function ObjectUtils.ObjectExists(fullName: string): boolean
	local success = ObjectUtils.GetObject(fullName)
	return success
end

return ObjectUtils
