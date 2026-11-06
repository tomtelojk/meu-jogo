#!/usr/bin/env python3
"""Package the exported Linux and Windows players; standard library only."""
import argparse
import hashlib
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLS = """
ENTRE REINOS — RPG DE MUNDO ABERTO

WASD ou setas: caminhar e nadar
Shift: correr ou acelerar na água
E: conversar, negociar, coletar e interagir
Espaço ou clique esquerdo: atacar animais próximos
I: inventário, ferramentas e provisões
J: objetivos e registros
B: escolher terreno; clique confirma, botão direito/Esc cancela
M: mapa do continente
Esc: pausa e gráficos (leve / nítido)

O modo leve é o padrão. Som ambiente é opcional.
Seu progresso é salvo automaticamente neste computador.
"""
VILLAGERS = """
DOIS REINOS, QUATRO VILAREJOS
Mapa 25 vezes maior: 16.000 x 12.800 unidades.
Explore Aurélia, Valverde, Pedra Alta, Ponte Velha, Porto Claro e Cedro.
As capitais e vilarejos somam 135 construções e 44 moradores.
Nas estalagens você pode descansar e viajar de caravana.

SUA VIDA DE AVENTUREIRO
Compre machado, picareta, martelo e espada nas ferrarias.
Use E perto de árvores e rochas para recolher madeira e pedra.
Venda materiais ou entregue encomendas diárias para ganhar moedas e experiência.
Vacas e galinhas fornecem provisões; cervos, coelhos e javalis vivem nos campos.
Javalis podem atacar. Provisões e descanso recuperam a vida.

CONSTRUA SUA CASA
Use B perto de um terreno livre de ruas, água, árvores e pedras.
Reservar o terreno custa 20 moedas. Depois, vá até a obra e use E.
Um martelo, 50 madeira e 20 pedra completam fundação, paredes e telhado.
Sua casa permite descansar e serve como retorno se você for socorrido.

MORADORES COM PLANOS PRÓPRIOS
Os NPCs trabalham, recebem moedas, visitam lojas e voltam para casa.
Quatro construtores dos vilarejos compram ferramentas, recolhem materiais e
constroem suas próprias casas ao longo do dia. Converse sobre compras e casa
para acompanhar a carteira, as ferramentas e o objetivo de cada um.

DESEMPENHO E SALVAMENTO
O mundo carrega no máximo 25 regiões próximas, liberando as que ficam longe.
Árvores usam grupos de instâncias, com vento e sombras leves.
Posição, inventário, moedas, saúde, casas, recursos retirados e progresso dos
moradores são salvos. Saves antigos migram para a entrada de Aurélia.
As antigas sementes continuam como uma atividade opcional do vale noroeste.
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
    binary = "EntreReinos.x86_64" if linux else "EntreReinos.exe"
    stage = ROOT / "build" / "packages" / f"EntreReinos-{system}"
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
            'cd "$game_dir"\nexec ./EntreReinos.x86_64 "$@"\n',
            encoding="utf-8",
        )
        launcher.chmod(0o755)
        instructions = """ENTRE REINOS — LINUX 64 BITS\n\nEste jogo está pronto para jogar. Não é necessário instalar o Godot.\n\n1. Extraia este ZIP inteiro.\n2. Abra Jogar.sh, ou execute ./Jogar.sh em um terminal nesta pasta.\n3. Se aparecer 'Permissão negada', execute:\n   chmod +x Jogar.sh EntreReinos.x86_64\n   ./Jogar.sh\n\nRequer um desktop Linux de 64 bits com suporte a OpenGL 3.3.\n"""
    else:
        instructions = """ENTRE REINOS — WINDOWS 64 BITS\n\nEste jogo está pronto para jogar. Não é necessário instalar o Godot.\n\n1. Extraia este ZIP inteiro para uma pasta.\n2. Abra EntreReinos.exe com dois cliques.\n\nRequer Windows 10/11 de 64 bits com suporte a OpenGL 3.3.\n"""
    (stage / "LEIA-ME.txt").write_text(instructions + CONTROLS + VILLAGERS, encoding="utf-8")
    for license_file in (ROOT / "licenses").glob("*.txt"):
        shutil.copy2(license_file, stage / license_file.name)
    shutil.copy2(ROOT / "assets" / "tomate" / "sources.json", stage / "FONTES-SPRITES.json")
    (stage / "FONTES-ARVORES.json").unlink(missing_ok=True)
    (stage / "CREDITOS.txt").write_text(
        "Entre Reinos\nMotor: Godot 4.6.3, licença MIT.\n"
        "Os avisos do Godot e de suas dependências acompanham este pacote.\n"
        "Sprites: dez PNGs originais de tomate.zip, fornecidos pelo autor do projeto.\n"
        "Inclui personagens, árvores, terrenos, transições, água e casas.\n"
        "Modelos 3D dos animais e das construções por etapas: geometria procedural do projeto.\n"
        "Os PNGs foram copiados e renomeados, preservando seus bytes originais.\n"
        "O fundo magenta é removido pelo renderizador do jogo.\n"
        "FONTES-SPRITES.json relaciona nomes recebidos, papéis e hashes SHA-256 das imagens e de tomate.zip.\n",
        encoding="utf-8",
    )
    archive = output / f"EntreReinos-{system}.zip"
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
    (args.output / "EntreReinos-SHA256.txt").write_text(checksums, encoding="ascii")


if __name__ == "__main__":
    main()
