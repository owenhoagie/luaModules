--!strict

--[[
	MessagingManager

	A shared Roblox chat helper for creating named messengers that can send
	styled system messages to specific players.

	What it does:
	- Create a messenger with a name, color, font, size, and optional gradient
	- Style the message body separately from the messenger prefix
	- Keep public colors as `Color3` values so callers can preview them in Studio
	- Accept gradients as `ColorSequence` values or `{ Time, Color }` stop arrays
	- Add and remove tags shown before or after the messenger name
	- Send a formatted chat message to one player, many players, or everyone

	Important:
	- Server scripts can target recipients, but the actual chat display happens
	  on each client through `TextChannel:DisplaySystemMessage()`
	- Gradients are applied client-side through `TextChatService.OnChatWindowAdded`
	- Roblox does not automatically filter these system messages, so only send
	  trusted text or filter player-generated text before calling `:Send()`
]]

export type RecipientInput = Player | { Player } | nil
export type ColorInput = Color3 | BrickColor | string
export type FontInput = Enum.Font | string
export type GradientStopInput = {
	Time: number,
	Color: ColorInput,
}
export type GradientInput = ColorSequence | { GradientStopInput } | {
	Stops: { GradientStopInput },
	Rotation: number?,
}

type GradientStopConfig = {
	Time: number,
	Color: Color3,
}

type GradientConfig = {
	Rotation: number,
	Stops: { GradientStopConfig },
}

export type Config = {
	Name: string?,
	Color: ColorInput?,
	Font: FontInput?,
	Size: number?,
	Gradient: GradientInput?,
	FrontTags: { string }?,
	BackTags: { string }?,
	MessageColor: ColorInput?,
	MessageFont: FontInput?,
	MessageSize: number?,
	MessageGradient: GradientInput?,
}

export type MessengerConfig = {
	Name: string,
	Color: Color3?,
	Font: string?,
	Size: number?,
	Gradient: GradientConfig?,
	FrontTags: { string },
	BackTags: { string },
	MessageColor: Color3?,
	MessageFont: string?,
	MessageSize: number?,
	MessageGradient: GradientConfig?,
}

type SerializedMessage = MessengerConfig & {
	Message: string,
}

