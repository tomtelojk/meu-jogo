# Modelos fora do padrão modular

A medição atual encontrou **zero modelos fora do padrão entre os 12 módulos de construção**. As raízes usam canto no chão, escala 1 e medidas compatíveis com o grid de 1 m. A auditoria mede os meshes gerados em Godot; não há modelos GLB/GLTF importados neste projeto.

Há também **cinco kits de casas em `game/data/houses/*.tres`**, montados por `game/house_mesh.gd`. Casas novas têm lotes inteiros no grid e uma superfície por casa; seus módulos e medidas aparecem no campo `house_kits` do relatório. Beirais e degraus têm extensão decorativa. [Ver os cinco kits e seus controles](casas-modulares.md).

Os lotes herdados abaixo mantêm as medidas antigas. Cabana, casa de madeira, casa de pedra, taverna, ferraria, biblioteca e alojamento agora usam os kits, com peças de borda recortadas ao lote. Castelos e torres conservam a geometria própria em `game/building_visual.gd`.

| Asset herdado | Terreno nominal (largura × profundidade) | Mesh medido (largura × profundidade) |
| --- | ---: | ---: |
| `cottage` | 2,75 × 2,00 m | 3,42 × 2,51 m |
| `timber` | 3,00 × 2,25 m | 3,67 × 2,76 m |
| `stone_house` | 2,75 × 2,00 m | 3,42 × 2,74 m |
| `tavern` | 3,50 × 2,50 m | 4,01 × 3,16 m |
| `forge` | 3,50 × 2,50 m | 4,01 × 3,16 m |
| `tower` | 2,00 × 2,00 m | 2,28 × 2,50 m |
| `castle` | 7,00 × 4,50 m | 7,28 × 5,00 m |
| `library` | 2,75 × 2,00 m | 3,49 × 2,67 m |
| `barracks` | 2,75 × 2,00 m | 3,26 × 2,66 m |

A tabela mede exemplares reproduzíveis com o nome do tipo, semente derivada do ID e estilo 0. Os campos `mesh_size_metres` e `source` do JSON registram as medidas e o gerador de cada exemplar. Na base herdada da geração 2, **124 dos 126 terrenos têm uma dimensão fracionária em metros**. Esses lotes continuam nos saves antigos. A geração 3 usa **131 lotes com dimensões inteiras**, assim como as casas novas do ateliê e do catálogo. Beirais, degraus, castelos e torres continuam sendo detalhes ou prédios completos, distintos das peças modulares de encaixe. [Estradas e realocação](estradas-e-posicionamento.md).

**`forge` aqui é o prédio completo da loja/oficina.** A estação de forja do catálogo avulso é outro modelo, ocupa 2 × 1 células e continua validada em `game/construction_visual.gd`.

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
