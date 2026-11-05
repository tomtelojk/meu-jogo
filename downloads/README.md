# Baixar Entre Folhas

Jogo para PC de 64 bits, sem precisar instalar o Godot.

Atualização: caminhada dos oito NPCs corrigida, árvores substituídas pelo novo atlas medieval com balanço lento e ruas corrigidas em curvas, pontas e cruzamentos.


- [Windows — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Windows.zip)
- [Linux — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Linux.zip)

Extraia o ZIP inteiro. No Windows, abra `EntreFolhas.exe`. No Linux, abra `Jogar.sh`.

O jogo inclui oito NPCs com suas pranchas originais, diálogos, Aurélia e Valverde, rotinas diferentes, ciclo de dia e noite e salvamento. Cada NPC continua aceitando uma prancha personalizada pelo diálogo. Os arquivos recebidos foram preservados sem alterações; nomes de origem e hashes SHA-256 estão em [assets/npcs/sources.json](../assets/npcs/sources.json) e no arquivo `FONTES-SPRITES.json` de cada pacote.

193 verificações do projeto passaram, incluindo alinhamento da caminhada e corrida, viradas, bloqueios por colisão e o novo atlas de árvores. Os 128 quadros de caminhada dos oito NPCs também foram conferidos visualmente. O executável Linux foi executado e inspecionado. O Windows foi exportado, sem teste em um Windows nativo.

Os hashes para conferir os ZIPs estão em `EntreFolhas-SHA256.txt`. Os arquivos seguem a visibilidade e as permissões deste repositório.
