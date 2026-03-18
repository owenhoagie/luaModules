--!strict

--[[
	WebhookManager

	A typed Luau builder for webhook payloads in Roblox.
	Use `WebhookManager.new()` to create a message builder, then add content,
	embeds, and mention settings before calling `:Build()` or `:Send()`.

	Public types exported by this module:
	- `WebhookManager.NewConfig`
	- `WebhookManager.Payload`
	- `WebhookManager.Embed`
	- `WebhookManager.WebhookManager`
	- `WebhookManager.EmbedBuilder`
]]

export type AllowedMentions = {
	parse: { string }?,
	users: { string }?,
	roles: { string }?,
	replied_user: boolean?,
}

export type EmbedAuthor = {
	name: string,
	url: string?,
	icon_url: string?,
}

export type EmbedMedia = {
	url: string,
}

export type EmbedFooter = {
	text: string,
	icon_url: string?,
}

export type EmbedField = {
	name: string,
	value: string,
	inline: boolean?,
}

export type Embed = {
	title: string?,
	description: string?,
	url: string?,
	timestamp: string?,
	color: number?,
	author: EmbedAuthor?,
	thumbnail: EmbedMedia?,
	image: EmbedMedia?,
	footer: EmbedFooter?,
	fields: { EmbedField }?,
}

export type Payload = {
	username: string?,
	avatar_url: string?,
	content: string?,
	tts: boolean,
	embeds: { Embed }?,
	allowed_mentions: AllowedMentions?,
}

export type NewConfig = {
	webhook: string,
	username: string?,
	avatarUrl: string?,
	avatar_url: string?,
}

type ColorInput = number | string | Color3

type WebhookResponse = {
	Success: boolean,
	StatusCode: number,
	StatusMessage: string,
	Body: string,
	Headers: { [string]: string }?,
}

type InternalPayload = {
	username: string?,
	avatar_url: string?,
	content: string?,
	tts: boolean,
	embeds: { Embed },
	allowed_mentions: AllowedMentions?,
}

type WebhookManagerMethods = {
	SetWebhook: (self: WebhookManager, webhook: string) -> WebhookManager,
	SetUsername: (self: WebhookManager, username: string?) -> WebhookManager,
	SetAvatar: (self: WebhookManager, avatarUrl: string?) -> WebhookManager,
	SetContent: (self: WebhookManager, content: string?) -> WebhookManager,
	AppendText: (self: WebhookManager, text: string, separator: string?) -> WebhookManager,
	ClearContent: (self: WebhookManager) -> WebhookManager,
	SetTTS: (self: WebhookManager, enabled: boolean) -> WebhookManager,
	SetAllowedMentions: (
		self: WebhookManager,
		parse: { string }?,
		users: { string }?,
		roles: { string }?,
		repliedUser: boolean?
	) -> WebhookManager,
	AddEmbed: (self: WebhookManager, embedData: Embed?) -> EmbedBuilder,
	ClearEmbeds: (self: WebhookManager) -> WebhookManager,
	Build: (self: WebhookManager) -> Payload,
	Send: (self: WebhookManager, httpService: HttpService?) -> WebhookResponse,
}

type EmbedBuilderMethods = {
	SetTitle: (self: EmbedBuilder, title: string) -> EmbedBuilder,
	SetDescription: (self: EmbedBuilder, description: string) -> EmbedBuilder,
	SetURL: (self: EmbedBuilder, url: string) -> EmbedBuilder,
	SetTimestamp: (self: EmbedBuilder, timestamp: string) -> EmbedBuilder,
	SetColor: (self: EmbedBuilder, color: ColorInput) -> EmbedBuilder,
	SetAuthor: (self: EmbedBuilder, name: string, url: string?, iconUrl: string?) -> EmbedBuilder,
	SetThumbnail: (self: EmbedBuilder, url: string) -> EmbedBuilder,
	SetImage: (self: EmbedBuilder, url: string) -> EmbedBuilder,
	SetFooter: (self: EmbedBuilder, text: string, iconUrl: string?) -> EmbedBuilder,
	AddField: (self: EmbedBuilder, name: string, value: string, inline: boolean?) -> EmbedBuilder,
	ToTable: (self: EmbedBuilder) -> Embed,
	Done: (self: EmbedBuilder) -> WebhookManager,
}

type WebhookManagerData = {
	_webhook: string,
	_payload: InternalPayload,
}

type EmbedBuilderData = {
	_webhook: WebhookManager,
	_embed: Embed,
}

export type WebhookManager = WebhookManagerData & WebhookManagerMethods
export type EmbedBuilder = EmbedBuilderData & EmbedBuilderMethods

local WebhookManager = {} :: any
WebhookManager.__index = WebhookManager

local EmbedBuilder = {} :: any
EmbedBuilder.__index = EmbedBuilder

