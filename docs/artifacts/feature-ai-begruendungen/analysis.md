# Feature #234: AI-Begründungen für Coach-Vorschläge — Analyse

## User-Erwartung
- Der Coach erklärt in **einem natürlichen Satz** warum ein Task jetzt passt
- Maximal eine Zeile, wie eine freundliche Nebenbemerkung
- Soll persönlich sein ("du erledigst Code-Tasks morgens") nicht generisch ("hohe Priorität")
- Aha-Moment: App sagt etwas über mich das stimmt, aber mir nicht bewusst war
- Fallback auf älteren Geräten: regelbasierter Satz, kein leeres Loch
- Nervt wenn: zu lang, generisch, belehrend, oder alle Sätze gleich klingen

## Technische Analyse
- Bestehend: `reasonText()` und `groupReasonText()` — deterministische Templates
- Pattern: `SuccessStoryService` als Vorbild (Plain-Text AI-Antwort, Fallback)
- Kontext verfügbar: BehavioralProfile, freie Slots, Tags, Meeting-Load, Tageszeit
- Scope: ~4 Dateien, ~140 LoC — neuer AICoachReasonService + Anpassungen

## Offene Entscheidung
Pro Task (individuell) oder pro Gruppe (wie heute)?
→ Empfehlung: Pro Task, da die Beispiele individuelle Sätze zeigen.
