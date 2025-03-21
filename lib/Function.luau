local RunService = game:GetService("RunService")

local Promise = require(script.Parent.Parent.Promise)
local Spawn = require(script.Parent.Parent.Spawn)

local Net = require(script.Parent.Net)
local Identifier = require(script.Parent.Identifier)

export type Function<A..., R...> = {
	Id: string,
	Validate: (...unknown) -> A...,

	SetCallback: (self: Function<A..., R...>, Callback: (Player, A...) -> R...) -> (),
	Call: (
		self: Function<A..., R...>,
		A...
	) -> Promise.Promise<boolean, R...>,
}

local function SetCallback<A..., R...>(self: Function<A..., R...>, Callback: (Player, A...) -> R...)
	assert(RunService:IsServer(), "Cannot set callback to function on client")

	Net.Server.SetListener(self.Id, function(Player, Args)
		local CallId = table.remove(Args, 1)

		if type(CallId) ~= "string" then
			return
		end

		Spawn(function(Player: Player, CallId: string, ...: any)
			if pcall(self.Validate, ...) then
				Net.Server.SendCallReturn(Player, CallId, table.pack(pcall(Callback, Player, ...)))
			end
		end, Player, CallId, unpack(Args))
	end)
end

local function Call<A..., R...>(self: Function<A..., R...>, ...: A...)
	return Promise.try(function(...: any)
		local CallId = Identifier.Unique()

		local CallList = Net.Client.CallAsync(self.Id, table.pack(CallId, ...))
		if CallList[1] == false then
			error(tostring(CallList[2]))
		end
		table.remove(CallList, 1)
		return unpack(CallList)
	end, ...)
end

local function Function<A..., R...>(
	Name: string,
	ValidateArg: (...unknown) -> A...,
	ValidateRet: (...unknown) -> R...
): Function<A..., R...>
	assert(not Identifier.Exists(Name), "Cannot use same name twice")

	return {
		Id = Identifier.Shared(Name):expect(),
		Validate = ValidateArg,

		SetCallback = SetCallback,
		Call = Call,
	} :: any
end

return Function
