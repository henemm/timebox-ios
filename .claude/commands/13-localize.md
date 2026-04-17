# Lokalisierung pruefen/hinzufuegen

Starte den `localizer` Agenten aus `.agent-os/agents/localizer.md`.

**Anfrage:** $ARGUMENTS

---

**Injizierte Standards:**
- `.agent-os/standards/global/documentation-rules.md`
- `.agent-os/standards/swiftui/localization.md`

**Anweisung:**

1. Finde hardcoded Strings (falls keine spezifische Anfrage)
2. Waehle passende Lokalisierungsmethode
3. Fuge Uebersetzungen hinzu
4. Teste Build
5. Gib Test-Anweisungen fuer alle Sprachen

**Qualitaet:** Natuerlich klingende Texte, konsistente Terminologie!

## State-Tracking

**Nach erfolgreicher Ausfuehrung** im Workflow registrieren:

```bash
python3 .claude/hooks/workflow.py mark-localize
```

Dies ist **PFLICHT** — der bash_gate Hook blockiert git commit ohne dieses Flag.
Falls keine User-facing Strings betroffen sind:
```bash
python3 .claude/hooks/workflow.py set-field no_user_strings true
```