-- Copy arrays so built payloads stay isolated from outside mutation.
local function copyStringArray(values: { string }?): { string }?
	if values == nil then
		return nil
	end

	local copied: { string } = {}

	for index, value in ipairs(values) do
		copied[index] = value
	end

	return copied
end

local function copyAllowedMentions(mentions: AllowedMentions?): AllowedMentions?
	if mentions == nil then
		return nil
	end

	local copied: AllowedMentions = {}

	if mentions.parse ~= nil then
		copied.parse = copyStringArray(mentions.parse)
	end

	if mentions.users ~= nil then
		copied.users = copyStringArray(mentions.users)
	end

	if mentions.roles ~= nil then
		copied.roles = copyStringArray(mentions.roles)
	end

	if mentions.replied_user ~= nil then
		copied.replied_user = mentions.replied_user
	end

	if next(copied) == nil then
		return nil
	end

	return copied
end

local function copyFields(fields: { EmbedField }?): { EmbedField }?
	if fields == nil then
		return nil
	end

	local copied: { EmbedField } = {}

	for index, field in ipairs(fields) do
		local copiedField: EmbedField = {
			name = field.name,
			value = field.value,
		}

		if field.inline ~= nil then
			copiedField.inline = field.inline
		end

		copied[index] = copiedField
	end

	if #copied == 0 then
		return nil
	end

	return copied
end

local function copyEmbed(embed: Embed): Embed
	local copied: Embed = {}

	if embed.title ~= nil then
		copied.title = embed.title
	end

	if embed.description ~= nil then
		copied.description = embed.description
	end

	if embed.url ~= nil then
		copied.url = embed.url
	end

	if embed.timestamp ~= nil then
		copied.timestamp = embed.timestamp
	end

	if embed.color ~= nil then
		copied.color = embed.color
	end

	if embed.author ~= nil then
		copied.author = {
			name = embed.author.name,
			url = embed.author.url,
			icon_url = embed.author.icon_url,
		}
	end

	if embed.thumbnail ~= nil then
		copied.thumbnail = {
			url = embed.thumbnail.url,
		}
	end

	if embed.image ~= nil then
		copied.image = {
			url = embed.image.url,
		}
	end

	if embed.footer ~= nil then
		copied.footer = {
			text = embed.footer.text,
			icon_url = embed.footer.icon_url,
		}
	end

	if embed.fields ~= nil then
		copied.fields = copyFields(embed.fields)
	end

	return copied
end

-- Accept a Discord decimal color, a hex string, or a Roblox Color3.
local function normalizeColor(color: ColorInput): number
	local colorType = typeof(color)

	if colorType == "number" then
		return math.clamp(math.floor(color :: number), 0, 0xFFFFFF)
	end

	if colorType == "Color3" then
		local color3 = color :: Color3
		return bit32.lshift(math.floor(color3.R * 255), 16)
			+ bit32.lshift(math.floor(color3.G * 255), 8)
			+ math.floor(color3.B * 255)
	end

	local sanitized = (color :: string):gsub("#", "")
	local parsed = tonumber(sanitized, 16)

	assert(parsed ~= nil, "Embed color must be a number, hex string, or Color3")
	return math.clamp(parsed, 0, 0xFFFFFF)
end

local function newEmbedBuilder(webhook: WebhookManager, embed: Embed): EmbedBuilder
	return setmetatable({
		_webhook = webhook,
		_embed = embed,
	}, EmbedBuilder) :: EmbedBuilder
end

-- Creates a new Discord webhook builder with optional username and avatar overrides.
function WebhookManager.new(config: NewConfig): WebhookManager
	assert(type(config.webhook) == "string" and config.webhook ~= "", "config.webhook is required")

	local self = setmetatable({
		_webhook = config.webhook,
		_payload = {
			username = config.username,
			avatar_url = config.avatarUrl or config.avatar_url,
			content = nil,
			tts = false,
			embeds = {},
			allowed_mentions = nil,
		} :: InternalPayload,
	}, WebhookManager) :: WebhookManager

	return self
end

-- Changes the target webhook URL for future sends.
function WebhookManager:SetWebhook(webhook: string): WebhookManager
	self._webhook = webhook
	return self
end

-- Overrides the webhook display name for this message.
function WebhookManager:SetUsername(username: string?): WebhookManager
	self._payload.username = username
	return self
end

-- Overrides the webhook avatar for this message.
function WebhookManager:SetAvatar(avatarUrl: string?): WebhookManager
	self._payload.avatar_url = avatarUrl
	return self
end

-- Replaces the message body content.
function WebhookManager:SetContent(content: string?): WebhookManager
	self._payload.content = content
	return self
end

-- Appends text to the message body, defaulting to a newline separator.
function WebhookManager:AppendText(text: string, separator: string?): WebhookManager
	if self._payload.content == nil or self._payload.content == "" then
		self._payload.content = text
	else
		self._payload.content ..= separator or "\n"
		self._payload.content ..= text
	end

	return self
