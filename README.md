# Entre Reinos · Godot 4

Um **RPG de mundo aberto 2.5D para Windows e Linux**. Personagens em pixel art vivem em cidades, vilarejos e campos com cenário 3D. Explore, negocie, compre ferramentas, enfrente animais e construa sua casa.

[Baixar o jogo pronto](downloads/README.md)

![Aurélia](docs/rpg-aurelia.png)

## Crie seu próprio mapa

Pressione **F2** para abrir o **Ateliê de Mundos**, incluído no jogo pronto. Comece com um mapa vazio ou edite a base dos reinos. Pinte terreno e rios; coloque casas, pontes, árvores, animais e moradores; defina os pontos de casa, trabalho e passeio dos NPCs. Use zoom, arraste a visão, desfaça/refaça e clique em **Testar mapa** para jogar.

**Salvar** guarda o rascunho. **Exportar / Importar** permite compartilhar mapas em JSON. Cada mundo mantém sua aventura separada; você pode voltar ao continente original e recuperar seu progresso.

[Guia do editor](docs/editor-de-mapas.md) · [Mapa de exemplo para importar](docs/mapa-exemplo.json)

![Editor de mapas](docs/editor-mapa.png)

![Aparências dos NPCs](docs/editor-npcs.png)

Os NPCs agora misturam **nove bases visuais diferentes**, incluindo os oito personagens de `abc.zip`. As construções usam **seis paletas**, telhados e detalhes variados. Novos shaders trabalham a água, os materiais das casas e as cores do cenário; os efeitos podem ser desligados no menu de pausa.

## O novo mundo

- **16.000 × 12.800 unidades**, 250 × 200 tiles: cinco vezes maior em cada eixo e **25 vezes a área** do mapa anterior.
- Dois reinos com capitais maiores: **Aurélia e Valverde**.
- Quatro vilarejos: **Pedra Alta, Ponte Velha, Porto Claro e Cedro**.
- **135 construções** nas capitais e povoados, com ruas, ferrarias, estalagens, castelos e fazendas.
- **44 NPCs**, com trabalho, comércio, encontros e descanso em horários próprios.
- Planícies, campos, pedreiras do norte, costa, rio com quatro pontes e pequenos bosques regionais.

A proposta principal passou a ser criar sua vida entre os reinos. As antigas sementes permanecem como uma atividade opcional do vale noroeste.

![Mapa do continente](docs/rpg-mapa.png)

## Ferramentas, comércio e experiência

Comece com 100 moedas e duas provisões. As ferrarias vendem machado (25), picareta (30), martelo (15), espada (35) e provisões (5).

Use **E** perto de árvores ou rochas: o machado entrega cinco unidades de madeira; a picareta entrega quatro de pedra. Cada recurso só pode ser recolhido uma vez, desaparece da cena e libera sua colisão. O estado persiste ao sair e retornar à região.

Venda materiais ou entregue encomendas de 15 madeira e oito pedra por 80 moedas e 40 XP, uma vez por dia em cada povoado. Explorar, recolher, construir e caçar dão experiência; o nível também aumenta o dano em combate.

![Loja](docs/rpg-loja.png)

## Sua casa

Pressione **B** para mostrar a prévia do terreno. A cor indica se o local está livre. Clique para reservar por 20 moedas; botão direito ou Esc cancela. A obra deve ficar perto do jogador e fora de ruas, rios, pedras, árvores, outras casas e terrenos reservados aos moradores.

Vá até a obra e use **E**, levando um martelo:

| Etapa | Madeira | Pedra |
| --- | ---: | ---: |
| Fundação | 15 | 10 |
| Paredes | 20 | 5 |
| Telhado | 15 | 5 |
| **Total** | **50** | **20** |

Cada etapa muda o modelo 3D e sua colisão. A casa pronta permite descansar e serve como ponto de retorno se o personagem for socorrido após perder a vida. Construção e descanso exigem estar junto ao terreno.

![Casa construída](docs/rpg-casa.png)

## Moradores que também compram e constroem

Cada NPC tem carteira e equipamento próprios. Moradores recebem salário e alguns compram a ferramenta de sua profissão quando visitam o comércio. Quatro construtores dos vilarejos têm um objetivo adicional:

1. Ir à ferraria e pagar por machado, picareta e martelo.
2. Reservar seu terreno com as próprias moedas.
3. Viajar até arvoredo e pedreira, recolher materiais e esgotar os mesmos recursos que o jogador pode usar.
4. Voltar à obra e pagar os custos de fundação, paredes e telhado.
5. Passar a usar a casa concluída em sua rotina de descanso.

Se o arvoredo ou a pedreira se esgotarem, o morador pode comprar material na loja. Converse e escolha **“Suas compras e sua casa”** para ver o dinheiro, as ferramentas, o objetivo e a etapa da construção. Os objetivos continuam sendo simulados longe da câmera; NPCs próximos usam a física e as animações de caminhada.

