# Projekt: Handelssystem FDAX (Dreier50)

## Kontext
- Instrument: FDAX (DAX-Futures) an der EUREX, Broker: AMP
- Plattform: MetaTrader 5, Sprache: MQL5
- Ziel: Pattern-/Event-Engine zur Regelanalyse und -verfeinerung; erste belastbare Handelsregel finden
- Zwei EAs teilen sich den Code: `Backtester.mq5` (erzeugt Daten) und `Visualizer.mq5` (zeigt/inspiziert Daten am Chart)
- Persistenz: SQLite-Datenbank `FDAX.db` im MT5-Common-Folder; Tabellen: market, patternCore, patternDynamic, events, relations, variants, trades, trends
- Versionskontrolle: eigenes Git-Repo direkt in `Dreier50` (unabhängig vom unaufgeräumten Repo eine Ebene höher unter `MQL5\Experts`), Remote auf GitHub: `https://github.com/HelmutSt/WinnerMQL5` (Branch `main`). Sync zwischen den beiden Arbeitsrechnern (Köln/Düsseldorf) über `git pull`/`git push` statt Dropbox. `.ex5`-Kompilate, die SQLite-DB und Logs sind über `.gitignore` ausgeschlossen und müssen pro Rechner lokal neu erzeugt werden.

## Pipeline
Bars → Pattern → Events → Trade. Events sind immer Zustandsänderungen von Pattern (siehe `EventReason`).

Für die Regelfindung wird pro Event ein Markt-Snapshot geschrieben, dazu:
1. räumliche/zeitliche Einbettung: Relations zwischen Event und 15 ausgewählten Pattern-Slots (`relationSlots`-Enum, `EnumDefAndConvert.mqh`)
2. zeitliche Einbettung: die letzten 8–10 Events vor dem aktuellen Event als „Story"

