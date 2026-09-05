---
name: standardauswertung
description: Standard-Kennzahlen-Report für den Dreier50-Backtest (fdax.db) — eine Zeile pro Variante mit Handelstage, Anzahl Trades, Winrate, Breakeven, Punkte/Trade, Max DD%, plus P/L-Equity-Kurve als Chart. Verwenden, wenn der User "Standardauswertung", "mach die Standardauswertung", "Tagesabschluss-Auswertung" oder sinngemäß danach fragt.
user-invocable: true
---

# Standardauswertung (Dreier50 Backtest-Report)

Fester Kennzahlen-Report für den aktuellen Stand von `fdax.db`
(`C:\Users\mail\AppData\Roaming\MetaQuotes\Terminal\Common\Files\fdax.db`).
Eine Zeile pro aktiver Trade-Variante, plus eine P/L-Chart. Ziel: mit einem
Satz ("Mache die Standardauswertung!") jederzeit denselben, vergleichbaren
Report abrufen können — ohne dass ich (Claude) jedes Mal neu über Metrik-
Definitionen nachdenke oder das Chart neu designen muss.

## 1. Population ermitteln

Ohne weitere Angabe: **alle Varianten, die aktuell Entry-Trades haben.**

```sql
SELECT DISTINCT t.variantId
FROM trades t
JOIN events e ON e.eventId = t.eventId
WHERE e.isEntryEvent = 1
```

Für jede gefundene `variantId`:
- Metadaten aus `variants` (orderType, slPoints, tpPoints, abortBars, ...)
- Label aus `events.eventReason` für diese variantId (z.B. `IS_TOUCHED`,
  `IS_POSTBREAK_RETEST_TOUCHED`) — Anzeigename z.B. `IS_TOUCHED SL=10`.

Falls der User eine Einschränkung nennt ("nur SL=10", "nur POSTBREAK"),
diese Population entsprechend filtern statt alle Varianten zu zeigen.

## 2. Pro Variante: Trades laden

```sql
SELECT t.createTime, t.exitReason, t.profit
FROM trades t
JOIN events e ON e.eventId = t.eventId
WHERE e.isEntryEvent = 1 AND t.variantId = :variantId
ORDER BY t.createTime
```

**n (Anzahl Trades)** = nur Zeilen mit `exitReason IN ('EXIT_SL','EXIT_TP')`
(konsistent mit allen bisherigen Auswertungen in diesem Projekt). Trades mit
`EXIT_SESSION`/`EXIT_NOFILL` NICHT in n, aber ihre Anzahl als Fußnote pro
Zeile mit ausgeben (z.B. "+3 Session/NoFill"), nicht stillschweigend
weglassen.

## 3. Kennzahlen pro Zeile

- **Anzahl Handelstage im Testzeitraum**: `SELECT COUNT(DISTINCT DATE(startTime, 'unixepoch')) FROM patternCore WHERE timeFrame='M3'`.
  (`startTime` ist ein Unix-Timestamp — ohne den `'unixepoch'`-Modifier liefert
  SQLites `DATE()` stur `0`, das ist beim ersten Testlauf dieses Skills passiert.)
  Das ist die Abdeckung des zugrundeliegenden Datensatzes, nicht variantenspezifisch —
  deshalb für alle Zeilen derselbe Wert (einmal berechnen, in jede Zeile übernehmen).
- **Anzahl Trades**: n wie oben.
- **Winrate**: `Anzahl EXIT_TP / n * 100`.
- **Breakeven**: `slPoints / (slPoints + tpPoints) * 100` (aus der `variants`-Zeile).
- **Punkte/Trade**: `SUM(profit) / n` über die n Trades.
- **Max DD%**: siehe Abschnitt 4.

## 4. Max Drawdown (Punkte und %)

Kumulierte P/L-Kurve bilden (Trades nach `createTime` sortiert, laufende Summe
von `profit`). Max DD in Punkten = klassischer Peak-to-Trough auf dieser Kurve:

