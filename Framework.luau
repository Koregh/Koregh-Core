--!strict
-- Framework.lua
-- O Ponto Central: Une todos os serviços, gerencia dependências e o ciclo de vida.

local Framework = {}
Framework.__index = Framework

-- 1. Importação de todos os seus módulos refatorados
local Log = require(script.ConsoleReporter)
local Guard = require(script.GuardClause)
local Memory = require(script.MemoryManager)
local Events = require(script.EventManager)
local Network = require(script.NetworkManager)
local Config = require(script.ConfigManager)
local Janitor = require(script.Janitor)

-- 2. Instâncias Únicas (Singletons)
Framework.Log = Log.new()
Framework.Guard = Guard
Framework.Memory = Memory.new()
Framework.Events = Events.new()
Framework.Network = Network.new()
Framework.Config = Config.new()

-- Armazenamento de Janitors por Player
local playerJanitors = {}

-- 3. Inicialização e Injeção de Dependências
function Framework.Init()
	-- "Fiação" interna: conecta um módulo ao outro
	Framework.Guard.ConnectReporter(Framework.Log)
	Framework.Network.Init(Framework.Log, Framework.Guard)
	Framework.Config.Init(Framework.Log, Framework.Guard, Framework.Events)
	
	-- Ciclo de Vida Global dos Jogadores
	game:GetService("Players").PlayerAdded:Connect(function(player)
		playerJanitors[player.UserId] = Janitor.new()
		Framework.Log:SendMessage("System", "Sessão iniciada para: " .. player.Name, "Print")
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		-- O momento sênior: Limpeza automática total
		Framework.Config:ClearPlayer(player) -- Salva e limpa estado
		
		if playerJanitors[player.UserId] then
			playerJanitors[player.UserId]:Destroy() -- Limpa conexões/instâncias
			playerJanitors[player.UserId] = nil
		end
		
		Framework.Log:SendMessage("System", "Sessão encerrada e memória limpa: " .. player.Name, "Print")
	end)

	Framework.Log:SendMessage("Framework", "Engrenagens integradas. Sistema operacional.", "Print")
end

-- Função utilitária para obter o Janitor de um player em outros scripts
function Framework:GetJanitor(player: Player)
	return playerJanitors[player.UserId]
end

return Framework
