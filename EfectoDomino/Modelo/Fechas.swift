import Foundation

extension Calendar {
    /// Semanas de lunes a domingo, en español de Chile.
    static let obra: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        calendario.locale = Locale(identifier: "es_CL")
        calendario.timeZone = .current
        calendario.firstWeekday = 2
        calendario.minimumDaysInFirstWeek = 4
        return calendario
    }()
}

extension Date {
    var inicioDelDia: Date { Calendar.obra.startOfDay(for: self) }

    /// Lunes (00:00) de la semana de esta fecha.
    var lunes: Date {
        Calendar.obra.dateInterval(of: .weekOfYear, for: self)?.start ?? inicioDelDia
    }

    /// 1 = lunes … 7 = domingo.
    var diaSemana: Int {
        let domingoPrimero = Calendar.obra.component(.weekday, from: self)
        return domingoPrimero == 1 ? 7 : domingoPrimero - 1
    }

    /// Semana del plan en que cae esta fecha: 1 es la semana de `inicioObra`.
    func semanaDelPlan(desde inicioObra: Date) -> Int {
        max(0, inicioObra.dias(hasta: self) / 7) + 1
    }

    var diaDelMes: Int { Calendar.obra.component(.day, from: self) }

    var hora: Int { Calendar.obra.component(.hour, from: self) }

    var minuto: Int { Calendar.obra.component(.minute, from: self) }

    func mas(dias: Int) -> Date {
        Calendar.obra.date(byAdding: .day, value: dias, to: self) ?? self
    }

    func mas(minutos: Int) -> Date {
        addingTimeInterval(TimeInterval(minutos) * 60)
    }

    func a(_ hora: Int, _ minuto: Int = 0) -> Date {
        Calendar.obra.date(bySettingHour: hora, minute: minuto, second: 0, of: self) ?? self
    }

    func mismoDia(que otra: Date) -> Bool {
        Calendar.obra.isDate(self, inSameDayAs: otra)
    }

    /// Días de calendario entre dos fechas (no cuenta horas).
    func dias(hasta otra: Date) -> Int {
        Calendar.obra.dateComponents([.day], from: inicioDelDia, to: otra.inicioDelDia).day ?? 0
    }

    /// Fracción del día transcurrida (0…1).
    var fraccionDelDia: Double {
        timeIntervalSince(inicioDelDia) / 86_400
    }

    /// Redondea hacia arriba al siguiente cuarto de hora.
    var siguienteCuarto: Date {
        let partes = Calendar.obra.dateComponents([.hour, .minute], from: self)
        let minutos = (partes.hour ?? 0) * 60 + (partes.minute ?? 0)
        let redondeado = Int((Double(minutos) / 15).rounded(.up)) * 15
        return inicioDelDia.mas(minutos: redondeado)
    }
}

enum Formato {
    static let locale = Locale(identifier: "es_CL")
    static let iniciales = ["L", "M", "M", "J", "V", "S", "D"]

    private static let formatoHora: DateFormatter = {
        let formato = DateFormatter()
        formato.locale = locale
        formato.dateFormat = "HH:mm"
        return formato
    }()

    private static let formatoFecha: DateFormatter = {
        let formato = DateFormatter()
        formato.locale = locale
        formato.dateFormat = "EEE d MMM"
        return formato
    }()

    /// "19:30"
    static func hora(_ fecha: Date) -> String {
        formatoHora.string(from: fecha)
    }

    /// "06:30"
    static func hora(_ hora: Int, _ minuto: Int) -> String {
        String(format: "%02d:%02d", hora, minuto)
    }

    static let nombresDias = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]

    /// "los miércoles", "los sábados".
    static func cadaSemana(_ dia: Int) -> String {
        let nombre = nombresDias[dia - 1]
        return dia >= 6 ? "los \(nombre)s" : "los \(nombre)"
    }

    /// "lunes"
    static func dia(_ fecha: Date) -> String {
        fecha.formatted(.dateTime.weekday(.wide).locale(locale))
    }

    /// "Viernes 23"
    static func diaConNumero(_ fecha: Date) -> String {
        "\(dia(fecha).conMayuscula) \(fecha.diaDelMes)"
    }

    /// "sáb 28 nov"
    static func fechaConDia(_ fecha: Date) -> String {
        formatoFecha.string(from: fecha).replacingOccurrences(of: ".", with: "")
    }

    /// "Hoy", "Mañana", "Ayer" o "Viernes 23".
    static func diaRelativo(_ fecha: Date, ahora: Date) -> String {
        switch ahora.dias(hasta: fecha) {
        case 0: "Hoy"
        case 1: "Mañana"
        case -1: "Ayer"
        default: diaConNumero(fecha)
        }
    }

    static func dias(_ cantidad: Int) -> String {
        cantidad == 1 ? "1 día" : "\(cantidad) días"
    }
}

extension String {
    var conMayuscula: String { prefix(1).uppercased() + dropFirst() }
}
