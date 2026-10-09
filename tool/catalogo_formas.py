"""Formas (comprimido, gotas, mL...) em que remédios comuns existem, quando
a regra automática de tool/gerar_catalogo.py não basta.

A regra automática parte da forma principal do item e acrescenta as que as
gramaturas indicam ("500 mg/mL" -> gotas e mL; "100 mcg/jato" -> jato;
"1%" -> aplicação). No cadastro, o app mostra só estas formas (mais a já
marcada e "Outras") — ninguém precisa ler "Jato" ou "Unidades (UI)" ao
cadastrar uma Dipirona.

Usado por tool/gerar_catalogo.py.
"""

FORMAS = {
    "Dipirona": ["comprimido", "gotas", "ml"],
    "Paracetamol": ["comprimido", "gotas", "ml"],
    "Ibuprofeno": ["comprimido", "capsula", "gotas", "ml"],
    "Amoxicilina": ["capsula", "comprimido", "ml"],
    "Amoxicilina + Clavulanato": ["comprimido", "ml"],
    "Azitromicina": ["comprimido", "ml"],
    "Cefalexina": ["capsula", "comprimido", "ml"],
    "Loratadina": ["comprimido", "ml"],
    "Desloratadina": ["comprimido", "ml"],
    "Dexclorfeniramina": ["comprimido", "ml", "gotas"],
    "Prednisolona": ["comprimido", "ml"],
    "Omeprazol": ["capsula", "comprimido"],
    "Simeticona": ["comprimido", "capsula", "gotas"],
    "Bromoprida": ["comprimido", "capsula", "gotas", "ml"],
    "Metoclopramida": ["comprimido", "gotas", "ml"],
    "Ondansetrona": ["comprimido"],
    "Escopolamina": ["comprimido", "gotas"],
    "Diclofenaco": ["comprimido", "gotas", "aplicacao"],
    "Nimesulida": ["comprimido", "gotas"],
    "Fluoxetina": ["capsula", "comprimido", "gotas"],
    "Clonazepam": ["comprimido", "gotas"],
    "Haloperidol": ["comprimido", "gotas"],
    "Risperidona": ["comprimido", "ml"],
    "Colecalciferol": ["capsula", "gotas", "comprimido"],
    "Sulfato ferroso": ["comprimido", "gotas"],
    "Ácido fólico": ["comprimido", "gotas"],
}
