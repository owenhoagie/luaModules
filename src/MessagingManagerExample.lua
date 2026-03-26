--!strict

--[[
	MessagingManagerExample

	Setup:
	1. Place `MessagingManager.lua` somewhere shared, such as ReplicatedStorage.
	2. Require it once on each client so it can listen for incoming messages.
	3. Require it on the server anywhere you want to create messengers.

	Important:
	- `DisplaySystemMessage()` is not automatically filtered by Roblox.
	- Use this module for trusted system text, or filter user-generated text first.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MessagingManager = require(ReplicatedStorage.Modules.MessagingManager)

-- Client bootstrap example:
-- Place this in a LocalScript, such as StarterPlayerScripts/ChatBootstrap.client.lua
-- local MessagingManager = require(game:GetService("ReplicatedStorage").Modules.MessagingManager)
-- MessagingManager.Start()

-- Server example:
MessagingManager.Start()

local messenger = MessagingManager.new({
	Name = "Match Director",
	Color = Color3.fromRGB(255, 209, 102),
	Font = Enum.Font.GothamBold,
	Size = 18,
	Gradient = {
		Rotation = 0,
		Stops = {
			{ Time = 0, Color = Color3.fromRGB(255, 242, 168) },
			{ Time = 1, Color = Color3.fromRGB(255, 159, 28) },
		},
	},
	FrontTags = { "[SYSTEM]" },
	BackTags = { "[LIVE]" },
	MessageColor = Color3.fromRGB(217, 240, 255),
	MessageFont = Enum.Font.SourceSans,
	MessageSize = 20,
})

messenger:Send("Warmup has started.", Players:GetPlayers())

messenger
	:SetName("Round Manager")
	:SetColor(Color3.fromRGB(123, 223, 242))
	:SetFont(Enum.Font.SourceSansBold)
	:SetSize(20)
	:RemoveBackTag("[LIVE]")
	:AddBackTag("[ROUND 1]")
	:SetMessageColor(nil)
	:SetMessageFont(Enum.Font.GothamMedium)
	:SetMessageSize(22)
	:SetMessageGradient({
		Rotation = 0,
		Stops = {
			{ Time = 0, Color = Color3.fromRGB(123, 223, 242) },
			{ Time = 0.5, Color = Color3.fromRGB(178, 247, 239) },
			{ Time = 1, Color = Color3.fromRGB(239, 247, 246) },
		},
	})
	:Send("Round 1 begins in 10 seconds.", Players:GetPlayers())
