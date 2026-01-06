--!strict
-- Framework.lua

local Framework = {}
Framework.__index = Framework

-- Módulos de infraestrutura e ferramentas base
local Log = require(script.ConsoleReporter)
local Guard = require(script.GuardClause)
local Memory = require(script.MemoryManager)
local Events = require(script.EventManager)
local Network = require(script.NetworkManager)
local Config = require(script.ConfigManager)
local Janitor = require(script.Janitor)
local Signal = require(script.Signal)
local ServiceManager = require(script.ServiceManager)

-- Inicializa as instâncias globais
Framework.Log = Log.new()
Framework.Guard = Guard
Framework.Memory = Memory.new()
Framework.Events = Events.new()
Framework.Network = Network.new()
Framework.Config = Config.new()

-- Exporta as classes
Framework.Janitor = Janitor
Framework.Signal = Signal

-- Controle de limpeza por jogador
local playerJanitors: { [number]: any } = {}

-- [[ MÉTODOS DE ACESSO ]] --

-- [NOVO] Atalho para que um serviço encontre o outro facilmente
function Framework:GetService(name: string): any
	return ServiceManager.Get(name)
end

-- Atalho para os serviços pendurarem coisas na limpeza automática do player
function Framework:GetJanitor(player: Player)
	return playerJanitors[player.UserId]
end

-- [[ INICIALIZAÇÃO ]] --

function Framework.Init()
	local startTime = os.clock() -- [TELEMETRIA] Início do boot do motor
	
	-- Dependency Injection
	Framework.Guard.ConnectReporter(Framework.Log)
	Framework.Network.Init(Framework.Log, Framework.Guard)
	Framework.Config.Init(
		Framework.Log, 
		Framework.Guard, 
		Framework.Events, 
		Framework.Network
	)
	
	-- Varre a pasta de Services e sobe a lógica de gameplay
	local servicesFolder = script:FindFirstChild("Services")
	if servicesFolder then
		ServiceManager.Load(servicesFolder)
		-- Injeta este framework em cada serviço
		ServiceManager.InitAll(Framework) 
		ServiceManager.StartAll()
	end
	
	-- Setup de Players
	game:GetService("Players").PlayerAdded:Connect(function(player)
		local pJanitor = Janitor.new()
		playerJanitors[player.UserId] = pJanitor
		Framework.Log:SendMessage("System", "Sessão iniciada: " .. player.Name, "Print")
	end)

	-- Faxina de Players
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		Framework.Config:ClearPlayer(player) 
		if playerJanitors[player.UserId] then
			playerJanitors[player.UserId]:Destroy()
			playerJanitors[player.UserId] = nil
		end
		Framework.Log:SendMessage("System", "Sessão encerrada: " .. player.Name, "Print")
	end)

	local bootTime = os.clock() - startTime
	Framework.Log:SendMessage("Framework", string.format("Motor e Serviços rodando 100%% (Boot: %.4fs).", bootTime), "Print")
end

return Framework

