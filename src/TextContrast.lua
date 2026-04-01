--!strict

-- TextContrast.lua
-- Chooses either white or black text based on which has stronger contrast
-- against a background Color3.

local TextContrast = {} :: any

local WHITE_TEXT = Color3.fromRGB(255, 255, 255)
local DARK_TEXT = Color3.fromRGB(0, 0, 0)

local function assertColor3(name: string, value: Color3)
	assert(typeof(value) == "Color3", string.format("%s must be a Color3", name))
end

local function assertRgbChannel(name: string, value: number)
	assert(type(value) == "number", string.format("%s must be a number", name))
	assert(value == value, string.format("%s must not be NaN", name))
	assert(value ~= math.huge and value ~= -math.huge, string.format("%s must be finite", name))
	assert(value >= 0 and value <= 255, string.format("%s must be between 0 and 255", name))
end

local function linearizeChannel(channel: number): number
	if channel <= 0.04045 then
		return channel / 12.92
	end

	return ((channel + 0.055) / 1.055) ^ 2.4
end

local function getRelativeLuminance(color: Color3): number
	local red = linearizeChannel(color.R)
	local green = linearizeChannel(color.G)
	local blue = linearizeChannel(color.B)

	return 0.2126 * red + 0.7152 * green + 0.0722 * blue
end

function TextContrast.GetRelativeLuminance(backgroundColor: Color3): number
	assertColor3("backgroundColor", backgroundColor)
	return getRelativeLuminance(backgroundColor)
end

function TextContrast.GetContrastRatio(backgroundColor: Color3, textColor: Color3): number
	assertColor3("backgroundColor", backgroundColor)
	assertColor3("textColor", textColor)

	local backgroundLuminance = getRelativeLuminance(backgroundColor)
	local textLuminance = getRelativeLuminance(textColor)

	local lighter = math.max(backgroundLuminance, textLuminance)
	local darker = math.min(backgroundLuminance, textLuminance)

	return (lighter + 0.05) / (darker + 0.05)
end

function TextContrast.ShouldUseWhiteText(backgroundColor: Color3): boolean
	assertColor3("backgroundColor", backgroundColor)

	local whiteContrast = TextContrast.GetContrastRatio(backgroundColor, WHITE_TEXT)
	local darkContrast = TextContrast.GetContrastRatio(backgroundColor, DARK_TEXT)

	return whiteContrast >= darkContrast
end

function TextContrast.GetTextColor(backgroundColor: Color3): Color3
	if TextContrast.ShouldUseWhiteText(backgroundColor) then
		return WHITE_TEXT
	end

	return DARK_TEXT
end

function TextContrast.GetTextColorFromRgb(red: number, green: number, blue: number): Color3
	assertRgbChannel("red", red)
	assertRgbChannel("green", green)
	assertRgbChannel("blue", blue)

	return TextContrast.GetTextColor(Color3.fromRGB(red, green, blue))
end

TextContrast.WhiteText = WHITE_TEXT
TextContrast.DarkText = DARK_TEXT

return TextContrast
