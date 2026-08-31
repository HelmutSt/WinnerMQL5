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

## patternCore vs. patternDynamic — Feld-Konvention
- `patternCore` wird **einmalig per INSERT** geschrieben (`ToSQL()` in `Structures.mqh`), nie per UPDATE. Felder gehören hier nur rein, wenn ihr Wert bei Erzeugung feststeht und sich nie mehr ändert (z. B. `startTime`, `direction`, `validFrom`).
- `patternDynamic` wird bei **jedem** Event einer neuen Zeile hinzugefügt (`p.dynamic.ToSQL(patternId, eventId)`, `EventManager.mqh::OnEvent()`) — auch bei Story-Events, nicht nur bei Entry-Events. Lifetime-Fakten, die sich nach der Erzeugung ändern können (z. B. `status`, `breakTime`, `validUntil`), gehören hierhin.
- Jeder Pattern-Typ (DREIER, HAMMER_BAR, VTH, TANGENTE) feuert bei Erzeugung `EmitEvent(IS_CREATED, ...)`, damit jedes Pattern ab Erzeugung mindestens eine `patternDynamic`-Baseline-Zeile hat — Voraussetzung für As-of-Queries (`WHERE patternId=? AND eventId<=? ORDER BY eventId DESC LIMIT 1`).

## Rule-Induction-Strategie
- Kein pre-materialisierter "Monster-Join" (Trade+Event+Market+15×Relations+PatternCore/Dynamic+8-10×Story-Events+PatternCore/Dynamic, überschlagen ~1750-2000 Spalten). Stattdessen: Rule Induction läuft direkt über Claude mit SQL-Zugriff auf das normalisierte Schema, mit gezielten, schmalen Queries pro Hypothese.
- Konsequenz: keine Denormalisierung/Feld-Duplizierung in `relations`/`events` einbauen, um einen Join zu vereinfachen — bewusst verworfen zugunsten von As-of-Queries gegen `patternDynamic` (siehe oben).

## Pattern-Status-Lifecycle (OPEN/BROKEN/CLOSED)
- Drei Stati (`enum PatternStatus`, EnumDefAndConvert.mqh:43): `OPEN`, `BROKEN`, `CLOSED`. Kritischer Preis: bei LONG-Pattern `priceLow`, bei SHORT-Pattern `priceHigh` — Bruch = Kurs schließt jenseits davon.
- **Nur zwei Trigger für Statuswechsel**, und zwar nur für **DREIER und VTH**:
  - `OPEN → BROKEN`: echter Preis-Bruch (`IS_BROKEN`).
  - `BROKEN → CLOSED`: Postbreak-Retest bricht die (jetzt umgekehrte) Linie ein zweites Mal — "echter BackBreak" (`IS_POSTBREAK_RETEST_BROKEN`). Ein bloßes Antesten ohne Durchbruch (`IS_POSTBREAK_RETEST_TOUCHED`) ändert den Status nicht, das Pattern bleibt BROKEN.
- **HAMMER_BAR und TANGENTE springen weiterhin direkt `OPEN → CLOSED`** beim echten Bruch — kein BROKEN-Zwischenzustand, kein Postbreak-Retest-Tracking. Fake-Break-Erkennung (`IS_FAKE_BREAK`) bleibt bei allen vier Pattern-Typen unverändert erhalten, läuft dem Bruch-Check immer vorgelagert.
- **Bewusst verworfen: eine "Verdrängungsregel" (`isVerdraengt`).** Idee war, ein älteres DREIER derselben Richtung+TF automatisch CLOSED/inaktiv zu setzen, sobald ein neueres, gleichgerichtetes DREIER entsteht (z. B. ein LONG-DREIER-Tief, das nie mehr angetestet wird, bevor ein höheres Tief entsteht — siehe Zick-Zack/Aufwärtstrend-Analyse). Verworfen, weil rein spekulativ (keine beobachtete Preis-Aktion, nur eine Vermutung über Relevanz) und zu komplex. Passt auch nicht zur Rule-Induction-Strategie oben: Status soll rein deskriptiv bleiben (was ist faktisch passiert), Relevanz-Bewertung überlässt man der Rule Induction anhand der vollständigen, ungefilterten Daten.
- **Noch NICHT implementiert.** `UpdatePatternTouchStates()`'s `STATUS: BROKEN`-Zweig (Retest-Touch-Tracking, `priceExtremeAfterBreak`, `IS_POSTBREAK_RETEST_*`-Events) und `ClearBrokenButNotConfirmed()`'s CASE 2 ("echter BackBreak") existieren im Code bereits vollständig, werden aber nie erreicht: CASE 1 (echter Break) setzt den Status heute für alle Pattern-Typen einheitlich direkt auf `CLOSED` statt auf `BROKEN` (Code-Kommentar: `// BROKEN; Ausnahme!!!!`). Nötige Änderung: in `ClearBrokenButNotConfirmed`, CASE 1, für DREIER/VTH auf `status = BROKEN` umstellen statt `CLOSED`; HAMMER_BAR/TANGENTE bleiben bei `CLOSED`.

