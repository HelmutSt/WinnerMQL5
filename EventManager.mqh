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

static string slotNames[26] =
  {
   "M3_EventOrigin",    //  0  → Pattern, der den Event ausgelöst hat (Trigger)
   "M3_SoM_Under",      //  1  → SoM unter Event (M3)
   "M3_SoM_Over",       //  2  → SoM über Event (M3)
   "M3_Open_Under",     //  3  → Open unter Event (M3)
   "M3_Open_Over",      //  4  → Open über Event (M3)

   "M3_Tang1_Under",    //  5  → Tangente 1 unter Event (M3)
   "M3_Tang1_Over",     //  6  → Tangente 1 über Event (M3)
   "M3_Tang2_Under",    //  7  → Tangente 2 unter Event (M3)
   "M3_Tang2_Over",     //  8  → Tangente 2 über Event (M3)

   "H1_Dreier_Near",    //  9  → nächster DREIER im H1
   "H1_SoM_Under",      // 10  → SoM unter Event (H1)
   "H1_SoM_Over",       // 11  → SoM über Event (H1)
   "H1_Open_Under",     // 12  → Open unter Event (H1)
   "H1_Open_Over",      // 13  → Open über Event (H1)

   "H1_Tang1_Under",    // 14  → Tangente 1 unter Event (H1)
   "H1_Tang1_Over",     // 15  → Tangente 1 über Event (H1)
   "H1_Tang2_Under",    // 16  → Tangente 2 unter Event (H1)
   "H1_Tang2_Over",     // 17  → Tangente 2 über Event (H1)

   "D1_VTH1_Under",     // 18  → VTH1 unter Event (D1)
   "D1_VTH1_Over",      // 19  → VTH1 über Event (D1)
   "D1_VTH2_Under",     // 20  → VTH2 unter Event (D1)
   "D1_VTH2_Over",      // 21  → VTH2 über Event (D1)

   "D1_Tang1_Under",    // 22  → Tangente 1 unter Event (D1)
   "D1_Tang1_Over",     // 23  → Tangente 1 über Event (D1)
   "D1_Tang2_Under",    // 24  → Tangente 2 unter Event (D1)
   "D1_Tang2_Over"      // 25  → Tangente 2 über Event (D1)
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

   structRelation        relations[26];


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
      VRR_Add("M3_DREIER_IS_TOUCHED         LIMIT   -      -      1     10       30           10         -           -  ");
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
      // prüfen ob ...
      ev.isEntryEvent = EventShouldCreateTrades(eventTypeStr);

      // 1. Event schreiben (für AuslösendeEvents UND für StoryEvents)
      DBExecute(__FUNCTION__, ev.ToSQL());

      // 2. PatternDynamic at Event schreiben
      structPattern p = patternManager.Get(ev.patternId);
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

      int tfIdx = TimeFrameToIndex(PERIOD_M3);

      // Liste der relations initialisieren
      for(int i=0; i<26; i++)
        {
         relations[i].Init();
         //
         relations[i].relationId = nextRelationId++;
         relations[i].eventId    = ev.eventId;
         relations[i].patternId  = -1;
         relations[i].slotName   = slotNames[i];      // noch nicht gefunden
         relations[i].priceDistance = DBL_MAX; // für suche nach nahestem
        }

      // erstmal nur die patternId suchen und in Liste schreiben

      // Slot 0: M3-Origin setzen
      if(ev.patternId != -1)
        {
         relations[0].patternId = ev.patternId;
         relations[0].priceDistance = 0;
        }
return; //TODO
      // Tangenten in allen TF sind in den Pattern Meta Daten gespeicher
      relations[5].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_M3)].tang1_UnderIdx;//  5  → Tangente 1 unter Event (M3)
      relations[6].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_M3)].tang1_OverIdx; //  6  → Tangente 1 über Event (M3)
      relations[7].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_M3)].tang2_UnderIdx;//  7  → Tangente 2 unter Event (M3)
      relations[8].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_M3)].tang2_OverIdx; //  8  → Tangente 2 über Event (M3)

      relations[14].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_H1)].tang1_UnderIdx;// 14  → Tangente 1 unter Event (H1)
      relations[15].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_H1)].tang1_OverIdx; // 15  → Tangente 1 über Event (H1)
      relations[16].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_H1)].tang1_UnderIdx;// 16  → Tangente 2 unter Event (H1)
      relations[17].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_H1)].tang1_OverIdx; // 17  → Tangente 2 über Event (H1)

      relations[22].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_D1)].tang1_UnderIdx;// 22  → Tangente 1 unter Event (D1)
      relations[23].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_D1)].tang1_OverIdx; // 23  → Tangente 1 über Event (D1)
      relations[24].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_D1)].tang1_UnderIdx;// 24  → Tangente 2 unter Event (D1)
      relations[25].patternId = patternManager.meta[TimeFrameToIndex(PERIOD_D1)].tang1_OverIdx; // 25  → Tangente 2 über Event (D1)

      // 3. DREIER und VTH  über Patterns-Array suchen
      int patternCount = patternManager.GetCount();
      for(int i = patternCount; i > 0 ; i--)
        {
         // suchen und eintragen der patternId und der distance
         structPattern p = patternManager.Get(i);
         FillDreierAndVthSlots(ev, p);
        };
     }; // end sub
   // -----------------------------------------------------
   void              FillRelationsListForEvent(structEvent &ev)
     {
      // Liste der relations mit Daten füllen und ausgeben
      for(int i=0; i<26; i++)
        {
         structRelation rel = relations[i];
         FillRelationSlot(rel, ev);
         DBExecute(__FUNCTION__, rel.ToSQL());
        };
     }; // end sub
   // -----------------------------------------------------
   void              FillDreierAndVthSlots(const structEvent &ev, const structPattern &p)
     {
      // Origin-Slot überspringen
      if(p.core.patternId == relations[0].patternId)
         return;

      // Geschlossene Patterns ignorieren
      if(p.dynamic.status == CLOSED)
         return;

      // ---------------------------------------------------------
      // Räumliche Distanz korrekt berechnen
      // ---------------------------------------------------------
      double startPrice   = 0.0;
      double nominalPrice = 0.0;
      double atr          = 0.0;

      DistanceAndAtr(p, startPrice, nominalPrice, atr);

      // Distanz IMMER absolut
      double distance = MathAbs(startPrice - ev.eventPrice);

      // Lage bestimmen
      bool isUnder = (startPrice < ev.eventPrice);
      bool isOver  = (startPrice > ev.eventPrice);

      int relIdx = 0;

      // ---------------------------------------------------------
      // M3 – DREIER
      // ---------------------------------------------------------
      if(p.core.type == DREIER && p.core.timeFrame == PERIOD_M3)
        {
         // SoM
         if(p.dynamic.isStartOfMove)
           {
            // M3_SoM_Under (Slot 1)
            relIdx = 1;
            if(isUnder && distance < relations[relIdx].priceDistance)
              {
               relations[relIdx].patternId    = p.core.patternId;
               relations[relIdx].priceDistance = distance;
               return;
              }

            // M3_SoM_Over (Slot 2)
            relIdx = 2;
            if(isOver && distance < relations[relIdx].priceDistance)
              {
               relations[relIdx].patternId    = p.core.patternId;
               relations[relIdx].priceDistance = distance;
               return;
              }
           }

         // M3_Open_Under (Slot 3)
         relIdx = 3;
         if(isUnder && distance < relations[relIdx].priceDistance)
           {
            relations[relIdx].patternId    = p.core.patternId;
            relations[relIdx].priceDistance = distance;
            return;
           }

         // M3_Open_Over (Slot 4)
         relIdx = 4;
         if(isOver && distance < relations[relIdx].priceDistance)
           {
            relations[relIdx].patternId    = p.core.patternId;
            relations[relIdx].priceDistance = distance;
            return;
           }
        }

      // ---------------------------------------------------------
      // H1 – DREIER
      // ---------------------------------------------------------
      if(p.core.type == DREIER && p.core.timeFrame == PERIOD_H1)
        {
         // H1_Dreier_Near (Slot 9) — Inside
         if(ev.eventPrice >= p.core.priceLow && ev.eventPrice <= p.core.priceHigh)
           {
            relIdx = 9;
            relations[relIdx].patternId = p.core.patternId;
            relations[relIdx].priceDistance = 0.0;
            return;
           }

         // SoM
         if(p.dynamic.isStartOfMove)
           {
            // H1_SoM_Under (Slot 10)
            relIdx = 10;
            if(isUnder && distance < relations[relIdx].priceDistance)
              {
               relations[relIdx].patternId    = p.core.patternId;
               relations[relIdx].priceDistance = distance;
               return;
              }

            // H1_SoM_Over (Slot 11)
            relIdx = 11;
            if(isOver && distance < relations[relIdx].priceDistance)
              {
               relations[relIdx].patternId    = p.core.patternId;
               relations[relIdx].priceDistance = distance;
               return;
              }
           }

         // H1_Open_Under (Slot 12)
         relIdx = 12;
         if(isUnder && distance < relations[relIdx].priceDistance)
           {
            relations[relIdx].patternId    = p.core.patternId;
            relations[relIdx].priceDistance = distance;
            return;
           }

         // H1_Open_Over (Slot 13)
         relIdx = 13;
         if(isOver && distance < relations[relIdx].priceDistance)
           {
            relations[relIdx].patternId    = p.core.patternId;
            relations[relIdx].priceDistance = distance;
            return;
           }
        }

      // ---------------------------------------------------------
      // VTH
      // ---------------------------------------------------------
      if(p.core.type == VTH)
        {
         // -----------------------------
         // VTH unter Event
         // -----------------------------
         if(isUnder)
           {
            // VTH1_Under (Slot 18)
            if(distance < relations[18].priceDistance)
              {
               relations[20] = relations[18]; // alter VTH1 → VTH2

               relations[18].patternId    = p.core.patternId;
               relations[18].priceDistance = distance;
               relations[18].slotName     = slotNames[18];
               return;
              }

            // VTH2_Under (Slot 20)
            if(distance < relations[20].priceDistance)
              {
               relations[20].patternId    = p.core.patternId;
               relations[20].priceDistance = distance;
               relations[20].slotName     = slotNames[20];
               return;
              }
           }

         // -----------------------------
         // VTH über Event
         // -----------------------------
         if(isOver)
           {
            // VTH1_Over (Slot 19)
            if(distance < relations[19].priceDistance)
              {
               relations[21] = relations[19]; // alter VTH1 → VTH2

               relations[19].patternId    = p.core.patternId;
               relations[19].priceDistance = distance;
               relations[19].slotName     = slotNames[19];
               return;
              }

            // VTH2_Over (Slot 21)
            if(distance < relations[21].priceDistance)
              {
               relations[21].patternId    = p.core.patternId;
               relations[21].priceDistance = distance;
               relations[21].slotName     = slotNames[21];
               return;
              }
           }
        }
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

      // TouchingNow
      r.isTouchingNow =
         (ev.eventPrice == p.core.priceLow ||
          ev.eventPrice == p.core.priceHigh);

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
      r.eventSlopeRelation    = p.core.priceSlopePerBar; // Tangenten haben echte slope
      r.eventPositionRelative = 0.0; // Tangenten haben kein Fenster
      // DREIER/VTH haben slope = 0 → eventSlopeRelation = 0
      r.eventSlopeRelation = 0.0;

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

                        v.variantId    = ComputeVariantId(rule.vrrId, d, s, t, trail, ab);
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
      tr.variantId    = ComputeVariantId(rule.vrrId, d, s, t, trail, ab);
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
