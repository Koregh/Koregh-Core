--!strict
-- ServiceManager.lua
-- Gerencia o ciclo de vida dos serviços com isolamento de erros.

local ServiceManager = {}
local _services: { [string]: any } = {}

-- [[ MÉTODOS PÚBLICOS ]] --

-- @desc Carrega os módulos e os armazena na memória interna
function ServiceManager.Load(servicesFolder: Folder)
	for _, module in ipairs(servicesFolder:GetChildren()) do
		if module:IsA("ModuleScript") then
			local success, service = pcall(require, module)
			if success then
				_services[module.Name] = service
			else
				warn(`[ServiceManager] Erro Crítico de Require em {module.Name}: {service}`)
			end
		end
	end
end

-- @desc Configura dependências (Roda sequencialmente, mas protegido)
function ServiceManager.InitAll(framework: any)
	for name, service in pairs(_services) do
		if type(service.Init) == "function" then
			-- O pcall aqui garante que um serviço quebrado não pare o Framework
			local success, err = pcall(service.Init, framework)
			if not success then
				-- Se o framework tiver log, usamos ele, senão usamos warn
				if framework.Log then
					framework.Log:SendMessage("Critical", `Erro no Init do serviço {name}: {err}`, "Error")
				else
					warn(`[ServiceManager] Erro no Init de {name}: {err}`)
				end
			end
		end
	end
end

-- @desc Inicia a lógica ativa (Roda em threads separadas e protegidas)
function ServiceManager.StartAll()
	for name, service in pairs(_services) do
		if type(service.Start) == "function" then
			-- Usamos task.spawn para cada serviço ter sua própria 'linha de vida'
			task.spawn(function()
				local success, err = pcall(service.Start)
				if not success then
					warn(`[ServiceManager] Erro de execução no serviço {name}: {err}`)
				end
			end)
		end
	end
end

return ServiceManager

