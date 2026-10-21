"""Resume a base oficial de medicamentos da ANVISA para o catálogo do app.

Fonte: dados abertos da ANVISA — "Medicamentos registrados no Brasil"
(https://dados.anvisa.gov.br/dados/DADOS_ABERTOS_MEDICAMENTOS.csv,
separado por ';', codificação Latin-1).

Uso:
    python tool/importar_anvisa.py caminho/DADOS_ABERTOS_MEDICAMENTOS.csv

Gera tool/dados/anvisa_resumo.json com TODOS os medicamentos de registro
ATIVO (os inativos não são mais vendidos): um item por princípio ativo, com
os nomes comerciais e a classe terapêutica; produtos sem princípio ativo
informado (baixo risco, fitoterápicos, soros) entram pelo nome do produto. O arquivo resumido fica no repositório, então
tool/gerar_catalogo.py roda sem a planilha de 46 MB.
"""

import collections
import html
import csv
import io
import json
import re
import sys
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "tool" / "dados" / "anvisa_resumo.json"

# Sais, hidratos e radicais que não mudam o "nome do remédio" para quem usa
# (losartana potássica = losartana).
SAIS = [
    r"cloridrato de", r"dicloridrato de", r"bromidrato de", r"maleato de",
    r"besilato de", r"besilato", r"mesilato de", r"tartarato de",
    r"bitartarato de", r"succinato de", r"hemifumarato de", r"fumarato de",
    r"sulfato de", r"citrato de", r"acetato de", r"fosfato de",
    r"dipropionato de", r"propionato de", r"valerato de", r"furoato de",
    r"butirato de", r"hiclato de", r"hiclato", r"oxalato de", r"lactato de",
    r"gluconato de", r"hidrobrometo de", r"cloreto de", r"brometo de",
    r"monoidratad[oa]", r"di-?hidratad[oa]", r"tri-?hidratad[oa]",
    r"hemi-?h?idratad[oa]", r"sesqui-?hidratad[oa]", r"pentaidratad[oa]",
    r"anidr[oa]", r"s[oó]dic[oa]", r"pot[aá]ssic[oa]", r"c[aá]lcic[oa]",
    r"magn[eé]sic[oa]", r"trometamol", r"micronizad[oa]", r"base",
]
SAL = re.compile(r"\b(" + "|".join(SAIS) + r")\b")

# Grafias diferentes do mesmo componente na base (o mesmo registro às vezes
# lista o ácido e o sal: "ácido clavulânico, clavulanato de potássio").
CANONICO = {
    "acido clavulanico": "clavulanato", "clavulanato de potassio": "clavulanato",
    "glicazida": "gliclazida", "pemetrexede dissodico": "pemetrexede",
}

# Nomes de produto que não são marca (laboratórios públicos, testes).
NAO_MARCA = re.compile(r"\b(teste|lqfex|furp|funed|lfm|iquego|lafepe|"
                       r"fiocruz|farmanguinhos)\b", re.I)


def sem_acento(texto: str) -> str:
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore")
    return t.decode()


def componentes(principio: str) -> list:
    """'dipirona monoidratada, cafeína' -> ['cafeina', 'dipirona']."""
    partes = re.split(r"\s*(?:,|;|\+|\be\b)\s*", principio.lower())
    saida = []
    for p in partes:
        p = SAL.sub(" ", p)
        p = " ".join(p.split())
        p = CANONICO.get(sem_acento(p), p)
        if p:
            saida.append(p)
    unicos = {}
    for p in saida:
        unicos.setdefault(sem_acento(p), p)
    # "losartan" e "losartana" no mesmo registro são o mesmo componente:
    # fica a grafia mais longa (a brasileira).
    for k in list(unicos):
        if any(o != k and o.startswith(k) and len(o) - len(k) <= 2
               for o in unicos):
            del unicos[k]
    return [unicos[k] for k in sorted(unicos)]


def chave(principio: str) -> str:
    return " + ".join(sem_acento(c) for c in componentes(principio))


def nome_generico(principio: str) -> str:
    return " + ".join(c[0].upper() + c[1:] for c in componentes(principio))


