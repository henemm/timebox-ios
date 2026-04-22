# Feature-Analyse: Swipe-Actions in CoachView (#278)

## Kern-Erkenntnis

Echter Swipe (.swipeActions) geht NUR in List — CoachView nutzt ScrollView+VStack wegen
Drawer-Animation und gemischtem Content (Coaching-Texte, Buttons, Tasks). List-Umbau wäre
200-300 LoC und risikobehaftet.

## Empfehlung: Inline-Action-Chips statt Swipe

Sections mit showActions: false (Heute geplant, Offen geblieben) bekommen dieselben
schnellen Action-Buttons die Vorschläge bereits haben. Ergebnis: gleiche Geschwindigkeit
wie Swipe, kein architektureller Umbau.

## Scope: 1 Datei (CoachView.swift), ~50 LoC
