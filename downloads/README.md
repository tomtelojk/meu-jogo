# Baixar Entre Folhas

Jogo para PC de 64 bits, sem precisar instalar o Godot.

Atualização: oito NPCs com os sprites originais de `abc.zip`, árvores e arbustos com balanço mais lento e suave e ruas corrigidas em curvas, pontas e cruzamentos.


- [Windows — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Windows.zip)
- [Linux — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Linux.zip)

Extraia o ZIP inteiro. No Windows, abra `EntreFolhas.exe`. No Linux, abra `Jogar.sh`.

O jogo inclui oito NPCs com suas pranchas originais, diálogos, Aurélia e Valverde, rotinas diferentes, ciclo de dia e noite e salvamento. Cada NPC continua aceitando uma prancha personalizada pelo diálogo. Os arquivos recebidos foram preservados sem alterações; nomes de origem e hashes SHA-256 estão em [assets/npcs/sources.json](../assets/npcs/sources.json) e no arquivo `FONTES-SPRITES.json` de cada pacote.

154 verificações do projeto passaram, incluindo os oito sprites originais e regressões para o vento e as ruas. As texturas também passaram em dois testes gráficos. O executável Linux foi executado e inspecionado. O Windows foi exportado, sem teste em um Windows nativo.

Os hashes para conferir os ZIPs estão em `EntreFolhas-SHA256.txt`. Os arquivos seguem a visibilidade e as permissões deste repositório.
