# Entre Folhas · Godot 4

Os pacotes prontos para jogar no Linux e no Windows estão em [downloads/README.md](downloads/README.md).

Uma pequena aventura de exploração **com visão de cima**, agora implementada nativamente em **Godot 4.6 / GDScript**. Encontre cinco sementes e leve uma nova primavera à árvore-mãe.

## Abrir e jogar

1. Abra `project.godot` no Godot 4.6 ou superior (validado no 4.6.3).
2. Aguarde a importação dos sprites.
3. Pressione **F5**, ou abra `scenes/main.tscn` e pressione **F6**.

Não é necessário Node.js, npm, plugin ou serviço externo.

Neste ambiente na nuvem, com uma sessão gráfica ativa:

```sh
cd /workspace/meu-jogo
./scripts/godot.sh --editor
```

Para executar diretamente: `./scripts/godot.sh`.

O wrapper mantém os dados e caches do Godot em `.runtime/` quando as variáveis XDG não estão configuradas, permitindo usar o motor no ambiente restrito sem alterar HOME. No seu computador, também é possível abrir o projeto diretamente pelo editor.

## Versões prontas para Linux e Windows

Os pacotes `EntreFolhas-Linux.zip` e `EntreFolhas-Windows.zip` contêm o jogo para PC de 64 bits, sem necessidade de instalar o Godot. No Windows, extraia o ZIP e abra `EntreFolhas.exe`. No Linux, extraia e abra `Jogar.sh`; se necessário, dê permissão de execução com `chmod +x Jogar.sh EntreFolhas.x86_64`.

Os pacotes gerados ficam em `/workspace/shared/downloads/`. O Linux é executado e validado neste ambiente; não há Windows disponível para validar a execução nativa do `.exe`.

Para reconstruir, os templates oficiais de exportação da mesma versão do Godot precisam estar instalados. Nesta máquina, foram usados os templates oficiais 4.6.3, com o arquivo de origem verificado contra o SHA-512 publicado pelo Godot. Os templates selecionados e seus hashes ficam em `.runtime/data/godot/export_templates/4.6.3.stable/`.

```sh
mkdir -p build/linux build/windows
./scripts/godot.sh --headless --export-release Linux build/linux/EntreFolhas.x86_64
./scripts/godot.sh --headless --export-release Windows build/windows/EntreFolhas.exe
python3 scripts/package_releases.py --output /workspace/shared/downloads
```

Os recursos do jogo ficam embutidos nos executáveis. O empacotador inclui controles, licenças oficiais, preserva a permissão de execução no Linux, verifica a integridade dos ZIPs e gera `EntreFolhas-SHA256.txt`.

## Dois reinos e oito moradores

**Aurélia**, no oeste dourado, e **Valverde**, a leste do riacho, têm castelos, bandeiras, mercados e moradores. Converse usando **E** e escolha uma pergunta. Cada personagem tem saudação, história sobre os dois reinos, dicas da missão e uma descrição da sua rotina.

| Morador | Reino | Rotina própria |
| --- | --- | --- |
| Bento, ferreiro | Aurélia | Forja, almoço na taverna, consertos e descanso às 22h. |
| Lia, comerciante | Aurélia | Mercado oeste, viagem ao mercado leste às 10h, retorno e taverna. |
| Tomás, guarda | Valverde | Abre o posto, patrulha a ponte em circuito e recolhe-se ao quartel. |
| Íris, herbalista | Valverde | Colhe ervas, entrega remédios no mercado e volta ao jardim. |
| Eron, sábio | Aurélia | Arquivo, observação da árvore-mãe e escrita ao entardecer. |
| Rei Aurel | Aurélia | Jardim, audiências às 9h e visita ao mercado às 14h. |
| Rei Caio | Valverde | Jardim, audiências às 10h, plantações e relatos da guarda. |
| Mila, camponesa | Valverde | Rega às 5h, jardim de ervas, feira às 13h e retorno à plantação. |

