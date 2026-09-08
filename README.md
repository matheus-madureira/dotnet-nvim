# Neovim para C# e .NET

Uma configuração de Neovim focada em desenvolvimento C# / .NET no dia a dia: navegação rápida, edição apoiada por LSP, debugging, testes, build integrado e um seletor de temas que não exige mexer nos arquivos de config.

Estruturalmente inspirada na [config de C++ do SalarAlo](https://github.com/SalarAlo/neovim_configuration) — mesma organização (`core/`, `plugins/`, `tools/`), mesmo sistema de temas persistidos, mesma filosofia de ferramentas locais pequenas — porém com todo o miolo trocado para o ecossistema .NET.

## Destaques

- Gerenciamento de plugins com [lazy.nvim](https://github.com/folke/lazy.nvim), instalado automaticamente no primeiro start.
- **C# via [roslyn.nvim](https://github.com/seblyng/roslyn.nvim)** — o mesmo servidor Roslyn que roda por trás da extensão oficial do VS Code, com análise de solução inteira, inlay hints e code lens. OmniSharp fica disponível como alternativa opt-in.
- LSP também para XML (`.csproj`, `Directory.Build.props`, `.targets`), JSON, YAML e Lua.
- **Debugging** com `nvim-dap` + `netcoredbg`: `<leader>dc` compila o projeto dono do arquivo atual, encontra a DLL em `bin/<Configuration>/<tfm>/` e anexa o debugger.
- **Testes** com `neotest` + `neotest-dotnet`: xUnit, NUnit e MSTest descobertos na solução inteira, executáveis e depuráveis a partir do buffer.
- **Build integrado**: `:Build`, `:Run`, `:Test`, `:Watch`, `:Publish` — comandos assíncronos cujos erros do MSBuild caem no quickfix já deduplicados e navegáveis com `:cnext`.
- **Ferramentas locais** para o que o LSP não cobre: ordenação de `using`, esqueleto de arquivo novo com namespace correto, e correção de namespace ao mover arquivos.
- Formatação com CSharpier quando disponível, caindo para o formatador do próprio Roslyn (que respeita o `.editorconfig`) quando não.
- Seletor de temas com persistência entre sessões e comandos de próximo/anterior.

## Instalação

Faça backup da sua config atual e clone este repositório no diretório de configuração do Neovim.

**Linux / macOS:**

```sh
mv ~/.config/nvim ~/.config/nvim.bak
git clone <url-do-repo> ~/.config/nvim
nvim
```

**Windows (PowerShell):**

```powershell
Move-Item $env:LOCALAPPDATA\nvim $env:LOCALAPPDATA\nvim.bak
git clone <url-do-repo> $env:LOCALAPPDATA\nvim
nvim
```

No primeiro start, o `lazy.nvim` se instala, baixa os plugins e o Mason busca o servidor Roslyn, o `netcoredbg`, o CSharpier e o `stylua`. Isso leva alguns minutos — acompanhe com `:Mason`.

### Pré-requisitos

| Ferramenta | Para quê | Obrigatório |
| --- | --- | --- |
| Neovim >= 0.11 | `vim.lsp.config`, `vim.system` | sim |
| [.NET SDK](https://dotnet.microsoft.com/download) | LSP, build, testes, debug | sim |
| `git` | bootstrap do lazy.nvim e dos plugins | sim |
| Compilador C (`zig`, `gcc`, `clang` ou MSVC) | compilar os parsers do Treesitter | recomendado |
| `ripgrep` | `live_grep` e `<leader>fp` no Telescope | recomendado |
| `make` | build do `telescope-fzf-native` (pulado se ausente) | opcional |

Sem um compilador C a config sobe normalmente, apenas avisa uma vez e não instala parsers. No Windows, `winget install --id=BrechtSanders.WinLibs.POSIX.UCRT -e` resolve; depois rode `:TSUpdate`.

## Comandos .NET

| Comando | O que faz |
| --- | --- |
| `:Build [args]` | `dotnet build` na solução (ou no projeto), erros no quickfix |
| `:Rebuild` | build com `--no-incremental` |
| `:Run [args]` | `dotnet run` do projeto dono do arquivo, em split de terminal |
| `:Watch [args]` | `dotnet watch` do projeto dono do arquivo |
| `:Test [args]` | `dotnet test`, falhas no quickfix |
| `:Restore` / `:Clean` | `dotnet restore` / `dotnet clean` |
| `:Publish` | `dotnet publish -c Release` |
| `:DotnetFormat` | `dotnet format` no alvo |
| `:Skel [tipo]` | insere esqueleto de tipo no buffer vazio |
| `:NamespaceFix` | realinha o namespace do arquivo com a pasta |
| `:UsingsSort` | ordena e deduplica o bloco de `using` |
| `:Format` | formata o buffer ou a seleção |
| `:Dotnet ...` | operações de solução do `easy-dotnet` (new, secrets, outdated) |

Comandos que rodam em background (`Build`, `Test`, `Restore`, `Clean`, `Publish`, `DotnetFormat`) não bloqueiam o editor; os interativos (`Run`, `Watch`) abrem um terminal porque precisam de stdin.

## Atalhos

A tecla líder é `<Space>`.

### Navegação e arquivos

| Tecla | Ação |
| --- | --- |
| `<leader>ff` | Buscar arquivos |
| `<leader>fw` | Buscar texto no projeto (live grep) |
| `<leader>fs` / `<leader>fS` | Símbolos do documento / do workspace |
| `<leader>fc` | Buscar palavra sob o cursor |
| `<leader>fb` | Buffers abertos |
| `<leader>fp` | Buscar `.csproj` / `.sln` |
| `<leader>ft` | Buscar TODOs |
| `<C-n>` / `<leader>e` | Alternar / focar a árvore de arquivos |
| `<Tab>` / `<S-Tab>` | Próximo / anterior buffer |
| `<leader>x` | Fechar buffer |

### LSP

| Tecla | Ação |
| --- | --- |
| `gd`, `gD`, `gi`, `gt` | Definição, declaração, implementações, tipo |
| `gR` | Referências |
| `K` | Documentação sob o cursor |
| `<leader>ca` | Code action |
| `<leader>rn` | Renomear símbolo |
| `<leader>d` / `<leader>D` | Diagnósticos da linha / do buffer |
| `[d` / `]d` | Diagnóstico anterior / próximo |
| `<leader>ih` | Alternar inlay hints |
| `<leader>ci`, `<leader>co`, `<leader>ch`, `<leader>cu` | Chamadas entrando/saindo, implementações, referências |
| `<leader>rt` / `<leader>rr` | Escolher solução alvo / reiniciar o Roslyn |
| `<leader>mp` | Formatar arquivo ou seleção |

### Build e projeto

| Tecla | Ação |
| --- | --- |
| `<leader>bb` / `<leader>bB` | Build / rebuild |
| `<leader>br` / `<leader>bw` | Run / watch |
| `<leader>bt` | Test |
| `<leader>bR` / `<leader>bc` | Restore / clean |
| `<leader>bf` / `<leader>bp` | Format / publish |
| `<leader>pn`, `<leader>pp`, `<leader>po`, `<leader>pk` | Novo projeto, escolher projeto, pacotes desatualizados, user secrets |

### Testes

| Tecla | Ação |
| --- | --- |
| `<leader>tr` / `<leader>tf` / `<leader>ta` | Rodar teste sob o cursor / do arquivo / da solução |
| `<leader>td` | Depurar o teste sob o cursor |
| `<leader>tS` / `<leader>to` / `<leader>tO` | Sumário / saída / painel de saída |
| `<leader>tx` | Parar execução |
| `<leader>tt` / `<leader>tb` / `<leader>tq` | Trouble: diagnósticos do workspace / do buffer / quickfix |

### Debug

| Tecla | Ação |
| --- | --- |
| `<leader>dc` | Continuar / iniciar |
| `<leader>db` / `<leader>dB` | Breakpoint / breakpoint condicional |
| `<leader>ds`, `<leader>di`, `<leader>do` | Step over / into / out |
| `<leader>dr` / `<leader>dt` / `<leader>dl` | Restart / terminate / rodar última config |
| `<leader>du` / `<leader>dv` | Alternar a UI / avaliar expressão |
| `<leader>dw`, `<leader>dW`, `<leader>dC` | Adicionar / remover / limpar watches |

### Temas

| Tecla | Ação |
| --- | --- |
| `<leader>ts` | Escolher tema |
| `<leader>tn` / `<leader>tp` | Próximo / anterior tema |

A escolha fica gravada em `stdpath("state")/theme.txt` e volta no próximo start.

## Ferramentas locais

Estas vivem em `lua/dotnet/tools/` e são o equivalente C# dos utilitários de `#include` da config original.

### Ordenação de `using` ao salvar

Ao salvar um `.cs`, o bloco de `using` do topo é ordenado (System primeiro, depois o resto em ordem ordinal), deduplicado e agrupado por espécie: `extern alias`, `global using`, `using`, `using static` e aliases, cada grupo separado por linha em branco.

O formatador é conservador de propósito: ele **não** toca no bloco se houver diretiva de pré-processador dentro dele (`#if`, `#region`), porque reordenar através de um condicional muda o que compila. `#nullable enable` acima do bloco é tolerado. Para desativar em um arquivo específico, coloque `// nousingformat` na primeira linha.

### Esqueleto de arquivo novo

Ao criar um `.cs`, o arquivo já nasce com o namespace derivado do `<RootNamespace>` do `.csproj` mais a hierarquia de pastas, e com um tipo nomeado a partir do arquivo. A espécie do tipo é inferida do nome:

| Nome do arquivo | Gera |
| --- | --- |
| `IOrderRepository.cs` | `public interface IOrderRepository` |
| `OrderService.cs` | `public sealed class OrderService` |
| `CreateOrderRequest.cs` | `public sealed record CreateOrderRequest` |
| `OrderServiceTests.cs` | classe de teste com `using Xunit;` e um `[Fact]` |
| `NotFoundException.cs` | exceção com os dois construtores usuais |
| `SmtpOptions.cs` | classe de options com `SectionName` |
| `OrderStatus.cs` | `public enum OrderStatus` |

`:Skel <tipo>` força a espécie (`class`, `static`, `interface`, `record`, `enum`, `options`, `exception`, `attribute`, `tests`). Arquivos gerados (`*.g.cs`, `*.Designer.cs`) são ignorados.

### Namespace ao mover arquivos

Renomear ou mover um `.cs` pela árvore de arquivos dispara `workspace/willRenameFiles` no language server — que corrige o namespace **e** todas as referências. Se nenhum servidor responder, a declaração `namespace` do próprio arquivo é reescrita como fallback. `:NamespaceFix` faz o mesmo sob demanda no buffer atual.

## Configuração

Ajustes ficam em `lua/dotnet/core/options.lua`:

| Variável | Padrão | Efeito |
| --- | --- | --- |
| `vim.g.dotnet_lsp` | `"roslyn"` | `"omnisharp"` troca o servidor de C#. Nunca sobem os dois juntos. |
| `vim.g.dotnet_configuration` | `"Debug"` | Configuration usada por build, run e debug |
| `vim.g.dotnet_file_scoped_namespaces` | `true` | `false` gera namespace com chaves em vez de `namespace X;` |
| `vim.g.dotnet_skeleton_on_new` | `true` | `false` desliga o esqueleto automático (mas mantém `:Skel`) |

Formatação ao salvar pode ser desligada com `:FormatDisable` (global) ou `:FormatDisable!` (só o buffer), e religada com `:FormatEnable`.

## Estrutura

```text
init.lua                      Ponto de entrada
lua/dotnet/lazy.lua           Bootstrap do lazy.nvim
lua/dotnet/core/              Opções, atalhos, filetypes e o sistema de temas
lua/dotnet/plugins/           Specs dos plugins
lua/dotnet/plugins/lsp/       Mason, nvim-lspconfig e roslyn.nvim
lua/dotnet/tools/             Ferramentas locais (projeto, usings, skeleton, CLI)
snippets/                     Snippets de C# do LuaSnip
```

`lua/dotnet/tools/project.lua` é a base das demais: descobre o `.csproj`/`.sln` dono de um arquivo, lê `<RootNamespace>` e `<AssemblyName>`, deriva o namespace correto e localiza a DLL de saída mais recente.

## Licença

MIT — veja [LICENSE](LICENSE).
