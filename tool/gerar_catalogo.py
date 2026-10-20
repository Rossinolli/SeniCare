"""Gera assets/data/medicamentos_br.json (catálogo do autocompletar) a partir
das listas curadas em tool/catalogo_base.py e tool/catalogo_novos.py e da
base oficial da ANVISA resumida em tool/dados/anvisa_resumo.json (ver
tool/importar_anvisa.py), validando:

* nomes únicos (sem diferenciar acento/maiúscula);
* nenhum sinônimo repetido entre medicamentos diferentes;
* forma farmacêutica e motivo de uso dentro das listas do app.

Uso (na raiz do projeto):  python tool/gerar_catalogo.py
O teste test/domain/catalogo_asset_test.dart confere o arquivo gerado.
"""

import io
import json
import re
import sys
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "tool"))

from catalogo_base import BASE  # noqa: E402
from catalogo_novos import NOVOS  # noqa: E402
from catalogo_formas import FORMAS as FORMAS_DO_ITEM  # noqa: E402
from catalogo_motivos import MOTIVOS as MOTIVOS_DO_ITEM  # noqa: E402
from classes_anvisa import motivos_da_classe  # noqa: E402
from importar_anvisa import chave as chave_anvisa  # noqa: E402

FORMAS = {
    "comprimido", "capsula", "cápsula", "gotas", "ml", "mL", "sache", "sachê",
    "jato", "unidades", "aplicacao", "aplicação", "adesivo", "ampola",
}
MOTIVOS = {
    "dor", "febre", "pressao", "diabetes", "colesterol", "coracao", "circulacao",
    "infeccao", "alergia", "respiracao", "estomago", "tireoide", "humor", "sono",
    "memoria", "ossos", "anticoncepcional", "vitamina", "outro",
}


def normalizar(texto: str) -> str:
    sem_acento = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore")
    return " ".join(sem_acento.decode().lower().split())


CANONICA = {"cápsula": "capsula", "mL": "ml", "sachê": "sache", "aplicação": "aplicacao"}


def formas_do_item(nome: str, forma: str, doses: list) -> list:
    """Formas em que o remédio existe: a lista manual (catalogo_formas.py)
    ou a forma principal mais as que as gramaturas indicam."""
    if nome in FORMAS_DO_ITEM:
        return FORMAS_DO_ITEM[nome]
    formas = [CANONICA.get(forma, forma)]
    for d in doses:
        if "/jato" in d or "/dose" in d:
            extras = ["jato"]
        elif "UI/mL" in d:
            extras = ["unidades"]
        elif re.search(r"mg/mL$", d):  # solução por mL: gotas ou mL
            extras = ["gotas", "ml"]
        elif re.search(r"/\s*\d+\s*mL$", d):  # xarope (ex.: 250 mg/5 mL)
            extras = ["ml"]
        elif ("%" in d or "mg/g" in d) and formas[0] not in ("gotas", "jato"):
            extras = ["aplicacao"]
        else:
            extras = []
        formas += [f for f in extras if f not in formas]
    return formas