type MessengerMethods = {
	SetName: (self: Messenger, name: string) -> Messenger,
	SetColor: (self: Messenger, color: ColorInput?) -> Messenger,
	SetFont: (self: Messenger, font: FontInput?) -> Messenger,
	SetSize: (self: Messenger, size: number?) -> Messenger,
	SetGradient: (self: Messenger, gradient: GradientInput?, rotation: number?) -> Messenger,
	SetMessageColor: (self: Messenger, color: ColorInput?) -> Messenger,
	SetMessageFont: (self: Messenger, font: FontInput?) -> Messenger,
	SetMessageSize: (self: Messenger, size: number?) -> Messenger,
	SetMessageGradient: (self: Messenger, gradient: GradientInput?, rotation: number?) -> Messenger,
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
	_color: Color3?,
	_font: string?,
	_size: number?,
	_gradient: GradientConfig?,
	_messageColor: Color3?,
	_messageFont: string?,
	_messageSize: number?,
	_messageGradient: GradientConfig?,
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
local MESSAGE_METADATA_PREFIX = "MessagingManager/"

local MessagingManager = {} :: any
MessagingManager.__index = MessagingManager

local remoteEvent: RemoteEvent? = nil
local clientConnection: RBXScriptConnection? = nil
local chatWindowHookInstalled = false
local pendingMessages: { [string]: SerializedMessage } = {}
local nextMessageId = 0

local function copyStringArray(values: { string }?): { string }
	local copied: { string } = {}

	for _, value in ipairs(values or {}) do
		table.insert(copied, value)
	end

	return copied
end

local function copyGradientStops(stops: { GradientStopConfig }?): { GradientStopConfig }?
	if stops == nil then
		return nil
	end

	local copied: { GradientStopConfig } = {}

	for _, stop in ipairs(stops) do
		table.insert(copied, {
			Time = stop.Time,
			Color = stop.Color,
		})
	end

	return copied
end

local function copyGradient(gradient: GradientConfig?): GradientConfig?
	if gradient == nil then
		return nil
	end

	return {
		Rotation = gradient.Rotation,
		Stops = copyGradientStops(gradient.Stops) or {},
	}
end

local function escapeRichText(text: string): string
	local escaped = text
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&apos;")

	return escaped
end

local function toHexChannel(value: number): string
	return string.format("%02X", math.clamp(math.floor(value + 0.5), 0, 255))
end

local function color3ToHex(color: Color3): string
	return "#" .. toHexChannel(color.R * 255) .. toHexChannel(color.G * 255) .. toHexChannel(color.B * 255)
end

local function normalizeColor(color: ColorInput?): Color3?
	if color == nil then
		return nil
	end

	local valueType = typeof(color)

	if valueType == "Color3" then
		return color :: Color3
	end

	if valueType == "BrickColor" then
		return (color :: BrickColor).Color
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
	local red = tonumber(string.sub(sanitized, 1, 2), 16) or 0
	local green = tonumber(string.sub(sanitized, 3, 4), 16) or 0
	local blue = tonumber(string.sub(sanitized, 5, 6), 16) or 0
	return Color3.fromRGB(red, green, blue)
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

local function normalizeSize(size: number?): number?
	if size == nil then
		return nil
	end

	assert(type(size) == "number" and size > 0, "Size must be a positive number")
	return math.floor(size + 0.5)
end

local function sortGradientStops(stops: { GradientStopConfig })
	table.sort(stops, function(left, right)
		return left.Time < right.Time
	end)
end

local function normalizeGradientStopsFromEntries(entries: { GradientStopInput }): { GradientStopConfig }
	assert(#entries > 0, "Gradient stop arrays must contain at least one entry")

	local stops: { GradientStopConfig } = {}

	for _, entry in ipairs(entries) do
		local normalizedColor = normalizeColor(entry.Color)

		assert(normalizedColor ~= nil, "Gradient stop colors cannot be nil")
		assert(type(entry.Time) == "number", "Gradient stops must include a numeric Time")
		assert(entry.Time >= 0 and entry.Time <= 1, "Gradient stop Time values must be between 0 and 1")

		table.insert(stops, {
			Time = entry.Time,
			Color = normalizedColor,
		})
	end

	if #stops == 1 then
		local single = stops[1]
		return {
			{
				Time = 0,
				Color = single.Color,
			},
			{
				Time = 1,
				Color = single.Color,
			},
		}
	end

	sortGradientStops(stops)
	return stops
end

local function normalizeGradient(gradient: GradientInput?, rotation: number?): GradientConfig?
	if gradient == nil then
		return nil
	end

	local resolvedRotation = if rotation ~= nil then rotation else 0
	local stops: { GradientStopConfig }
	local gradientType = typeof(gradient)

	if gradientType == "ColorSequence" then
		stops = {}

		for _, keypoint in ipairs((gradient :: ColorSequence).Keypoints) do
			table.insert(stops, {
				Time = keypoint.Time,
				Color = keypoint.Value,
			})
		end
	elseif type(gradient) == "table" then
		local gradientTable = gradient :: any

		if gradientTable.Rotation ~= nil and rotation == nil then
			resolvedRotation = gradientTable.Rotation
		end

		if gradientTable.Stops ~= nil then
			stops = normalizeGradientStopsFromEntries(gradientTable.Stops)
		else
			stops = normalizeGradientStopsFromEntries(gradient :: { GradientStopInput })
		end
	else
		error("Gradient must be a ColorSequence or a table of { Time, Color } stops", 2)
	end

	sortGradientStops(stops)

	return {
		Rotation = resolvedRotation,
		Stops = stops,
	}
end

local function removeFirstValue(values: { string }, valueToRemove: string)
	local index = table.find(values, valueToRemove)

	if index ~= nil then
		table.remove(values, index)
	end
end

local function buildFontAttributes(font: string?, size: number?): { string }
	local attributes: { string } = {}

	if font ~= nil then
		table.insert(attributes, string.format('face="%s"', escapeRichText(font)))
	end

	if size ~= nil then
		table.insert(attributes, string.format('size="%d"', size))
	end

	return attributes
end

local function buildStyledText(text: string, font: string?, size: number?): string
	local escapedText = escapeRichText(text)
	local attributes = buildFontAttributes(font, size)

	if #attributes == 0 then
		return escapedText
	end

	return string.format("<font %s>%s</font>", table.concat(attributes, " "), escapedText)
end

local function buildPrefix(config: MessengerConfig): string
	local parts: { string } = {}

	for _, tag in ipairs(config.FrontTags) do
		table.insert(parts, tag)
	end

	table.insert(parts, config.Name)

	for _, tag in ipairs(config.BackTags) do
		table.insert(parts, tag)
	end

	return buildStyledText(table.concat(parts, " "), config.Font, config.Size)
end

local function buildBodyText(payload: SerializedMessage): string
	return buildStyledText(payload.Message, payload.MessageFont, payload.MessageSize)
end

local function buildSerializedMessage(config: MessengerConfig, message: string): SerializedMessage
	return {
		Name = config.Name,
		Color = config.Color,
		Font = config.Font,
		Size = config.Size,
		Gradient = copyGradient(config.Gradient),
		FrontTags = copyStringArray(config.FrontTags),
		BackTags = copyStringArray(config.BackTags),
		MessageColor = config.MessageColor,
		MessageFont = config.MessageFont,
		MessageSize = config.MessageSize,
		MessageGradient = copyGradient(config.MessageGradient),
		Message = message,
	}
end

local function formatSerializedMessage(payload: SerializedMessage): string
	return string.format("%s: %s", buildPrefix(payload), buildBodyText(payload))
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

local function deriveMessageProperties(): ChatWindowMessageProperties
	local configuration = TextChatService.ChatWindowConfiguration

	if configuration ~= nil then
		return configuration:DeriveNewMessageProperties()
	end

	return Instance.new("ChatWindowMessageProperties") :: any
end

local function ensurePrefixTextProperties(properties: ChatWindowMessageProperties): ChatWindowMessageProperties
	if properties.PrefixTextProperties ~= nil then
		return properties.PrefixTextProperties
	end

	local derivedPrefixProperties = deriveMessageProperties()
	properties.PrefixTextProperties = derivedPrefixProperties
	return derivedPrefixProperties
end

local function applyGradient(target: Instance, gradient: GradientConfig?)
	if gradient == nil then
		return
	end

	local keypoints: { ColorSequenceKeypoint } = {}

	for _, stop in ipairs(gradient.Stops) do
		table.insert(keypoints, ColorSequenceKeypoint.new(stop.Time, stop.Color))
	end

	local uiGradient = Instance.new("UIGradient")
	uiGradient.Color = ColorSequence.new(keypoints)
	uiGradient.Rotation = gradient.Rotation
	uiGradient.Parent = target
end

local function applyTextAppearance(target: ChatWindowMessageProperties, color: Color3?, gradient: GradientConfig?)
	if gradient ~= nil then
		target.TextColor3 = Color3.fromRGB(255, 255, 255)
		return
	end

	if color ~= nil then
		target.TextColor3 = color
	end
end

local function nextMessageToken(): string
	nextMessageId += 1
	return MESSAGE_METADATA_PREFIX .. tostring(nextMessageId)
end

local function takePendingMessage(metadata: string): SerializedMessage?
	if string.sub(metadata, 1, #MESSAGE_METADATA_PREFIX) ~= MESSAGE_METADATA_PREFIX then
		return nil
	end

	local payload = pendingMessages[metadata]
	pendingMessages[metadata] = nil
	return payload
end

local function installChatWindowHook()
	if not RunService:IsClient() or chatWindowHookInstalled then
		return
	end

	chatWindowHookInstalled = true

	TextChatService.OnChatWindowAdded = function(textChatMessage: TextChatMessage): ChatWindowMessageProperties?
		local payload = takePendingMessage(textChatMessage.Metadata)

		if payload == nil then
			return nil
		end

		local overrideProperties = deriveMessageProperties()
		overrideProperties.PrefixText = buildPrefix(payload)
		overrideProperties.Text = buildBodyText(payload)
		applyTextAppearance(overrideProperties, payload.MessageColor, payload.MessageGradient)

		local prefixProperties = ensurePrefixTextProperties(overrideProperties)
		applyTextAppearance(prefixProperties, payload.Color, payload.Gradient)

		applyGradient(overrideProperties, payload.MessageGradient)
		applyGradient(prefixProperties, payload.Gradient)

		return overrideProperties
	end
end

local function displaySerializedMessage(payload: SerializedMessage)
	local channel = getDisplayChannel()

	if channel == nil then
		warn("[MessagingManager] Could not find RBXGeneral or RBXSystem to display a message.")
		return
	end

	installChatWindowHook()

	local metadata = nextMessageToken()
	pendingMessages[metadata] = payload
	channel:DisplaySystemMessage(payload.Message, metadata)
end

local function ensureClientListener()
	if not RunService:IsClient() or clientConnection ~= nil then
		return
	end

	installChatWindowHook()

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
		_size = normalizeSize(resolvedConfig.Size),
		_gradient = normalizeGradient(resolvedConfig.Gradient, nil),
		_messageColor = normalizeColor(resolvedConfig.MessageColor),
		_messageFont = normalizeFont(resolvedConfig.MessageFont),
		_messageSize = normalizeSize(resolvedConfig.MessageSize),
		_messageGradient = normalizeGradient(resolvedConfig.MessageGradient, nil),
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

function MessagingManager:SetSize(size: number?): Messenger
	self._size = normalizeSize(size)
	return self
end

function MessagingManager:SetGradient(gradient: GradientInput?, rotation: number?): Messenger
	self._gradient = normalizeGradient(gradient, rotation)
	return self
end

function MessagingManager:SetMessageColor(color: ColorInput?): Messenger
	self._messageColor = normalizeColor(color)
	return self
end

function MessagingManager:SetMessageFont(font: FontInput?): Messenger
	self._messageFont = normalizeFont(font)
	return self
end

function MessagingManager:SetMessageSize(size: number?): Messenger
	self._messageSize = normalizeSize(size)
	return self
end

function MessagingManager:SetMessageGradient(gradient: GradientInput?, rotation: number?): Messenger
	self._messageGradient = normalizeGradient(gradient, rotation)
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
		Size = self._size,
		Gradient = copyGradient(self._gradient),
		FrontTags = copyStringArray(self._frontTags),
		BackTags = copyStringArray(self._backTags),
		MessageColor = self._messageColor,
		MessageFont = self._messageFont,
		MessageSize = self._messageSize,
		MessageGradient = copyGradient(self._messageGradient),
	}
end

function MessagingManager:Format(message: string): string
	assert(type(message) == "string" and message ~= "", "message must be a non-empty string")
	return formatSerializedMessage(buildSerializedMessage(self:GetConfig(), message))
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
