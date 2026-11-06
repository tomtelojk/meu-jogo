# Medição do RPG de mundo aberto

Godot 4.6.3 / Compatibility, Mesa llvmpipe (LLVM 19.1.7), renderização por CPU. Tela de 1280 × 800; modo leve com cenário a 80% por eixo e interface em resolução integral. Os números representam esta máquina, não uma promessa de FPS para todo computador.

Mundo com 16.000 × 12.800 unidades, 135 construções e 44 NPCs. No máximo 25 regiões permanecem carregadas. O teste carrega a região de cada ponto antes do aquecimento, congela simulação e economia, desliga V-Sync, aquece dez quadros e registra 45 quadros por posição. Nenhum outro processo Godot concorria durante a coleta.

| Local | FPS mediano | Quadro mediano | P95 | Chamadas visíveis |
| --- | ---: | ---: | ---: | ---: |
| Capital | 30.2 | 33.1 ms | 50.7 ms | 78 |
| Ferraria | 29.7 | 33.7 ms | 55.0 ms | 80 |
| Ponte | 29.8 | 33.5 ms | 41.1 ms | 73 |

[Dados completos](rpg-desempenho.json). O monitor `cpu_ms` vem de `Performance.TIME_PROCESS` e inclui espera do driver, portanto não deve ser interpretado como custo puro de CPU. As chamadas vêm do viewport principal.

Para reproduzir:

```sh
./scripts/godot.sh --audio-driver Dummy --disable-vsync --script res://tests/performance_benchmark.gd -- --test --hybrid /tmp/rpg-performance.json
```

## Validação funcional

- 238 verificações de mundo, sprites originais, NPCs, compras, coleta, venda, encomendas, construção, colisão da obra, viagens, liberação de regiões, simulação de um construtor, combate e salvamento/migração.
- 24 verificações gráficas de câmera, resolução, compras por botões reais, prévia e três etapas da casa, casa de NPC, viagens, animais, mapa e rio.

As duas suítes passaram. O executável Linux final foi executado com sucesso; Windows é exportado e verificado, sem Windows nativo disponível neste ambiente.
