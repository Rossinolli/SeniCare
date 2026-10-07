"""Gera as imagens da marca SeniCare a partir da fonte Great Vibes.

Logo: um "S" caligráfico branco sobre um círculo azul (mesmo conceito do
ícone do Facebook: letra única, branca, sobre a cor da marca).

Uso (na raiz do projeto):  python tool/gerar_logo.py
Depois:  dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
FONTE = RAIZ / "assets" / "fonts" / "GreatVibes-Regular.ttf"
SAIDA = RAIZ / "assets" / "branding"

AZUL_MARCA = (21, 101, 192, 255)  # #1565C0 — branco sobre ele: contraste 5,7:1
BRANCO = (255, 255, 255, 255)
LADO = 1024
SUPERAMOSTRAGEM = 4  # desenha 4x maior e reduz: bordas suaves


def _desenhar_s(lado: int, altura_letra: float) -> Image.Image:
    """'S' branco centralizado opticamente numa imagem transparente."""
    grande = lado * SUPERAMOSTRAGEM
    img = Image.new("RGBA", (grande, grande), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Ajusta o tamanho da fonte até a ALTURA real do glifo bater com o alvo.
    alvo = altura_letra * grande
    tamanho = int(alvo)
    for _ in range(8):
        fonte = ImageFont.truetype(str(FONTE), tamanho)
        x0, y0, x1, y1 = draw.textbbox((0, 0), "S", font=fonte)
        tamanho = max(1, int(tamanho * alvo / (y1 - y0)))
    fonte = ImageFont.truetype(str(FONTE), tamanho)
    x0, y0, x1, y1 = draw.textbbox((0, 0), "S", font=fonte)
    x = (grande - (x1 - x0)) / 2 - x0
    y = (grande - (y1 - y0)) / 2 - y0
    # Traço levemente engrossado: o caligráfico fino some no ícone de 48 dp.
    espessura = max(1, int(alvo * 0.018))
    draw.text((x, y), "S", font=fonte, fill=BRANCO, stroke_width=espessura, stroke_fill=BRANCO)
    return img.resize((lado, lado), Image.LANCZOS)


def _circulo(lado: int, diametro: float, cor) -> Image.Image:
    grande = lado * SUPERAMOSTRAGEM
    img = Image.new("RGBA", (grande, grande), (0, 0, 0, 0))
    d = diametro * grande
    m = (grande - d) / 2
    ImageDraw.Draw(img).ellipse((m, m, m + d, m + d), fill=cor)
    return img.resize((lado, lado), Image.LANCZOS)


def main() -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)

    # 1) Ícone completo (iOS / Android antigo): fundo azul inteiro + S.
    icone = Image.new("RGBA", (LADO, LADO), AZUL_MARCA)
    icone.alpha_composite(_desenhar_s(LADO, 0.62))
    icone.convert("RGB").save(SAIDA / "icone.png")

    # 2) Primeiro plano do ícone adaptativo (Android 8+): só o S, dentro da
    #    zona segura de 66% (o sistema recorta em círculo/squircle).
    _desenhar_s(LADO, 0.42).save(SAIDA / "icone_frente.png")

    # 3) Selo da marca (círculo azul + S) — splash nativa e telas do app.
    selo = _circulo(LADO, 1.0, AZUL_MARCA)
    selo.alpha_composite(_desenhar_s(LADO, 0.62))
    selo.save(SAIDA / "selo.png")

    # 4) Splash do Android 12+: o sistema mostra a imagem num círculo de
    #    2/3 do lado; o selo ocupa esse círculo.
    splash12 = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    splash12.alpha_composite(_circulo(LADO, 0.62, AZUL_MARCA))
    splash12.alpha_composite(_desenhar_s(LADO, 0.40))
    splash12.save(SAIDA / "splash_android12.png")

    print("Imagens geradas em", SAIDA)


if __name__ == "__main__":
    main()