## Aktueller Implementierungsstand
- Abort-nach-X-Bars, `against`-Inversion und volle Variants-Tabelle: implementiert und verifiziert.
- Grundfelder (events/trades/market/patternCore/patternDynamic) an Live-Daten verifiziert (Phase 2), zwei Bugs dabei gefunden und gefixt: `Visualizer.mq5` (7 veraltete Feldnamen), `structTrade.initialSLPrice/initialTPPrice` (nie gesetzt).
- Relations auf die echten 15 `relationSlots` umgestellt und verifiziert (Phase 3, `EventManager.mqh::EvaluatePatternForSlots`) — DREIER/VTH/HAMMER_BAR/TANGENTE-Slots befüllen sich korrekt (D1_NEXT_TANGENTE bleibt strukturell immer leer, TANGENTE kommt nur auf M3/H1 vor).
- Story (letzte 8–10 Events) ist weiterhin nicht implementiert.
- **TANGENTE-Erkennung neu implementiert und verifiziert** (`PatternManager.mqh::DetectNewTangentePattern`/`TryFormTangente`/`CreateTangente`): 5-Bar-Fraktal-Swings, Mindestabstand 5 Bars zwischen den beiden Swing-Punkten (`TANGENTE_MIN_BARS_BETWEEN`), max. 3 gleichzeitig aktive Tangenten je TF+Richtung mit FIFO-Verdrängung (`TANGENTE_MAX_ACTIVE`), Bruch = Close jenseits der extrapolierten Linie über die bestehende `UpdatePatternTouchStates`/`ClearBrokenButNotConfirmed`-Maschinerie (kein Docht-Bruch). Läuft auf M3 und H1, beide Richtungen (LONG=Support/steigende Tiefs, SHORT=Resistance/fallende Hochs).
- **Visualizer-Rendering-Bug behoben**: `OBJ_TREND`-Objekte liefen per MT5-Default unendlich nach rechts weiter (`RAY_RIGHT=true`), unabhängig vom gesetzten Linienende — betraf VTH/DREIER/TANGENTE gleichermaßen. `RenderQueue.mqh` setzt jetzt `RAY_RIGHT`/`RAY_LEFT=false` für alle `OBJ_TREND`.
- **`validUntil` von `patternCore` nach `patternDynamic` verschoben** (siehe Konvention oben) und der bisherige TANGENTE-Sonderfall beim ersten echten Break (`ClearBrokenButNotConfirmed`) generisch für alle Pattern-Typen gemacht — vorher wurde `validUntil` bei DREIER/VTH nie aktualisiert. Visualizer nutzt für VTH/RANGE jetzt den neuesten `patternDynamic`-Snapshot (`pd.validUntil` wenn `status==CLOSED`, sonst `TimeCurrent()`) statt des nie aktualisierten `patternCore`-Werts.
- `Backtester.mq5` und `Visualizer.mq5` kompilieren fehlerfrei (0 Errors/0 Warnings).

## Roadmap (Gesamtplan)
1. Code sauber ziehen (Varianten generieren, in Tabelle ablegen) — ✅ erledigt
2. Anhand weniger Datensätze Feldkorrektheit prüfen (Grundfelder) — ✅ erledigt
3. Alles freischalten, EA über größeren Zeitraum laufen lassen — ⬅ aktuelle Phase (Relations auf 15 Slots umgestellt, TANGENTE-Erkennung neu implementiert, beides an Live-Daten verifiziert)
4. Erste Regelfindung ausgehend von `M3_DREIER_IS_TOUCHED` mit `causedOppositeBreak = true`
5. Weitere, story-basierte Regeln

## Offene Punkte
- `VRRandERRadd.mqh::VRR_Add`: Parsing von `trailingAbortDistanceList` (Feld 9) nutzt noch eine verworfene `dummyCount`-Variable statt eines echten Counts — nicht im Rahmen des ersten Umbaus angefasst.
- Pattern-Status-Lifecycle (siehe oben) ist entschieden, aber noch nicht implementiert.
- **Nächstes Thema (Stand 2026-08-31):** Auswahlregeln für die 14 räumlichen Relation-Slots (`EventManager.mqh::EvaluatePatternForSlots`) sollen diskutiert und verschärft werden — Ausgangsfrage des Users: die Event-Story beschreibt, welche "Züge" passiert sind, aber nicht *wo* auf dem Feld (eigener Strafraum vs. vor dem gegnerischen Tor). User bezog sich auf eine Fußballspieler-Analogie aus einer früheren, in dieser Session nicht sichtbaren Unterhaltung — beim Wiederaufnehmen ggf. nachfragen/erneut zeigen lassen.

## Zusammenarbeit
- Kleine, nachvollziehbare Schritte; bei mehrdeutigen Design-Entscheidungen nachfragen statt raten.
- Vor jeder "fertig"-Meldung: wenn möglich mit MetaEditor kompilieren und Ergebnis nennen (0 Errors/0 Warnings o.ä.), nicht nur den Code lesen.
- Riskante/destruktive Nebenwirkungen (z. B. gelöschte .ex5-Binaries durch Compile) immer transparent melden, auch wenn sie nicht beabsichtigt waren — kein Git-Netz vorhanden.
- Diese Datei bildet nur den *stabilen* Stand ab (Architektur, Konventionen, offene strukturelle Punkte) — Fortschritt einzelner Sessions gehört nicht hierher, sondern in die Konversation/Commits.
