--!strict

--[[
	MessagingManager

	A shared Roblox chat helper for creating named messengers that can send
	styled system messages to specific players.

	What it does:
	- Create a messenger with a name, color, and font
	- Update that messenger later through chainable setters
	- Add and remove tags shown before or after the messenger name
	- Send a formatted chat message to one player, many players, or everyone

	Important:
	- Server scripts can target recipients, but the actual chat display happens
	  on each client through `TextChannel:DisplaySystemMessage()`
	- Roblox does not automatically filter these system messages, so only send
	  trusted text or filter player-generated text before calling `:Send()`
]]

export type RecipientInput = Player | { Player } | nil
export type ColorInput = Color3 | BrickColor | string
export type FontInput = Enum.Font | string

export type Config = {
	Name: string?,
	Color: ColorInput?,
	Font: FontInput?,
	FrontTags: { string }?,
	BackTags: { string }?,
}

export type MessengerConfig = {
	Name: string,
	Color: string?,
	Font: string?,
	FrontTags: { string },
	BackTags: { string },
}

type SerializedMessage = MessengerConfig & {
	Message: string,
}

type MessengerMethods = {
	SetName: (self: Messenger, name: string) -> Messenger,
	SetColor: (self: Messenger, color: ColorInput?) -> Messenger,
	SetFont: (self: Messenger, font: FontInput?) -> Messenger,
	SetFrontTags: (self: Messenger, tags: { string }?) -> Messenger,
	SetBackTags: (self: Messenger, tags: { string }?) -> Messenger,
	AddFrontTag: (self: Messenger, tag: string) -> Messenger,
	AddBackTag: (self: Messenger, tag: string) -> Messenger,
	RemoveFrontTag: (self: Messenger, tag: string) -> Messenger,
	RemoveBackTag: (self: Messenger, tag: string) -> Messenger,
	ClearFrontTags: (self: Messenger) -> Messenger,
	ClearBackTags: (self: Messenger) -> Messenger,
	GetConfig: (self: Messenger) -> MessengerConfig,
	Format: (self: Messenger, message: string) -> string,
	Send: (self: Messenger, message: string, recipients: RecipientInput) -> Messenger,
}

type MessengerData = {
	_name: string,
	_color: string?,
	_font: string?,
	_frontTags: { string },
	_backTags: { string },
}

export type Messenger = MessengerData & MessengerMethods

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local DEFAULT_NAME = "Messenger"
local REMOTE_NAME = "MessagingManagerRemote"
local DEFAULT_CHANNEL_NAMES = { "RBXGeneral", "RBXSystem" }

local MessagingManager = {} :: any
MessagingManager.__index = MessagingManager

local remoteEvent: RemoteEvent? = nil
local clientConnection: RBXScriptConnection? = nil

local function copyStringArray(values: { string }?): { string }
	local copied: { string } = {}

	for _, value in ipairs(values or {}) do
		table.insert(copied, value)
	end

	return copied
end

local function escapeRichText(text: string): string
	return text
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&apos;")
end

local function toHexChannel(value: number): string
	return string.format("%02X", math.clamp(math.floor(value + 0.5), 0, 255))
end

local function color3ToHex(color: Color3): string
	return "#" .. toHexChannel(color.R * 255) .. toHexChannel(color.G * 255) .. toHexChannel(color.B * 255)
end

