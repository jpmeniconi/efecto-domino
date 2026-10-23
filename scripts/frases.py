"""Genera EfectoDomino/Bienvenida/FrasesDeInicio.swift desde content-drafts/frases-efecto-domino.xlsx.

Lee la hoja «Citas de autores»: toma las candidatas «Para inicio» y las marcadas en «Mis favoritas».
Si no hay favoritas, la app usa las 20 frases del prototipo de inicio.
Uso: python3 -I scripts/frases.py
"""
import pathlib
import xml.etree.ElementTree as ET
import zipfile

RAIZ = pathlib.Path(__file__).resolve().parent.parent
EXCEL = RAIZ / "content-drafts" / "frases-efecto-domino.xlsx"
SALIDA = RAIZ / "EfectoDomino" / "Bienvenida" / "FrasesDeInicio.swift"
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
HOJA = "Citas de autores"
# Las 20 frases del prototipo de inicio (content-drafts/inicio-referencia.html), en su orden.
PROTOTIPO = [
    "cita_021", "cita_065", "cita_042", "cita_063", "cita_005", "cita_085", "cita_015", "cita_071", "cita_050", "cita_003",
    "cita_011", "cita_074", "cita_023", "cita_033", "cita_079", "cita_097", "cita_030", "cita_048", "cita_059", "cita_002",
]


def texto_de(celda, compartidos):
    valor = celda.find("m:v", NS)
    if celda.get("t") == "s" and valor is not None:
        return compartidos[int(valor.text)]
    if celda.get("t") == "inlineStr":
        return "".join(t.text or "" for t in celda.iter("{%s}t" % NS["m"]))
    return valor.text if valor is not None else ""


def filas_de_la_hoja(libro):
    compartidos = []
    if "xl/sharedStrings.xml" in libro.namelist():
        for si in ET.fromstring(libro.read("xl/sharedStrings.xml")).findall("m:si", NS):
            compartidos.append("".join(t.text or "" for t in si.iter("{%s}t" % NS["m"])))
    nombres = [hoja.get("name") for hoja in ET.fromstring(libro.read("xl/workbook.xml")).find("m:sheets", NS)]
    datos = ET.fromstring(libro.read(f"xl/worksheets/sheet{nombres.index(HOJA) + 1}.xml"))
    for fila in datos.find("m:sheetData", NS).findall("m:row", NS):
        celdas = {}
        for celda in fila.findall("m:c", NS):
            columna = "".join(c for c in celda.get("r") if c.isalpha())
            celdas[columna] = texto_de(celda, compartidos).strip()
        yield celdas


def swift(texto):
    return '"' + texto.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    with zipfile.ZipFile(EXCEL) as libro:
        filas = list(filas_de_la_hoja(libro))
    encabezado = next(i for i, fila in enumerate(filas) if fila.get("A") == "ID")
    columnas = {nombre: col for col, nombre in filas[encabezado].items()}
    citas = [fila for fila in filas[encabezado + 1:] if fila.get("A", "").startswith("cita_")]

    def campo(fila, nombre):
        return fila.get(columnas[nombre], "")

    candidatas = [c for c in citas if campo(c, "Para inicio").lower().startswith("s")]
    favoritas = [campo(c, "ID") for c in citas if campo(c, "Mis favoritas") in ("1", "1.0", "TRUE", "true")]
    incluidas = {campo(c, "ID") for c in candidatas} | set(favoritas) | set(PROTOTIPO)

    lineas = [
        "// Generado por scripts/frases.py desde content-drafts/frases-efecto-domino.xlsx. No editar a mano.",
        "",
        "extension Frases {",
        "    static let candidatas: [Frase] = [",
    ]
    for cita in citas:
        if campo(cita, "ID") in incluidas:
            lineas.append(
                f"        Frase(id: {swift(campo(cita, 'ID'))}, texto: {swift(campo(cita, 'Cita en español'))}, autor: {swift(campo(cita, 'Autor / autora'))}),"
            )
    lineas += [
        "    ]",
        "",
        "    /// Marcadas en «Mis favoritas». Si está vacío, se usan las del prototipo.",
        "    static let favoritas: [String] = [" + ", ".join(swift(f) for f in favoritas) + "]",
        "",
        "    /// Las 20 del prototipo de inicio, en su orden.",
        "    static let prototipo: [String] = [" + ", ".join(swift(p) for p in PROTOTIPO) + "]",
        "}",
        "",
    ]
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text("\n".join(lineas), encoding="utf-8")
    print(f"{len(incluidas)} frases ({len(favoritas)} favoritas) → {SALIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
