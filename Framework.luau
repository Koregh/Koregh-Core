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

-- Inicializa as instâncias globais que o jogo inteiro vai usar
Framework.Log = Log.new()
Framework.Guard = Guard
Framework.Memory = Memory.new()
Framework.Events = Events.new()
Framework.Network = Network.new()
Framework.Config = Config.new()

-- Exporta as classes para que os serviços possam instanciar seus próprios utilitários
Framework.Janitor = Janitor
Framework.Signal = Signal

-- Controle de limpeza por jogador (evita memory leak ao sair do servidor)
local playerJanitors: { [number]: any } = {}

-- Prepara o terreno e sobe os serviços
function Framework.Init()
	-- Amarramos as dependências uma na outra (Dependency Injection)
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
		-- Injeta este framework em cada serviço para que eles tenham acesso a tudo
		ServiceManager.InitAll(Framework) 
		ServiceManager.StartAll()
	end
	
	-- Setup inicial quando alguém entra no jogo
	game:GetService("Players").PlayerAdded:Connect(function(player)
		-- Cada player ganha um Janitor próprio para rastrear suas conexões
		local pJanitor = Janitor.new()
		playerJanitors[player.UserId] = pJanitor
		Framework.Log:SendMessage("System", "Sessão iniciada: " .. player.Name, "Print")
	end)

	-- Faxina completa quando o player desloga
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		-- Remove o cache de configurações
		Framework.Config:ClearPlayer(player) 
		
		-- Mata qualquer conexão ou instância que ficou pendurada no Janitor dele
		if playerJanitors[player.UserId] then
			playerJanitors[player.UserId]:Destroy()
			playerJanitors[player.UserId] = nil
		end
		
		Framework.Log:SendMessage("System", "Sessão encerrada: " .. player.Name, "Print")
	end)

	Framework.Log:SendMessage("Framework", "Motor e Serviços rodando 100%.", "Print")
end

-- Atalho para os serviços pendurarem coisas na limpeza automática do player
function Framework:GetJanitor(player: Player)
	return playerJanitors[player.UserId]
end

return Framework