Um dia dura 12 minutos reais. Os moradores caminham por caminhos calculados com `AStarGrid2D`, respeitam o rio e os edifícios, voltam para descansar e acordam em horários diferentes. Ao iniciar uma conversa ou pausar, o relógio e as rotinas param. O acampamento permite descansar até as 7h do dia seguinte. A luz e os marcadores dos moradores acompanham o horário.

Os dois reis podem dar sua palavra para renovar o **Acordo das Raízes**. A aliança só é concluída com o aval dos dois e a árvore-mãe restaurada. O salvamento preserva dia, horário, posições dos NPCs, encontros e compromisso dos reinos, mantendo compatibilidade com a jornada anterior.

O protagonista e os oito NPCs usam as cinco folhas complementares do agricultor fornecidas em `tomate.zip`, com variações discretas na roupa dos moradores. Nomes, reinos, diálogos e rotinas são mantidos. Os dez PNGs do pacote estão em `assets/tomate/`, preservando os bytes originais. O [manifesto de origem](assets/tomate/sources.json) registra nomes recebidos, papéis e hashes SHA-256. Para personalizar uma aparência no jogo pronto, converse com o morador e escolha **Escolher sprite deste morador**.

## Controles

| Ação | Controle |
| --- | --- |
| Caminhar | WASD ou setas |
| Correr | Shift |
| Recolher sementes, ler e plantar | E |
| Abrir/fechar o mapa | M |
| Pausar/voltar | Esc |

Em telas menores ou dispositivos com toque, a interface oferece um controle de movimento e botão de interação. Som ambiente e efeitos são sintetizados localmente, com ativação opcional no botão de música.

## Sprites e personagens

As quatro árvores de `tomate.zip` são carvalho, pinheiro, árvore seca e macieira. Recebem vento contínuo na copa, com pequenas rajadas e raízes imóveis. A árvore-mãe começa seca e volta a ser um carvalho ao concluir a missão. As três casas fornecidas representam os edifícios dos dois reinos, preservando proporção, portas, nomes, profundidade e colisões.

Grama, flores, pedras, terra, areia, calçamento e musgo vêm da nova folha de terrenos. As transições formam as bordas dos caminhos. O rio usa as quatro fases de água com transição suave e margens estáticas. Recortes inteiros excluem as grades das folhas, e as texturas dos caminhos ficam fixas nas coordenadas do mundo. A decoração do chão faz parte dos tiles e não deixa obstáculos invisíveis da arte anterior.

**Escolher personagem**, na introdução ou no menu de pausa, abre um seletor de arquivo PNG nativo do Godot. Ele aceita as pranchas de cinco colunas e oito linhas das imagens enviadas. As primeiras quatro linhas representam frente, costas, direita e esquerda ao caminhar; as quatro seguintes representam corrida. A primeira coluna contém a pose parada, e as demais contêm os quatro quadros de movimento. Os sprites laterais não são espelhados.

O pacote fornece uma folha de repouso nas quatro direções e quatro folhas de caminhada, uma por direção. Elas são combinadas em 12 animações. A corrida reutiliza as poses de caminhada em sua cadência própria. A escala é normalizada nas viradas, e o fundo magenta dos PNGs RGB é removido apenas durante a renderização, sem alterar os arquivos.

Os passos avançam conforme a distância realmente percorrida: moradores mais lentos têm uma passada mais calma, e a corrida usa um passo mais comprido. O ciclo para junto com o personagem e mantém a fase nas viradas, independentemente da taxa de quadros.

O protagonista usa o agricultor por padrão e permite importar uma prancha local. A imagem escolhida é copiada, sem modificar o original, para `user://characters/selected.png`. As artes recebidas anteriormente continuam arquivadas no projeto e são excluídas dos executáveis atuais.

## Salvamento

O progresso é salvo automaticamente em `user://journey.json` a cada dois segundos, ao recolher sementes, plantar, pausar ou fechar a janela. A posição, as sementes, a vitória e a escolha de personagem são restauradas ao continuar. Reiniciar requer confirmação e mantém o personagem escolhido. Dados inválidos são filtrados, com retorno à posição inicial quando necessário.

