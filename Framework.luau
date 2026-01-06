--!strict
-- Framework.lua
-- O Ponto Central: Une todos os serviços, gerencia dependências e o ciclo de vida.

local Framework = {}
Framework.__index = Framework

-- 1. Importação dos Módulos
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
local playerJanitors: { [number]: any } = {}

-- 3. Inicialização e Injeção de Dependências
function Framework.Init()
	-- A ordem aqui é vital para evitar erros de "nil"
	
	-- 1. Primeiro o Guard recebe o Log para reportar erros de validação
	Framework.Guard.ConnectReporter(Framework.Log)
	
	-- 2. O Network recebe Log e Guard para proteger as Remotes
	Framework.Network.Init(Framework.Log, Framework.Guard)
	
	-- 3. O Config agora recebe Network também (para a Replicação Ativa)
	Framework.Config.Init(
		Framework.Log, 
		Framework.Guard, 
		Framework.Events, 
		Framework.Network -- Nova dependência injetada!
	)
	
	-- Ciclo de Vida Global dos Jogadores
	game:GetService("Players").PlayerAdded:Connect(function(player)
		-- Cria um Janitor exclusivo para limpar a bagunça deste player ao sair
		local pJanitor = Janitor.new()
		playerJanitors[player.UserId] = pJanitor
		
		Framework.Log:SendMessage("System", "Sessão iniciada: " .. player.Name, "Print")
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		-- A ordem de limpeza sênior:
		
		-- 1. Limpa o estado no ConfigManager
		Framework.Config:ClearPlayer(player) 
		
		-- 2. Destrói o Janitor (Limpa todas as conexões/objetos ligados ao player)
		if playerJanitors[player.UserId] then
			playerJanitors[player.UserId]:Destroy()
			playerJanitors[player.UserId] = nil
		end
		
		Framework.Log:SendMessage("System", "Sessão encerrada: " .. player.Name, "Print")
	end)

	Framework.Log:SendMessage("Framework", "Motor Sênior Operacional (Core Integrado).", "Print")
end

-- Função utilitária para outros scripts pegarem o faxineiro do player
function Framework:GetJanitor(player: Player)
	return playerJanitors[player.UserId]
end

return Framework

