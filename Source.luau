--// Localization
local table_insert = table.insert
local table_concat = table.concat

--// Console & Dependencies
local function PrintConsole(Option, ...)
	local Options = { [1] = print, [2] = warn, [3] = error }
	local Fn = Options[Option]

	if not Fn then return "Invalid Option" end
	return Fn(...)
end

local function TypeCheck(Object, Type, FunctionName, Param)
	assert(typeof(Object) == Type, `invalid argument #{Param} for {FunctionName}, expected {Type}, got {typeof(Object)}`)
end

--// Services
local HttpService = game:GetService("HttpService")
--// Dependencies
local JSONDecode = function(Raw) return HttpService:JSONDecode(Raw) end
local SendRequest = request or (http and http.request) or http_request
local ScriptBlox = { Server = "https://scriptblox.com" }
ScriptBlox.__index = ScriptBlox

--[[
	Internal: sends a GET request to the given path and decodes the JSON body.
	Returns the decoded table on success, nil on failure.
--]]

function ScriptBlox:GetPath(Path)
	TypeCheck(Path, "string", "GetPath", 1)

	local Response = SendRequest({ Url = ScriptBlox.Server .. Path, Method = "GET" })

	if not Response.Success then
		PrintConsole(2, `[ ScriptBlox ]: Request failed, Response:\n\n [ StatusCode -> {Response.StatusCode}\nBody -> {Response.Body}\n ]`)
		return
	end

	local Success, Data = pcall(JSONDecode, Response.Body)
	if not Success or not Data then
		PrintConsole(2, `[ ScriptBlox ]: Failed to decode JSON -> {Response.Body}`)
		return
	end

	return Data
end

--[[
	Fetch home-page / filtered scripts.
	All parameters are optional.

	Options (table):
		page(number)  – page index, default 1
		max(number)  – results per page, max 20
		mode(string)  – "free" | "paid"
		patched(number)  – 1 = patched only, 0 = unpatched only
		key(number)  – 1 = key-locked only, 0 = no key
		universal(number)  – 1 = universal scripts only
		verified(number)  – 1 = verified only
		sortBy(string)  – "views" | "updatedAt" | "createdAt"
		order(string)  – "asc" | "desc"

	Returns array of script objects, or nil on failure.
--]]
function ScriptBlox:Fetch(Options)
	Options = Options or {}

	local Params = {}
	local Allowed = { "page", "max", "mode", "patched", "key", "universal", "verified", "sortBy", "order" }

	for _, Key in Allowed do
		if Options[Key] ~= nil then
			table_insert(Params, `{Key}={Options[Key]}`)
		end
	end

	local Query = #Params > 0 and ("?" .. table_concat(Params, "&")) or ""
	local Data = ScriptBlox:GetPath(`/api/script/fetch{Query}`)

	if Data and Data.result and Data.result.scripts then
		return Data.result.scripts, Data.result.totalPages, Data.result.nextPage
	end

	PrintConsole(2, "[ ScriptBlox - Fetch ]: Unexpected response structure")
end

--[[
	Search for scripts by keyword.

	SearchQuery  (string)  – required search term
	Options      (table):
		page     (number)  – page index, default 1
		max      (number)  – results per page, max 20
		mode     (string)  – "free" | "paid"
		strict   (boolean) – true for strict matching
		patched  (number)  – 1 / 0
		key      (number)  – 1 / 0
		verified (number)  – 1 / 0

	Returns array of script objects, or nil on failure.
--]]
function ScriptBlox:Search(SearchQuery, Options)
	TypeCheck(SearchQuery, "string", "Search", 1)

	Options = Options or {}

	local Params = { `q={SearchQuery}` }
	local Allowed = { "page", "max", "mode", "strict", "patched", "key", "verified" }

	for _, Key in Allowed do
		if Options[Key] ~= nil then
			table_insert(Params, `{Key}={Options[Key]}`)
		end
	end

	local Data = ScriptBlox:GetPath(`/api/script/search?{table_concat(Params, "&")}`)

	if Data and Data.result and Data.result.scripts then
		return Data.result.scripts, Data.result.totalPages, Data.result.nextPage
	end

	PrintConsole(2, "[ ScriptBlox - Search ]: Unexpected response")
end

--[[
	Fetch the currently trending scripts.
	Returns array of script objects, or nil on failure.
--]]

function ScriptBlox:Trending()
	local Data = ScriptBlox:GetPath("/api/script/trending")

	if Data and Data.result and Data.result.scripts then
		return Data.result.scripts
	end

	PrintConsole(2, "[ ScriptBlox - Trending ]: Unexpected response")
	return
end

--[[
	Fetch full details for a single script by its slug or ID.

	Slug (string) – the script's slug/id

	Returns a script detail table, or nil on failure.
	Detail table fields include: title, game, features, tags, script, verified, key, views, etc.
--]]
function ScriptBlox:GetScript(Slug)
	TypeCheck(Slug, "string", "GetScript", 1)

	local Data = ScriptBlox:GetPath(`/api/script/{Slug}`)

	if Data and Data.script then
		return Data.script
	end

	PrintConsole(2, `[ ScriptBlox - GetScript ]: Could not retrieve script for slug "{Slug}"`)
	return
end

--[[
	Fetch the raw Lua source of a script by its slug or ID.

	Slug (string) - the script's slug/id

	Returns the raw script string, or nil on failure.
--]]
function ScriptBlox:GetRawScript(Slug)
	TypeCheck(Slug, "string", "GetRawScript", 1)

	local Response = SendRequest({
		Url = `{ScriptBlox.Server}/api/script/raw/{Slug}`,
		Method = "GET"
	})

	if Response.Success and Response.Body and #Response.Body > 0 then
		return Response.Body
	end

	PrintConsole(2, `[ ScriptBlox - GetRawScript ]: Failed to fetch raw script for slug "{Slug}"`)
	return
end

return ScriptBlox
