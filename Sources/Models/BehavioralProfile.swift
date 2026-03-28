import Foundation

/// Tageszeit-Fenster für Affinitäts-Berechnung.
/// morning: 06-12, afternoon: 12-18, evening: 18-06 (übernächtigend)
enum DayPeriod: String, CaseIterable, Hashable {
    case morning   = "morning"    // 06:00–11:59
    case afternoon = "afternoon"  // 12:00–17:59
    case evening   = "evening"    // 18:00–05:59
}

/// Meeting-Dichte eines Tages.
/// Nur non-allDay CalendarEvents zaehlen als "Meeting".
enum MeetingLoad: String, CaseIterable, Hashable {
    case low    // 0-2 Meetings/Tag
    case medium // 3-4 Meetings/Tag
    case high   // 5+ Meetings/Tag
}

/// Ein Cluster von chronisch verschobenen Tasks mit gemeinsamen Merkmalen.
struct ProcrastinationPattern: Equatable {
    /// Die gemeinsame Kategorie dieses Clusters (nil = unkategorisiert).
    let category: TaskCategory?
    /// Anzahl Tasks in diesem Cluster.
    let taskCount: Int
    /// Durchschnittlicher rescheduleCount der Tasks im Cluster.
    let avgRescheduleCount: Double
    /// Durchschnittliche Importance der Tasks im Cluster (nil = keine importance gesetzt).
    let avgImportance: Double?
}

/// Berechnetes Verhaltensprofil aus den letzten 28 Tagen.
/// Wird von BehavioralProfileService erzeugt und in-memory gecacht.
/// Alle Felder können nil sein wenn nicht genügend Daten vorliegen.
struct BehavioralProfile {
    /// Zeitpunkt der Berechnung (für Cache-Validierung)
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

    /// Durchschnittliche Task-Completion pro Meeting-Dichte.
    /// Nur Buckets mit >= 3 Tagen; fehlende Buckets = nicht genug Daten.
    /// nil = weniger als 5 Tage mit sowohl Tasks als auch Kalender-Daten.
    let capacityByMeetingLoad: [MeetingLoad: Double]?

    /// Verschiebungs-Muster: Cluster von Tasks mit rescheduleCount >= 3.
    /// Sortiert nach taskCount absteigend.
    /// nil = weniger als 3 Tasks mit rescheduleCount >= 3.
    let procrastinationPatterns: [ProcrastinationPattern]?
}
