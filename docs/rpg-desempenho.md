# Medição do RPG de mundo aberto

Godot 4.6.3 / Compatibility, Mesa llvmpipe (LLVM 19.1.7), renderização por CPU. Tela de 1280 × 800; modo leve com cenário a 80% por eixo e interface em resolução integral. Os números representam esta máquina, não uma promessa de FPS para todo computador.

Mundo com 16.000 × 12.800 unidades, 135 construções e 44 NPCs. No máximo 25 regiões permanecem carregadas. O teste carrega a região de cada ponto antes do aquecimento, congela simulação e economia, desliga V-Sync, aquece dez quadros e registra 45 quadros por posição. Nenhum outro processo Godot concorria durante a coleta. Água e materiais usam os novos shaders; a correção de cor em tela cheia fica reservada ao modo nítido.

| Local | FPS mediano | Quadro mediano | P95 | Chamadas visíveis |
| --- | ---: | ---: | ---: | ---: |
| Capital | 31.7 | 31.5 ms | 44.2 ms | 60 |
| Ferraria | 32.4 | 30.9 ms | 39.4 ms | 61 |
| Ponte | 33.2 | 30.1 ms | 33.7 ms | 71 |

[Dados completos](rpg-desempenho.json). O monitor `cpu_ms` vem de `Performance.TIME_PROCESS` e inclui espera do driver, portanto não deve ser interpretado como custo puro de CPU. As chamadas vêm do viewport principal.

Para reproduzir:

```sh
./scripts/godot.sh --audio-driver Dummy --disable-vsync --script res://tests/performance_benchmark.gd -- --test --hybrid /tmp/rpg-performance.json
```

## Validação funcional

- 239 verificações de mundo, sprites originais, NPCs, compras, coleta, venda, encomendas, construção, colisão da obra, viagens, simulação de um construtor, combate e salvamento/migração.
- 46 verificações independentes de cabeça e pés nas caminhadas e corridas dos 44 moradores, incluindo a regressão de Caio nos PNGs reais.
- 24 verificações gráficas do RPG: câmera, resolução, compras por botões reais, prévia, três etapas da casa, casa de NPC, viagens, animais, mapa e rio.
- 40 verificações funcionais e 48 gráficas do editor validam pincéis, histórico, arquivos JSON, importação inválida, criação de mundo, rotinas, lojas, pontes, lagos e retorno à aventura anterior. A versão gráfica usa mouse e atalhos reais e testa os dois modos de qualidade.

No executável Linux exportado, um teste com teclado e mouse reais abriu F2, renomeou e salvou um rascunho, ativou o mapa, reabriu o ateliê e confirmou que a jornada original permaneceu no disco. O processo encerrou com código 0. O Windows é exportado e verificado, sem Windows nativo disponível aqui.

As cinco suítes passaram: **397 verificações**.
