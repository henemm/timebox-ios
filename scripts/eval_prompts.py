#!/usr/bin/env python3
"""
FocusBlox AI Prompt Evaluation mit Apple Foundation Models Python SDK.

Testet unsere echten Prompts (Kategorisierung, Zeitschätzung, Enrichment)
direkt gegen das On-Device-Modell — ohne Xcode/Simulator.

Vorteile gegenüber XCTest:
- Schnelleres Iterieren bei Prompt-Tuning
- Batch-Evaluierung mit vielen Test-Cases
- Einfacher A/B-Vergleich von Prompt-Varianten
- Token-Counting für Context-Window-Optimierung

Voraussetzungen:
  source .venv-fm/bin/activate
  python3 scripts/eval_prompts.py
"""

import asyncio
import json
import time
import apple_fm_sdk as fm


# ============================================================
# Test-Daten: Gleiche Cases wie in AITitleQualityTests.swift
# ============================================================

CATEGORIZATION_CASES = [
    # (input, expected_category, label)
    # --- Income ---
    ("Rechnung an Kunden schicken", "income", "Earn"),
    ("Quartalsbericht fertigstellen", "income", "Earn"),
    ("Bewerbung schreiben", "income", "Earn"),
    ("Meeting mit Chef vorbereiten", "income", "Earn"),
    ("Freelance-Projekt abrechnen", "income", "Earn"),
    # --- Maintenance ---
    ("Wohnung aufräumen", "maintenance", "Essentials"),
    ("Einkaufen gehen", "maintenance", "Essentials"),
    ("Zahnarzt anrufen", "maintenance", "Essentials"),
    ("Steuererklärung abgeben", "maintenance", "Essentials"),
    ("Auto zum TÜV bringen", "maintenance", "Essentials"),
    # --- Recharge ---
    ("Joggen gehen", "recharge", "Self Care"),
    ("Sauna besuchen", "recharge", "Self Care"),
    ("Neue Serie auf Netflix schauen", "recharge", "Self Care"),
    ("Meditation 20 Minuten", "recharge", "Self Care"),
    ("Gitarre üben", "recharge", "Self Care"),
    # --- Learning ---
    ("Swift-Kurs weitermachen", "learning", "Learn"),
    ("Buch über Produktivität lesen", "learning", "Learn"),
    ("WWDC-Session anschauen", "learning", "Learn"),
    ("Spanisch-Vokabeln lernen", "learning", "Learn"),
    ("Podcast über KI hören", "learning", "Learn"),
    # --- Giving Back ---
    ("Mama anrufen", "giving_back", "Social"),
    ("Geschenk für Sarahs Geburtstag kaufen", "giving_back", "Social"),
    ("Nachbarin beim Umzug helfen", "giving_back", "Social"),
    ("Abendessen mit Freunden organisieren", "giving_back", "Social"),
    ("Ehrenamt im Tierheim", "giving_back", "Social"),
    # --- Grenzfälle ---
    ("Kruder & Dorfmeister Tickets kaufen", "recharge", "Self Care"),
    ("Wolle waschen", "maintenance", "Essentials"),
    ("Pull Request reviewen", "income", "Earn"),
    ("Kindergeburtstag planen", "giving_back", "Social"),
    ("Erste-Hilfe-Kurs machen", "learning", "Learn"),
]

DURATION_CASES = [
    # (input, min_minutes, max_minutes, label)
    ("Mama anrufen", 5, 15, "5-15"),
    ("E-Mail an Chef schreiben", 5, 15, "5-15"),
    ("Termin beim Zahnarzt machen", 5, 5, "5"),
    ("Medikamente bestellen", 5, 15, "5-15"),
    ("Einkaufen gehen", 15, 30, "15-30"),
    ("Wohnung aufräumen", 30, 60, "30-60"),
    ("Wolle waschen", 15, 30, "15-30"),
    ("Paket zur Post bringen", 15, 15, "15"),
    ("Quartalsbericht schreiben", 30, 60, "30-60"),
    ("Pull Request reviewen", 15, 30, "15-30"),
    ("Bewerbung schreiben", 30, 60, "30-60"),
    ("Steuererklärung machen", 60, 60, "60"),
    ("Joggen gehen", 15, 30, "15-30"),
    ("Meditation 20 Minuten", 15, 30, "15-30"),
    ("30 Minuten Spanisch lernen", 30, 30, "30"),
    ("1 Stunde lesen", 60, 60, "60"),
]

