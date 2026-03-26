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
	FrontTags = { "[SYSTEM]" },
	BackTags = { "[LIVE]" },
})

messenger:Send("Warmup has started.", Players:GetPlayers())

messenger
	:SetName("Round Manager")
	:SetColor("#7BDFF2")
	:SetFont(Enum.Font.SourceSansBold)
	:RemoveBackTag("[LIVE]")
	:AddBackTag("[ROUND 1]")
	:Send("Round 1 begins in 10 seconds.", Players:GetPlayers())