![Casa de um NPC](docs/rpg-casa-npc.png)

## Animais, combate e rio

Vacas e galinhas vivem nas fazendas e fornecem provisões ao ajudar com **E**. A produção tem intervalo persistente, inclusive ao trocar de região ou carregar o save. Cervos, coelhos e javalis aparecem nos campos; animais tímidos fogem e javalis podem perseguir e atacar.

**Espaço ou clique esquerdo** ataca animais próximos. A espada aumenta o dano. Caça entrega carne para venda e experiência. Provisões restauram vida; estalagens e sua casa oferecem descanso. Ao perder a vida, o personagem é socorrido, mantém o equipamento e perde cinco moedas.

É possível nadar de uma margem à outra e passar sob as pontes. Quem caminha usa rampas e corrimãos com colisão. Os moradores continuam seguindo rotas terrestres.

![Fazenda](docs/rpg-animais.png)

## Controles

| Tecla | Ação |
| --- | --- |
| WASD / setas | Mover e nadar |
| Shift | Correr / acelerar na água |
| E | Conversar, negociar, coletar e interagir |
| Espaço / clique esquerdo | Atacar |
| I | Inventário e provisões |
| J | Objetivos e registros |
| B | Escolher terreno / consultar sua obra |
| M | Mapa do continente |
| F2 | Criar / editar seu mapa |
| Esc | Cancelar prévia, fechar menu ou pausar |

Nas estalagens, caravanas de cinco moedas ligam os seis povoados. O mapa mostra cidades, posição do jogador e seu lar.

## Desempenho e salvamento

O mundo mantém **no máximo 25 regiões próximas de 512 × 512**. Terreno, árvores, rochas e animais são criados e liberados conforme o jogador se move. Cada terreno é desenhado uma vez para uma textura local; não há uma textura gigante do continente inteiro.

Árvores e rochas usam `MultiMesh`; animais usam uma instância de partes geométricas por modelo. O vento atua nos vértices, sombras de árvores ficam no terreno e personagens distantes deixam de executar física a cada quadro. A navegação considera cidades, rio, pontes e recursos das regiões ativas.

O modo **leve** usa 80% da resolução por eixo no cenário 3D; a interface fica na resolução integral. Em **Esc → Gráficos**, alterne para **nítido**. Em **Esc → Shaders**, ligue ou desligue os efeitos adicionais. As preferências são salvas.

O save versão 2 preserva posição, saúde, inventário, ferramentas, dinheiro, XP, exploração, recursos esgotados, casas, contas e equipamentos dos NPCs, produção das fazendas, encomendas e relógio. Saves antigos migram para a entrada de Aurélia e preservam aparência e a atividade antiga. O diretório de usuário `EntreFolhas` foi mantido para localizar esses dados.

Os PNGs originais de `tomate.zip` continuam intactos; os hashes estão em [assets/tomate/sources.json](assets/tomate/sources.json). Animais e etapas de obra usam geometria procedural do projeto.

## Abrir e validar

Abra `project.godot` no **Godot 4.6.3 ou superior** e pressione F5. Neste ambiente:

```sh
./scripts/godot.sh --editor
./scripts/godot.sh --headless --audio-driver Dummy --script res://tests/run.gd -- --test
./scripts/godot.sh --audio-driver Dummy --script res://tests/hybrid_tests.gd -- --test --hybrid
./scripts/godot.sh --headless --audio-driver Dummy --script res://tests/editor_tests.gd -- --test
./scripts/godot.sh --audio-driver Dummy --script res://tests/editor_tests.gd -- --test --hybrid
```

A primeira suíte valida mundo, imagens, economia, construção, viagens, NPCs, combate e save. A segunda valida compras pela interface, prévia e modelos das obras, liberação de regiões, animais, mapa e natação em uma sessão gráfica. Os testes do protótipo anterior permanecem como referência histórica; as suítes acima representam o RPG atual.

Os resultados e a cobertura dos testes estão em [docs/rpg-desempenho.md](docs/rpg-desempenho.md). A suíte do editor também valida entradas por mouse e atalhos, histórico, importação/exportação, rotinas, água, pontes, lojas e retorno ao save anterior.

Para medir uma versão já aquecida, sem outros processos Godot concorrentes:

```sh
./scripts/godot.sh --audio-driver Dummy --disable-vsync --script res://tests/performance_benchmark.gd -- --test --hybrid /tmp/rpg-performance.json
```

## Exportar

Com os templates oficiais da mesma versão do Godot instalados:

```sh
mkdir -p build/linux build/windows
./scripts/godot.sh --headless --audio-driver Dummy --export-release Linux build/linux/EntreReinos.x86_64
./scripts/godot.sh --headless --audio-driver Dummy --export-release Windows build/windows/EntreReinos.exe
python3 scripts/package_releases.py --output /workspace/shared/downloads
```

O Linux é executado neste ambiente. O Windows é exportado e o pacote verificado; não há Windows nativo disponível para teste aqui.