ENRICHMENT_CASES = [
    # (input, expected_importance, expected_urgent, expected_energy)
    ("Steuererklärung abgeben", 3, False, "high"),
    ("Einkaufen gehen", 2, False, "low"),
    ("Dringend: Server ist down", 3, True, "high"),
    ("Gitarre üben", 1, False, "low"),
    ("Meeting mit CEO morgen", 3, True, "high"),
    ("Netflix schauen", 1, False, "low"),
    ("Bewerbung bis Freitag fertig", 3, True, "high"),
    ("Müll rausbringen", 2, False, "low"),
]


# ============================================================
# Prompt-Definitionen (exakt wie in Swift)
# ============================================================

CATEGORIZATION_INSTRUCTIONS = (
    "Du kategorisierst Aufgaben in genau eine Kategorie:\n"
    "- income: Arbeit, Geld verdienen, Karriere, Freelance, Rechnungen, Kunden, Berichte, Präsentationen, Code, Meetings\n"
    "- maintenance: Haushalt, Besorgungen, Reparaturen, Putzen, Einkaufen, Gesundheitstermine, Behörden, Steuern, Versicherungen\n"
    "- recharge: Sport, Erholung, Hobbys, Meditation, Wellness, Freizeit, Konzerte, Filme, Serien, Musik\n"
    "- learning: Lernen, Lesen, Kurse, Weiterbildung, Konferenzen (WWDC etc.), Vokabeln, Podcasts\n"
    "- giving_back: Familie, Freunde, Ehrenamt, Geschenke, soziale Events, Helfen\n\n"
    "Beispiele:\n"
    "  Quartalsbericht fertigstellen → income\n"
    "  Bewerbung schreiben → income\n"
    "  Pull Request reviewen → income\n"
    "  Steuererklärung abgeben → maintenance\n"
    "  WWDC-Session anschauen → learning\n"
    "  Gitarre üben → recharge\n"
    "  Kruder & Dorfmeister Tickets kaufen → recharge"
)

DURATION_INSTRUCTIONS = (
    "Estimate how long a task takes in minutes. Consider:\n"
    "- Quick calls/messages: 5-10 min\n"
    "- Simple errands (groceries, pickup): 15-30 min\n"
    "- Focused work (writing, coding): 30-60 min\n"
    "- Appointments (doctor, meeting): 30-60 min\n"
    "- Deep work (tax return, project): 60-120 min\n"
    "- Household chores: 15-45 min"
)

ENRICHMENT_INSTRUCTIONS = (
    "Du analysierst Task-Titel und leitest fehlende Attribute ab.\n\n"
    "Wichtigkeit (1-3):\n"
    "  1 = nice to have (Freizeit, Hobby, optional)\n"
    "  2 = should do (Routine, Haushalt, Einkaufen)\n"
    "  3 = must do (Pflichten, Deadlines, Finanzen, Bewerbungen, Gesundheit)\n\n"
    "Dringlichkeit: true wenn zeitkritisch (Termin, Frist, morgen, heute, bis [Datum])\n\n"
    "Kategorie: income (Geld verdienen), maintenance (Pflege/Haushalt), recharge (Erholung), learning (Lernen), giving_back (Helfen)\n\n"
    "Energie:\n"
    "  high = kognitive Tiefenarbeit (Steuererklärung, Bewerbung schreiben, Programmieren, Analyse, Berichte)\n"
    "  low = Routine ohne tiefes Nachdenken (Einkaufen, Putzen, Müll rausbringen, Gitarre üben)\n\n"
    "Beispiele:\n"
    "  Steuererklärung abgeben → importance: 3, urgent: false, category: maintenance, energy: high\n"
    "  Bewerbung schreiben → importance: 3, urgent: false, category: income, energy: high\n"
    "  Einkaufen gehen → importance: 2, urgent: false, category: maintenance, energy: low\n"
    "  Gitarre üben → importance: 1, urgent: false, category: recharge, energy: low\n"
    "  Server ist down → importance: 3, urgent: true, category: income, energy: high\n"
    "  Netflix schauen → importance: 1, urgent: false, category: recharge, energy: low\n\n"
    "Orientiere dich an den Attributen ähnlicher bestehender Tasks wenn vorhanden."
)


# ============================================================
# Generable-Klassen (Äquivalent zu Swift @Generable)
# ============================================================

@fm.generable
class CategorizedTask:
    category: str = fm.guide(
        "The task category",
        anyOf=["income", "maintenance", "recharge", "learning", "giving_back"]
    )
    confidence: str = fm.guide(
        "Confidence: high, medium, or low",
        anyOf=["high", "medium", "low"]
    )


@fm.generable
class EstimatedTask:
    duration_minutes: str = fm.guide(
        "Estimated duration in minutes",
        anyOf=["5", "15", "30", "60"]
    )
    confidence: str = fm.guide(
        "Confidence: high, medium, or low",
        anyOf=["high", "medium", "low"]
    )