# Siglas que ficam em maiúsculas no nome comercial (Glifage XR, Aradois H).
SIGLAS = {"XR", "SR", "AP", "MR", "LP", "CR", "ER", "XL", "HCT", "ODT", "DC",
          "D", "H", "B", "C", "E", "K", "IV", "II", "III", "AAS", "UI", "GR"}


def nome_comercial(bruto: str) -> str:
    # Tira concentração no fim ("LABORHEX 2,0%", "XYZ 500 MG").
    t = re.sub(r"\s+\d[\d.,/]*\s*(%|MG|G|ML|MCG|UI)?(\s.*)?$", "", bruto.strip())
    palavras = []
    for p in t.split():
        if p.upper() in SIGLAS or (len(p) <= 3 and not re.search(r"[AEIOU]", p)):
            palavras.append(p.upper())
        else:
            palavras.append(p[0].upper() + p[1:].lower())
    return " ".join(palavras)


def nome_valido(bruto: str) -> bool:
    """Descarta nomes ilegíveis da base ("N?O DECLARADO", "&#231;")."""
    t = sem_acento(bruto).upper()
    return bool(t.strip()) and "?" not in bruto and "NAO DECLARADO" not in t


def main() -> None:
    caminho = sys.argv[1]
    grupos = collections.defaultdict(lambda: {
        "principio": collections.Counter(), "marcas": set(), "classes": collections.Counter(),
        "registros": 0,
    })
    with io.open(caminho, encoding="latin-1", newline="") as f:
        for l in csv.DictReader(f, delimiter=";"):
            if l["SITUACAO_REGISTRO"] != "Ativo":
                continue
            bruto = html.unescape(l["NOME_PRODUTO"])
            principio = html.unescape(l["PRINCIPIO_ATIVO"]).strip()
            classe = l["CLASSE_TERAPEUTICA"].strip()
            comps = componentes(principio) if principio else []
            if not comps or len(comps) > 4:
                # Sem princípio ativo informado, ou associação longa demais
                # para virar nome ("A + B + C + D + E"): entra pelo nome do
                # produto.
                if not nome_valido(bruto):
                    continue
                nome = nome_comercial(bruto)
                if not nome:
                    continue
                g = grupos[sem_acento(nome).lower()]
                g["principio"][nome] += 1
                g["registros"] += 1
                if classe:
                    g["classes"][classe] += 1
                continue
            g = grupos[chave(principio)]
            g["principio"][nome_generico(principio)] += 1
            g["registros"] += 1
            if classe:
                g["classes"][classe] += 1
            marca = nome_comercial(bruto)
            # Genérico registrado pelo nome do princípio não é marca, nem
            # "Laboratório X - Dipirona".
            nm = sem_acento(marca).lower()
            if (marca and nome_valido(bruto) and not NAO_MARCA.search(marca)
                    and not any(len(c) >= 5 and sem_acento(c) in nm
                                for c in comps)):
                g["marcas"].add(marca)

    itens = []
    for k, g in sorted(grupos.items()):
        itens.append({
            "chave": k,
            # A grafia mais comum, preferindo a acentuada ("Ácido
            # acetilsalicílico", não "Acido acetilsalicilico").
            "nome": max(g["principio"].items(),
                        key=lambda kv: (kv[0] != sem_acento(kv[0]), kv[1]))[0],
            "marcas": sorted(g["marcas"], key=sem_acento),
            "classes": [c for c, _ in g["classes"].most_common(3)],
            "registros": g["registros"],
        })
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    texto = json.dumps({"fonte": "ANVISA - dados abertos, medicamentos "
                        "registrados (todos com situação Ativo)", "itens": itens},
                       ensure_ascii=False)
    texto = texto.replace('"itens": [{', '"itens": [\n{').replace("}, {", "},\n{")
    io.open(DESTINO, "w", encoding="utf-8").write(texto + "\n")
    marcas = sum(len(i["marcas"]) for i in itens)
    print(f"{len(itens)} princípios ativos, {marcas} nomes comerciais -> {DESTINO}")


if __name__ == "__main__":
    main()
