--!strict

--[[
	ColorSimilarityScorer

	A Luau module that mirrors the public `scoreHsb` implementation shown on
	https://dialed.gg/scoring.

	Input HSB values use:
	- Hue: 0-1
	- Saturation: 0-1
	- Brightness: 0-1

	This matches normalized decimal values such as Roblox's `Color3:ToHSV()`
	output. The score is returned on a 0-10 scale.
]]

export type HSBColor = {
	H: number,
	S: number,
	B: number,
}

export type ScoreBreakdown = {
	Score: number,
	BaseScore: number,
	DeltaE: number,
	HueDifference: number,
	HueRecovery: number,
	HuePenalty: number,
}

local ColorSimilarityScorer = {} :: any

local function roundTo(value: number, decimalPlaces: number): number
	local scale = 10 ^ decimalPlaces
	return math.round(value * scale) / scale
end

local function normalizeHue(hue: number): number
	local normalized = hue % 360
	if normalized < 0 then
		normalized += 360
	end

	return normalized
end

local function assertFiniteNumber(name: string, value: number)
	assert(type(value) == "number", string.format("%s must be a number", name))
	assert(value == value, string.format("%s must not be NaN", name))
	assert(value ~= math.huge and value ~= -math.huge, string.format("%s must be finite", name))
end

local function assertUnitInterval(name: string, value: number)
	assertFiniteNumber(name, value)
	assert(value >= 0 and value <= 1, string.format("%s must be between 0 and 1", name))
end

local function assertPercent(name: string, value: number)
	assertFiniteNumber(name, value)
	assert(value >= 0 and value <= 100, string.format("%s must be between 0 and 100", name))
end

local function validateNormalizedHsb(label: string, hue: number, saturation: number, brightness: number): (number, number, number)
	assertUnitInterval(label .. " hue", hue)
	assertUnitInterval(label .. " saturation", saturation)
	assertUnitInterval(label .. " brightness", brightness)

	return normalizeHue(hue * 360), saturation * 100, brightness * 100
end

local function validateDialedHsb(label: string, hue: number, saturation: number, brightness: number): (number, number, number)
	assertFiniteNumber(label .. " hue", hue)
	assertPercent(label .. " saturation", saturation)
	assertPercent(label .. " brightness", brightness)

	return normalizeHue(hue), saturation, brightness
end

local function validateColor(label: string, color: HSBColor): (number, number, number)
	assert(type(color) == "table", string.format("%s must be an HSB table", label))
	return validateNormalizedHsb(label, color.H, color.S, color.B)
end

local function hsbToRgb(hue: number, saturation: number, brightness: number): (number, number, number)
	local s = saturation / 100
	local b = brightness / 100

	local chroma = b * s
	local x = chroma * (1 - math.abs((hue / 60) % 2 - 1))
	local match = b - chroma

	local r = 0
	local g = 0
	local blue = 0

	if hue < 60 then
		r, g, blue = chroma, x, 0
	elseif hue < 120 then
		r, g, blue = x, chroma, 0
	elseif hue < 180 then
		r, g, blue = 0, chroma, x
	elseif hue < 240 then
		r, g, blue = 0, x, chroma
	elseif hue < 300 then
		r, g, blue = x, 0, chroma
	else
		r, g, blue = chroma, 0, x
	end

	return math.round((r + match) * 255), math.round((g + match) * 255), math.round((blue + match) * 255)
end

local function pivotRgbChannel(channel: number): number
	channel /= 255

	if channel > 0.04045 then
		return ((channel + 0.055) / 1.055) ^ 2.4
	end

	return channel / 12.92
end

local function pivotLabChannel(value: number): number
	if value > 0.008856 then
		return value ^ (1 / 3)
	end

	return 7.787 * value + 16 / 116
end

local function rgbToLab(red: number, green: number, blue: number): (number, number, number)
	local r = pivotRgbChannel(red)
	local g = pivotRgbChannel(green)
	local b = pivotRgbChannel(blue)

	local x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
	local y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
	local z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883

	local fx = pivotLabChannel(x)
	local fy = pivotLabChannel(y)
	local fz = pivotLabChannel(z)

	return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end