```python
peak = -inf
max_dd_points = 0
cum = 0
for profit in trades_sorted_by_time:
    cum += profit
    if cum > peak:
        peak = cum
    dd_points = peak - cum
    if dd_points > max_dd_points:
        max_dd_points = dd_points
```

**Max DD%: NICHT gegen den lokalen Peak normieren** — beim ersten Testlauf
dieses Skills (2026-09-05) hat das absurde Werte geliefert (1120%, 623%),
weil der Peak zum Zeitpunkt des größten Drawdowns oft klein war (System hat
kein Startkapital, die kumulierte Kurve pendelt anfangs nah um 0 oder ist erst
kurz zuvor knapp ins Plus gedreht — jeder Drawdown relativ zu einem kleinen
Peak wirkt riesig, ist aber nicht aussagekräftig).

Stattdessen: **% relativ zum Bruttogewinn** (Summe aller Punkte aus
`EXIT_TP`-Trades, unabhängig von Verlusten) — das ist immer stabil positiv,
solange mindestens ein Gewinner existiert:

```python
gross_profit = sum(p for ts, r, p in scored_trades if r == 'EXIT_TP')
max_dd_pct = max_dd_points / gross_profit * 100 if gross_profit > 0 else None
```

Ausgabe: `Max DD% = max_dd_pct` gerundet (Bedeutung: "der größte Rückschlag
entspricht X% des insgesamt erzielten Bruttogewinns"), oder **"n/a (kein
Bruttogewinn)"** falls `gross_profit == 0`. Max DD in Punkten IMMER zusätzlich
angeben — das bleibt die robustere Einzelzahl.

## 5. Tabelle ausgeben

Eine Markdown-Tabelle im Chat, eine Zeile pro Variante:

| Variante | Handelstage | n | Winrate | Breakeven | Pkt/Trade | Max DD |
|---|---|---|---|---|---|---|

Max-DD-Spalte als `-XX Pkt (YY%)` bzw. `-XX Pkt (n/a)`.

## 6. P/L-Chart (Artifact)

Eine Line-Chart der kumulierten P/L-Kurve (x = Trade-Index oder Zeit,
y = kumulierte Punkte), eine Linie pro Variante zum Vergleich.

**Persistentes Artifact statt Neuanlage bei jedem Aufruf:**
- Prüfen, ob `.claude/skills/standardauswertung/artifact_url.txt` existiert
  und eine URL enthält.
  - **Ja**: Artifact mit `action:"read"` und dieser `url` laden (Ausgangsbasis
    für die Bearbeitung), dann Datenarrays/Tabellen-Werte im HTML aktualisieren
    und mit `action:"publish"` + derselben `url` erneut veröffentlichen (selber
    Link bleibt stabil, kein neuer Artifact).
  - **Nein** (erster Lauf): `artifact-design`-Skill laden, neue Seite bauen
    (Designsprache: IBM Plex Sans/Mono, gedecktes Amber/Gold für Gewinn-Serien,
    gedecktes Brick-Rot als zweite Akzentfarbe, siehe frühere Artefakte dieser
    Session als Referenz — technisch/nüchterner Report-Stil, kein Marketing-Look).
    Nach dem Publish die zurückgegebene URL in
    `.claude/skills/standardauswertung/artifact_url.txt` speichern.
- Titel des Artifacts: "Dreier50 Standardauswertung" (stabil halten, nicht bei
  jedem Update ändern).
- Chart-Inhalt: Kennzahlen-Tabelle (wie Abschnitt 5) oben als Kacheln/Tabelle,
  darunter die P/L-Kurve. Reales Datum des Laufs (heutiges Datum) als
  Zeitstempel auf der Seite vermerken, damit erkennbar ist, welcher Stand
  gerade angezeigt wird.

## 7. Am Ende im Chat

Kurzer Text: Tabelle (Abschnitt 5) + Link zum Artifact. Kein langes Vor-Prosa,
das ist ein wiederkehrender, immer gleich strukturierter Abruf — direkt liefern.
