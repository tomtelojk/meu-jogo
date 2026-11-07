# Modelos fora do padrão modular

A medição atual encontrou **zero modelos fora do padrão entre os 12 módulos de construção**. As raízes usam canto no chão, escala 1 e medidas compatíveis com o grid de 1 m. A auditoria mede os meshes gerados em Godot; não há modelos GLB/GLTF importados neste projeto.

Os prédios completos abaixo são **prefabs de cenário**, gerados por `game/building_visual.gd`. Não devem ser usados como segmentos intercambiáveis de parede, chão ou cobertura. O terreno de oito tipos tem dimensões fracionárias; todos têm beirais, degraus ou outros detalhes que excedem o terreno.

| Asset | Terreno nominal (largura × profundidade) | Mesh real no estilo 0 (largura × profundidade) |
| --- | ---: | ---: |
| `cottage` | 2,75 × 2 m | 3,17 × 2,57 m |
| `timber` | 3 × 2,25 m | 3,42 × 2,82 m |
| `stone_house` | 2,75 × 2 m | 3,17 × 2,57 m |
| `tavern` | 3,5 × 2,5 m | 3,92 × 3,33 m |
| `forge` | 3,5 × 2,5 m | 3,92 × 3,33 m |
| `tower` | 2 × 2 m | 2,28 × 2,5 m |
| `castle` | 7 × 4,5 m | 7,28 × 5 m |
| `library` | 2,75 × 2 m | 3,17 × 2,57 m |
| `barracks` | 2,75 × 2 m | 3,17 × 2,57 m |

As alturas e alguns detalhes variam com estilo e nome do prédio; a tabela mede um exemplar reproduzível com estilo 0. Os prédios da base também têm tamanhos próprios gerados por `SettlementLayout`, listados individualmente no JSON. Na base original, **124 dos 126 terrenos de prédios têm ao menos uma dimensão fracionária em metros**. Esses lotes preservam o desenho irregular das cidades. A refatoração padroniza seus pivôs de renderização sem mover as cidades.

**`forge` acima é o prédio completo da ferraria.** A estação de forja do catálogo modular é outro modelo, definido em `game/construction_visual.gd`, ocupa 2 × 1 células e passou na validação.

## Divergências medidas e corrigidas no catálogo

| Módulo | Medição anterior | Correção |
| --- | --- | --- |
| `wood_wall` | Mesh com 1,69 m de altura contra 1,65 declarados; espessura de 0,22 m contra 0,1875 física | Parede de 2 m × 0,25 m, com painel e junção comuns |
| `stone_wall` | Altura de 1,75 m, diferente da família de madeira/porta | Altura comum de 2 m |
| `door` | Mesh com 1,71 m de altura e 0,23 m de espessura, diferentes do catálogo e colisor | Moldura de 2 m × 0,25 m; pivô e junções nas bordas |
| `roof` | 1,04 × 1,04 m por célula de 1 × 1 m | 1 × 1 m; base em 2 m, sem beiral modular sobreposto |
| `wood_floor` | Extensão de 0,994 m; tábuas com frestas de 0,006 m | Superfície contínua de 1 × 1 m |
| `table` | 0,83 m de altura contra 0,8 declarados | Altura declarada corrigida; largura ajustada à folga das paredes |
| `bench` | 0,455 m contra 0,45 declarados | Catálogo corrigido; geometria ajustada à célula |
| `workbench` | 0,945 m contra 0,9 declarados | Catálogo corrigido; geometria ajustada à célula |
| `torch` | 1,245 m contra 1,15 declarados | Catálogo corrigido, base no chão |
| `bed` e estação `forge` | Referência central e área girada deslocavam o pivô; folga das paredes não era explícita | Canto local, giro da área e geometria centralizada dentro da folga |

Piso de madeira e de pedra agora têm altura comum de 0,08 m. Móveis não precisam preencher o metro inteiro: sua **área de ocupação** é um número inteiro de células, e o mesh cabe dentro dela.

[Medição original](grid-audit-before.json) · [Relatório atual completo](grid-audit.json) · [Guia de encaixe e validação](construcao-grid.md)
