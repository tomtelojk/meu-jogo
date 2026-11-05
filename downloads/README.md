# Baixar Entre Folhas

Jogo para PC de 64 bits, sem precisar instalar o Godot.

Atualização: passos dos NPCs sincronizados com o deslocamento real e vento contínuo na copa das árvores, com a base dos troncos firme.

[Ver a prévia animada](../docs/movimento.gif)


- [Windows — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Windows.zip)
- [Linux — baixar ZIP](https://github.com/tomtelojk/meu-jogo/raw/refs/heads/main/downloads/EntreFolhas-Linux.zip)

Extraia o ZIP inteiro. No Windows, abra `EntreFolhas.exe`. No Linux, abra `Jogar.sh`.

O jogo inclui oito NPCs com suas pranchas originais, diálogos, Aurélia e Valverde, rotinas diferentes, ciclo de dia e noite e salvamento. Cada NPC continua aceitando uma prancha personalizada pelo diálogo. Os arquivos recebidos foram preservados sem alterações; nomes de origem e hashes SHA-256 estão em [assets/npcs/sources.json](../assets/npcs/sources.json) e no arquivo `FONTES-SPRITES.json` de cada pacote.

As verificações cobrem alinhamento dos passos, cadência em velocidades diferentes, viradas, colisões, raízes imóveis, vento contínuo, iluminação e transparência. A prévia temporal mostra o controlador de passos dos oito NPCs e o vento usado no jogo. O executável Linux foi executado e inspecionado. O Windows foi exportado, sem teste em um Windows nativo.

Os hashes para conferir os ZIPs estão em `EntreFolhas-SHA256.txt`. Os arquivos seguem a visibilidade e as permissões deste repositório.