local function normalizeColor(color: ColorInput?): string?
	if color == nil then
		return nil
	end

	local valueType = typeof(color)

	if valueType == "Color3" then
		return color3ToHex(color :: Color3)
	end

	if valueType == "BrickColor" then
		return color3ToHex((color :: BrickColor).Color)
	end

	local sanitized = (color :: string):upper():gsub("#", ""):gsub("^0X", "")

	if #sanitized == 3 then
		sanitized = string.format(
			"%s%s%s%s%s%s",
			string.sub(sanitized, 1, 1),
			string.sub(sanitized, 1, 1),
			string.sub(sanitized, 2, 2),
			string.sub(sanitized, 2, 2),
			string.sub(sanitized, 3, 3),
			string.sub(sanitized, 3, 3)
		)
	end

	assert(#sanitized == 6 and sanitized:match("^[%x]+$") ~= nil, "Color must be a Color3, BrickColor, or hex string")
	return "#" .. sanitized
end

local function normalizeFont(font: FontInput?): string?
	if font == nil then
		return nil
	end

	if typeof(font) == "EnumItem" then
		local enumItem = font :: EnumItem
		assert(enumItem.EnumType == Enum.Font, "Font enum input must be an Enum.Font value")
		return enumItem.Name
	end

	assert(type(font) == "string" and font ~= "", "Font must be a non-empty string or Enum.Font")
	return font :: string
end

local function removeFirstValue(values: { string }, valueToRemove: string)
	local index = table.find(values, valueToRemove)

	if index ~= nil then
		table.remove(values, index)
	end
end

local function buildPrefix(config: MessengerConfig): string
	local parts: { string } = {}

	for _, tag in ipairs(config.FrontTags) do
		table.insert(parts, escapeRichText(tag))
	end

	table.insert(parts, escapeRichText(config.Name))

	for _, tag in ipairs(config.BackTags) do
		table.insert(parts, escapeRichText(tag))
	end

	local prefix = table.concat(parts, " ")
	local attributes: { string } = {}

	if config.Color ~= nil then
		table.insert(attributes, string.format('color="%s"', config.Color))
	end

	if config.Font ~= nil then
		table.insert(attributes, string.format('face="%s"', escapeRichText(config.Font)))
	end

	if #attributes == 0 then
		return prefix
	end

	return string.format("<font %s>%s</font>", table.concat(attributes, " "), prefix)
end

local function buildSerializedMessage(config: MessengerConfig, message: string): SerializedMessage
	return {
		Name = config.Name,
		Color = config.Color,
		Font = config.Font,
		FrontTags = copyStringArray(config.FrontTags),
		BackTags = copyStringArray(config.BackTags),
		Message = message,
	}
end

local function formatSerializedMessage(payload: SerializedMessage): string
	local prefix = buildPrefix(payload)
	return string.format("%s: %s", prefix, escapeRichText(payload.Message))
end

local function resolveRecipients(recipients: RecipientInput): { Player }
	if recipients == nil then
		return Players:GetPlayers()
	end

	if typeof(recipients) == "Instance" then
		local player = recipients :: Instance
		assert(player:IsA("Player"), "recipients must be a Player, a player array, or nil")
		return { player :: Player }
	end

	assert(type(recipients) == "table", "recipients must be a Player, a player array, or nil")

	local resolved: { Player } = {}
	local seenByUserId: { [number]: true } = {}

	for _, recipient in ipairs(recipients :: { Player }) do
		assert(typeof(recipient) == "Instance" and recipient:IsA("Player"), "Recipient arrays may only contain Player instances")

		if seenByUserId[recipient.UserId] ~= true then
			seenByUserId[recipient.UserId] = true

			if recipient.Parent == Players then
				table.insert(resolved, recipient)
			end
		end
	end

	return resolved
end

local function getRemoteEvent(): RemoteEvent
	if remoteEvent ~= nil then
		return remoteEvent
	end

	if RunService:IsServer() then
		local existingRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)

		if existingRemote ~= nil then
			assert(existingRemote:IsA("RemoteEvent"), string.format("%s must be a RemoteEvent", REMOTE_NAME))
			remoteEvent = existingRemote
			return existingRemote
		end

		local createdRemote = Instance.new("RemoteEvent")
		createdRemote.Name = REMOTE_NAME
		createdRemote.Parent = ReplicatedStorage
		remoteEvent = createdRemote
		return createdRemote
	end

	local existingRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)

	if existingRemote ~= nil then
		assert(existingRemote:IsA("RemoteEvent"), string.format("%s must be a RemoteEvent", REMOTE_NAME))
		remoteEvent = existingRemote
		return existingRemote
	end

	local waitedRemote = ReplicatedStorage:WaitForChild(REMOTE_NAME)
	assert(waitedRemote:IsA("RemoteEvent"), string.format("%s must be a RemoteEvent", REMOTE_NAME))
	remoteEvent = waitedRemote
	return waitedRemote
end

local function getDisplayChannel(): TextChannel?
	local textChannels = TextChatService:FindFirstChild("TextChannels")

	if textChannels == nil then
		textChannels = TextChatService:WaitForChild("TextChannels", 5)
	end

	if textChannels == nil then
		return nil
	end

	for _, channelName in ipairs(DEFAULT_CHANNEL_NAMES) do
		local channel = textChannels:FindFirstChild(channelName)

		if channel ~= nil and channel:IsA("TextChannel") then
			return channel
		end
	end

	return nil
