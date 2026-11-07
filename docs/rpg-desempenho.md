# Medição do RPG de mundo aberto

Godot 4.6.3 / Compatibility, Mesa llvmpipe (LLVM 19.1.7), renderização por CPU. Tela de 1280 × 800; modo leve com cenário a 65% por eixo e interface em resolução integral. Os números representam esta máquina, não uma promessa de FPS para todo computador.

Mundo com 16.000 × 12.800 unidades, 126 construções e 44 NPCs. No máximo 25 regiões permanecem carregadas. O teste carrega a região de cada ponto antes do aquecimento, congela simulação e economia, desliga V-Sync, aquece 25 quadros e registra 45 quadros por posição. Nenhum outro processo Godot concorria durante a coleta. Luz do dia, chuva automática, neblina, grama reativa e sombras de silhueta estão ativas. A ponte também ativa a captura planar da água. Água e materiais usam os novos shaders; blur, bloom e sombras do sol ficam reservados ao modo HD-2D.

| Local | FPS mediano | Quadro mediano | P95 | Chamadas visíveis |
| --- | ---: | ---: | ---: | ---: |
| Capital | 35.5 | 28.2 ms | 48.0 ms | 79 |
| Ferraria | 35.1 | 28.5 ms | 35.2 ms | 81 |
| Ponte | 32.4 | 30.9 ms | 37.4 ms | 86 |

[Dados completos](rpg-desempenho.json). O monitor `cpu_ms` vem de `Performance.TIME_PROCESS` e inclui espera do driver, portanto não deve ser interpretado como custo puro de CPU. As chamadas vêm do viewport principal.

Para reproduzir:

```sh
./scripts/godot.sh --audio-driver Dummy --disable-vsync --script res://tests/performance_benchmark.gd -- --test --hybrid /tmp/rpg-performance.json
```

## Validação funcional

- 240 verificações de mundo, sprites originais, NPCs, compras, coleta, venda, encomendas, construção, colisão da obra, viagens, simulação de um construtor, combate e salvamento/migração.
- 46 verificações independentes de cabeça e pés nas caminhadas e corridas dos 44 moradores, incluindo a regressão de Caio nos PNGs reais.
- 24 verificações gráficas do RPG: câmera, resolução, compras por botões reais, prévia, três etapas da casa, casa de NPC, viagens, animais, mapa e rio.
- 40 verificações funcionais e 48 gráficas do editor validam pincéis, histórico, arquivos JSON, importação inválida, criação de mundo, rotinas, lojas, pontes, lagos e retorno à aventura anterior. A versão gráfica usa mouse e atalhos reais e testa os dois modos de qualidade.

No executável Linux final, teclado e mouse iniciaram a aventura, giraram e aproximaram a câmera, ligaram a lanterna e gravaram as preferências visuais no save. O processo renderizou e encerrou com código 0. Os testes de teclado, mouse, mapas e persistência são executados nas suítes gráficas acima. O Windows é exportado e seu pacote verificado, sem Windows nativo disponível aqui.

A versão com construção também foi executada como Linux nativo: B abriu o catálogo JSON embutido, Enter escolheu uma parede, T girou e um clique construiu. O save gravou a peça com vida completa e descontou exatamente cinco madeiras. Uma segunda execução carregou a mesma peça, orientação, vida e inventário. Ambos os processos encerraram com código 0, sem erros de script ou shader, usando um perfil de teste separado.

Na versão com relacionamentos, o executável Linux foi controlado por E, Enter e Tab em um perfil separado. Um presente amado consumiu uma provisão, creditou o NPC e elevou a afinidade a 12; uma resposta acolhedora elevou a 15 e registrou uma lembrança. Outra execução preservou afinidade, preferência e memórias sem repetir recompensa. As duas execuções terminaram com código 0, sem erros de script ou shader. Os JSONs de relações e receitas estão embutidos nos executáveis.

A validação de rotinas e interface acrescenta 22 verificações sem renderização e 26 gráficas: geração reproduzível, bairros irregulares, patrulhas com física real, trabalho, descanso, fuga, refeições, comércio, recuperação de rotas, atalhos da hotbar, save, luz e neblina. Os novos registros também incluem capturas de dia, de noite e do menu.

A coleta acrescenta 32 verificações sem renderização e 34 gráficas: vida parcial, tiers e custos, energia, habilidades, minério, drops pendentes no save, clique com a ferramenta equipada, som, queda, partículas, atração, prevenção de duplicação, troca de região e regeneração segura.

O visual HD-2D acrescenta 33 verificações: entradas reais de câmera e hotbar, limites, movimento orientado pela tela, save, projeção de construção, proporções dos billboards, sombra desenhada, grama deformada, oclusão por telhados, clima, luzes noturnas e geometria na reflexão. Testes de pixels independentes medem redução de contraste pelo blur e halo pelo bloom, preservando a faixa de foco.

A construção modular acrescenta **76 verificações sem renderização e 83 gráficas**: custos, camadas e rotação, sobreposição e bloqueios, fantasma verde/vermelho, cliques no catálogo e nas receitas, fila paralela e sequencial, cancelamento e prevenção de duplicação, ferramentas de ferro, reparos, destruição por javali, portas com física e navegação, trabalho e descanso dos moradores, refeições, retorno pela cama, gravação em disco, migração e isolamento dos mapas. Pisos apoiam personagens e sombras também no modo HD-2D. Modelos são liberados e recriados ao mudar de região.

Os relacionamentos acrescentam **158 verificações sem renderização e 161 gráficas**: perfis e gostos dos 44 NPCs, afinidade limitada, quatro reações a presentes, custos e limites diários, condições de classe e facção inclusive em respostas internas, consequências, memória de roubo e reparação, carteiras reais, missões pessoais e progresso de combate, prevenção de recompensas repetidas, cenas com retratos/câmera e retomada de página, romance adulto, exclusividade do vínculo, aliança fabricada, casamento e cama compartilhada. Companhia percorre rotas, usa física e animação, aguarda na margem e pode ser dispensada sem teletransporte. Save em disco, isolamento dos mapas e refeições pagas uma vez por turno também são verificados.

A cobertura atual soma **1.023 verificações**, incluindo as execuções sem renderização e gráficas. Todas passaram. As medições de desempenho acima foram registradas na etapa de construção, com somente um processo Godot e sem exportação ou empacotamento concorrentes. Os números medem as três posições do mundo original; o custo de um assentamento depende da quantidade e da disposição das peças.
