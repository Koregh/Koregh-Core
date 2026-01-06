--!strict
-- NetworkManager.lua
-- Gerenciamento de rede seguro.

local NetworkManager = {}
NetworkManager.__index = NetworkManager

-- Dependências Injetadas
local _logger: any = nil
local _guard: any = nil

-- Configurações
local RATE_LIMIT_MS = 100 -- 0.1s entre chamadas por jogador
local playerThrottling = {} -- { [UserId]: { [eventName]: lastTime } }

-- Tipos
export type NetworkManagerType = typeof(setmetatable({} :: {
	_events: { [string]: RemoteEvent },
	_connections: { [string]: { RBXScriptConnection } }
}, NetworkManager))

function NetworkManager.Init(logger: any, guard: any)
	_logger = logger
	_guard = guard
end

local function report(msg: string, msgType: "Warn" | "Error")
	if _logger then _logger:SendMessage("Network", msg, msgType) end
end

function NetworkManager.new(): NetworkManagerType
	return setmetatable({
		_events = {},
		_connections = {}
	}, NetworkManager) :: any
end

-- @desc Registra ou Cria uma RemoteEvent automaticamente
function NetworkManager:GetEvent(name: string): RemoteEvent
	if self._events[name] then return self._events[name] end
	
	-- Tenta achar no jogo, se não existir, cria no ReplicatedStorage
	local storage = game:GetService("ReplicatedStorage")
	local remoteFolder = storage:FindFirstChild("Remotes") or Instance.new("Folder", storage)
	remoteFolder.Name = "Remotes"
	
	local remote = remoteFolder:FindFirstChild(name) or Instance.new("RemoteEvent", remoteFolder)
	remote.Name = name
	
	self._events[name] = remote :: RemoteEvent
	self._connections[name] = {}
	return self._events[name]
end

-- @desc Conexão Blindada com Middleware (GuardClause)
function NetworkManager:Connect(name: string, blueprint: {[string]: string}?, callback: (Player, any) -> ())
	local event = self:GetEvent(name)
	
	local connection = event.OnServerEvent:Connect(function(player: Player, data: any)
		-- 1. PROTEÇÃO: Rate Limiting (Evita spammer/hacker)
		local now = os.clock()
		local pId = player.UserId
		playerThrottling[pId] = playerThrottling[pId] or {}
		
		if playerThrottling[pId][name] and (now - playerThrottling[pId][name]) < (RATE_LIMIT_MS / 1000) then
			report("Rate limit atingido por: " .. player.Name .. " no evento: " .. name, "Warn")
			return
		end
		playerThrottling[pId][name] = now

		-- 2. PROTEÇÃO: Validação de Schema (Se houver blueprint)
		if blueprint and _guard then
			if not _guard:Schema(data, blueprint) then
				report("Dados inválidos bloqueados de: " .. player.Name, "Error")
				return -- Mata a execução se o dado for lixo
			end
		end

		-- 3. EXECUÇÃO SEGURA
		task.spawn(callback, player, data)
	end)

	table.insert(self._connections[name], connection)
end

function NetworkManager:FireClient(name: string, player: Player, ...: any)
	local event = self._events[name]
	if event then event:FireClient(player, ...) end
end

function NetworkManager:FireAllClients(name: string, ...: any)
	local event = self._events[name]
	if event then event:FireAllClients(...) end
end

return NetworkManager
