--!strict

--[[
	PercentageTextAnimator

	Animates a TextLabel from a start percentage to an end percentage using an
	ease-out curve, so it begins quickly and slows down near the target.

	Default text output format:
		0.00 %

	Example:
		local animator = PercentageTextAnimator.Animate(myLabel, 78.34, {
			Duration = 2,
		})

		animator:Wait()
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

export type AnimationOptions = {
	Duration: number?,
	StartValue: number?,
	DecimalPlaces: number?,
	Prefix: string?,
	Suffix: string?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type AnimationHandle = {
	Running: boolean,
	Completed: boolean,
	Cancelled: boolean,
	Cancel: (self: AnimationHandle) -> (),
	Wait: (self: AnimationHandle) -> boolean,
}

type AnimationHandleInternal = AnimationHandle & {
	_completedEvent: BindableEvent,
	_finished: boolean,
}

local PercentageTextAnimator = {} :: any

local DEFAULT_DURATION = 1.75
local DEFAULT_START_VALUE = 0
local DEFAULT_DECIMAL_PLACES = 2
local DEFAULT_PREFIX = ""
local DEFAULT_SUFFIX = " %"
local DEFAULT_EASING_STYLE = Enum.EasingStyle.Quint
local DEFAULT_EASING_DIRECTION = Enum.EasingDirection.Out

local activeAnimations = {} :: { [TextLabel]: AnimationHandleInternal }

local function assertFiniteNumber(name: string, value: number)
	assert(type(value) == "number", string.format("%s must be a number", name))
	assert(value == value, string.format("%s must not be NaN", name))
	assert(value ~= math.huge and value ~= -math.huge, string.format("%s must be finite", name))
end

local function assertPercentage(name: string, value: number)
	assertFiniteNumber(name, value)
	assert(value >= 0 and value <= 100, string.format("%s must be between 0 and 100", name))
end

local function assertTextLabel(label: TextLabel)
	assert(typeof(label) == "Instance" and label:IsA("TextLabel"), "label must be a TextLabel")
end

local function formatPercent(value: number, decimalPlaces: number, prefix: string, suffix: string): string
	return string.format("%s%." .. tostring(decimalPlaces) .. "f%s", prefix, value, suffix)
end

local function finishAnimation(handle: AnimationHandleInternal, completed: boolean, cancelled: boolean)
	if handle._finished then
		return
	end

	handle._finished = true
	handle.Running = false
	handle.Completed = completed
	handle.Cancelled = cancelled
	handle._completedEvent:Fire(completed)
end

local function createHandle(): AnimationHandleInternal
	local completedEvent = Instance.new("BindableEvent")

	local handle = {
		Running = true,
		Completed = false,
		Cancelled = false,
		_completedEvent = completedEvent,
		_finished = false,
	} :: AnimationHandleInternal

	function handle:Cancel()
		finishAnimation(self, false, true)
	end

	function handle:Wait(): boolean
		if self._finished then
			return self.Completed
		end

		return self._completedEvent.Event:Wait()
	end

	return handle
end

function PercentageTextAnimator.Format(value: number, decimalPlaces: number?, prefix: string?, suffix: string?): string
	assertPercentage("value", value)

	local resolvedDecimalPlaces = decimalPlaces or DEFAULT_DECIMAL_PLACES
	assert(type(resolvedDecimalPlaces) == "number" and resolvedDecimalPlaces >= 0, "decimalPlaces must be 0 or greater")

	return formatPercent(
		value,
		math.floor(resolvedDecimalPlaces),
		prefix or DEFAULT_PREFIX,
		suffix or DEFAULT_SUFFIX
	)
end

function PercentageTextAnimator.Animate(label: TextLabel, targetValue: number, options: AnimationOptions?): AnimationHandle
	assertTextLabel(label)
	assertPercentage("targetValue", targetValue)

	local resolvedOptions = options or {}
	local duration = resolvedOptions.Duration or DEFAULT_DURATION
	local startValue = resolvedOptions.StartValue or DEFAULT_START_VALUE
	local decimalPlaces = resolvedOptions.DecimalPlaces or DEFAULT_DECIMAL_PLACES
	local prefix = resolvedOptions.Prefix or DEFAULT_PREFIX
	local suffix = resolvedOptions.Suffix or DEFAULT_SUFFIX
	local easingStyle = resolvedOptions.EasingStyle or DEFAULT_EASING_STYLE
	local easingDirection = resolvedOptions.EasingDirection or DEFAULT_EASING_DIRECTION

	assertFiniteNumber("duration", duration)
	assert(duration > 0, "duration must be greater than 0")
	assertPercentage("startValue", startValue)
	assert(type(decimalPlaces) == "number" and decimalPlaces >= 0, "decimalPlaces must be 0 or greater")
	assert(type(prefix) == "string", "prefix must be a string")
	assert(type(suffix) == "string", "suffix must be a string")

	local existingAnimation = activeAnimations[label]
	if existingAnimation and existingAnimation.Running then
		existingAnimation:Cancel()
	end

	local handle = createHandle()
	activeAnimations[label] = handle

	local roundedDecimalPlaces = math.floor(decimalPlaces)
	label.Text = formatPercent(startValue, roundedDecimalPlaces, prefix, suffix)

	task.spawn(function()
		local startTime = os.clock()

		while handle.Running do
			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local easedAlpha = TweenService:GetValue(alpha, easingStyle, easingDirection)
			local currentValue = startValue + (targetValue - startValue) * easedAlpha

			label.Text = formatPercent(currentValue, roundedDecimalPlaces, prefix, suffix)

			if alpha >= 1 then
				break
			end

			RunService.Heartbeat:Wait()
		end

		if activeAnimations[label] == handle then
			activeAnimations[label] = nil
		end

		if handle.Running then
			label.Text = formatPercent(targetValue, roundedDecimalPlaces, prefix, suffix)
			finishAnimation(handle, true, false)
		end
	end)

	return handle
end

return PercentageTextAnimator
