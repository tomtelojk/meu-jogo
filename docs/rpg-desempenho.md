# Medição do RPG de mundo aberto

Godot 4.6.3 / Compatibility, Mesa llvmpipe (LLVM 19.1.7), renderização por CPU. Tela de 1280 × 800; modo leve com cenário a 65% por eixo e interface em resolução integral. Os números representam esta máquina, não uma promessa de FPS para todo computador.

Mundo com 16.000 × 12.800 unidades, 126 construções e 44 NPCs. No máximo 25 regiões permanecem carregadas. O teste carrega a região de cada ponto antes do aquecimento, congela simulação e economia, desliga V-Sync, aquece 25 quadros e registra 45 quadros por posição. Nenhum outro processo Godot concorria durante a coleta. Luz do dia, chuva automática, neblina, grama reativa e sombras de silhueta estão ativas. A ponte também ativa a captura planar da água. Água e materiais usam os novos shaders; blur, bloom e sombras do sol ficam reservados ao modo HD-2D.

| Local | FPS mediano | Quadro mediano | P95 | Chamadas visíveis |
| --- | ---: | ---: | ---: | ---: |
| Capital | 32.2 | 31.0 ms | 52.3 ms | 79 |
| Ferraria | 33.1 | 30.2 ms | 34.8 ms | 81 |
| Ponte | 30.2 | 33.1 ms | 41.8 ms | 86 |

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

A validação de rotinas e interface acrescenta 22 verificações sem renderização e 26 gráficas: geração reproduzível, bairros irregulares, patrulhas com física real, trabalho, descanso, fuga, refeições, comércio, recuperação de rotas, atalhos da hotbar, save, luz e neblina. Os novos registros também incluem capturas de dia, de noite e do menu.

A coleta acrescenta 32 verificações sem renderização e 34 gráficas: vida parcial, tiers e custos, energia, habilidades, minério, drops pendentes no save, clique com a ferramenta equipada, som, queda, partículas, atração, prevenção de duplicação, troca de região e regeneração segura.

O visual HD-2D acrescenta 33 verificações: entradas reais de câmera e hotbar, limites, movimento orientado pela tela, save, projeção de construção, proporções dos billboards, sombra desenhada, grama deformada, oclusão por telhados, clima, luzes noturnas e geometria na reflexão. Testes de pixels independentes medem redução de contraste pelo blur e halo pelo bloom, preservando a faixa de foco.

A cobertura atual soma **545 verificações**, incluindo as execuções sem renderização e gráficas do editor, das rotinas e da coleta. As medições de desempenho usam somente um processo Godot.
