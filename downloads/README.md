# Baixar Entre Folhas

Jogo para PC de 64 bits, sem precisar instalar o Godot.

Atualização de desempenho e natação: floresta agrupada, sombras fixas e modo gráfico leve por padrão. Casas com deslizamento nas paredes; ponte com rampas e corrimãos sólidos. Agora você pode nadar no rio e passar sob a ponte.

Visual 2.5D: cenário, casas e ponte em 3D com personagens e árvores em sprites 2D. Câmera inclinada, sombras, copas ao vento e água em movimento. A arte de `tomate.zip` permanece nos personagens, árvores, solo, rio e fachadas.

[Ver a natação](../docs/natacao.png) · [Ver o cenário atual](../docs/hibrido-vila.png) · [Ver o bosque](../docs/hibrido-bosque.png)


- [Windows — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Windows.zip)
- [Linux — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Linux.zip)

WASD/setas também controlam a natação; Shift acelera. Em Esc → Gráficos, escolha leve ou nítido.

Extraia o ZIP inteiro. No Windows, abra `EntreFolhas.exe`. No Linux, abra `Jogar.sh`.

O jogo inclui oito NPCs, diálogos, Aurélia e Valverde, rotinas diferentes, ciclo de dia e noite e salvamento. As cinco folhas complementares do agricultor formam o novo personagem nas quatro direções, com roupas levemente diferentes entre moradores. Cada NPC continua aceitando uma prancha personalizada pelo diálogo. Os PNGs estão preservados sem alterações; nomes e hashes SHA-256 estão em [assets/tomate/sources.json](../assets/tomate/sources.json) e em `FONTES-SPRITES.json` de cada pacote.

As verificações cobrem alinhamento dos passos, cadência em velocidades diferentes, viradas, colisões, raízes imóveis, vento contínuo, iluminação e transparência. Os testes da apresentação 3D também verificam os pivôs dos sprites, a câmera, os controles, os diálogos e a coleta de sementes. O executável Linux foi executado e inspecionado. O Windows foi exportado, sem teste em um Windows nativo.

O roteiro e os resultados da medição de desempenho estão em [docs/desempenho.md](../docs/desempenho.md).

Os hashes para conferir os ZIPs estão em `EntreFolhas-SHA256.txt`. Os arquivos seguem a visibilidade e as permissões deste repositório.
