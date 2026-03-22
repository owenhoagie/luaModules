--!strict

--[[
	WhitelistManager

	A server-side Roblox module for maintaining a join whitelist that can be
	configured before startup and edited live through chat commands.

	Key behavior:
	- Whitelist can be enabled or disabled at runtime
	- Whitelist entries can be added before calling `:Start()`
	- Admin permissions are driven by a user table
	- Any admin who successfully runs a command is automatically kept whitelisted
	- Non-whitelisted players are kicked whenever the whitelist is enabled
]]

export type UserEntry = number | string

export type Config = {
	Enabled: boolean?,
	Whitelist: { UserEntry }?,
	Admins: { UserEntry }?,
	CommandPrefix: string?,
	CommandAliases: { string }?,
	KickMessage: string?,
	Players: Players?,
}

type UserIdSet = { [number]: true }
type UserNameSet = { [string]: true }

type WhitelistManagerMethods = {
	Start: (self: WhitelistManager) -> WhitelistManager,
	Destroy: (self: WhitelistManager) -> (),
	Enable: (self: WhitelistManager) -> WhitelistManager,
	Disable: (self: WhitelistManager) -> WhitelistManager,
	SetEnabled: (self: WhitelistManager, enabled: boolean) -> WhitelistManager,
	IsEnabled: (self: WhitelistManager) -> boolean,
	AddUser: (self: WhitelistManager, user: UserEntry) -> WhitelistManager,
	RemoveUser: (self: WhitelistManager, user: UserEntry) -> WhitelistManager,
	IsWhitelisted: (self: WhitelistManager, playerOrUser: Player | UserEntry) -> boolean,
	IsAdmin: (self: WhitelistManager, playerOrUser: Player | UserEntry) -> boolean,
	GetWhitelistSnapshot: (self: WhitelistManager) -> { string },
}

type WhitelistManagerData = {
	_enabled: boolean,
	_started: boolean,
	_players: Players,
	_kickMessage: string,
	_commandPrefix: string,
	_commandAliases: { [string]: true },
	_whitelistIds: UserIdSet,
	_whitelistNames: UserNameSet,
	_adminIds: UserIdSet,
	_adminNames: UserNameSet,
	_connections: { RBXScriptConnection },
}

export type WhitelistManager = WhitelistManagerData & WhitelistManagerMethods

local DEFAULT_KICK_MESSAGE = "You are not whitelisted for this server."
local DEFAULT_COMMAND_PREFIX = "!"
local DEFAULT_COMMAND_ALIASES = { "whitelist", "wl" }

local WhitelistManager = {} :: any
WhitelistManager.__index = WhitelistManager

local function normalizeName(name: string): string
	return string.lower(name)
end

local function parseUserEntry(user: UserEntry): (number?, string?)
	if type(user) == "number" then
		return user, nil
	end

	if string.match(user, "^%d+$") then
		return tonumber(user), nil
	end

	return nil, normalizeName(user)
end

local function insertUser(idSet: UserIdSet, nameSet: UserNameSet, user: UserEntry)
	local userId, userName = parseUserEntry(user)

	if userId ~= nil then
		idSet[userId] = true
	end

	if userName ~= nil then
		nameSet[userName] = true
	end
end

local function removeUser(idSet: UserIdSet, nameSet: UserNameSet, user: UserEntry)
	local userId, userName = parseUserEntry(user)

	if userId ~= nil then
		idSet[userId] = nil
	end

	if userName ~= nil then
		nameSet[userName] = nil
	end
end

local function trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or ""
end

local function splitCommand(message: string): { string }
	local parts: { string } = {}

	for part in string.gmatch(message, "%S+") do
		table.insert(parts, part)
	end

	return parts
end

local function buildAliasSet(aliases: { string }?): { [string]: true }
	local aliasSet: { [string]: true } = {}
	local sourceAliases = aliases or DEFAULT_COMMAND_ALIASES

	for _, alias in ipairs(sourceAliases) do
		aliasSet[normalizeName(alias)] = true
	end

	return aliasSet
end

local function logMessage(message: string)
	warn(string.format("[WhitelistManager] %s", message))
end

function WhitelistManager.new(config: Config?): WhitelistManager
	local resolvedConfig = config or {}
	local self = setmetatable({
		_enabled = resolvedConfig.Enabled == true,
		_started = false,
		_players = resolvedConfig.Players or game:GetService("Players"),
		_kickMessage = resolvedConfig.KickMessage or DEFAULT_KICK_MESSAGE,
		_commandPrefix = resolvedConfig.CommandPrefix or DEFAULT_COMMAND_PREFIX,
		_commandAliases = buildAliasSet(resolvedConfig.CommandAliases),
		_whitelistIds = {},
		_whitelistNames = {},
		_adminIds = {},
		_adminNames = {},
		_connections = {},
	}, WhitelistManager) :: WhitelistManager

	for _, user in ipairs(resolvedConfig.Whitelist or {}) do
		self:AddUser(user)
	end

	for _, user in ipairs(resolvedConfig.Admins or {}) do
		insertUser(self._adminIds, self._adminNames, user)
	end

	return self
end

function WhitelistManager:IsEnabled(): boolean
	return self._enabled
end

