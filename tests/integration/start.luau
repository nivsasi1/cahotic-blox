-- Passed to Studio with -runScriptFile, starts one server and two client windows
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")

print("[RUNNER] starting multiplayer test")
local result = StudioTestService:ExecuteMultiplayerTestAsync(2, {})
print(`[RUNNER] finished {HttpService:JSONEncode(result)}`)
