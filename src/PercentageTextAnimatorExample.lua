--!strict

--[[
	PercentageTextAnimatorExample

	Setup:
	1. Place `PercentageTextAnimator.lua` somewhere you can `require()`, such as ReplicatedStorage.
	2. Put this example logic in a LocalScript.
	3. Point `percentageLabel` at your UI TextLabel.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PercentageTextAnimator = require(ReplicatedStorage.Modules.PercentageTextAnimator)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("ScreenGui")
local percentageLabel = screenGui:WaitForChild("PercentageLabel") :: TextLabel

percentageLabel.Text = "0.00 %"

local animation = PercentageTextAnimator.Animate(percentageLabel, 84.37, {
	Duration = 2.5,
	StartValue = 0,
	DecimalPlaces = 2,
})

animation:Wait()
print("Finished animating to", percentageLabel.Text)

-- You can reuse it with a different target later:
task.wait(1)

PercentageTextAnimator.Animate(percentageLabel, 96.12, {
	Duration = 3,
	StartValue = 0,
	DecimalPlaces = 2,
	EasingStyle = Enum.EasingStyle.Exponential,
	EasingDirection = Enum.EasingDirection.Out,
})