Com o wrapper e sem variáveis XDG predefinidas, `user://` corresponde a `.runtime/data/EntreFolhas/`. No editor aberto diretamente, é o diretório de dados do usuário escolhido pelo Godot. Os dados do antigo protótipo de navegador não são migrados automaticamente.

## Validação

Importar os recursos e analisar os scripts:

```sh
./scripts/godot.sh --headless --audio-driver Dummy --editor --import --quit
```

Executar os testes nativos:

```sh
./scripts/godot.sh --headless --audio-driver Dummy --script res://tests/run.gd -- --test
```

A suíte termina com código diferente de zero se uma verificação falhar e inclui regressões para a duração do vento, as raízes do atlas novo, o alinhamento dos passos, as viradas e a textura das ruas. Ela usa dados temporários, não altera a jornada do jogador e tem limite de 60 segundos. Verifica acessibilidade dos objetivos, movimento e colisões reais, travessia da ponte, interação pela tecla E, coleta única, plantio, vitória, salvamento em disco, validação dos dados, importação e quadros dos personagens, menus e controles de toque.

`tests/capture_motion.gd` oferece uma conferência gráfica dos 128 quadros de caminhada dos NPCs, nas quatro direções, com guias de alinhamento.

`tests/natural_motion_preview.gd` renderiza uma sequência temporal usando o controlador de passos dos oito NPCs e o material de vento do jogo. A simulação por instantes definidos permite conferir a cadência e o vento sem alterar o ritmo por causa do custo da gravação. As rotas e colisões reais são verificadas separadamente pela suíte nativa.

[Ver a prévia animada](docs/movimento.gif) · [Vídeo da prévia](docs/movimento.mp4)

Uma verificação gráfica opcional, em uma sessão com display ativo:

```sh
./scripts/godot.sh --audio-driver Dummy --script res://tests/capture.gd -- --capture
```

Ela renderiza o cenário no próprio Godot e salva capturas temporárias de introdução, jogo, mapa, árvore restaurada, dois reinos, conversas, rotinas, noite e tela estreita em `/tmp/entre-folhas-godot-*.png`. A migração foi validada com o renderizador Compatibility / OpenGL e Mesa llvmpipe. Não é necessário instalar templates de exportação para editar e jogar no motor; um executável distribuível é uma etapa separada no menu de exportação do Godot.

## Estrutura do projeto

- `project.godot`: projeto Godot 4.6, renderização 2D Compatibility e filtro de pixels.
- `scenes/main.tscn`: cena principal com mundo, personagem, câmera e HUD.
- `game/main.gd`: objetivos, diálogos, entradas e salvamento.
- `game/world.gd`: chão em `TileMapLayer`, árvores em `AnimatedSprite2D`, profundidade por Y e colisões em `StaticBody2D`.
- `game/world_data.gd`: mapa determinístico, destinos e regras de navegação.
- `game/terrain.gd`: ruas e clareiras com textura fixa nas coordenadas do mundo, sem esticar a imagem nas curvas ou sobrepor bordas nos cruzamentos.
- `game/player.gd`: `CharacterBody2D`, movimento, animações e sensor de interação em `Area2D`.
- `game/seed.gd`: colecionável com `Area2D` e brilho animado.
- `game/npc.gd`, `game/kingdom_data.gd` e `game/world_clock.gd`: moradores, reinos, diálogos, navegação e relógio.
- `game/character_sheet.gd`: importação compartilhada das pranchas para jogador e NPCs.
- `game/hud.gd`, `game/minimap.gd` e `game/joystick.gd`: interface nativa e controles de toque.
- `game/forest_audio.gd`: vento e efeitos em `AudioStreamPlayer`.
- `assets/`: sprites originais, ícone e shader de iluminação.
- `tests/`: validação do motor e captura gráfica.

O protótipo web anterior foi preservado em `/workspace/scratch/meu-jogo-web-antes-godot.zip`. O projeto principal não depende dele.

Cada tarefa na nuvem já usa um ambiente isolado. Trabalhe no checkout existente; não crie um Git worktree sem solicitação explícita.
