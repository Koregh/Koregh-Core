--!strict
-- Framework.lua
-- O Ponto Central: Orquestra ferramentas, serviços e o ciclo de vida do jogo.

local Framework = {}
Framework.__index = Framework

-- 1. Importação dos Módulos (Ferramentas Base)
local Log = require(script.ConsoleReporter)
local Guard = require(script.GuardClause)
local Memory = require(script.MemoryManager)
local Events = require(script.EventManager)
local Network = require(script.NetworkManager)
local Config = require(script.ConfigManager)
local Janitor = require(script.Janitor)
local Signal = require(script.Signal) -- O novo módulo que você criou
local ServiceManager = require(script.ServiceManager) -- O gerenciador separado

-- 2. Instâncias e Classes Únicas
Framework.Log = Log.new()
Framework.Guard = Guard
Framework.Memory = Memory.new()
Framework.Events = Events.new()
Framework.Network = Network.new()
Framework.Config = Config.new()

-- Disponibiliza as Classes para que os Serviços possam criar novas instâncias
Framework.Janitor = Janitor
Framework.Signal = Signal

-- Armazenamento de Janitors por Player
local playerJanitors: { [number]: any } = {}

-- 3. Inicialização e Orquestração
function Framework.Init()
	-- A. Injeção de Dependências nos Utilitários
	Framework.Guard.ConnectReporter(Framework.Log)
	Framework.Network.Init(Framework.Log, Framework.Guard)
	Framework.Config.Init(
		Framework.Log, 
		Framework.Guard, 
		Framework.Events, 
		Framework.Network
	)
	
	-- B. CARREGAMENTO DOS SERVIÇOS (A lógica do jogo)
	local servicesFolder = script:FindFirstChild("Services")
	if servicesFolder then
		ServiceManager.Load(servicesFolder)
		ServiceManager.InitAll(Framework) -- Passa este framework para todos os serviços
		ServiceManager.StartAll()
	end
	
	-- C. Ciclo de Vida dos Jogadores
	game:GetService("Players").PlayerAdded:Connect(function(player)
		local pJanitor = Janitor.new()
		playerJanitors[player.UserId] = pJanitor
		Framework.Log:SendMessage("System", "Sessão iniciada: " .. player.Name, "Print")
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		-- 1. Limpa o estado no ConfigManager
		Framework.Config:ClearPlayer(player) 
		
		-- 2. Limpeza total de memória/conexões via Janitor
		if playerJanitors[player.UserId] then
			playerJanitors[player.UserId]:Destroy()
			playerJanitors[player.UserId] = nil
		end
		
		Framework.Log:SendMessage("System", "Sessão encerrada: " .. player.Name, "Print")
	end)

	Framework.Log:SendMessage("Framework", "Motor Sênior e Serviços Totalmente Operacionais.", "Print")
end

-- Utilitário para Serviços obterem o Janitor de um player
function Framework:GetJanitor(player: Player)
	return playerJanitors[player.UserId]
end

return Framework