function WhitelistManager:AddUser(user: UserEntry): WhitelistManager
	insertUser(self._whitelistIds, self._whitelistNames, user)
	return self
end

function WhitelistManager:RemoveUser(user: UserEntry): WhitelistManager
	removeUser(self._whitelistIds, self._whitelistNames, user)
	return self
end

function WhitelistManager:IsWhitelisted(playerOrUser: Player | UserEntry): boolean
	if typeof(playerOrUser) == "Instance" then
		local player = playerOrUser :: Player
		return self._whitelistIds[player.UserId] == true or self._whitelistNames[normalizeName(player.Name)] == true
	end

	local userId, userName = parseUserEntry(playerOrUser :: UserEntry)

	if userId ~= nil and self._whitelistIds[userId] == true then
		return true
	end

	if userName ~= nil and self._whitelistNames[userName] == true then
		return true
	end

	return false
end

function WhitelistManager:IsAdmin(playerOrUser: Player | UserEntry): boolean
	if typeof(playerOrUser) == "Instance" then
		local player = playerOrUser :: Player
		return self._adminIds[player.UserId] == true or self._adminNames[normalizeName(player.Name)] == true
	end

	local userId, userName = parseUserEntry(playerOrUser :: UserEntry)

	if userId ~= nil and self._adminIds[userId] == true then
		return true
	end

	if userName ~= nil and self._adminNames[userName] == true then
		return true
	end

	return false
end

function WhitelistManager:GetWhitelistSnapshot(): { string }
	local snapshot: { string } = {}

	for userId in pairs(self._whitelistIds) do
		table.insert(snapshot, tostring(userId))
	end

	for userName in pairs(self._whitelistNames) do
		table.insert(snapshot, userName)
	end

	table.sort(snapshot)
	return snapshot
end

function WhitelistManager:_ensurePlayerWhitelisted(player: Player)
	self._whitelistIds[player.UserId] = true
	self._whitelistNames[normalizeName(player.Name)] = true
end

function WhitelistManager:_enforcePlayer(player: Player)
	if self._enabled and not self:IsWhitelisted(player) then
		player:Kick(self._kickMessage)
	end
end

function WhitelistManager:_enforceAllPlayers()
	for _, player in ipairs(self._players:GetPlayers()) do
		self:_enforcePlayer(player)
	end
end

function WhitelistManager:_handleCommand(player: Player, message: string)
	local trimmedMessage = trim(message)
	local parts = splitCommand(trimmedMessage)
	local commandToken = parts[1]

	if commandToken == nil then
		return
	end

	if string.sub(commandToken, 1, #self._commandPrefix) ~= self._commandPrefix then
		return
	end

	local alias = normalizeName(string.sub(commandToken, #self._commandPrefix + 1))

	if self._commandAliases[alias] ~= true then
		return
	end

	if not self:IsAdmin(player) then
		return
	end

	self:_ensurePlayerWhitelisted(player)

	local action = normalizeName(parts[2] or "")
	local argument = parts[3]

	if action == "on" or action == "enable" then
		self:Enable()
		logMessage(string.format("%s enabled the whitelist.", player.Name))
	elseif action == "off" or action == "disable" then
		self:Disable()
		logMessage(string.format("%s disabled the whitelist.", player.Name))
	elseif action == "add" and argument ~= nil then
		self:AddUser(argument)
		logMessage(string.format("%s added '%s' to the whitelist.", player.Name, argument))
	elseif (action == "remove" or action == "delete") and argument ~= nil then
		self:RemoveUser(argument)
		self:_ensurePlayerWhitelisted(player)
		logMessage(string.format("%s removed '%s' from the whitelist.", player.Name, argument))
	elseif action == "status" then
		logMessage(string.format("%s requested whitelist status: %s", player.Name, tostring(self._enabled)))
	elseif action == "list" then
		logMessage(string.format("%s requested whitelist list: %s", player.Name, table.concat(self:GetWhitelistSnapshot(), ", ")))
	else
		logMessage(string.format("%s used an invalid whitelist command: %s", player.Name, trimmedMessage))
	end

	if self._enabled then
		self:_enforceAllPlayers()
	end
end

function WhitelistManager:_bindPlayer(player: Player)
	table.insert(self._connections, player.Chatted:Connect(function(message: string)
		self:_handleCommand(player, message)
	end))

	self:_enforcePlayer(player)
end

function WhitelistManager:SetEnabled(enabled: boolean): WhitelistManager
	self._enabled = enabled

	if self._enabled then
		self:_enforceAllPlayers()
	end

	return self
end

function WhitelistManager:Enable(): WhitelistManager
	return self:SetEnabled(true)
end

function WhitelistManager:Disable(): WhitelistManager
	return self:SetEnabled(false)
end

function WhitelistManager:Start(): WhitelistManager
	if self._started then
		return self
	end

	self._started = true

	table.insert(self._connections, self._players.PlayerAdded:Connect(function(player: Player)
		self:_bindPlayer(player)
	end))

	for _, player in ipairs(self._players:GetPlayers()) do
		self:_bindPlayer(player)
	end

	if self._enabled then
		self:_enforceAllPlayers()
	end

	return self
end

function WhitelistManager:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self._connections)
	self._started = false
end

return WhitelistManager
