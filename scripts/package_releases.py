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
Espaço: atacar animais próximos
1 a 4: equipar espada, machado, picareta ou martelo
5: comer provisão | 6: mapa | 7: diário | 8: ligar/desligar lanterna
Roda do mouse: selecionar espaço da hotbar | Clique esquerdo: usar o item
Q/R ou botão do meio + arrastar: girar câmera (limite de 35 graus)
Ctrl+roda ou PgUp/PgDn: zoom | Home: restaurar câmera
I: inventário, ferramentas e provisões
J: objetivos e registros
B: catálogo de construção | T: girar peça | Clique: construir
Botão direito/Esc: sair da prévia | B na prévia: voltar ao catálogo
M: mapa do continente
F2: Ateliê de Mundos — crie ou edite seu mapa
Esc: pausa e gráficos (leve / HD-2D), shaders e clima

O modo leve é o padrão. Som ambiente é opcional.
HD-2D ativa foco suave, bloom e sombras do sol. A interface fica nítida.
Clima pode ser automático ou fixado no menu Esc.
Seu progresso é salvo automaticamente neste computador.

NPCS E RELACIONAMENTOS
E perto de um NPC > Conversar e relacionamentos.
J > Relações, missões e identidade mostra vínculos, classe e facção.
Afinidade vai de -100 a 100. Há preferências próprias e dois presentes por dia.
Escolhas, ajuda, promessas, roubo e reparação ficam na memória do morador.
Missões pessoais e níveis de amizade abrem encontros com câmera e retratos.
NPCs adultos podem aceitar romance, casamento e viagens em companhia.
A forja fabrica a aliança: 2 lingotes de cobre e 1 de ferro, em 30 minutos.
O companheiro segue rotas seguras e espera na margem enquanto você nada.
Classe, facção, memórias, vínculos e cenas pendentes são salvos por mapa.
GUIA-DOS-RELACIONAMENTOS.md contém os requisitos e as instruções completas.

FACÇÕES, GUILDAS E FRONTEIRAS
J > Facções, guildas e territórios mostra sua progressão e as ideologias.
E nas bandeiras abre QGs e postos; os mestres também recebem durante o dia.
Aurélia e Valverde têm reputação própria: Hostil, Neutro, Aliado e Herói.
Apoios e encomendas favorecem uma Coroa e podem irritar a rival.
Desconfiança encarece compras; aliados e heróis recebem descontos.
Hostilidade fecha comércio e a praça da capital. Em -60, há perseguição.
Reparação em QGs/postos usa 15 moedas e 2 provisões e recupera até 15 pontos.
Artífices, Rotas e Vigília têm uniformes, contratos, lojas e quatro ranks.
Filiação custa 20 moedas; visitas e combate contam após aceitar contratos.
Um apoio diário por posto muda influência; em +60/-60, muda o controle.
O mapa mostra administração dos quatro vilarejos e os QGs das três guildas.
As cartas das Coroas têm três caminhos e desfechos conforme sua aliança.
Toda a progressão é salva por mapa. O editor mantém serviços personalizados.
GUIA-DAS-FACCOES.md contém custos, faixas, requisitos e consequências.

CRIE SEU PRÓPRIO MAPA
F2 abre o ateliê. Comece com Novo mapa vazio ou edite a base dos reinos.
Pinte terrenos e água; coloque casas, pontes, árvores, animais e moradores.
Selecione um NPC para marcar casa, trabalho e passeio.
Roda do mouse: zoom. Botão direito/meio: arrastar a visão. WASD: navegar.
Ctrl+Z: desfazer. Ctrl+Y: refazer. Delete: apagar seleção. Ctrl+S: salvar.
Salvar guarda o rascunho. Exportar cria um JSON na pasta que você escolher.
Importar abre esse JSON em outro computador. Testar mapa entra no seu mundo.
Fechar/F2 guarda alterações pendentes sem trocar o mundo da aventura atual.
Voltar à aventura original recupera o continente e o progresso anteriores.
MAPA-EXEMPLO.json pode ser importado pelo ateliê.
GUIA-DO-EDITOR.md contém o guia completo.

O menu Esc permite desligar os novos efeitos em Shaders.
"""
VILLAGERS = """
DOIS REINOS, QUATRO VILAREJOS
Mapa 25 vezes maior: 16.000 x 12.800 unidades.
Explore Aurélia, Valverde, Pedra Alta, Ponte Velha, Porto Claro e Cedro.
As capitais e vilarejos somam 126 construções e 44 moradores.
Ruas curvas, lotes irregulares, bosques em grupos e rio de largura variável.
Nas estalagens você pode descansar e viajar de caravana.

SUA VIDA DE AVENTUREIRO
Compre machado, picareta, martelo e espada nas ferrarias.
Use E ou a ferramenta da hotbar para golpear árvores e rochas.
Golpes gastam energia. Árvores tremem, caem e deixam um toco.
Materiais saltam para o chão e são atraídos quando você chega perto.
Árvores regeneram após 3 dias; rochas e minérios após 5 a 7 dias.
Fome de material? Melhore machado e picareta na ferraria:
pedra custa 40 moedas, 5 madeira, 10 pedra; ferro custa 90 moedas e 6 ferro.
Rochas duras e minérios exigem pedra; basalto exige ferro.
Lenhador e mineiro ganham níveis, melhorando dano e uso de energia.
O inventário mostra habilidades, cobre, ferro e energia.
Ative Som na interface para ouvir os impactos.
Venda materiais ou entregue encomendas diárias para ganhar moedas e experiência.
Vacas e galinhas fornecem provisões; cervos, coelhos e javalis vivem nos campos.
Javalis podem atacar. Provisões e descanso recuperam a vida.