local function calculateScore(h1: number, s1: number, b1: number, h2: number, s2: number, b2: number): ScoreBreakdown
	local r1, g1, blue1 = hsbToRgb(h1, s1, b1)
	local r2, g2, blue2 = hsbToRgb(h2, s2, b2)

	local l1, a1, labBlue1 = rgbToLab(r1, g1, blue1)
	local l2, a2, labBlue2 = rgbToLab(r2, g2, blue2)

	local deltaE = math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (labBlue1 - labBlue2) ^ 2)
	local baseScore = 10 / (1 + (deltaE / 38) ^ 1.6)

	local rawHueDifference = math.abs(h1 - h2)
	local hueDifference = math.min(rawHueDifference, 360 - rawHueDifference)
	local averageSaturation = (s1 + s2) / 2

	local hueAccuracy = math.max(0, 1 - (hueDifference / 25) ^ 1.5)
	local recoverySaturationWeight = math.min(1, averageSaturation / 30)
	local recovery = (10 - baseScore) * hueAccuracy * recoverySaturationWeight * 0.5

	local penaltyHueFactor = math.max(0, (hueDifference - 30) / 150)
	local penaltySaturationWeight = math.min(1, averageSaturation / 40)
	local penalty = baseScore * penaltyHueFactor * penaltySaturationWeight * 0.4

	local score = math.clamp(roundTo(baseScore + recovery - penalty, 2), 0, 10)

	return {
		Score = score,
		BaseScore = baseScore,
		DeltaE = deltaE,
		HueDifference = hueDifference,
		HueRecovery = recovery,
		HuePenalty = penalty,
	}
end

function ColorSimilarityScorer.Analyze(target: HSBColor, guess: HSBColor): ScoreBreakdown
	local h1, s1, b1 = validateColor("target", target)
	local h2, s2, b2 = validateColor("guess", guess)

	return calculateScore(h1, s1, b1, h2, s2, b2)
end

function ColorSimilarityScorer.Score(target: HSBColor, guess: HSBColor): number
	return ColorSimilarityScorer.Analyze(target, guess).Score
end

function ColorSimilarityScorer.AnalyzeHsb(
	targetHue: number,
	targetSaturation: number,
	targetBrightness: number,
	guessHue: number,
	guessSaturation: number,
	guessBrightness: number
): ScoreBreakdown
	local h1, s1, b1 = validateNormalizedHsb("target", targetHue, targetSaturation, targetBrightness)
	local h2, s2, b2 = validateNormalizedHsb("guess", guessHue, guessSaturation, guessBrightness)

	return calculateScore(h1, s1, b1, h2, s2, b2)
end

function ColorSimilarityScorer.ScoreHsb(
	targetHue: number,
	targetSaturation: number,
	targetBrightness: number,
	guessHue: number,
	guessSaturation: number,
	guessBrightness: number
): number
	return ColorSimilarityScorer.AnalyzeHsb(
		targetHue,
		targetSaturation,
		targetBrightness,
		guessHue,
		guessSaturation,
		guessBrightness
	).Score
end

function ColorSimilarityScorer.AnalyzeDialedScale(
	targetHue: number,
	targetSaturation: number,
	targetBrightness: number,
	guessHue: number,
	guessSaturation: number,
	guessBrightness: number
): ScoreBreakdown
	local h1, s1, b1 = validateDialedHsb("target", targetHue, targetSaturation, targetBrightness)
	local h2, s2, b2 = validateDialedHsb("guess", guessHue, guessSaturation, guessBrightness)

	return calculateScore(h1, s1, b1, h2, s2, b2)
end

function ColorSimilarityScorer.ScoreDialedScale(
	targetHue: number,
	targetSaturation: number,
	targetBrightness: number,
	guessHue: number,
	guessSaturation: number,
	guessBrightness: number
): number
	return ColorSimilarityScorer.AnalyzeDialedScale(
		targetHue,
		targetSaturation,
		targetBrightness,
		guessHue,
		guessSaturation,
		guessBrightness
	).Score
end

return ColorSimilarityScorer
