import Foundation

/// Tageszeit-Fenster fuer Affinitaets-Berechnung.
/// morning: 06-12, afternoon: 12-18, evening: 18-06 (uebernaechtigend)
enum DayPeriod: String, CaseIterable, Hashable {
    case morning   = "morning"    // 06:00–11:59
    case afternoon = "afternoon"  // 12:00–17:59
    case evening   = "evening"    // 18:00–05:59
}

/// Berechnetes Verhaltensprofil aus den letzten 28 Tagen.
/// Wird von BehavioralProfileService erzeugt und in-memory gecacht.
/// Alle Felder koennen nil sein wenn nicht genuegend Daten vorliegen.
struct BehavioralProfile {
    /// Zeitpunkt der Berechnung (fuer Cache-Validierung)
    let computedAt: Date

    /// Tageszeit-Affinitaet pro Kategorie.
    /// [Kategorie: [Tageszeit: Anteil 0.0-1.0]]
    /// nil = unter Mindestschwelle (< 10 abgeschlossene Tasks mit Kategorie)
    let categoryTimeAffinity: [TaskCategory: [DayPeriod: Double]]?

    /// Durchschnittliche Anzahl erledigter Tasks pro aktivem Tag.
    /// nil = unter Mindestschwelle (< 5 aktive Tage im Fenster)
    let avgTasksPerDay: Double?

    /// Durchschnittliche tatsaechliche Arbeitszeit pro aktivem Tag (Minuten).
    /// Basiert auf FocusBlock.taskTimes-Summen.
    /// nil = unter Mindestschwelle (< 5 aktive Tage im Fenster)
    let avgMinutesPerDay: Double?

    /// Schaetz-Genauigkeits-Faktor.
    /// 1.0 = perfekt, 1.5 = User braucht 50% laenger als geschaetzt.
    /// nil = unter Mindestschwelle (< 10 Tasks mit beiden Werten)
    let estimationFactor: Double?
}