@fm.generable
class TaskEnrichment:
    suggested_importance: int = fm.guide(
        "Importance 1-3: 1=nice to have, 2=should do, 3=must do"
    )
    suggested_urgent: bool = fm.guide(
        "Is this time-critical? true=urgent, false=not urgent"
    )
    suggested_task_type: str = fm.guide(
        "Category",
        anyOf=["income", "maintenance", "recharge", "learning", "giving_back"]
    )
    suggested_energy_level: str = fm.guide(
        "Cognitive energy: high for deep focus, low for routine",
        anyOf=["high", "low"]
    )


# ============================================================
# Evaluation Functions
# ============================================================

async def eval_categorization(instructions):
    """Teste Kategorisierung mit frischer Session pro Task (wie Production-Code)."""
    print("\n" + "=" * 60)
    print("KATEGORISIERUNG — Apple Intelligence On-Device (macOS 26.4)")
    print("=" * 60 + "\n")

    correct = 0
    errors = 0
    misses = []

    for task_input, expected, label in CATEGORIZATION_CASES:
        try:
            session = fm.LanguageModelSession(instructions=instructions)
            response = await session.respond(
                f"Categorize: {task_input}",
                generating=CategorizedTask
            )
            ok = response.category == expected
            if ok:
                correct += 1
                marker = "✓"
            else:
                marker = "✗"
                misses.append((task_input, expected, response.category, response.confidence))

            print(f"  [{marker}] {task_input}")
            if not ok:
                print(f"      Erwartet: {expected} ({label})  →  Got: {response.category} [{response.confidence}]")
        except Exception as e:
            errors += 1
            print(f"  [!] {task_input} — ERROR: {e}")

    total = len(CATEGORIZATION_CASES)
    pct = (correct / total) * 100
    print(f"\n  Score: {correct}/{total} ({pct:.0f}%) korrekt, {errors} Errors")

    if misses:
        print(f"\n  Fehlklassifizierungen:")
        for inp, exp, got, conf in misses:
            print(f"    - \"{inp}\": erwartet={exp}, bekommen={got} (Konfidenz: {conf})")

    return correct, total, errors


async def eval_duration(instructions):
    """Teste Zeitschätzung mit frischer Session pro Task (wie Production-Code)."""
    print("\n" + "=" * 60)
    print("ZEITSCHÄTZUNG — Apple Intelligence On-Device (macOS 26.4)")
    print("=" * 60 + "\n")

    correct = 0
    errors = 0
    misses = []

    for task_input, min_m, max_m, label in DURATION_CASES:
        try:
            session = fm.LanguageModelSession(instructions=instructions)
            response = await session.respond(
                f"Estimate duration: {task_input}",
                generating=EstimatedTask
            )
            dur = int(response.duration_minutes)
            in_range = min_m <= dur <= max_m
            if in_range:
                correct += 1
                marker = "✓"
            else:
                marker = "✗"
                misses.append((task_input, dur, f"{min_m}-{max_m}", response.confidence))

            print(f"  [{marker}] {task_input}: {dur} min [{response.confidence}]  (erwartet: {label})")
        except Exception as e:
            errors += 1
            print(f"  [!] {task_input} — ERROR: {e}")

    total = len(DURATION_CASES)
    pct = (correct / total) * 100
    print(f"\n  Score: {correct}/{total} ({pct:.0f}%) in Range, {errors} Errors")
    return correct, total, errors


async def eval_enrichment(instructions):
    """Teste Enrichment mit frischer Session pro Task (wie Production-Code)."""
    print("\n" + "=" * 60)
    print("ENRICHMENT — Apple Intelligence On-Device (macOS 26.4)")
    print("=" * 60 + "\n")

    correct_fields = 0
    total_fields = 0
    errors = 0

    for task_input, exp_imp, exp_urgent, exp_energy in ENRICHMENT_CASES:
        try:
            session = fm.LanguageModelSession(instructions=instructions)
            response = await session.respond(
                f"Task: {task_input}",
                generating=TaskEnrichment
            )

            imp_ok = response.suggested_importance == exp_imp
            urg_ok = response.suggested_urgent == exp_urgent
            nrg_ok = response.suggested_energy_level == exp_energy

            field_score = sum([imp_ok, urg_ok, nrg_ok])
            correct_fields += field_score
            total_fields += 3

            marker = "✓" if field_score == 3 else ("~" if field_score >= 2 else "✗")
            print(f"  [{marker}] {task_input} ({field_score}/3)")
            if not imp_ok:
                print(f"      Importance: erwartet={exp_imp}, got={response.suggested_importance}")
            if not urg_ok:
                print(f"      Urgent: erwartet={exp_urgent}, got={response.suggested_urgent}")
            if not nrg_ok:
                print(f"      Energy: erwartet={exp_energy}, got={response.suggested_energy_level}")
        except Exception as e:
            errors += 1
            total_fields += 3
            print(f"  [!] {task_input} — ERROR: {e}")

    pct = (correct_fields / total_fields) * 100 if total_fields > 0 else 0
    print(f"\n  Score: {correct_fields}/{total_fields} Felder ({pct:.0f}%) korrekt, {errors} Errors")
    return correct_fields, total_fields, errors


