--!strict

local ColorSimilarityScorer = require(script.Parent.ColorSimilarityScorer)

local target = {
	H = 210,
	S = 72,
	B = 78,
}

local guess = {
	H = 205,
	S = 68,
	B = 80,
}

local score = ColorSimilarityScorer.Score(target, guess)
local breakdown = ColorSimilarityScorer.Analyze(target, guess)

print(string.format("Score: %.2f / 10", score))
print(string.format("Base score: %.2f", breakdown.BaseScore))
print(string.format("Delta E: %.2f", breakdown.DeltaE))
print(string.format("Hue recovery: +%.2f", breakdown.HueRecovery))
print(string.format("Hue penalty: -%.2f", breakdown.HuePenalty))
