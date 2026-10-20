"""Classe terapêutica da ANVISA -> motivos de uso do app ("Para que serve?").

Usado por tool/gerar_catalogo.py para os medicamentos que vêm só da base da
ANVISA (sem curadoria manual). A primeira regra que casar com a classe vale;
classes sem regra ficam sem motivo sugerido (o app mostra a lista completa).
"""

import re

REGRAS = [
    (r"ANTICONCEPC", ["anticoncepcional"]),
    (r"ANTIDIABET|INSULINA", ["diabetes"]),
    (r"ANTILIPEM|HIPOLIPEM|ESTATINA", ["colesterol"]),
    (r"BETABLOQ", ["pressao", "coracao"]),
    (r"HIPERTENS|DIURETIC|ENZIMA CONVERSORA|ANGIOTENSINA|BLOQUEADORES? "
     r"(DOS? )?CANA[IL]S? DE CALCIO", ["pressao"]),
    (r"ANTIANGIN|ANTIARRIT|CARDIOTON|MIOCARDIO|INSUFICIENCIA CARDIACA",
     ["coracao"]),
    (r"ANTITROMB|ANTIAGREG|ANTICOAGUL|VASODILAT|ANTIVARICOS|HEMATOPOIESE|"
     r"ANTIANEMIC|FERRO", ["circulacao"]),
    (r"ANTIBIOT|CEFALOSPOR|PENICILIN|ANTIVIR|ANTIMICOT|ANTIFUNG|"
     r"ANTIPARASIT|ANTIHELMINT|ANTI-HELMINT|ANTINFECC|SULFONAMID|QUINOLON|"
     r"TUBERCUL|ANTIMALAR", ["infeccao"]),
    (r"HISTAMIN|ANTIALERG", ["alergia"]),
    (r"GLICOCORTIC|CORTICOSTER", ["alergia", "respiracao", "ossos"]),
    (r"ANTIASMAT|BRONCODILAT|EXPECTOR|MUCOLIT|ANTITUSSIG|GRIPE|"
     r"DESCONGESTION|RESPIRAT", ["respiracao"]),
    (r"ANTIULCER|ANTIACID|ANTIEMET|ANTINAUSE|LAXANT|ANTIDIARR|ANTIESPASM|"
     r"DIGESTIV|HEPATOPROT|ANTIFLATUL|PROTONS", ["estomago"]),
    (r"TIREOID|TIROID", ["tireoide"]),
    (r"ANTIDEPRESS|ANSIOLIT|ANTIPSICOT|NEUROLEPT|ESTABILIZADOR", ["humor"]),
    (r"HIPNOT|SEDATIV", ["sono"]),
    (r"DEMENCIA|ALZHEIMER|NOOTROP", ["memoria"]),
    (r"REABSORCAO OSSEA|ESTRUTURA OSSEA|ANTIREUMAT|ANTIGOT|URICOS|"
     r"OSTEOPOR", ["ossos", "dor"]),
    (r"ANALGES|ANTINFLAM|ANTI-INFLAM|RELAXANTES MUSC|ANTIENXAQ|"
     r"ENXAQUECA", ["dor"]),
    (r"VITAMIN|MINERA|SUPLEMENT|POLIVITAM|CALCIO", ["vitamina"]),
]

_COMPILADAS = [(re.compile(p), m) for p, m in REGRAS]


def motivos_da_classe(classes):
    """Motivos sugeridos para as classes (a mais frequente primeiro)."""
    saida = []
    for classe in classes:
        for regra, motivos in _COMPILADAS:
            if regra.search(classe):
                saida += [m for m in motivos if m not in saida]
                break
    return saida[:3]
