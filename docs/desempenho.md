# Desempenho e física da atualização

Medição no Godot 4.6.3 / Compatibility, em uma tela de 1280 × 800, usando **Mesa llvmpipe (renderização por CPU)**. São resultados deste ambiente; o FPS no computador do jogador depende do hardware.

Comparação com o código publicado em `75a9314`. O mesmo executável do Godot, cache gráfico aquecido, V-Sync desligado e três posições fixas foram usados, sem outros processos Godot concorrendo durante a coleta. O relógio e os NPCs ficaram parados para repetir a cena. Cada posição teve 10 quadros de aquecimento e 45 amostras.

A versão anterior renderizava o cenário em resolução integral. A atualização usa o modo leve padrão: 80% por eixo no cenário 3D, com interface em resolução integral. Também agrupa árvores por espécie e região, reúne a ponte, usa recorte das copas em uma passagem, move o vento nos vértices, grava sombras no chão uma vez e evita sincronizar centenas de árvores pela CPU.

| Cena | FPS antes | FPS depois | Tempo mediano antes → depois | Chamadas visíveis antes → depois |
| --- | ---: | ---: | --- | --- |
| Bosque | 4.3 | 16.7 | 230.5 → 59.9 ms | 1816 → 85 |
| Vila | 4.6 | 16.0 | 215.3 → 62.5 ms | 1397 → 98 |
| Ponte | 5.0 | 17.2 | 201.2 → 58.1 ms | 1681 → 89 |

Os tempos P95 e os demais contadores estão nos arquivos [antes](desempenho-antes.json) e [depois](desempenho-depois.json). As chamadas usam `Viewport.get_render_info(TYPE_VISIBLE, DRAW_CALLS_IN_FRAME)` do viewport principal; o contador global inclui dados de viewports auxiliares e não foi usado na tabela. O diagnóstico registra também o monitor de tempo do Godot, que não deve ser interpretado como tempo puro de CPU.

## Repetir a medição

Com uma sessão gráfica ativa:

```sh
./scripts/godot.sh --audio-driver Dummy --disable-vsync --script res://tests/performance_benchmark.gd -- --test --hybrid /tmp/desempenho.json
```

No jogo, **Esc → Gráficos** alterna entre leve e nítido. A preferência é salva; a alteração preserva o tamanho e a nitidez da interface.

## Validação funcional

- 189 verificações da suíte principal: NPCs, rotas, missões, salvamento, controles e interface.
- 31 verificações de física: paredes das 13 casas, deslizamento nos cantos, alinhamento da ponte, corrimãos, rampas, entrada e saída da água, passagem sob a ponte, pausa e salvamento na água.
- 24 verificações gráficas: agrupamento das árvores, pivôs, câmera, modos de resolução, pés sobre o tablado, submersão e ondulação.

Todas passaram. As capturas atuais mostram o [bosque](hibrido-bosque.png), a [vila](hibrido-vila.png), a [ponte](hibrido-ponte.png) e a [natação](natacao.png). Linux foi executado neste ambiente. O pacote Windows foi exportado; não há um Windows nativo disponível para teste.
