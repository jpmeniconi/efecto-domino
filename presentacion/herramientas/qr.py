"""Dibuja un QR en SVG (modo byte, nivel M) sin dependencias. Uso: python3 presentacion/herramientas/qr.py [texto] [salida.svg]"""
import html
import itertools
import math
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parents[2]
TEXTO = "https://github.com/jpmeniconi/efecto-domino"
SALIDA = RAIZ / "presentacion" / "qr-repo.svg"
SILENCIO = 4  # zona de silencio, en módulos

# Nivel M, versiones 1 a 40 (ISO/IEC 18004, tabla 9). El índice es la versión.
CORRECCION_POR_BLOQUE = [
    None,
    10, 16, 26, 18, 24, 16, 18, 22, 22, 26,
    30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
    26, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
]
BLOQUES = [
    None,
    1, 1, 1, 2, 2, 4, 4, 4, 5, 5,
    5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
    17, 17, 18, 20, 21, 23, 25, 26, 28, 29,
    31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
]

# Tabla 10: donde la condición se cumple sobre (fila, columna), el módulo de datos se invierte.
MASCARAS = [
    lambda f, c: (f + c) % 2 == 0,
    lambda f, c: f % 2 == 0,
    lambda f, c: c % 3 == 0,
    lambda f, c: (f + c) % 3 == 0,
    lambda f, c: (f // 2 + c // 3) % 2 == 0,
    lambda f, c: f * c % 2 + f * c % 3 == 0,
    lambda f, c: (f * c % 2 + f * c % 3) % 2 == 0,
    lambda f, c: ((f + c) % 2 + f * c % 3) % 2 == 0,
]

# GF(256) con x⁸ + x⁴ + x³ + x² + 1 (0x11D): potencias de α = 2 y sus logaritmos.
POTENCIA = [1]
while len(POTENCIA) < 255:
    doble = POTENCIA[-1] << 1
    POTENCIA.append(doble ^ 0x11D if doble & 0x100 else doble)
LOGARITMO = {valor: i for i, valor in enumerate(POTENCIA)}


def multiplicar(a, b):
    return POTENCIA[(LOGARITMO[a] + LOGARITMO[b]) % 255] if a and b else 0


def correccion(palabras, cantidad):
    """Reed-Solomon: resto de palabras·xⁿ dividido por (x - α⁰)(x - α¹)…(x - αⁿ⁻¹), con n = cantidad."""
    generador = [1]
    for i in range(cantidad):
        generador = [a ^ multiplicar(b, POTENCIA[i]) for a, b in zip(generador + [0], [0] + generador)]
    resto = list(palabras) + [0] * cantidad
    for i in range(len(palabras)):
        factor = resto[i]
        if factor:
            for j, coeficiente in enumerate(generador):
                resto[i + j] ^= multiplicar(coeficiente, factor)
    return resto[len(palabras):]


def bch(dato, generador):
    """El dato seguido del resto de dividirlo por el generador en GF(2). Sirve al formato y a la versión."""
    grado = generador.bit_length() - 1
    resto = dato << grado
    while resto.bit_length() > grado:
        resto ^= generador << (resto.bit_length() - 1 - grado)
    return (dato << grado) | resto


def centros_de_alineamiento(version):
    # De 6 a lado - 7 con el menor paso par que alcanza; el primer tramo absorbe la diferencia. La 32 es la excepción.
    if version == 1:
        return []
    cantidad = version // 7 + 2
    ultimo = 4 * version + 10
    paso = 26 if version == 32 else 2 * math.ceil((ultimo - 6) / (2 * cantidad - 2))
    return [6] + list(range(ultimo - paso * (cantidad - 2), ultimo + 1, paso))


def posiciones_de_formato(lado):
    # Los 15 bits del formato, del menos al más significativo, en sus dos copias.
    primera = [(f, 8) for f in (0, 1, 2, 3, 4, 5, 7, 8)] + [(8, c) for c in (7, 5, 4, 3, 2, 1, 0)]
    segunda = [(8, lado - 1 - i) for i in range(8)] + [(lado - 7 + i, 8) for i in range(7)]
    return primera, segunda


def plantilla(version):
    """Patrones fijos de la versión como (oscuro, fijo). Lo que no es fijo queda para los datos."""
    lado = 4 * version + 17
    oscuro = [[False] * lado for _ in range(lado)]
    fijo = [[False] * lado for _ in range(lado)]

    def poner(f, c, valor):
        oscuro[f][c], fijo[f][c] = valor, True

    # Búsqueda en tres esquinas: cuadro oscuro de 7, claro de 5, núcleo de 3 y separador claro.
    for cf, cc in ((3, 3), (3, lado - 4), (lado - 4, 3)):
        for f in range(max(cf - 4, 0), min(cf + 5, lado)):
            for c in range(max(cc - 4, 0), min(cc + 5, lado)):
                poner(f, c, max(abs(f - cf), abs(c - cc)) not in (2, 4))
    # Alineamiento, salvo donde caería sobre la búsqueda.
    centros = centros_de_alineamiento(version)
    for cf, cc in itertools.product(centros, centros):
        if not fijo[cf][cc]:
            for f in range(cf - 2, cf + 3):
                for c in range(cc - 2, cc + 3):
                    poner(f, c, max(abs(f - cf), abs(c - cc)) != 1)
    # Temporización en la fila y la columna 6.
    for i in range(8, lado - 8):
        poner(6, i, i % 2 == 0)
        poner(i, 6, i % 2 == 0)
    # Módulo oscuro y espacio para el formato, que se escribe con cada máscara.
    poner(lado - 8, 8, True)
    for f, c in itertools.chain(*posiciones_de_formato(lado)):
        poner(f, c, False)
    # Versión desde la 7: BCH(18,6), una copia junto a cada búsqueda lejana.
    if version >= 7:
        bits = bch(version, 0x1F25)
        for i in range(18):
            poner(i // 3, lado - 11 + i % 3, bool(bits >> i & 1))
            poner(lado - 11 + i % 3, i // 3, bool(bits >> i & 1))
    return oscuro, fijo


def capacidad(version):
    # Palabras de datos con nivel M: los módulos libres en bytes, menos la corrección.
    libres = sum(fila.count(False) for fila in plantilla(version)[1])
    return libres // 8 - CORRECCION_POR_BLOQUE[version] * BLOQUES[version]


def bits_del_largo(version):
    # Indicador de largo en modo byte.
    return 8 if version < 10 else 16


def elegir_version(largo):
    for version in range(1, 41):
        if 4 + bits_del_largo(version) + 8 * largo <= 8 * capacidad(version):
            return version
    raise SystemExit("El texto no cabe en un QR de nivel M.")


def intercalar(bloques):
    # Una palabra de cada bloque por turno; los bloques cortos se agotan antes.
    return [p for fila in itertools.zip_longest(*bloques) for p in fila if p is not None]


def palabras_finales(datos, version):
    """Modo byte, largo, datos, terminador y relleno; luego bloques con su corrección, intercalados."""
    total = capacidad(version)
    bits = "0100" + format(len(datos), f"0{bits_del_largo(version)}b") + "".join(f"{b:08b}" for b in datos)
    bits += "0" * min(4, 8 * total - len(bits))
    bits += "0" * (-len(bits) % 8)
    palabras = [int(bits[i:i + 8], 2) for i in range(0, len(bits), 8)]
    palabras = (palabras + [0xEC, 0x11] * total)[:total]
    # Si no se reparten parejo, los últimos bloques llevan una palabra más.
    cantidad = BLOQUES[version]
    corto, largos = divmod(total, cantidad)
    bloques, inicio = [], 0
    for i in range(cantidad):
        fin = inicio + corto + (i >= cantidad - largos)
        bloques.append(palabras[inicio:fin])
        inicio = fin
    correcciones = [correccion(bloque, CORRECCION_POR_BLOQUE[version]) for bloque in bloques]
    return intercalar(bloques) + intercalar(correcciones)


def colocar(matriz, fijo, palabras):
    # Zigzag de a dos columnas desde abajo a la derecha, saltando la columna 6. Los bits que sobran quedan claros.
    lado = len(matriz)
    orden = []
    for n, derecha in enumerate(c if c > 6 else c - 1 for c in range(lado - 1, 0, -2)):
        filas = range(lado - 1, -1, -1) if n % 2 == 0 else range(lado)
        orden += [(f, c) for f in filas for c in (derecha, derecha - 1) if not fijo[f][c]]
    for (f, c), bit in zip(orden, "".join(f"{p:08b}" for p in palabras)):
        matriz[f][c] = bit == "1"


def enmascarar(base, fijo, mascara):
    regla = MASCARAS[mascara]
    matriz = [[m != (not fijo[f][c] and regla(f, c)) for c, m in enumerate(fila)] for f, fila in enumerate(base)]
    # Formato: nivel M (00) y máscara, con BCH(15,5) y la máscara 0x5412.
    bits = bch(mascara, 0x537) ^ 0x5412
    for copia in posiciones_de_formato(len(matriz)):
        for i, (f, c) in enumerate(copia):
            matriz[f][c] = bool(bits >> i & 1)
    return matriz


def penalizacion(matriz):
    """Las cuatro reglas de la norma (7.8.3). Gana la máscara con menos puntos."""
    puntos = 0
    for linea in matriz + list(zip(*matriz)):
        # 1. Cinco o más módulos seguidos del mismo color: 3, más 1 por cada uno sobre 5.
        for _, grupo in itertools.groupby(linea):
            largo = len(list(grupo))
            if largo >= 5:
                puntos += largo - 2
        # 3. Oscuro, claro, tres oscuros, claro, oscuro, con cuatro claros a un lado: 40. Fuera del símbolo es claro.
        texto = "0000" + "".join("1" if m else "0" for m in linea) + "0000"
        for hallazgo in re.finditer("(?=1011101)", texto):
            i = hallazgo.start()
            if texto[i - 4:i] == "0000" or texto[i + 7:i + 11] == "0000":
                puntos += 40
    # 2. Cada cuadro de 2×2 del mismo color: 3.
    for arriba, abajo in zip(matriz, matriz[1:]):
        puntos += 3 * sum(a == b == c == d for a, b, c, d in zip(arriba, arriba[1:], abajo, abajo[1:]))
    # 4. 10 por cada 5 % completo que la proporción de oscuros se aleja del 50 %.
    oscuros, total = sum(map(sum, matriz)), len(matriz) ** 2
    return puntos + 10 * (abs(20 * oscuros - 10 * total) // total)


def codificar(texto):
    """Matriz del QR (True es oscuro), su versión y la máscara elegida."""
    datos = texto.encode("utf-8")
    version = elegir_version(len(datos))
    base, fijo = plantilla(version)
    colocar(base, fijo, palabras_finales(datos, version))
    mascara = min(range(8), key=lambda m: penalizacion(enmascarar(base, fijo, m)))
    return enmascarar(base, fijo, mascara), version, mascara


def svg(matriz, texto):
    lado = len(matriz) + 2 * SILENCIO
    trazo = ""
    for f, fila in enumerate(matriz):
        c = SILENCIO
        for es_oscuro, grupo in itertools.groupby(fila):
            largo = len(list(grupo))
            if es_oscuro:
                trazo += f"M{c} {f + SILENCIO}h{largo}v1h-{largo}z"
            c += largo
    nombre = html.escape(texto)
    return "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {lado} {lado}" role="img" aria-label="{nombre}">',
        f"<title>{nombre}</title>",
        f'<rect width="{lado}" height="{lado}" fill="#fff"/>',
        f'<path fill="#000" shape-rendering="crispEdges" d="{trazo}"/>',
        "</svg>",
        "",
    ])


def main():
    texto = sys.argv[1] if len(sys.argv) > 1 else TEXTO
    salida = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else SALIDA
    matriz, version, mascara = codificar(texto)
    salida.parent.mkdir(parents=True, exist_ok=True)
    salida.write_text(svg(matriz, texto), encoding="utf-8")
    nombre = salida.relative_to(RAIZ) if salida.is_relative_to(RAIZ) else salida
    print(f"Versión {version}-M, máscara {mascara}, {len(matriz)}×{len(matriz)} módulos → {nombre}")


if __name__ == "__main__":
    main()
