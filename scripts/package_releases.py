#!/usr/bin/env python3
"""Package the exported Linux and Windows players; standard library only."""
import argparse
import hashlib
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLS = """\nCOMO JOGAR\nEncontre as cinco sementes douradas e leve-as de volta à árvore-mãe.\n\nWASD ou setas: caminhar\nShift: correr\nE: recolher sementes, ler e plantar\nM: abrir e fechar o mapa\nEsc: pausar e voltar\n\nSeu progresso é salvo automaticamente neste computador.\nSom ambiente é opcional, no botão de música.\n"""
VILLAGERS = """
OS DOIS REINOS
Aurélia fica no oeste dourado; Valverde, a leste do riacho.
Converse com os oito moradores usando E. Cada um tem histórias, dicas e horários próprios.
Os NPCs trabalham, viajam, patrulham e voltam para casa ao longo do dia.
O relógio aparece na tela. Na barraca do acampamento, você pode descansar até a manhã seguinte.
Fale com os dois reis e restaure a árvore-mãe para renovar o Acordo das Raízes.

APARÊNCIAS DOS MORADORES
O protagonista e os oito NPCs usam as cinco folhas complementares de tomate.zip.
Para personalizar uma aparência, converse com o NPC e escolha
'Escolher sprite deste morador'. Isso não exige instalar o Godot.
As rotinas e os diálogos continuam funcionando com a prancha escolhida.

ATUALIZAÇÃO VISUAL 2.5D
Cenário, casas e ponte em 3D com personagens e árvores em sprites 2D.
A câmera inclinada acompanha o jogador, com sombras e água em movimento.
Personagens, quatro árvores, terrenos, água e três estilos de casas usam tomate.zip.
As árvores têm vento contínuo na copa e troncos firmes.
Os passos dos moradores acompanham sua velocidade e param quando eles param.
"""


def verify_player(path: Path, prefix: bytes) -> None:
    if not path.is_file() or path.stat().st_size < 1_000_000:
        raise RuntimeError(f"Executável ausente ou incompleto: {path}")
    with path.open("rb") as file:
        if not file.read(len(prefix)) == prefix:
            raise RuntimeError(f"Formato inválido: {path}")
        file.seek(-4, 2)
        if file.read() != b"GDPC":
            raise RuntimeError(f"Recursos do jogo não estão embutidos: {path}")


def package(system: str, output: Path) -> Path:
    linux = system == "Linux"
    binary = "EntreFolhas.x86_64" if linux else "EntreFolhas.exe"
    stage = ROOT / "build" / "packages" / f"EntreFolhas-{system}"
    stage.mkdir(parents=True, exist_ok=True)
    player = ROOT / "build" / system.lower() / binary
    verify_player(player, b"\x7fELF" if linux else b"MZ")
    shutil.copy2(player, stage / binary)
    if linux:
        (stage / binary).chmod(0o755)
        launcher = stage / "Jogar.sh"
        launcher.write_text(
            '#!/usr/bin/env sh\nset -eu\n'
            'game_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"\n'
            'cd "$game_dir"\nexec ./EntreFolhas.x86_64 "$@"\n',
            encoding="utf-8",
        )
        launcher.chmod(0o755)
        instructions = """ENTRE FOLHAS — LINUX 64 BITS\n\nEste jogo está pronto para jogar. Não é necessário instalar o Godot.\n\n1. Extraia este ZIP inteiro.\n2. Abra Jogar.sh, ou execute ./Jogar.sh em um terminal nesta pasta.\n3. Se aparecer 'Permissão negada', execute:\n   chmod +x Jogar.sh EntreFolhas.x86_64\n   ./Jogar.sh\n\nRequer um desktop Linux de 64 bits com suporte a OpenGL 3.3.\n"""
    else:
        instructions = """ENTRE FOLHAS — WINDOWS 64 BITS\n\nEste jogo está pronto para jogar. Não é necessário instalar o Godot.\n\n1. Extraia este ZIP inteiro para uma pasta.\n2. Abra EntreFolhas.exe com dois cliques.\n\nRequer Windows 10/11 de 64 bits com suporte a OpenGL 3.3.\n"""
    (stage / "LEIA-ME.txt").write_text(instructions + CONTROLS + VILLAGERS, encoding="utf-8")
    for license_file in (ROOT / "licenses").glob("*.txt"):
        shutil.copy2(license_file, stage / license_file.name)
    shutil.copy2(ROOT / "assets" / "tomate" / "sources.json", stage / "FONTES-SPRITES.json")
    (stage / "FONTES-ARVORES.json").unlink(missing_ok=True)
    (stage / "CREDITOS.txt").write_text(
        "Entre Folhas\nMotor: Godot 4.6.3, licença MIT.\n"
        "Os avisos do Godot e de suas dependências acompanham este pacote.\n"
        "Sprites: dez PNGs originais de tomate.zip, fornecidos pelo autor do projeto.\n"
        "Inclui personagens, árvores, terrenos, transições, água e casas.\n"
        "Os PNGs foram copiados e renomeados, preservando seus bytes originais.\n"
        "O fundo magenta é removido pelo renderizador do jogo.\n"
        "FONTES-SPRITES.json relaciona nomes recebidos, papéis e hashes SHA-256 das imagens e de tomate.zip.\n",
        encoding="utf-8",
    )
    archive = output / f"EntreFolhas-{system}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as file:
        for path in sorted(stage.iterdir()):
            file.write(path, f"{stage.name}/{path.name}")
    with zipfile.ZipFile(archive) as file:
        if file.testzip() is not None:
            raise RuntimeError(f"Falha de integridade: {archive}")
        if linux:
            for name in [binary, "Jogar.sh"]:
                mode = file.getinfo(f"{stage.name}/{name}").external_attr >> 16
                if not mode & 0o111:
                    raise RuntimeError("Permissão de execução não foi preservada no ZIP.")
    print(f"{archive} ({archive.stat().st_size / 1024 / 1024:.1f} MiB)")
    return archive


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "build" / "releases")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    archives = [package(system, args.output) for system in ["Linux", "Windows"]]
    checksums = "".join(
        f"{hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()}  {path.name}\n"
        for path in archives
    )
    (args.output / "EntreFolhas-SHA256.txt").write_text(checksums, encoding="ascii")


if __name__ == "__main__":
    main()