CONSTRUA SUA CASA
Use B para escolher paredes, chão, móveis e estações, com custos e grade.
Fantasma verde: local válido; vermelho: explica o impedimento. T gira.
Você precisa de martelo. Clique constrói; Esc/botão direito encerra a prévia.
A bancada usa 10 madeira e 4 pedra e transforma 2 madeira em 2 tábuas.
A forja usa 18 pedra, 4 tábuas e 2 cobre e permite fabricação avançada.
Use E na estação para receitas, fila, reparos e designar trabalhador.
Pedidos reservam ingredientes; cancelar devolve unidades não concluídas.
Produção avança com o tempo do mundo e durante o descanso. Menus pausam.
Use E na cama livre para descansar, salvar e definir ponto de retorno.
É possível designar NPCs a camas e estações; eles seguem seus turnos.
Trabalhador presente acelera a estação em 25%. Javalis danificam obstáculos.
Estruturas têm vida; martelo e materiais permitem reparar pelo menu E.
Construções, designações e filas são guardadas no save de cada mapa.
A casa antiga continua em B > Casa completa por etapas, com seus custos.
GUIA-DA-CONSTRUCAO.md contém as instruções completas.

MORADORES COM PLANOS PRÓPRIOS
Os NPCs têm turnos variados, refeições, encontros e descanso em casa.
O guarda patrulha a ponte e a comerciante viaja entre os reinos.
Moradores compram ferramentas, vendem produção, evitam aglomerações,
procuram desvios e fogem de javalis próximos.
Quatro construtores dos vilarejos compram ferramentas, recolhem materiais e
constroem suas próprias casas ao longo do dia. Converse sobre compras e casa
para acompanhar a carteira, as ferramentas e o objetivo de cada um.

DESEMPENHO E SALVAMENTO
O cenário 2.5D tem ciclo de luz, neblina, postes e lanterna noturna.
Sprites acompanham a câmera sem esticar e projetam sombras no chão.
Chuva tem partículas e respingos; vento move árvores e grama.
A grama se curva com a passagem do jogador. A água reflete a cena.
Casas e árvores que encobrem o personagem ficam parcialmente transparentes.
O modo leve reduz a resolução do cenário, mantendo a interface nítida.
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
    player = ROOT / "build" / system.lower() / binary
    verify_player(player, b"\x7fELF" if linux else b"MZ")
    # The stage is generated here; rebuild it so previous exports and Godot
    # import sidecars cannot silently become part of the next release.
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True, exist_ok=True)
    (ROOT / "build" / ".gdignore").touch()
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
    shutil.copy2(ROOT / "assets" / "npcs" / "sources.json", stage / "FONTES-NPCS.json")
    shutil.copy2(ROOT / "docs" / "mapa-exemplo.json", stage / "MAPA-EXEMPLO.json")
    guide = (ROOT / "docs" / "editor-de-mapas.md").read_text(encoding="utf-8")
    (stage / "GUIA-DO-EDITOR.md").write_text(
        guide.replace("(mapa-exemplo.json)", "(MAPA-EXEMPLO.json)"), encoding="utf-8"
    )
    shutil.copy2(ROOT / "docs" / "editor-mapa.png", stage / "editor-mapa.png")
    shutil.copy2(ROOT / "docs" / "coleta-e-ferramentas.md", stage / "GUIA-DA-COLETA.md")
    shutil.copy2(ROOT / "docs" / "visual-hd2d.md", stage / "GUIA-DO-VISUAL.md")
    shutil.copy2(ROOT / "docs" / "construcao-e-fabricacao.md", stage / "GUIA-DA-CONSTRUCAO.md")
    shutil.copy2(ROOT / "docs" / "npcs-e-relacionamentos.md", stage / "GUIA-DOS-RELACIONAMENTOS.md")
    shutil.copy2(ROOT / "docs" / "faccoes-e-guildas.md", stage / "GUIA-DAS-FACCOES.md")
    for image_name in ["faccoes-reputacao.png", "faccoes-guilda.png", "faccoes-territorio.png", "faccoes-mapa.png", "faccoes-historia.png"]:
        shutil.copy2(ROOT / "docs" / image_name, stage / image_name)
    for image_name in ["coleta-queda.png", "coleta-toco.png", "hd2d-aurelia.png", "hd2d-noite.png", "hd2d-ponte.png", "hd2d-chuva.png", "construcao-catalogo.png", "construcao-previa.png", "construcao-fila.png", "construcao-assentamento.png", "relacoes-amizade.png", "relacoes-encontro.png", "relacoes-casamento.png", "relacoes-companhia.png", "relacoes-memoria.png"]:
        shutil.copy2(ROOT / "docs" / image_name, stage / image_name)
    (stage / "FONTES-ARVORES.json").unlink(missing_ok=True)
    (stage / "CREDITOS.txt").write_text(
        "Entre Reinos\nMotor: Godot 4.6.3, licença MIT.\n"
        "Os avisos do Godot e de suas dependências acompanham este pacote.\n"
        "Sprites: dez PNGs originais de tomate.zip, fornecidos pelo autor do projeto.\n"
        "Inclui personagens, árvores, terrenos, transições, água e casas.\n"
        "NPCs: oito pranchas originais de abc.zip, fornecidas pelo autor, além do agricultor de tomate.zip.\n"
        "FONTES-NPCS.json registra a origem e os hashes das pranchas de NPCs.\n"
        "Modelos 3D dos animais e das construções por etapas: geometria procedural do projeto.\n"
        "Fonte bitmap 5x7, ícones da interface e paisagem do menu: criados no projeto.\n"
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
