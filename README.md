# ELF — Elite Luau Framework

Um **framework de alto desempenho, modular e seguro** para desenvolvimento profissional no Roblox.

O **ELF (Elite Luau Framework)** foi projetado para desenvolvedores que precisam de uma **arquitetura escalável, previsível e segura**, com foco em **Injeção de Dependências**, **Segurança de Memória**, **Imutabilidade de Estado** e **Middleware Anti-Exploit**.

---

## 🚀 Filosofia Central

- 🧩 **Arquitetura Modular**  
  Toda a lógica é desacoplada em *Services*, coordenados por um **Kernel central**.

- 🛡️ **Segurança em Primeiro Lugar**  
  Validação nativa de dados (schemas) e *rate limit* em toda comunicação de rede.

- 🔄 **Estado Reativo e Imutável**  
  Gerenciamento de dados com replicação automática para o cliente e proteção contra mutações acidentais.

- 🧹 **Eficiência de Memória**  
  Gerenciamento rigoroso de ciclo de vida utilizando o padrão **Janitor**, prevenindo memory leaks.

---

## 📂 Estrutura do Projeto

```text
Framework/
├── Services/           # Lógica do jogo (EconomyService, QuestService, etc)
├── ServiceManager      # Orquestra carregamento e ciclo de vida
├── NetworkManager      # Camada de comunicação segura
├── ConfigManager       # Estado imutável e replicação
├── GuardClause         # Motor de validação de dados
├── Signal              # Eventos internos de alta performance
├── Janitor             # Utilitário de limpeza de memória
└── ConsoleReporter     # Log centralizado e telemetria
```

---

## 🛠️ Referência da API

### 1. Núcleo do Framework (`Framework.lua`)

Responsável por inicializar os módulos e injetar dependências nos serviços.

| Método | Descrição |
|------|----------|
| `Framework.Init()` | Inicializa os módulos principais e inicia o `ServiceManager`. |
| `Framework:GetJanitor(player)` | Retorna uma instância exclusiva de `Janitor` associada ao jogador. |

---

### 2. Service Manager

Gerencia o ciclo de vida dos serviços do jogo.

| Etapa | Método | Ação |
|-----|--------|------|
| I | `Load(folder)` | Requer todos os `ModuleScripts` do diretório informado. |
| II | `InitAll(fm)` | Injeta o `Framework` em cada `Service.Init()`. |
| III | `StartAll()` | Executa `Service.Start()` em threads isoladas. |

---

### 3. Config Manager

Gerencia dados dos jogadores com **imutabilidade garantida**.  
Toda leitura retorna uma **cópia profunda**, evitando corrupção de estado.

- `SetPlayer(player, key, value)`  
  Atualiza o estado interno e replica automaticamente se a chave estiver marcada para sync.

- `GetPlayer(player, key)`  
  Retorna uma cópia protegida do dado.

- `ImportPlayerData(player, data)`  
  Inicializa a sessão do jogador com dados externos (ex: DataStore).

---

### 4. Network Manager

Interface segura para `RemoteEvents`.

- `Connect(name, blueprint, callback, cooldown)`  
  - **Blueprint**: Schema opcional para validação dos dados recebidos.  
  - **Cooldown**: Rate limit automático por jogador.

- `FireClient(name, player, ...)`  
  Envia dados de forma segura para um cliente específico.

---

### 5. Signal (Eventos Internos)

Implementação pura do padrão **Observer** em Luau, mais rápida que `BindableEvents`.

- `Connect(handler)` — Inscreve um listener e retorna uma conexão.
- `Fire(...)` — Dispara o evento para todos os listeners.
- `Wait()` — Suspende a execução até o evento ser disparado.

---

## 🧪 Exemplo de Implementação de Serviço

Crie um `ModuleScript` dentro da pasta `Services`:

```lua
local MyService = {}
local _FM -- Referência do Framework

function MyService.Init(framework)
    _FM = framework
    _FM.Log:SendMessage("MyService", "Inicializado com sucesso!", "Print")
end

function MyService.Start()
    _FM.Network:Connect(
        "PlayerAction",
        { ID = "string" },
        function(player, data)
            print(player.Name .. " executou a ação: " .. data.ID)
        end
    )
end

return MyService
```

---

## 📜 Licença

Este projeto é distribuído sob a **Licença MIT**.

---

## 📎 Próximos Passos

- Criar `DATA_STRUCTURE.md` documentando os schemas do `ConfigManager`
- Adicionar um `.gitignore` padrão para projetos Roblox
- Documentação avançada de segurança e anti-exploit

---

**ELF — arquitetura de nível profissional para jogos Roblox escaláveis.**
