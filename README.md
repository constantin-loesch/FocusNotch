# FocusNotch

Pomodoro-Timer als Dynamic Island für die MacBook-Notch – plus Desktop-Widget.

## Island
- **Immer sichtbar** links neben der Kamera: Start-Button und Zeit (ohne laufenden Timer die eingestellte Fokuszeit, z. B. 25:00).
- **Timer läuft:** Anhalten- und Überspringen-Button direkt neben der Zeit, Fortschrittsring rechts der Kamera.
- **Maus auf die Notch:** Island klappt auf – die Buttons bleiben an derselben Stelle und sind sofort klickbar.
  - Digitaluhr
  - Timer mit Pause/Weiter, Überspringen, Stoppen
  - **Heute:** Fokuszeit und Pausenzeit (live)
  - **Sessions:** Kästchen-Graph der letzten 13 Wochen – je kräftiger, desto mehr Sessions (skaliert automatisch auf deinen besten Tag)
- **Zahnrad:** Fokus-/Pausenlängen, lange Pause, **Farbe der App**, Auto-Pause, Ton, Beim Login starten, Statistik zurücksetzen.

## Widget
Klein: Zeit + Start/Pause (ganzes Widget ist der Button). Mittel: zusätzlich Überspringen/Stoppen, Fokus- und Pausenzeit von heute und der Sessions-Graph.
Hinzufügen: Rechtsklick auf den Schreibtisch → „Widgets bearbeiten…“ → „FocusNotch“.

## Bauen

    ./build.sh            # baut FocusNotch.app in diesem Ordner
    ./build.sh install    # zusätzlich nach /Applications kopieren und starten (empfohlen)

Benötigt nur die Xcode Command Line Tools.