end

-- Clears the message body content without touching embeds.
function WebhookManager:ClearContent(): WebhookManager
	self._payload.content = nil
	return self
end

-- Enables or disables Discord text-to-speech for this message.
function WebhookManager:SetTTS(enabled: boolean): WebhookManager
	self._payload.tts = enabled
	return self
end

-- Sets Discord's allowed_mentions object so callers can control pings.
function WebhookManager:SetAllowedMentions(
	parse: { string }?,
	users: { string }?,
	roles: { string }?,
	repliedUser: boolean?
): WebhookManager
	self._payload.allowed_mentions = {
		parse = copyStringArray(parse),
		users = copyStringArray(users),
		roles = copyStringArray(roles),
		replied_user = repliedUser,
	}

	return self
end

-- Adds a new embed and returns a builder focused on that embed.
function WebhookManager:AddEmbed(embedData: Embed?): EmbedBuilder
	local embed = if embedData ~= nil then copyEmbed(embedData) else {} :: Embed
	table.insert(self._payload.embeds, embed)
	return newEmbedBuilder(self, embed)
end

-- Removes all embeds from the current message.
function WebhookManager:ClearEmbeds(): WebhookManager
	self._payload.embeds = {}
	return self
end

-- Builds a clean payload table that is ready for HttpService:JSONEncode().
function WebhookManager:Build(): Payload
	local payload: Payload = {
		username = self._payload.username,
		avatar_url = self._payload.avatar_url,
		content = self._payload.content,
		tts = self._payload.tts,
		allowed_mentions = copyAllowedMentions(self._payload.allowed_mentions),
	}

	local embeds: { Embed } = {}

	for _, embed in ipairs(self._payload.embeds) do
		table.insert(embeds, copyEmbed(embed))
	end

	if #embeds > 0 then
		payload.embeds = embeds
	end

	assert(
		(payload.content ~= nil and payload.content ~= "") or (payload.embeds ~= nil and #payload.embeds > 0),
		"Discord requires content or at least one embed"
	)

	return payload
end

-- Sends the current payload to Discord using Roblox HttpService.
function WebhookManager:Send(httpService: HttpService?): WebhookResponse
	local service: HttpService = httpService or game:GetService("HttpService")
	local response = service:RequestAsync({
		Url = self._webhook,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = service:JSONEncode(self:Build()),
	}) :: WebhookResponse

	if not response.Success then
		error(string.format("Discord webhook request failed (%s): %s", response.StatusCode, response.Body), 2)
	end

	return response
end

-- Sets the embed title.
function EmbedBuilder:SetTitle(title: string): EmbedBuilder
	self._embed.title = title
	return self
end

-- Sets the embed description text.
function EmbedBuilder:SetDescription(description: string): EmbedBuilder
	self._embed.description = description
	return self
end

-- Sets the embed target URL.
function EmbedBuilder:SetURL(url: string): EmbedBuilder
	self._embed.url = url
	return self
end

-- Sets the embed timestamp. Discord expects an ISO-8601 string.
function EmbedBuilder:SetTimestamp(timestamp: string): EmbedBuilder
	self._embed.timestamp = timestamp
	return self
end

-- Sets the embed accent color from a decimal, hex string, or Color3.
function EmbedBuilder:SetColor(color: ColorInput): EmbedBuilder
	self._embed.color = normalizeColor(color)
	return self
end

-- Sets the embed author block.
function EmbedBuilder:SetAuthor(name: string, url: string?, iconUrl: string?): EmbedBuilder
	self._embed.author = {
		name = name,
		url = url,
		icon_url = iconUrl,
	}

	return self
end

-- Sets the embed thumbnail image.
function EmbedBuilder:SetThumbnail(url: string): EmbedBuilder
	self._embed.thumbnail = {
		url = url,
	}

	return self
end

-- Sets the main embed image.
function EmbedBuilder:SetImage(url: string): EmbedBuilder
	self._embed.image = {
		url = url,
	}

	return self
end

-- Sets the embed footer block.
function EmbedBuilder:SetFooter(text: string, iconUrl: string?): EmbedBuilder
	self._embed.footer = {
		text = text,
		icon_url = iconUrl,
	}

	return self
end

-- Adds a field to the embed. Field values are strings in Discord payloads.
function EmbedBuilder:AddField(name: string, value: string, inline: boolean?): EmbedBuilder
	local fields = self._embed.fields

	if fields == nil then
		fields = {}
		self._embed.fields = fields
	end

	table.insert(fields, {
		name = name,
		value = value,
		inline = inline,
	})

	return self
end

-- Returns a copy of the current embed table for inspection or reuse.
function EmbedBuilder:ToTable(): Embed
	return copyEmbed(self._embed)
end

-- Returns to the parent webhook builder so callers can continue chaining.
function EmbedBuilder:Done(): WebhookManager
	return self._webhook
end

return WebhookManager
