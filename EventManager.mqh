//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __EVENTMANAGER_MQH__
#define __EVENTMANAGER_MQH__

#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"

struct structVariantRoutingRule
  {
   int               vrrId;
   string            eventType;
   OrderType         orderType;
   bool              against;
   bool              twoUnitMode;    // FreiKauf
   double            deltaList[10];
   int               deltaCount;
   double            slList[10];
   int               slCount;
   double            tpList[10];
   int               tpCount;
   double            trailingList[10];
   int               trailingCount;
   double            trailingAbortDistanceList[10];
   int               abortBarsList[10];   // 0 = kein Abort
   int               abortBarsCount;

   void              Init()
     {
      eventType   = "";
      orderType   = LIMIT;
      against     = false;
      twoUnitMode = false;
      abortBarsCount = 0;
      for(int i=0; i<10; i++)
        {
         deltaList[i]                 = EMPTY_VALUE;
         slList[i]                    = EMPTY_VALUE;
         tpList[i]                    = EMPTY_VALUE;
         trailingList[i]              = EMPTY_VALUE;
         trailingAbortDistanceList[i] = EMPTY_VALUE;
         abortBarsList[i]             = 0;
        }
     }
  };

static string slotNames[15] =
  {
   "M3_EventOrigin",           //  0  → Pattern, der den Event ausgelöst hat (Trigger)

   "M3_Last_SoM_SHORT",        //  1  → zeitlich letztes M3-SoM-Pattern, direction==SHORT
   "M3_Last_DREIER_SHORT",     //  2  → zeitlich letzter M3-DREIER, direction==SHORT
   "M3_Last_HAMMER_BAR_SHORT", //  3  → zeitlich letzter M3-HAMMER_BAR, direction==SHORT
   "M3_Last_HAMMER_BAR_LONG",  //  4  → zeitlich letzter M3-HAMMER_BAR, direction==LONG
   "M3_Last_DREIER_LONG",      //  5  → zeitlich letzter M3-DREIER, direction==LONG
   "M3_Last_SoM_LONG",         //  6  → zeitlich letztes M3-SoM-Pattern, direction==LONG

   "H1_NEXT_DREIER_SHORT",     //  7  → räumlich nächster H1-DREIER, direction==SHORT
   "H1_NEXT_VTH_SHORT",        //  8  → räumlich nächstes H1-VTH, direction==SHORT
   "H1_NEXT_TANGENTE_SHORT",   //  9  → räumlich nächste H1-TANGENTE, direction==SHORT
   "H1_NEXT_DREIER_LONG",      // 10  → räumlich nächster H1-DREIER, direction==LONG
   "H1_NEXT_VTH_LONG",         // 11  → räumlich nächstes H1-VTH, direction==LONG
   "H1_NEXT_TANGENTE_LONG",    // 12  → räumlich nächste H1-TANGENTE, direction==LONG

   "D1_NEXT_TANGENTE_SHORT",   // 13  → räumlich nächste D1-TANGENTE, direction==SHORT
   "D1_NEXT_TANGENTE_LONG"     // 14  → räumlich nächste D1-TANGENTE, direction==LONG
  };
