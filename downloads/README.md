# Baixar Entre Reinos

RPG de mundo aberto 2.5D para PC de 64 bits. Não é necessário instalar o Godot.

**Estradas e casas:** a nova geração coloca as ruas antes dos lotes e verifica margens de estrada, água, rochas e outras construções. Para mundos existentes, use **B → Validar estradas e terrenos → Realocar casas em conflito**. Há backup, relatório e opção de desfazer; conflitos sem espaço seguro continuam listados. F2 também valida e corrige. O ZIP inclui `GUIA-DO-POSICIONAMENTO.md`. [Guia](../docs/estradas-e-posicionamento.md).

**Casas modulares:** cinco kits, portas com interiores mobiliados, varandas, beirais, degraus, janelas iluminadas à noite e chaminés com fumaça lenta. Use **B → Casas completas**, **T** para girar e **V** para variar. F2 também permite colocar e variar os kits. O ZIP inclui `GUIA-DAS-CASAS.md`. [Ver casas e controles](../docs/casas-modulares.md).

**Construção com grid de 1 m:** pivôs no canto, paredes nas bordas, junções sem frestas, pisos e coberturas com medidas exatas e linhas-guia na prévia. **B → Validar grid e modelos** aponta desalinhamentos e exporta JSON. O ZIP inclui o guia e a lista dos modelos fora do padrão modular. Saves antigos com peças ganham cópia antes da migração. [Guia do grid](../docs/construcao-grid.md).

Esta versão inclui **facções e três guildas**: reputação com consequências, ranks, contratos, uniformes, lojas e QGs. Os quatro postos mudam de administração com suas ações. Guardas, moradores e preços reagem; as cartas das Coroas têm três caminhos de história. Use **J → Facções, guildas e territórios**, ou **E nas bandeiras**. [Guia completo](../docs/faccoes-e-guildas.md).

- [Windows — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreReinos-Windows.zip)
- [Linux — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreReinos-Linux.zip)

Extraia o ZIP inteiro. No Windows, abra **EntreReinos.exe**. No Linux, abra **Jogar.sh**; se necessário, dê permissão de execução aos dois arquivos.

O mapa tem **25 vezes a área anterior**, dois reinos maiores, quatro vilarejos, 131 construções na nova geração, 44 NPCs e animais. Ruas curvas, bairros irregulares, bosques em grupos e um rio de largura variável tornam o continente menos repetitivo. Compre ferramentas, recolha materiais, negocie, suba de nível e construa sua casa. Mundos anteriores preservam seus lotes até a correção explícita.

**F2 abre o Ateliê de Mundos**, incluído no jogo. Comece com um mapa vazio ou edite os reinos: pinte terreno e água, coloque casas, pontes, árvores, animais e NPCs e marque suas rotinas. Salve, exporte ou importe mapas em JSON e use **Testar mapa** para jogar. O ZIP inclui um mapa de exemplo e o guia do editor.

Os moradores usam nove bases visuais, com os sprites originais de NPCs enviados pelo autor. As casas combinam cinco kits com cores, tamanhos e giros controlados por semente. Shaders melhoram água, materiais e cor; podem ser desligados no menu de pausa.

Os NPCs têm turnos de trabalho, comércio, refeições, patrulhas, encontros e descanso. Evitam aglomerações, procuram desvios e fogem de javalis. Quatro moradores também compram equipamento e constroem casas. A iluminação acompanha o dia, com neblina de distância, postes e lanterna à noite. O título e toda a interface seguem o estilo de RPG em pixel art.

**Coleta por golpes:** recursos têm vida, ferramenta mínima e drops próprios. Árvores tremem, caem e deixam tocos; materiais saltam para o chão e são recolhidos por atração ao se aproximar. Há partículas, fragmentos, som e números de dano. Ferramentas evoluem de madeira para pedra e ferro; habilidades de lenhador/mineiro melhoram dano e gasto de energia. Árvores regeneram em três dias e rochas/minérios em cinco a sete. O editor também permite colocar os depósitos. [Guia da coleta](../docs/coleta-e-ferramentas.md).

**Visual HD-2D:** sprites preservam suas proporções ao acompanhar a câmera, sombras se projetam no chão, grama reage ao jogador e água reflete a cena. Há chuva, neblina, vento e iluminação de dia/noite, com tochas e janelas acesas. Ative **Esc → Gráficos: HD-2D** para blur, bloom e sombras do sol; o modo leve continua disponível. **Q/R** ou botão do meio gira; **Ctrl+roda / PgUp / PgDn** dá zoom; **Home** centraliza. [Guia do visual](../docs/visual-hd2d.md).

[Guia do editor](../docs/editor-de-mapas.md) · [Ver o ateliê](../docs/editor-mapa.png) · [Mapa de exemplo](../docs/mapa-exemplo.json)

**Construção modular:** B abre paredes, chão, móveis e estações, com custos, grade e fantasma verde/vermelho. T gira a peça. E em bancadas e forjas abre receitas, fila, reparos e designação de trabalhadores. Camas permitem morar, descansar e salvar um ponto de retorno. NPCs seguem seus turnos e aceleram a estação; vida, portas, designações e filas são salvas por mapa. [Guia da construção](../docs/construcao-e-fabricacao.md).

**NPCs e relacionamentos:** E abre escolhas, presentes e memórias de cada morador. Afinidade de -100 a 100, classe e facção influenciam diálogos e consequências. Há missões pessoais, cenas de amizade, rivalidade, romance, casamento e um companheiro que segue rotas navegáveis. O cônjuge pode morar nas construções do jogador. J acompanha vínculos e compromissos; tudo fica salvo por mapa. [Guia dos relacionamentos](../docs/npcs-e-relacionamentos.md).

**E** interage, **I** abre inventário e **B** abre o catálogo. A hotbar usa **1–4** para ferramentas, **5** para comer, **6** para mapa, **7** para diário e **8** para lanterna. A roda do mouse seleciona e o clique esquerdo usa o item. **Espaço** ataca. Nas estalagens, use caravanas para visitar outros povoados. O modo gráfico leve é o padrão.

[Ver o início](../docs/rpg-inicio.png) · [Ver a interface](../docs/rpg-hud.png) · [Ver iluminação e neblina](../docs/rpg-noite.png)

[Ver Aurélia](../docs/rpg-aurelia.png) · [Ver animais](../docs/rpg-animais.png) · [Ver construção](../docs/rpg-casa.png) · [Ver mapa](../docs/rpg-mapa.png) · [Ver casa de um NPC](../docs/rpg-casa-npc.png)

Inventário, moedas, exploração, recursos, construções e progresso dos moradores são salvos automaticamente. As antigas sementes viraram uma atividade opcional. Os saves anteriores migram para a nova entrada de Aurélia.

Os hashes estão em **EntreReinos-SHA256.txt**. Linux foi testado neste ambiente; Windows foi exportado, sem teste nativo em Windows. Os downloads seguem a visibilidade e as permissões deste repositório.
