--!strict

--[[
	WebhookManagerExample

	This file serves as the standalone documentation and usage example for
	`WebhookManager.lua`.

	Setup notes:
	1. Place `WebhookManager.lua` somewhere you can `require()`, such as ReplicatedStorage.
	2. Enable "Allow HTTP Requests" in Roblox Game Settings > Security.
	3. Replace the placeholder webhook URL before calling `:Send()`.

	Quick API reference:
	- `WebhookManager.new({ webhook, username?, avatarUrl? })`
	- `:SetContent(text)` or `:AppendText(text, separator?)`
	- `:AddEmbed(embedTable?)` to begin editing an embed
	- `:Done()` to return from the embed builder to the webhook builder
	- `:Build()` to inspect the JSON-ready payload
	- `:Send()` to post the message to Discord
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WebhookManager = require(ReplicatedStorage.Modules.WebhookManager)
local noMentions: { string } = {}

local webhook = WebhookManager.new({
	webhook = "https://discord.com/api/webhooks/REPLACE_ME",
	username = "Build Bot",
	avatarUrl = "https://cdn.example.com/bot-avatar.png",
})

webhook
	:AppendText("Deployment finished successfully.")
	:AppendText("All production checks passed.")
	:SetAllowedMentions(noMentions, noMentions, noMentions, false)
	:AddEmbed()
	:SetTitle("Release v1.0.0")
	:SetDescription("The new build is live and healthy.")
	:SetColor(Color3.fromRGB(87, 242, 135))
	:SetAuthor("CI Pipeline", nil, "https://cdn.example.com/ci-icon.png")
	:AddField("Place Version", tostring(game.PlaceVersion), true)
	:AddField("Job Id", game.JobId, false)
	:SetFooter("luaModules example")
	:SetTimestamp(DateTime.now():ToIsoDate())
	:Done()

-- `Build()` lets you inspect or log the exact payload before sending it.
local payload = webhook:Build()
print(HttpService:JSONEncode(payload))

-- Uncomment this when your webhook URL is real and HTTP requests are enabled.
-- webhook:Send()