//+------------------------------------------------------------------+
class CEventManager
  {
private:
   structVariantRoutingRule variantRoutingRule[100];
   int                      variantRoutingCount;


   int               nextRelationId;
   int               nextVariantId;
   int               nextTradeId;
   int               nextVrrId;


   struct structSlot
     {
      int            patternId;
      double         distance;
      string         slotName;
     };

   structRelation        relations[15];


public:
   // ------------------------------- c o n s t r u c t o r -------------------------
   void                CEventManager() {     };
   // ------------------------------------------------------------------------------
   bool              Init()
     {
      nextTradeId = 0;
      nextVariantId = 0;
      nextRelationId = 0;
      nextVrrId = 1;

      // eventType                         orderType against twoUM delta  sl       tp        trailing trailingAbort  -Bars
      // ------------------------------------|------|------|------|------|------|------------|--------|----------|---------|
      //          M1 HAMMER
      // VRR_Add("M1_HAMMER_IS_BAR_CREATED     STOP    -      -      1     10      50,70,100    10         -           -  ");
      // VRR_Add("M1_HAMMER_IS_BAR_BREAK       STOP    X      -      1     10      50,70,100    10         -           -  ");

      //          M3 DREIER
      VRR_Add("M3_DREIER_IS_TOUCHED                   LIMIT   -      -      1     10,20       30         0         -           -  ");
      VRR_Add("M3_DREIER_IS_POSTBREAK_RETEST_TOUCHED  LIMIT   -      -      1     10,20       30         0         -           -  ");   // HYP2
      // VRR_Add("M3_DREIER_IS_FAKE_BREAK      TRAIL   -      -      1     10       50,70,100    10         -           -  ");
      // VRR_Add("M3_DREIER_IS_BROKEN          LIMIT   X      -      1     10       50,70,100    10         -           -  ");
      // VRR_Add("M3_DREIER_IS_RETOUCHED       LIMIT   X      -      1     10       50,70,100    10         -           -  ");

      // M3 HAMMER
      // VRR_Add("M3_HAMMER_BAR_IS_CREATED     STOP    -      -      1     10       50,70,100    10         -           -  ");
      // VRR_Add("M3_HAMMER_BAR_IS_BREAK       STOP    X      -      1     10       50,70,100    10         -           -  ");

      GenerateAllVariants();

      return true;
     }
   // ------------------------------------------------------------------------------
   double            NearThreshold()
     {
      double atr = engine.market.atrM3;   // du hast dieses Feld bereits

      double nt = 0.2 * atr;
      if(nt < 2.0)
         nt = 2.0;
      return nt;;
     }

   // ############################################################################
   // ### O n E v e n t ############################################################
   // ############################################################################
   void              OnEvent(structEvent &ev)
     {
      // Event Type   z.B. "M3_DREIER_BROKEN"
      string eventTypeStr = TimeFrameToString(ev.patternTF) + "_" +
                            EnumToString(ev.patternType) + "_" +
                            EnumToString(ev.eventReason);
      structPattern p = patternManager.Get(ev.patternId);

      // prüfen ob ...
      ev.isEntryEvent = EventShouldCreateTrades(eventTypeStr);

      // TEST HYP4-Formation: nur 1. Touch eines M3-DREIER, das waehrend der
      // Formation eines gleichgerichteten H1-DREIER entstanden ist.
      // Live-Scan zum Touch-Zeitpunkt (HasH1FormationParent), NICHT das bei
      // M3-Erzeugung eingefrorene h1FormationParentId-Feld - der H1-DREIER
      // ist bei M3-Erzeugung oft noch gar nicht in patterns[] eingetragen.
      // IS_POSTBREAK_RETEST_TOUCHED (HYP2) wird als Erweiterung von HYP4
      // behandelt: gleiche H1-Formation-Bedingung, aber der "1. Touch"-Zaehler
      // muss postBreakRetestTouches sein (der Retest-Zaehler nach dem Bruch),
      // nicht touches (der Vorbruch-Zaehler) - sonst wird das falsche Feld geprueft.
      int touchCountForEntry = (ev.eventReason == IS_POSTBREAK_RETEST_TOUCHED)
                                ? p.dynamic.postBreakRetestTouches
                                : p.dynamic.touches;

      if(ev.isEntryEvent &&
         (touchCountForEntry != 1 || !patternManager.HasH1FormationParent(p.core)))
         ev.isEntryEvent = false;

      // 1. Event schreiben (für AuslösendeEvents UND für StoryEvents)
      DBExecute(__FUNCTION__, ev.ToSQL());

      // 2. PatternDynamic at Event schreiben
      DBExecute(__FUNCTION__, p.dynamic.ToSQL(ev.patternId, ev.eventId));

      if(!ev.isEntryEvent)   // weiter nur wenn ENTRY
         return;

      // 4. Market at Event schreiben
      DBExecute(__FUNCTION__, engine.market.ToSQL(ev.eventId));

      // 5. Räumliche Einbettung - RelationListe erstellen, füllen und schreiben
      BuildRelationsListForEvent(ev);
      FillRelationsListForEvent(ev);
      
      // 4. Trades
      GenerateTradesForEvent(ev);

     };

private:
   // ------------------------------------------------
   void              BuildRelationsListForEvent(const structEvent &ev)
     {

      // Liste der relations initialisieren
      for(int i=0; i<15; i++)
        {
         relations[i].Init();
         //
         relations[i].relationId = nextRelationId++;
         relations[i].eventId    = ev.eventId;
         relations[i].patternId  = -1;
         relations[i].slotName   = slotNames[i];      // noch nicht gefunden
         relations[i].priceDistance = DBL_MAX; // für suche nach nahestem
        }

      // Slot 0: M3-Origin setzen
      if(ev.patternId != -1)
        {
         relations[0].patternId = ev.patternId;
         relations[0].priceDistance = 0;
        }

      // Slots 1-14: rückwärts über alle bisher bekannten Patterns
      // (patternId steigt mit Erzeugungszeitpunkt -> absteigend iterieren = zeitlich rückwärts,
      //  wichtig für die "Last"-Slots: erster Treffer je Slot ist automatisch der zeitlich letzte)
      int patternCount = patternManager.GetCount();
      for(int i = patternCount - 1; i >= 0; i--)
        {
         structPattern p = patternManager.Get(i);
         EvaluatePatternForSlots(ev, p);
        };
     }; // end sub
   // -----------------------------------------------------
   void              FillRelationsListForEvent(structEvent &ev)
     {
      // Liste der relations mit Daten füllen und ausgeben
      for(int i=0; i<15; i++)
        {
         structRelation rel = relations[i];
         FillRelationSlot(rel, ev);
         DBExecute(__FUNCTION__, rel.ToSQL());
        };
     }; // end sub
   // -----------------------------------------------------
   // Slot füllen, wenn noch leer (relIdx zählt als "leer" bei priceDistance==DBL_MAX)
   void              SetIfEmpty(int relIdx, int patternId, double distance)
     {
      if(relations[relIdx].priceDistance == DBL_MAX)
        {
         relations[relIdx].patternId     = patternId;
         relations[relIdx].priceDistance = distance;
        }
     }
   // Slot mit dem räumlich nächsten Pattern belegen (kleinste priceDistance gewinnt)
   void              SetIfNearer(int relIdx, int patternId, double distance)
     {
      if(distance < relations[relIdx].priceDistance)
        {
         relations[relIdx].patternId     = patternId;
         relations[relIdx].priceDistance = distance;
        }
     }
   // ------------------------------------------------
   // Prüft ein einzelnes Pattern gegen alle 14 Nicht-Origin-Slots (1-14).
   // Wird absteigend nach patternId (= zeitlich rückwärts) aufgerufen:
   // M3-Slots (1-6, "Last")   -> erster Treffer je Slot ist automatisch der zeitlich letzte (SetIfEmpty)
   // H1/D1-Slots (7-14, "Next") -> räumlich nächster gewinnt, unabhängig von der Aufrufreihenfolge (SetIfNearer)
   // ------------------------------------------------
   void              EvaluatePatternForSlots(const structEvent &ev, const structPattern &p)
     {
      // Origin-Slot überspringen
      if(p.core.patternId == relations[0].patternId)
         return;

      // Richtungslose Patterns können keinem SHORT/LONG-Slot zugeordnet werden
      if(p.core.direction != LONG && p.core.direction != SHORT)
         return;

      bool isShort = (p.core.direction == SHORT);

      // ---------------------------------------------------------
      // Räumliche Distanz (für "Next"-Slots und zur Doku bei "Last"-Slots)
      // ---------------------------------------------------------
      double startPrice   = 0.0;
      double nominalPrice = 0.0;
      double atr          = 0.0;

      DistanceAndAtr(p, startPrice, nominalPrice, atr);
      double distance = MathAbs(startPrice - ev.eventPrice);

      // ---------------------------------------------------------
      // M3 – "Last" Slots (1-6): zeitlich letztes Pattern je Typ+Richtung
      // ---------------------------------------------------------
      if(p.core.timeFrame == PERIOD_M3)
        {
         if(p.dynamic.isStartOfMove)
            SetIfEmpty(isShort ? 1 : 6, p.core.patternId, distance);   // M3_Last_SoM_SHORT/LONG

         if(p.core.type == DREIER)
            SetIfEmpty(isShort ? 2 : 5, p.core.patternId, distance);   // M3_Last_DREIER_SHORT/LONG

         if(p.core.type == HAMMER_BAR)
            SetIfEmpty(isShort ? 3 : 4, p.core.patternId, distance);   // M3_Last_HAMMER_BAR_SHORT/LONG
        }

      // ---------------------------------------------------------
      // H1 – "Next" Slots (7-12): räumlich nächstes Pattern je Typ+Richtung
      // (auch geschlossene Patterns bleiben als Preis-Level relevant, z.B. gebrochener
      //  Widerstand als neue Unterstützung)
      // ---------------------------------------------------------
      if(p.core.timeFrame == PERIOD_H1)
        {
         if(p.core.type == DREIER)
            SetIfNearer(isShort ? 7 : 10, p.core.patternId, distance);  // H1_NEXT_DREIER_SHORT/LONG

         if(p.core.type == VTH)
            SetIfNearer(isShort ? 8 : 11, p.core.patternId, distance);  // H1_NEXT_VTH_SHORT/LONG

         if(p.core.type == TANGENTE)
            SetIfNearer(isShort ? 9 : 12, p.core.patternId, distance);  // H1_NEXT_TANGENTE_SHORT/LONG
        }

      // ---------------------------------------------------------
      // D1 – "Next" Slots (13-14): räumlich nächste Tangente je Richtung
      // ---------------------------------------------------------
      if(p.core.timeFrame == PERIOD_D1 && p.core.type == TANGENTE)
         SetIfNearer(isShort ? 13 : 14, p.core.patternId, distance);   // D1_NEXT_TANGENTE_SHORT/LONG
     };
   // --------------------------------------------------------------
   void              FillRelationSlot(structRelation &r, const structEvent &ev)
     {
      // ---------------------------------------------------------
      // 1. Kein Pattern → neutrale Relation
      // ---------------------------------------------------------
      if(r.patternId < 0)
         return;

      // ---------------------------------------------------------
      // 2. Pattern laden
      // ---------------------------------------------------------
      structPattern p = patternManager.GetById(r.patternId);

      // ---------------------------------------------------------
      // 3. BarIndex IM Timeframe des Patterns
      // ---------------------------------------------------------
      int barIndex = 0;

      switch(p.core.timeFrame)
        {
         case PERIOD_M3:
            barIndex = engine.market.barIndexM3;
            break;
         case PERIOD_H1:
            barIndex = engine.market.barIndexH1;
            break;
         case PERIOD_D1:
            barIndex = engine.market.barIndexD1;
            break;
         default:
            barIndex = engine.market.barIndexM3;
            break;
        }

      // ---------------------------------------------------------
      // 4. StartPrice, NominalPrice, ATR
      // ---------------------------------------------------------
      double startPrice = 0.0;
      double nominal    = 0.0;
      double atr        = 0.0;

      DistanceAndAtr(p, startPrice, nominal, atr);

      // ---------------------------------------------------------
      // 5. UNIVERSAL: priceDistance
      // ---------------------------------------------------------
      r.priceDistance = MathAbs(ev.eventPrice - startPrice);

      // ---------------------------------------------------------
      // 6. Zeitliche Distanz (IM TF des Patterns!)
      // ---------------------------------------------------------
      r.barsSinceStart = barIndex - p.core.startBarIndex;

      if(p.dynamic.breakBarIndex >= 0)
         r.barsSinceBreak = barIndex - p.dynamic.breakBarIndex;
      else
         r.barsSinceBreak = 0;

      // ---------------------------------------------------------
      // 7. Räumliche Distanz
      // ---------------------------------------------------------
      r.priceDistanceToBreakLevel        = MathAbs(ev.eventPrice - startPrice);
      r.priceDistanceExtremeBeforeBreak  = MathAbs(ev.eventPrice - p.dynamic.priceExtremeBeforeBreak);
      r.priceDistanceExtremeAfterBreak   = MathAbs(ev.eventPrice - p.dynamic.priceExtremeAfterBreak);


      // flags ----------------------------
      // OriginPattern
      r.isOriginPattern = (ev.patternId == p.core.patternId);

      // InPatternNow
      r.isInPatternNow =
         (ev.eventPrice >= p.core.priceLow &&
          ev.eventPrice <= p.core.priceHigh);

      // TouchingNow: gleiche Bedingung wie die Touch-Detektion in UpdatePatternTouchStates()
      // (dort feuert IS_TOUCHED bei distNominal<=0, nicht bei exakter Gleichheit mit priceLow/priceHigh -
      // der Tick kann den Nominal-Preis schon uebersprungen haben)
      double distNominalNow = (ev.eventPrice - nominal) * p.core.direction;
      // BROKEN: Retest kommt von der anderen Seite, gleiche Vorzeichenumkehr wie dort (Zeile "distNominal = -distNominal;")
      if(p.dynamic.status == BROKEN)
         distNominalNow = -distNominalNow;
      r.isTouchingNow = (distNominalNow <= 0);

      // NearTouchingNow (0.2 ATR als Beispiel)
      double distLow  = MathAbs(ev.eventPrice - p.core.priceLow);
      double distHigh = MathAbs(ev.eventPrice - p.core.priceHigh);

      r.isNearTouchingNow =
         (distLow  <= 10 ||
          distHigh <= 10);

      // BreakingNow = Status BROKEN + Nähe zum BreakLevel (= StartPrice)
      double breakDelta = MathAbs(ev.eventPrice - startPrice);
      bool   nearBreak  = (breakDelta <= 0.5 * atr);

      r.isBreakingNow =
         (p.dynamic.status == BROKEN && nearBreak);

      // Nur Tangenten
      if(p.core.type == TANGENTE)
        {
         // Tangenten-Felder
         r.eventSlopeRelation = p.core.priceSlopePerBar;  // echte Slope, DREIER/VTH haben 0.0 (siehe FillRelationForDreier)
         r.tangenteIndex    = 3;
         r.tangSlope        = p.core.priceSlopePerBar;
         //  r.tangAngle        = 0.0; // falls später berechnet
         //   r.tangLength       = CalcPriceDistance(p.core.priceLow, p.core.priceHigh);
         r.tangPriceAtEvent = startPrice;
        }


      // ---------------------------------------------------------
      // 8. Dispatcher nach PatternType
      // ---------------------------------------------------------
      if(p.core.type == DREIER)
         FillRelationForDreier(r, ev, p);
     };


   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   void              FillRelationForDreier(structRelation &r, const structEvent   &ev, const structPattern &p)
     {
      // ---------------------------------------------------------
      // 5. Relative Lage
      // ---------------------------------------------------------
      r.eventSlopeRelation    = 0.0; // DREIER/VTH sind horizontale Linien, keine Slope (echte Slope: siehe TANGENTE-Zweig in FillRelationSlot)
      r.eventPositionRelative = 0.0; // Tangenten haben kein Fenster

      // Position im Fenster (0..1)
      double range = p.core.priceHigh - p.core.priceLow;
      if(range > 0.0)
         r.eventPositionRelative = (ev.eventPrice - p.core.priceLow) / range;
      else
         r.eventPositionRelative = 0.0;

      // ---------------------------------------------------------
      // 7. Relevanz
      // ---------------------------------------------------------
      // Beispiel: Kombination aus Pattern-Stärke und Nähe
      r.patternRelevanceAtEvent =
         p.core.patternStrengthAtCreate
         + (1.0 - r.eventPositionRelative)
         + (r.isTouchingNow ? 0.5 : 0.0)
         + (r.isBreakingNow ? 1.0 : 0.0);
     }

   // ############################################################################
   // ### T R A D E S     ########################################################
   // ############################################################################
   void              GenerateTradesForEvent(const structEvent &ev)
     {

      structPattern p = patternManager.Get(ev.patternId);

      string eventType      = TimeFrameToString(ev.patternTF) + "_" +
                              EnumToString(ev.patternType) + "_" +
                              EnumToString(ev.eventReason) ;

      for(int i=0; i < variantRoutingCount; i++)
        {
         if(variantRoutingRule[i].eventType != eventType)
            continue;

         structVariantRoutingRule rule = variantRoutingRule[i];

         for(int d=0; d < rule.deltaCount; d++)
            for(int s=0; s < rule.slCount; s++)
               for(int t=0; t < rule.tpCount; t++)
                  for(int trail=0; trail < rule.trailingCount; trail++)
                     for(int ab=0; ab < rule.abortBarsCount; ab++)
                       {
                        // Übergabe der indices auf die listen
                        BuildTrade(ev, rule, d, s, t, trail, ab);
                       }
        }
     };
   // -------------------------------------------------------------------
   // Muss dieselbe variantId liefern wie GenerateAllVariants() für dieselben Indizes
   int               ComputeVariantId(int vrrId, int d, int s, int t, int trail, int ab)
     {
      return (vrrId * 100000) + (d * 10000) + (s * 1000) + (t * 100) + (trail * 10) + ab;
     }
   // -------------------------------------------------------------------
   // Erzeugt einmalig alle Parameter-Kombinationen (Varianten) aus den Routing-Regeln
   // und schreibt sie in die variants-Tabelle. Wird einmal in Init() aufgerufen.
   void              GenerateAllVariants()
     {
      for(int i=0; i < variantRoutingCount; i++)
        {
         structVariantRoutingRule rule = variantRoutingRule[i];

         for(int d=0; d < rule.deltaCount; d++)
            for(int s=0; s < rule.slCount; s++)
               for(int t=0; t < rule.tpCount; t++)
                  for(int trail=0; trail < rule.trailingCount; trail++)
                     for(int ab=0; ab < rule.abortBarsCount; ab++)
                       {
                        structVariant v;
                        v.Init();

                        v.variantId    = ComputeVariantId(rule.vrrId,
                                             (int)rule.deltaList[d], (int)rule.slList[s],
                                             (int)rule.tpList[t], (int)rule.trailingList[trail],
                                             rule.abortBarsList[ab]);
                        v.orderType    = rule.orderType;
                        v.against      = rule.against;
                        v.twoUnitMode  = rule.twoUnitMode;
                        v.delta        = rule.deltaList[d];
                        v.slPoints     = rule.slList[s];
                        v.tpPoints     = rule.tpList[t];
                        v.trailingDist = rule.trailingList[trail];
                        v.abortBars    = rule.abortBarsList[ab];

                        DBExecute(__FUNCTION__, v.ToSQL());
                       }
        }
     }
   // -------------------------------------------------------------------
   void              BuildTrade(const structEvent &ev,
                                structVariantRoutingRule &rule,
                                int d, int s, int t, int trail, int ab)
     {
      structTrade tr;
      tr.Init();

      // technische ID (AUTOINCREMENT in DB, aber intern vergeben wir sie trotzdem)
      tr.tradeId      = nextTradeId++;
      tr.variantId    = ComputeVariantId(rule.vrrId,
                                          (int)rule.deltaList[d], (int)rule.slList[s],
                                          (int)rule.tpList[t], (int)rule.trailingList[trail],
                                          rule.abortBarsList[ab]);
      tr.eventId      = ev.eventId;

      tr.orderType    = rule.orderType;

      // finalOrderDirection = against ? invert(eventDirection) : eventDirection
      Direction dir = ev.eventDirection;
      if(rule.against)
         Toogle(dir);
      tr.direction    = dir;

      tr.twoUnitMode  = rule.twoUnitMode;
      tr.entryPrice   = ev.eventPrice + rule.deltaList[d] * tr.direction;
      tr.slPoints           = rule.slList[s];
      tr.tpPoints           = rule.tpList[t];
      tr.trailingDist = rule.trailingList[trail];
      tr.abortBars    = rule.abortBarsList[ab];

      tr.createTime  = ev.eventTime;
      tr.createBarIndex = engine.market.barIndexM3;

      tr.status       = TRADE_WAITING; // geht sofort los

      tradeManager.AddTrade(tr);
     }

   // #############################################################################

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   void              DistanceAndAtr(const structPattern &p,
                                    double &start,
                                    double &nominal,
                                    double &atr)
     {
      // Reset OUT-Parameter
      start   = 0.0;
      nominal = 0.0;
      atr         = 0.0;

      int barIndex = 0;

      // ATR + BarIndex im Pattern-TF
      switch(p.core.timeFrame)
        {
         case PERIOD_M1:
            atr      = engine.market.atrM1;
            barIndex = engine.market.barIndexM1;
            break;

         case PERIOD_M3:
            atr      = engine.market.atrM3;
            barIndex = engine.market.barIndexM3;
            break;

         case PERIOD_H1:
            atr      = engine.market.atrH1;
            barIndex = engine.market.barIndexH1;
            break;

         case PERIOD_D1:
            atr      = engine.market.atrD1;
            barIndex = engine.market.barIndexD1;
            break;

         default:
            atr      = engine.market.atrM3;
            barIndex = engine.market.barIndexM3;
            break;
        }

      // Nominal + Start rekonstruieren
      nominal = (p.core.direction == LONG ? p.core.priceHigh : p.core.priceLow);
      start   = (p.core.direction == LONG ? p.core.priceLow  : p.core.priceHigh);
      // Zuschlag wenn schräg
      nominal += p.core.priceSlopePerBar * (barIndex - p.core.startBarIndex);
      start   += p.core.priceSlopePerBar * (barIndex - p.core.startBarIndex);
     };

#include "VRRandERRadd.mqh";

  }; // Ende CEntryManager


#endif
//+------------------------------------------------------------------+