Kernidee: Trade-Entscheidungen werden primär aus der Story (Sequenz vorheriger Events) abgeleitet, nicht aus einer Momentaufnahme von Trend/Dynamic/Volumen. Hintergrund: am FDAX konkurrieren Käufer und kurzfristige Gegenspieler („Shorties") um eine Marke; aus der Kursbewegung selbst (nicht aus Indikatoren) soll erkennbar sein, welche Partei gerade welche Strategie fährt.

## structEvent.eventDirection
`eventDirection` bestimmt die Order-Richtung des Trades und wird in `PatternManager.mqh::CalcEventDirection()` aus `patternDirection` + `eventReason` abgeleitet:

| eventReason | eventDirection relativ zu patternDirection |
|---|---|
| IS_CREATED | = patternDirection |
| IS_STRONGER_THAN_PREVIOUS | = patternDirection (Story-only, löst i.d.R. keinen Trade aus) |
| IS_NEAR_TOUCHED | = patternDirection |
| IS_TOUCHED | = patternDirection |
| IS_FAKE_BREAK | = patternDirection |
| IS_BROKEN | invertiert |
| IS_TREND_BREAK | invertiert |
| IS_POSTBREAK_RETEST_NEAR_TOUCHED | = patternDirection |
| IS_POSTBREAK_RETEST_TOUCHED | = patternDirection |
| IS_POSTBREAK_RETEST_FAKE_BREAK | = patternDirection |
| IS_POSTBREAK_RETEST_BROKEN | invertiert |

(Stand geprüft gegen Code, nicht nur Dokumentation — vorherige Version dieser Datei hatte `IS_POSTBREAK_RETEST_BROKEN` fälschlich als "= patternDirection" dokumentiert.)

## relationSlots (15 Slots, `EnumDefAndConvert.mqh`)
Pro qualifizierendem Event werden 15 Relations geschrieben (`EventManager.mqh::EvaluatePatternForSlots`), Slot 0 ist immer das auslösende Pattern selbst (`M3_EventOrigin`). Für die restlichen 14 Slots gilt:
- **SHORT/LONG-Suffix** = eigene Richtung des gefundenen Patterns (`p.core.direction`), NICHT die Preislage relativ zum Event.
- **M3-Slots ("Last", 1–6)**: zeitlich zuletzt entstandenes Pattern des jeweiligen Typs+Richtung (SoM/DREIER/HAMMER_BAR), unabhängig vom aktuellen Status (auch bereits `CLOSED`).
- **H1/D1-Slots ("Next", 7–14)**: räumlich nächstes Pattern des jeweiligen Typs+Richtung (DREIER/VTH/TANGENTE), ebenfalls unabhängig vom Status.
- Leere Slots (`patternId = NULL`) sind normal, wenn (noch) kein passendes Pattern existiert.

## structVariant.against (bool)
- `finalOrderDirection = against ? invert(eventDirection) : eventDirection`
- Wird aktuell nur für `IS_CREATED` per VRR mit beiden Werten (true/false) zugeordnet; bei allen anderen Events nur `against=false`.
- Bewusst keine Validierung/Fehlerbehandlung für andere Events (Einfachheit vor erster Regel).

## Abort-Logik (structTrade/structVariant.abortBars, vormals trailingAbortBars)
- Gilt nur im Zustand `TRADE_WAITING` (Order im Markt, noch kein Fill) — einheitlich für LIMIT, STOP und STOP TRAILING.
- Zählbasis: `currentBarIndex - createBarIndex >= abortBars` → Order canceln (`TradeManager.mqh::Abort_Setzen`).
- `abortBars = 0` bedeutet: Abort deaktiviert (Konvention, nicht -1).
- Exit-Reason: `EXIT_ABORT_WAITING` (LIMIT/STOP) bzw. `EXIT_ABORT_TRAILING` (STOP TRAILING).
- Betrifft NICHT die Laufzeit bereits gefüllter Trades (TRADE_RUNNING) — das regeln SL/TP/Positionsmanagement separat.

## Variants-Tabelle
- `structVariant` wird für jede VRR-Regel als volles kartesisches Produkt (delta × sl × tp × trailing × abortBars) einmalig vorab generiert (`EventManager.mqh::GenerateAllVariants`) und in eigene SQLite-Tabelle `variants` geschrieben (FK von `trades.variantId`).
- `variantId`-Kodierung: `vrrId*100000 + delta*10000 + sl*1000 + tp*100 + trailing*10 + abortBars` (`ComputeVariantId`).

## Aktueller Implementierungsstand
- Abort-nach-X-Bars, `against`-Inversion und volle Variants-Tabelle: implementiert und verifiziert.
- Grundfelder (events/trades/market/patternCore/patternDynamic) an Live-Daten verifiziert (Phase 2), zwei Bugs dabei gefunden und gefixt: `Visualizer.mq5` (7 veraltete Feldnamen), `structTrade.initialSLPrice/initialTPPrice` (nie gesetzt).
- Relations auf die echten 15 `relationSlots` umgestellt und verifiziert (Phase 3, `EventManager.mqh::EvaluatePatternForSlots`) — DREIER/VTH/HAMMER_BAR-Slots befüllen sich korrekt.
- Story (letzte 8–10 Events) ist weiterhin nicht implementiert.
- **TANGENTE-Erkennung ist ein bewusster Platzhalter** (`PatternManager.mqh`) und wird noch überarbeitet — die TANGENTE-bezogenen Relation-Slots (`H1_NEXT_TANGENTE_*`, `D1_NEXT_TANGENTE_*`) sind erst nach diesem Rework sinnvoll verifizierbar. Auffälligkeiten dort (z. B. nur eine Richtung vorhanden) sind aktuell erwartet, kein Bug.
- `Backtester.mq5` kompiliert fehlerfrei (0 Errors/0 Warnings).

## Roadmap (Gesamtplan)
1. Code sauber ziehen (Varianten generieren, in Tabelle ablegen) — ✅ erledigt
2. Anhand weniger Datensätze Feldkorrektheit prüfen (Grundfelder) — ✅ erledigt
3. Alles freischalten, EA über größeren Zeitraum laufen lassen — ⬅ aktuelle Phase (Relations auf 15 Slots umgestellt; Tangenten-Erkennung wird vor der finalen Verifikation noch überarbeitet)
4. Erste Regelfindung ausgehend von `M3_DREIER_IS_TOUCHED` mit `causedOppositeBreak = true`
5. Weitere, story-basierte Regeln

## Offene Punkte
- `VRRandERRadd.mqh::VRR_Add`: Parsing von `trailingAbortDistanceList` (Feld 9) nutzt noch eine verworfene `dummyCount`-Variable statt eines echten Counts — nicht im Rahmen des ersten Umbaus angefasst.
- TANGENTE-Erkennungsalgorithmus (`PatternManager.mqh`) muss neu entwickelt werden, bevor TANGENTE-bezogene Relation-Slots final verifiziert werden können.

## Zusammenarbeit
- Kleine, nachvollziehbare Schritte; bei mehrdeutigen Design-Entscheidungen nachfragen statt raten.
- Vor jeder "fertig"-Meldung: wenn möglich mit MetaEditor kompilieren und Ergebnis nennen (0 Errors/0 Warnings o.ä.), nicht nur den Code lesen.
- Riskante/destruktive Nebenwirkungen (z. B. gelöschte .ex5-Binaries durch Compile) immer transparent melden, auch wenn sie nicht beabsichtigt waren — kein Git-Netz vorhanden.
- Diese Datei bildet nur den *stabilen* Stand ab (Architektur, Konventionen, offene strukturelle Punkte) — Fortschritt einzelner Sessions gehört nicht hierher, sondern in die Konversation/Commits.