end

local function displaySerializedMessage(payload: SerializedMessage)
	local channel = getDisplayChannel()

	if channel == nil then
		warn("[MessagingManager] Could not find RBXGeneral or RBXSystem to display a message.")
		return
	end

	channel:DisplaySystemMessage(formatSerializedMessage(payload))
end

local function ensureClientListener()
	if not RunService:IsClient() or clientConnection ~= nil then
		return
	end

	local remote = getRemoteEvent()
	clientConnection = remote.OnClientEvent:Connect(function(payload: SerializedMessage)
		displaySerializedMessage(payload)
	end)
end

function MessagingManager.Start()
	if RunService:IsServer() then
		getRemoteEvent()
	else
		ensureClientListener()
	end
end

function MessagingManager.new(config: Config?): Messenger
	local resolvedConfig = config or {}

	local self = setmetatable({
		_name = resolvedConfig.Name or DEFAULT_NAME,
		_color = normalizeColor(resolvedConfig.Color),
		_font = normalizeFont(resolvedConfig.Font),
		_frontTags = copyStringArray(resolvedConfig.FrontTags),
		_backTags = copyStringArray(resolvedConfig.BackTags),
	}, MessagingManager) :: Messenger

	if RunService:IsClient() then
		ensureClientListener()
	end

	return self
end

function MessagingManager:SetName(name: string): Messenger
	assert(type(name) == "string" and name ~= "", "name must be a non-empty string")
	self._name = name
	return self
end

function MessagingManager:SetColor(color: ColorInput?): Messenger
	self._color = normalizeColor(color)
	return self
end

function MessagingManager:SetFont(font: FontInput?): Messenger
	self._font = normalizeFont(font)
	return self
end

function MessagingManager:SetFrontTags(tags: { string }?): Messenger
	self._frontTags = copyStringArray(tags)
	return self
end

function MessagingManager:SetBackTags(tags: { string }?): Messenger
	self._backTags = copyStringArray(tags)
	return self
end

function MessagingManager:AddFrontTag(tag: string): Messenger
	assert(type(tag) == "string" and tag ~= "", "tag must be a non-empty string")
	table.insert(self._frontTags, tag)
	return self
end

function MessagingManager:AddBackTag(tag: string): Messenger
	assert(type(tag) == "string" and tag ~= "", "tag must be a non-empty string")
	table.insert(self._backTags, tag)
	return self
end

function MessagingManager:RemoveFrontTag(tag: string): Messenger
	removeFirstValue(self._frontTags, tag)
	return self
end

function MessagingManager:RemoveBackTag(tag: string): Messenger
	removeFirstValue(self._backTags, tag)
	return self
end

function MessagingManager:ClearFrontTags(): Messenger
	table.clear(self._frontTags)
	return self
end

function MessagingManager:ClearBackTags(): Messenger
	table.clear(self._backTags)
	return self
end

function MessagingManager:GetConfig(): MessengerConfig
	return {
		Name = self._name,
		Color = self._color,
		Font = self._font,
		FrontTags = copyStringArray(self._frontTags),
		BackTags = copyStringArray(self._backTags),
	}
end

function MessagingManager:Format(message: string): string
	assert(type(message) == "string" and message ~= "", "message must be a non-empty string")

	local payload = buildSerializedMessage(self:GetConfig(), message)

	return formatSerializedMessage(payload)
end

function MessagingManager:Send(message: string, recipients: RecipientInput): Messenger
	assert(type(message) == "string" and message ~= "", "message must be a non-empty string")

	local payload = buildSerializedMessage(self:GetConfig(), message)

	if RunService:IsServer() then
		local remote = getRemoteEvent()

		for _, recipient in ipairs(resolveRecipients(recipients)) do
			remote:FireClient(recipient, payload)
		end
	else
		ensureClientListener()

		if recipients == nil then
			displaySerializedMessage(payload)
			return self
		end

		local localPlayer = Players.LocalPlayer

		if localPlayer == nil then
			return self
		end

		for _, recipient in ipairs(resolveRecipients(recipients)) do
			if recipient == localPlayer then
				displaySerializedMessage(payload)
				break
			end
		end
	end

	return self
end

if RunService:IsClient() then
	task.defer(function()
		ensureClientListener()
	end)
end

return MessagingManager