async def check_token_usage():
    """Nutze die neue tokenCount API um unser Context-Budget zu prüfen."""
    print("\n" + "=" * 60)
    print("TOKEN-ANALYSE — Context Window Budget")
    print("=" * 60 + "\n")

    model = fm.SystemLanguageModel()
    is_available, reason = model.is_available()

    if not is_available:
        print(f"  Modell nicht verfügbar: {reason}")
        return

    # Teste Token-Count für unsere Prompts
    prompts = {
        "Categorization Instructions": CATEGORIZATION_INSTRUCTIONS,
        "Duration Instructions": DURATION_INSTRUCTIONS,
        "Enrichment Instructions (DE)": ENRICHMENT_INSTRUCTIONS,
        "Typischer Task-Prompt": "Task: Steuererklärung abgeben\nTags: Finanzen\nFrist: in 3 Tagen",
        "Langer Task mit Kontext": (
            "Task: Quartalsbericht fertigstellen\n"
            "Tags: Arbeit, Reporting\n"
            "Frist: übermorgen\n"
            "Beschreibung: Q1 2026 Finanzbericht für Board Meeting\n\n"
            "Bestehende Tasks des Nutzers:\n"
            "- Rechnung schicken | Kat: income | Imp: 2 | Urg: not_urgent\n"
            "- Meeting vorbereiten | Kat: income | Imp: 3 | Urg: urgent\n"
            "- Einkaufen gehen | Kat: maintenance | Imp: 2 | Urg: not_urgent"
        ),
    }

    for name, text in prompts.items():
        try:
            count = model.token_count(text)
            print(f"  {name}: {count} Tokens")
        except AttributeError:
            print(f"  {name}: (token_count API nicht in Python SDK)")
            break
        except Exception as e:
            print(f"  {name}: Fehler — {e}")
            break

    try:
        ctx = model.context_size
        print(f"\n  Max Context Size: {ctx} Tokens")
    except AttributeError:
        print(f"\n  context_size Property nicht in Python SDK")
    except Exception as e:
        print(f"\n  Context Size Fehler: {e}")


async def main():
    print("╔══════════════════════════════════════════════════════════╗")
    print("║  FocusBlox AI Prompt Evaluation                        ║")
    print("║  Apple Foundation Models Python SDK v0.1.1              ║")
    print("║  macOS 26.4 — On-Device ~3B Parameter Model            ║")
    print("╚══════════════════════════════════════════════════════════╝")

    model = fm.SystemLanguageModel()
    is_available, reason = model.is_available()

    if not is_available:
        print(f"\n❌ Apple Intelligence nicht verfügbar: {reason}")
        print("   Stelle sicher dass Apple Intelligence in Systemeinstellungen aktiviert ist.")
        return

    print(f"\n✓ Apple Intelligence verfügbar")

    start = time.time()

    # Token-Analyse
    await check_token_usage()

    # Kategorisierung (frische Session pro Task — wie Production-Code)
    cat_correct, cat_total, cat_errors = await eval_categorization(CATEGORIZATION_INSTRUCTIONS)

    # Zeitschätzung (frische Session pro Task)
    dur_correct, dur_total, dur_errors = await eval_duration(DURATION_INSTRUCTIONS)

    # Enrichment (frische Session pro Task)
    enr_correct, enr_total, enr_errors = await eval_enrichment(ENRICHMENT_INSTRUCTIONS)

    elapsed = time.time() - start

    # Zusammenfassung
    print("\n" + "=" * 60)
    print("ZUSAMMENFASSUNG")
    print("=" * 60)
    print(f"\n  Kategorisierung: {cat_correct}/{cat_total} ({cat_correct/cat_total*100:.0f}%)")
    print(f"  Zeitschätzung:   {dur_correct}/{dur_total} ({dur_correct/dur_total*100:.0f}%)")
    print(f"  Enrichment:      {enr_correct}/{enr_total} ({enr_correct/enr_total*100:.0f}%)")
    print(f"\n  Laufzeit: {elapsed:.1f}s (vs. ~{(cat_total+dur_total+len(ENRICHMENT_CASES))*0.5:.0f}s in XCTest)")
    print(f"  Modell: macOS 26.4 On-Device (~3B Parameter)")


if __name__ == "__main__":
    asyncio.run(main())