def main() -> None:
    erros = []
    nomes = {}
    sinonimos = {}
    itens = []
    for nome, aliases, forma, doses, motivo in BASE + NOVOS:
        chave = normalizar(nome)
        if chave in nomes:
            erros.append(f"nome repetido: {nome}")
        nomes[chave] = nome
        formas = formas_do_item(nome, forma, doses)
        for f in [forma, *formas]:
            if f not in FORMAS:
                erros.append(f"{nome}: forma inválida {f!r}")
        motivos = MOTIVOS_DO_ITEM.get(nome) or ([motivo] if motivo else [])
        for m in motivos:
            if m not in MOTIVOS:
                erros.append(f"{nome}: motivo inválido {m!r}")
        for a in aliases:
            ka = normalizar(a)
            dono = sinonimos.get(ka)
            if dono is not None and dono != nome:
                erros.append(f"sinônimo {a!r} em {dono} e {nome}")
            sinonimos[ka] = nome
        # Lista de formas; a primeira é a pré-selecionada no app.
        item = {"n": nome, "a": aliases, "f": formas, "d": doses}
        if motivos:
            # Lista de usos; o primeiro é o pré-selecionado no app.
            item["m"] = motivos
        itens.append(item)

    for nome in [*MOTIVOS_DO_ITEM, *FORMAS_DO_ITEM]:
        if normalizar(nome) not in nomes:
            erros.append(f"{nome!r} (catalogo_motivos/formas) não está no catálogo")

    # Um sinônimo não pode ser também o nome de outro medicamento.
    for ka, dono in sinonimos.items():
        if ka in nomes and nomes[ka] != dono:
            erros.append(f"sinônimo {ka!r} de {dono} é nome de {nomes[ka]}")

    if erros:
        print("\n".join(erros))
        sys.exit(1)

    curados = len(itens)
    marcas = juntar_anvisa(itens, nomes, sinonimos)

    itens.sort(key=lambda i: normalizar(i["n"]))
    saida = {
        "versao": 3,
        "fonte": (
            "Curadoria SeniCare (medicamentos de uso comum, com formas, "
            "gramaturas e usos) + base oficial da ANVISA (dados abertos, "
            "registros ativos), com os nomes comerciais como sinônimos. As "
            "dosagens são atalhos — confira sempre na embalagem ou receita."
        ),
        "itens": itens,
    }
    texto = json.dumps(saida, ensure_ascii=False, indent=None)
    # Um item por linha: diffs legíveis no git.
    texto = texto.replace('"itens": [{', '"itens": [\n{').replace("}, {", "},\n{")
    destino = RAIZ / "assets" / "data" / "medicamentos_br.json"
    io.open(destino, "w", encoding="utf-8").write(texto + "\n")
    com_motivo = sum(1 for i in itens if "m" in i)
    nomes_busca = len(itens) + sum(len(i["a"]) for i in itens)
    print(
        f"{len(itens)} medicamentos ({curados} curados, "
        f"{len(itens) - curados} da ANVISA; {com_motivo} com motivo sugerido); "
        f"{marcas} nomes comerciais da ANVISA; {nomes_busca} nomes buscáveis "
        f"-> {destino}"
    )


def juntar_anvisa(itens, nomes, sinonimos) -> int:
    """Acrescenta a base da ANVISA: os nomes comerciais viram sinônimos do
    item curado do mesmo princípio ativo; princípios sem curadoria viram
    itens novos (sem forma/gramatura: o app mostra todas as opções), com o
    motivo deduzido da classe terapêutica. Devolve quantas marcas entraram."""
    caminho = RAIZ / "tool" / "dados" / "anvisa_resumo.json"
    base = json.loads(io.open(caminho, encoding="utf-8").read())["itens"]
    por_chave = {chave_anvisa(i["n"]): i for i in itens}
    marcas = 0

    def sinonimo_livre(nome_marca: str) -> bool:
        k = normalizar(nome_marca)
        return k not in sinonimos and k not in nomes

    for g in base:
        item = por_chave.get(g["chave"])
        if item is None:
            if normalizar(g["nome"]) in nomes:
                continue
            item = {"n": g["nome"], "a": [], "f": [], "d": []}
            classes = [normalizar(c).upper() for c in g["classes"]]
            motivos = motivos_da_classe(classes)
            if motivos:
                item["m"] = motivos
            nomes[normalizar(g["nome"])] = g["nome"]
            por_chave[g["chave"]] = item
            itens.append(item)
        for marca in g["marcas"]:
            # Marca repetida entre princípios (raro) fica com o primeiro.
            if sinonimo_livre(marca):
                item["a"].append(marca)
                sinonimos[normalizar(marca)] = item["n"]
                marcas += 1
    return marcas


if __name__ == "__main__":
    main()
