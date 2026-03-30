--!strict

local ColorSimilarityScorer = require(script.Parent.ColorSimilarityScorer)

local target = {
	H = 0.42,
	S = 0.77,
	B = 0.24,
}

local guess = {
	H = 0.40,
	S = 0.74,
	B = 0.27,
}

local score = ColorSimilarityScorer.Score(target, guess)
local breakdown = ColorSimilarityScorer.Analyze(target, guess)

print(string.format("Score: %.2f / 10", score))
print(string.format("Base score: %.2f", breakdown.BaseScore))
print(string.format("Delta E: %.2f", breakdown.DeltaE))
print(string.format("Hue recovery: +%.2f", breakdown.HueRecovery))
print(string.format("Hue penalty: -%.2f", breakdown.HuePenalty))
