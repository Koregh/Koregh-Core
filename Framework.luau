--!strict
-- Framework.lua
-- O Ponto Central: Orquestra utilitários e gerencia o ciclo de vida dos serviços.

local Framework = {}
Framework.__index = Framework

-- 1. Importação dos Módulos Base
local Log = require(script.ConsoleReporter)
local Guard = require(script.GuardClause)
local Memory = require(script.MemoryManager)
local Events = require(script.EventManager)
local Network = require(script.NetworkManager)
local Config = require(script.ConfigManager)
local Janitor = require(script.Janitor)

-- 2. O Módulo Separado que você criou
local ServiceManager = require(script.ServiceManager)

-- Instâncias Únicas (Singletons)
Framework.Log = Log.new()
Framework.Guard = Guard
Framework.Memory = Memory.new()
Framework.Events = Events.new()
Framework.Network = Network.new()
Framework.Config = Config.new()
Framework.Janitor = Janitor -- Exporta a classe para os serviços usarem

-- Armazenamento de Janitors por Player
local playerJanitors: { [number]: any } = {}

-- [[ INICIALIZAÇÃO ]] --

function Framework.Init()
	-- 1. Configuração de Dependências dos Utilitários
	Framework.Guard.ConnectReporter(Framework.Log)
	Framework.Network.Init(Framework.Log, Framework.Guard)
	Framework.Config.Init(Framework.Log, Framework.Guard, Framework.Events, Framework.Network)
	
	-- 2. CARREGAMENTO DOS SERVIÇOS
	-- Procura a pasta 'Services' dentro do Framework
	local servicesFolder = script:FindFirstChild("Services")
	if servicesFolder then
		ServiceManager.Load(servicesFolder)    -- Dá o 'require' nos módulos
		ServiceManager.InitAll(Framework)      -- Roda o Init(Framework) de cada um
		ServiceManager.StartAll()              -- Roda o Start() em threads seguras
	end

	-- 3. Ciclo de Vida Global dos Jogadores
	game:GetService("Players").PlayerAdded:Connect(function(player)
		local pJanitor = Janitor.new()
		playerJanitors[player.UserId] = pJanitor
		Framework.Log:SendMessage("System", "Sessão iniciada: " .. player.Name, "Print")
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		Framework.Config:ClearPlayer(player) 
		
		if playerJanitors[player.UserId] then
			playerJanitors[player.UserId]:Destroy()
			playerJanitors[player.UserId] = nil
		end
		
		Framework.Log:SendMessage("System", "Sessão encerrada: " .. player.Name, "Print")
	end)

	Framework.Log:SendMessage("Framework", "Motor Sênior e Serviços Online.", "Print")
end

-- Função utilitária para outros scripts pegarem o janitor do player
function Framework:GetJanitor(player: Player)
	return playerJanitors[player.UserId]
end

return Framework

