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
- **Formatação ao salvar pelo próprio Roslyn**, que é quem aplica as regras de espaçamento e quebra de linha do `.editorconfig` — e ainda reorganiza os `using` no mesmo passe. CSharpier continua disponível como alternativa opt-in.
- **Ruleset de C# padrão**: estilo, nomenclatura e severidades de analyzers em um `.editorconfig` que o language server e o formatador leem juntos — instalado automaticamente em projetos que ainda não têm o seu.
- Treesitter na branch `main` (a que o plugin usa por padrão hoje), com seleção incremental reimplementada, já que o módulo que a fornecia foi removido de lá.
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

No primeiro start, o `lazy.nvim` se instala, baixa os plugins e o Mason busca o servidor Roslyn, o `netcoredbg`, o CSharpier, o `tree-sitter` CLI e o `stylua`. Isso leva alguns minutos — acompanhe com `:Mason`.

O servidor Roslyn não está no registry padrão do Mason; a config adiciona `github:crashdummyy/mason-registry`, que é o que o `roslyn.nvim` acompanha. Os parsers do Treesitter só começam a compilar depois que o Mason termina, porque dependem do `tree-sitter` CLI que ele instala.

### Pré-requisitos

| Ferramenta | Para quê | Obrigatório |
| --- | --- | --- |
| Neovim >= 0.11 | `vim.lsp.config`, `vim.system` | sim |
| [.NET SDK](https://dotnet.microsoft.com/download) | LSP, build, testes, debug | sim |
| `git` | bootstrap do lazy.nvim e dos plugins | sim |
| Compilador C (`gcc`, `clang`, MSVC ou `zig`) | compilar os parsers do Treesitter | recomendado |
| `tree-sitter` CLI | gerar parsers do Treesitter (o Mason instala) | recomendado |
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
| `:DotnetEditorConfig[!]` | escreve o `.editorconfig` padrão de C# na raiz do workspace |
| `:DotnetEditorConfigEdit` | abre o `.editorconfig` que está valendo |
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
| `<C-space>` / `<BS>` | Expandir / reduzir a seleção por nó do Treesitter |

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

Isso vale quando o language server não está fazendo o serviço: com o Roslyn anexado e formatação ao salvar ligada, o passe local sai de cena, porque o servidor reescreve o bloco inteiro a partir do `.editorconfig` logo em seguida — e as duas ordenações discordam no espaçamento entre grupos.

O formatador é conservador de propósito: ele **não** toca no bloco se houver diretiva de pré-processador dentro dele (`#if`, `#region`), porque reordenar através de um condicional muda o que compila. `#nullable enable` acima do bloco é tolerado. Para desativar em um arquivo específico, coloque `// nousingformat` na primeira linha.

### Ruleset padrão de C# (`.editorconfig`)

Estilo de código, regras de nomenclatura e severidade de analyzers não são configuráveis pelo lado do Neovim: o Roslyn (e o OmniSharp) leem tudo isso do `.editorconfig`, e o CSharpier e o `dotnet format` leem dali as regras de espaçamento. É o único canal que alcança o servidor **e** o formatador — e, de quebra, faz as regras valerem também no `dotnet build`, na CI e no Visual Studio.

Por isso a config traz um ruleset pronto em [`templates/dotnet.editorconfig`](templates/dotnet.editorconfig): namespaces `file_scoped`, `var` só quando o tipo é aparente, chaves obrigatórias, `readonly` em campos, modificadores de acesso explícitos, expression-bodied em propriedades e lambdas mas não em métodos, ordem de modificadores, espaçamento e quebras de linha, ordenação de `using` com `System` primeiro, além do desligamento das regras CA/IDE/Sonar que só geram ruído.

Ao abrir um arquivo de um workspace .NET que **não** tem nenhum `.editorconfig` acima dele, o arquivo padrão é escrito na raiz (diretório da solução, senão do projeto, senão do repositório git). Projeto que já tem o seu nunca é tocado — as regras dele ganham.

| | |
| --- | --- |
| `:DotnetEditorConfig` | escreve o padrão na raiz do workspace (recusa se já existir) |
| `:DotnetEditorConfig!` | sobrescreve o que estiver lá |
| `:DotnetEditorConfig <dir>` | escreve em um diretório específico |
| `:DotnetEditorConfigEdit` | abre o `.editorconfig` em vigor, ou o template se não houver nenhum |

Depois de gerar o arquivo, `:Roslyn restart` reaplica as severidades. `vim.g.dotnet_editorconfig = false` desliga a geração automática e mantém os comandos.

#### Quem formata ao salvar

Quem aplica essas regras ao salvar é o **Roslyn**, não o CSharpier: o formatador do servidor lê `csharp_new_line_*`, `csharp_space_*`, `csharp_indent_*` e companhia direto do `.editorconfig`, e — com `dotnet_organize_imports_on_format` ligado — reordena os `using` no mesmo passe, respeitando `dotnet_sort_system_directives_first` e `dotnet_separate_import_directive_groups`. O CSharpier é opinativo por natureza: das regras do arquivo ele lê indentação, fim de linha e largura de linha, e decide o resto sozinho — o que sobrescreveria o ruleset.

Ele segue instalado e assume em dois casos: quando não há servidor anexado ao buffer (ou o que há não formata trechos, no `:Format` sobre uma seleção), e quando você pede, com `vim.g.dotnet_formatter = "csharpier"`.

Uma coisa que **não** acontece ao salvar: correções de estilo. Regras como `csharp_style_namespace_declarations = file_scoped` ou `csharp_style_var_elsewhere = false` viram diagnóstico (`IDE0161`, `IDE0008`) com a severidade que você definiu, e se corrigem com o code action em cima do diagnóstico (`<leader>ca`) — não pelo formatador. O servidor Roslyn anuncia apenas os code actions `quickfix` e `refactor`, sem o `source.fixAll` que o VS Code usa para arrumar tudo ao salvar. Para um passe em lote existe o `:DotnetFormat`, que roda `dotnet format` no alvo inteiro.

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
| `vim.g.dotnet_editorconfig` | `true` | `false` para de gerar o `.editorconfig` padrão (mas mantém `:DotnetEditorConfig`) |
| `vim.g.dotnet_formatter` | `"lsp"` | `"csharpier"` entrega a formatação de C# ao CSharpier em vez do Roslyn |

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
templates/                    Ruleset padrão de C# (.editorconfig)
```

`lua/dotnet/tools/project.lua` é a base das demais: descobre o `.csproj`/`.sln` dono de um arquivo, lê `<RootNamespace>` e `<AssemblyName>`, deriva o namespace correto e localiza a DLL de saída mais recente.

## Licença

MIT — veja [LICENSE](LICENSE).
