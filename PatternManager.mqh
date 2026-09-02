//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __PATTERNMANAGER_MQH__
#define __PATTERNMANAGER_MQH__

#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"

//   DREIER, RANGE, VTH, HAMMERBAR, TANGENTE

// --- TANGENTE-Erkennung: Parameter -------------------------------------
#define TANGENTE_SWING_N            2   // 5-Bar-Fraktal (N Bars auf jeder Seite)
#define TANGENTE_MIN_BARS_BETWEEN   5   // Mindestabstand zwischen den beiden Swing-Punkten
#define TANGENTE_MAX_ACTIVE         3   // max. gleichzeitig aktive Tangenten je TF+Richtung (FIFO)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPatternManager
  {
public:
   struct structPatternMeta
     {
      int               lastSoMLongIdx;
      int               lastSoMShortIdx;

      int               lastDreierLongIdx;
      int               lastDreierShortIdx;

      int               lastHammerBarLongIdx;
      int               lastHammerBarShortIdx;

      // TANGENTE: letzter bestätigter Swing-Punkt je Richtung (für Paarbildung mit dem nächsten Swing)
      double            lastSwingLowPrice;
      int               lastSwingLowBarIndex;
      datetime          lastSwingLowTime;
      double            lastSwingHighPrice;
      int               lastSwingHighBarIndex;
      datetime          lastSwingHighTime;

      Direction         trendPattern    ;
     };

   structPatternMeta meta[NUM_TIMEFRAMES];

private:
   structPattern     patterns[50000];
   int               patternCount;

   int               nextPatternId;
   int               nextEventId;

   datetime          vthHighTime;
   double            vthHighPrice;
   int               vthHighBarIndex;
   datetime          vthLowTime;
   double            vthLowPrice;
   int               vthLowBarIndex;

   bool              dreierLongMoeglich[NUM_TIMEFRAMES]; // für DREIER Regel
   bool              dreierShortMoeglich[NUM_TIMEFRAMES];

   datetime          lastDreierLongStartTime[NUM_TIMEFRAMES]; // für DREIER Regel
   datetime          lastDreierShortStartTime[NUM_TIMEFRAMES];

   // ---

public:
                     CPatternManager()
     {
      patternCount   = 0;
      nextPatternId  = 0;
      nextEventId    = 0;

      vthHighTime  = 0;
      vthHighPrice = 0;
      vthLowTime   = 0;
      vthLowPrice  = DBL_MAX;

      for(int i=0;i<NUM_TIMEFRAMES;i++)
        {
         dreierLongMoeglich[i]         = false;
         dreierShortMoeglich[i]        = false;
         lastDreierLongStartTime[i]    = 0;
         lastDreierShortStartTime[i]   = 0;
         meta[i].lastDreierLongIdx     = -1;
         meta[i].lastDreierShortIdx    = -1;
         meta[i].lastSoMLongIdx        = -1;
         meta[i].lastSoMShortIdx       = -1;
         meta[i].lastHammerBarLongIdx  = -1;
         meta[i].lastHammerBarShortIdx = -1;

         meta[i].lastSwingLowPrice    = 0.0;
         meta[i].lastSwingLowBarIndex = -1;
         meta[i].lastSwingLowTime     = 0;
         meta[i].lastSwingHighPrice    = 0.0;
         meta[i].lastSwingHighBarIndex = -1;
         meta[i].lastSwingHighTime     = 0;


         meta[i].trendPattern               = LONG;
        }
     };
                    ~CPatternManager()  {};

   // -----------------------------------------------------------
   bool              Add(structPattern &p)
     {

      patterns[patternCount] = p;
      patternCount++;

      // In DB schreiben
      string sql = p.core.ToSQL();
      DBExecute(__FUNCTION__,sql);

      engine.OnPattern(p);

      return true;
     };
   // ---------------------------------------------------------------
   structPattern     GetById(int patternId)
     {

      if(patterns[patternId].core.patternId != patternId)
        {
         structPattern p;
         p.Init();
         MessageBox("");
         return p;
        }
      return patterns[patternId];
     }

   // ---------------------------------------------------------------
   int               GetCount() const
     {
      return patternCount;
     }

   // ---------------------------------------------------------------
   structPattern     Get(int idx)
     {
      return patterns[idx];
     }

   // ###########################################################################
   // #########################  EVENT EMITTER  #################################
   // ###########################################################################
   Direction         CalcEventDirection(Direction patternDirection, EventReason reason)
     {
      switch(reason)
        {
         // Story-Events → Pattern-Richtung
         case IS_CREATED:
         case IS_STRONGER_THAN_PREVIOUS:
         case IS_NEAR_TOUCHED:
         case IS_TOUCHED:
         case IS_FAKE_BREAK:
            return patternDirection;

         // Break-Events → Gegenrichtung
         case IS_BROKEN:
         case IS_TREND_BREAK:
            return Opposite(patternDirection);

         // PostBreak-Retests → Pattern-Richtung
         case IS_POSTBREAK_RETEST_NEAR_TOUCHED:
         case IS_POSTBREAK_RETEST_TOUCHED:
         case IS_POSTBREAK_RETEST_FAKE_BREAK:
            return patternDirection;

         // PostBreak-Retest-Break → Gegenrichtung
         case IS_POSTBREAK_RETEST_BROKEN:
            return Opposite(patternDirection);

         default:
            return FLAT;
        }
     }
   // ---------------------------------------------------------------
   Direction         Opposite(const Direction dir)
     {
      switch(dir)
        {
         case LONG:
            return SHORT;
         case SHORT:
            return LONG;
         case FLAT:
            return FLAT;
         default:
            return FLAT;
        }
     }
   // ----------------------------------------------------------------------------
   void              EmitEvent(structPattern &p, EventReason reason, datetime time, double price)
     {
      structEvent ev;
      ev.Init();

      // IDs
      ev.eventId   = nextEventId++;
      ev.patternId = p.core.patternId;

      // Pattern-Kontext (Story-Pattern)
      ev.patternTF        = p.core.timeFrame;
      ev.patternType      = p.core.type;
      ev.patternDirection = p.core.direction;

      // z.B. "CREATED", "TOUCHED", "BROKEN", ...
      ev.eventReason   =  reason;

      // Event-Richtung aus Reason ableiten
      ev.eventDirection = CalcEventDirection(ev.patternDirection, ev.eventReason);

      // Zeit & Preis
      ev.eventTime  = time;
      ev.eventPrice = price;

      // Dispatch
      engine.OnEvent(ev);
     };

   // ###########################################################################
   // ################## O n T i c k ( )  #######################################
   // ###########################################################################

   void              OnTick(MqlTick &t)
     {
      // die beiden (Long,Short) laufenden DREIER (nur M3)
      int tfIdx = TimeFrameToIndex(PERIOD_M3);

      // über alle pattern
      for(int i = 0; i < patternCount; i++)
        {
         if(patterns[i].dynamic.status == CLOSED)
            continue;
         if(patterns[i].core.type == DREIER ||
            patterns[i].core.type == HAMMER_BAR)
            UpdateExtremeBeforeBreak(patterns[i], t);
         if(patterns[i].core.type == HAMMER_BAR)
            UpdateHammerBreakStates(patterns[i], t);
         else     // patterns[i].core.type == VTH, DREIER, TANGENTE
            UpdatePatternTouchStates(patterns[i], t);
        }
     };

   // --------------------------------------------------
   void              UpdateExtremeBeforeBreak(structPattern &p, MqlTick &t)
     {
      if(p.dynamic.status == BROKEN)
         return;

      // 1. eigenen Extremwert aktualisieren
      double price = t.last ;

      if(p.core.direction == LONG)
        {
         if(price > p.dynamic.priceExtremeBeforeBreak)
            p.dynamic.priceExtremeBeforeBreak = price;
        }
      else // SHORT
        {
         if(price < p.dynamic.priceExtremeBeforeBreak)
            p.dynamic.priceExtremeBeforeBreak = price;
        }

      // 2. Relation zum Vorgänger prüfen
      double prevExtreme = p.dynamic.priceExtremePrevious;


      if(p.core.direction == LONG)
        {
         if(p.dynamic.priceExtremeBeforeBreak > prevExtreme)
            p.dynamic.previousExtremeBeforeBreakPriceRelation = BEYOND;
         else
            p.dynamic.previousExtremeBeforeBreakPriceRelation = BEHIND;
        }
      else // SHORT
        {
         if(p.dynamic.priceExtremeBeforeBreak < prevExtreme)
            p.dynamic.previousExtremeBeforeBreakPriceRelation = BEYOND;
         else
            p.dynamic.previousExtremeBeforeBreakPriceRelation = BEHIND;
        }

      if(p.dynamic.priceExtremeBeforeBreak == prevExtreme)
         p.dynamic.previousExtremeBeforeBreakPriceRelation = EVEN;

     };

   // ---------------------------------------------------------
   // Hammer‑Break‑Events
   // ---------------------------------------------------------
   void              UpdateHammerBreakStates(structPattern &p, MqlTick &t)
     {
      if(p.core.type != HAMMER_BAR)
         return;

      if(p.dynamic.status != OPEN)
         return;

      double last = t.last;

      bool isLongHammer  = (p.core.direction == LONG);
      bool isShortHammer = (p.core.direction == SHORT);

      // LONG-HAMMER
      if(isLongHammer)
        {
         if(last < p.core.priceLow)
           {
            p.dynamic.status = CLOSED;
            p.dynamic.validUntil = t.time;
            //   EmitEvent(p, IS_BROKEN, t.time, last);
           }
         if(last > p.core.priceHigh)
            p.dynamic.status = CLOSED;
         p.dynamic.validUntil = t.time;
        }

      // SHORT-HAMMER
      if(isShortHammer)
        {
         if(last > p.core.priceHigh)
           {
            p.dynamic.status = CLOSED;
            p.dynamic.validUntil = t.time;
            //   EmitEvent(p, IS_BROKEN, t.time, last);
           }
         if(last < p.core.priceLow)
            p.dynamic.status = CLOSED;
         p.dynamic.validUntil = t.time;
        }

      return;
     };

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   void              UpdatePatternTouchStates(structPattern &p, MqlTick &t)
     {
      // Pattern geschlossen oder Break bereits in Prüfung → nichts tun
      if(p.dynamic.status == CLOSED ||
         p.temp.brokenButNotConfirmed ||
         p.temp.postBreakRetestBrokenButNotConfirmed)
         return;

      double start=0.0, nominal=0.0, atr=0.0;
      DistanceAndAtr(p, start, nominal, atr);

      double distNominal = (t.last - nominal) * p.core.direction;
      double distStart   = (t.last - start)   * p.core.direction;

      double nearThreshold = atr * 0.2  ;
      double awayThreshold = atr * 2  ;

      bool isLong  = (p.core.direction == LONG);
      bool isShort = !isLong;

      // ============================================================
      // STATUS: OPEN
      // ============================================================
      if(p.dynamic.status == OPEN)
        {
         // Reset NearTouch / Touch
         if(p.temp.isNearTouching && distNominal > awayThreshold)
           {
            p.temp.isNearTouching = false;
            p.temp.isTouching     = false;
           }

         // NEAR_TOUCHED
         if(!p.temp.isNearTouching && distNominal <= nearThreshold)
           {
            p.dynamic.nearTouches++;
            p.temp.isNearTouching = true;

            EmitEvent(p, IS_NEAR_TOUCHED, t.time, t.last);
           }

         // TOUCHED
         if(!p.temp.isTouching && distNominal <= 0)
           {
            p.dynamic.touches++;
            p.temp.isTouching = true;

            EmitEvent(p, IS_TOUCHED, t.time, t.last);
           }

         // ExtremBeforeBreak aktualisieren
         if(p.dynamic.touches > 0) // mindstens einmal ... loggen bis closed
           {
            bool newExtreme =
               (isLong  && t.last > p.dynamic.priceExtremeBeforeBreak) ||
               (isShort && t.last < p.dynamic.priceExtremeBeforeBreak);

            if(newExtreme)
               p.dynamic.priceExtremeBeforeBreak = t.last;
           }

         // BREAK but not confirmed
         if(distStart < 0)
           {
            p.temp.brokenButNotConfirmed = true;
           }
        }

      // ============================================================
      // STATUS: BROKEN
      // ============================================================
      if(p.dynamic.status == BROKEN)
        {
         distNominal = -distNominal;
         // distStart   = (t.last - start)   * p.core.direction;

         nearThreshold = -nearThreshold;
         awayThreshold = -awayThreshold;

           {
            // Reset Retest-NearTouch / Retest-Touch
            if(p.temp.isNearPostBreakRetestTouching && distNominal > awayThreshold)
              {
               p.temp.isNearPostBreakRetestTouching = false;
               p.temp.isPostBreakRetestTouching     = false;
              }

            // NEAR_POSTBREAK_RETEST_TOUCHED
            if(!p.temp.isNearPostBreakRetestTouching && distNominal < nearThreshold)
              {
               p.dynamic.nearPostBreakRetestTouches++;
               p.temp.isNearPostBreakRetestTouching = true;

               EmitEvent(p, IS_POSTBREAK_RETEST_NEAR_TOUCHED, t.time, t.last);
              }

            // POSTBREAK_RETEST_TOUCHED
            if(!p.temp.isPostBreakRetestTouching && distNominal < 0)
              {
               p.dynamic.postBreakRetestTouches++;
               p.temp.isPostBreakRetestTouching = true;

               EmitEvent(p, IS_POSTBREAK_RETEST_TOUCHED, t.time, t.last);
              }

            // ExtremAfterBreak aktualisieren
            if(p.temp.isPostBreakRetestTouching)
              {
               bool newExtreme =
                  (isLong  && t.last < p.dynamic.priceExtremeAfterBreak) ||
                  (isShort && t.last > p.dynamic.priceExtremeAfterBreak);

               if(newExtreme)
                  p.dynamic.priceExtremeAfterBreak = t.last;
              }

            //   but not confirmed
            if(distStart > 0)
              {
               p.temp.postBreakRetestBrokenButNotConfirmed = true;
              }
           }
        }
     }

   // ###########################################################################
   // ################## O n N e w B a r  ( )  ##################################
   // ###########################################################################
   void              OnNewBar(structBarBlock &bb)
     {
      //ToDO(HE): wo auf Hamemr prüfen hier oder BarManager
      DetectNewVTHPattern(bb);
      if(bb.timeFrame == PERIOD_D1)
         return;

      DetectNewDreierPattern(bb);
      DetectNewHammerBarPattern(bb);
      DetectNewTangentePattern(bb);

      // -- Fake or Break ------------------------------------------------
      ClearBrokenButNotConfirmed(bb);

     }

   // -------------------------------------------------------------
   void              DetectNewVTHPattern(structBarBlock &bb)
     {
      if(bb.timeFrame != PERIOD_H1)
         return;

      datetime tBar0 = bb.bars[0].time;
      datetime tBar1 = bb.bars[1].time;

      int dayBar0 = (int)(tBar0 / 86400);
      int dayBar1 = (int)(tBar1 / 86400);

      // --- 1. VTH ausgeben, wenn neuer Tag beginnt
      if(dayBar0 != dayBar1 && vthLowTime > 0 && vthHighTime > 0)
        {
         // ============================================================
         // LONG VTH
         // ============================================================
         structPattern p;
         p.Init();

         p.core.patternId = nextPatternId++;
         p.core.type      = VTH;
         p.core.direction = LONG;
         p.core.timeFrame = PERIOD_H1;
         p.dynamic.status    = OPEN;

         p.core.startTime = vthLowTime;
         p.core.endTime   = bb.bars[1].time;

         p.core.validFrom     = (dayBar0 * 86400);
         p.dynamic.validUntil = D'2099.12.31';

         p.core.startBarIndex     = vthLowBarIndex;
         p.core.endBarIndex       = bb.bars[1].barIndex;
         p.core.validFromBarIndex = bb.bars[0].barIndex;

         p.core.priceLow  = vthLowPrice - 10;
         p.core.priceHigh = vthLowPrice;

         SetCommonPatternFields(p);

         this.Add(p);

         EmitEvent(p, IS_CREATED, bb.bars[1].time, vthLowPrice);

         // ============================================================
         // SHORT VTH
         // ============================================================
         p.Init();

         p.core.patternId = nextPatternId++;
         p.core.type      = VTH;
         p.core.direction = SHORT;
         p.core.timeFrame = PERIOD_H1;
         p.dynamic.status    = OPEN;

         p.core.startTime = vthHighTime;
         p.core.endTime   = bb.bars[1].time + 3600;

         p.core.validFrom     = (dayBar0 * 86400);
         p.dynamic.validUntil = D'2099.12.31';

         p.core.startBarIndex     = vthHighBarIndex;
         p.core.endBarIndex       = bb.bars[1].barIndex;
         p.core.validFromBarIndex = bb.bars[0].barIndex;

         p.core.priceLow  = vthHighPrice;
         p.core.priceHigh = vthHighPrice + 10;
         p.core.width     = p.core.priceHigh - p.core.priceLow;

         SetCommonPatternFields(p);

         this.Add(p);

         EmitEvent(p, IS_CREATED, bb.bars[1].time, vthHighPrice);

         // --- Reset auf 00:00 des neuen Tages ---
         datetime nextDay = (dayBar0 * 86400);

         vthHighTime  = nextDay;
         vthHighPrice = 0;

         vthLowTime   = nextDay;
         vthLowPrice  = DBL_MAX;
        }

      // --- 4. Jetzt erst sammeln!
      if(bb.bars[1].high > vthHighPrice)
        {
         vthHighPrice    = bb.bars[1].high;
         vthHighTime     = bb.bars[1].time;
         vthHighBarIndex = bb.bars[1].barIndex;
        }

      if(bb.bars[1].low < vthLowPrice)
        {
         vthLowPrice    = bb.bars[1].low;
         vthLowTime     = bb.bars[1].time;
         vthLowBarIndex = bb.bars[1].barIndex;
        }
     }
   // --------------------------------------------------------------------
   void              DetectNewDreierPattern(structBarBlock &bb)
     {
      if(bb.timeFrame != PERIOD_H1 && bb.timeFrame != PERIOD_M3)
         return;

      if(bb.bars[4].time == 0)
         return;

      int tfIdx = TimeFrameToIndex(bb.timeFrame);

      // ---------------------------------------------------------
      // LONG-DREIER möglich?
      // ---------------------------------------------------------
      if(bb.bars[4].high > bb.bars[3].high)
         dreierLongMoeglich[tfIdx] = true;

      if(dreierLongMoeglich[tfIdx])
        {
         bool isDreier =
            (bb.bars[3].low <= bb.bars[2].low) &&
            (bb.bars[2].low <= bb.bars[1].low) &&
            (bb.bars[3].low <  bb.bars[1].low);

         if(isDreier && bb.bars[3].time != lastDreierLongStartTime[tfIdx])
           {
            structPattern p;
            p.Init();

            p.core.patternId   = nextPatternId++;
            p.core.type        = DREIER;
            p.core.direction   = LONG;
            p.core.timeFrame   = bb.timeFrame;
            p.dynamic.status      = OPEN;

            p.core.startTime   = bb.bars[3].time;
            p.core.endTime     = bb.bars[1].time;

            p.core.validFrom      = bb.bars[0].time;
            p.dynamic.validUntil  = 0;

            p.core.startBarIndex     = bb.bars[3].barIndex;
            p.core.validFromBarIndex = bb.bars[1].barIndex;
            p.dynamic.breakBarIndex     = bb.bars[1].barIndex;
            p.core.endBarIndex       = bb.bars[1].barIndex;

            // --- StartPrice & NominalPrice ---
            double priceNominal = MathMin(bb.bars[2].open, bb.bars[2].close);

            // --- Core-Preisfenster ---
            p.core.priceLow  = bb.bars[3].low;
            p.core.priceHigh = priceNominal;
            p.core.width     = p.core.priceHigh - p.core.priceLow;

            // ---------------------------------------------------------
            // BAR A (Entstehungsbar)
            // ---------------------------------------------------------
            const structBar barA = bb.bars[3];
            double bodyA  = MathAbs(barA.close - barA.open);
            double upperA = barA.high - MathMax(barA.open, barA.close);
            double lowerA = MathMin(barA.open, barA.close) - barA.low;

            p.core.rangeBarA = barA.high - barA.low;
            p.core.shapeBarA = barA.shape;
            p.core.wickRatio = (bodyA > 0 ? (upperA + lowerA) / bodyA : 0);

            // ---------------------------------------------------------
            // BAR B (Folgebar)
            // ---------------------------------------------------------
            const structBar barB = bb.bars[2];
            p.core.rangeBarB = barB.high - barB.low;
            p.core.shapeBarB = barB.shape;

            // ---------------------------------------------------------
            // BAR C (dritte Bar)
            // ---------------------------------------------------------
            const structBar barC = bb.bars[1];
            p.core.rangeBarC = barC.high - barC.low;
            p.core.shapeBarC = barC.shape;

            SetCommonPatternFields(p);

            this.Add(p);

            EmitEvent(p, IS_CREATED, bb.bars[0].time, priceNominal);
            if(p.core.timeFrame == PERIOD_H1)
               engine.market.targetTrendH1 = LONG;

            lastDreierLongStartTime[tfIdx] = bb.bars[2].time;
            meta[tfIdx].lastDreierLongIdx       = patternCount - 1;
            dreierLongMoeglich[tfIdx]      = false;
           }
        }

      // ---------------------------------------------------------
      // SHORT-DREIER möglich?
      // ---------------------------------------------------------
      if(bb.bars[4].low < bb.bars[3].low)
         dreierShortMoeglich[tfIdx] = true;

      if(dreierShortMoeglich[tfIdx])
        {
         bool isDreier =
            (bb.bars[3].high >= bb.bars[2].high) &&
            (bb.bars[2].high >= bb.bars[1].high) &&
            (bb.bars[3].high >  bb.bars[1].high);

         if(isDreier && bb.bars[3].time != lastDreierShortStartTime[tfIdx])
           {
            structPattern p;
            p.Init();

            p.core.patternId   = nextPatternId++;
            p.core.type        = DREIER;
            p.core.direction   = SHORT;
            p.core.timeFrame   = bb.timeFrame;
            p.dynamic.status      = OPEN;

            p.core.startTime   = bb.bars[3].time;
            p.core.endTime     = bb.bars[1].time;

            p.core.validFrom      = bb.bars[0].time;
            p.dynamic.validUntil  = 0;

            p.core.startBarIndex     = bb.bars[3].barIndex;
            p.core.validFromBarIndex = bb.bars[1].barIndex;
            p.dynamic.breakBarIndex     = bb.bars[1].barIndex;
            p.core.endBarIndex       = bb.bars[1].barIndex;

            double priceNominal = MathMax(bb.bars[2].open, bb.bars[2].close);

            p.core.priceLow  = priceNominal;
            p.core.priceHigh = bb.bars[3].high;
            p.core.width     = p.core.priceHigh - p.core.priceLow;

            const structBar barA = bb.bars[3];
            double bodyA  = MathAbs(barA.close - barA.open);
            double upperA = barA.high - MathMax(barA.open, barA.close);
            double lowerA = MathMin(barA.open, barA.close) - barA.low;

            p.core.rangeBarA = barA.high - barA.low;
            p.core.shapeBarA = barA.shape;
            p.core.wickRatio = (bodyA > 0 ? (upperA + lowerA) / bodyA : 0);

            const structBar barB = bb.bars[2];
            p.core.rangeBarB = barB.high - barB.low;
            p.core.shapeBarB = barB.shape;

            const structBar barC = bb.bars[1];
            p.core.rangeBarC = barC.high - barC.low;
            p.core.shapeBarC = barC.shape;

            SetCommonPatternFields(p);

            this.Add(p);

            EmitEvent(p, IS_CREATED, bb.bars[0].time, priceNominal);
            if(p.core.timeFrame == PERIOD_H1)
               marketManager.TrendSet(bb.bars[0].time,"targetTrendH1",SHORT);

            lastDreierShortStartTime[tfIdx] = bb.bars[2].time;
            meta[tfIdx].lastDreierShortIdx       = patternCount - 1;
            dreierShortMoeglich[tfIdx]      = false;
           }
        }
     }

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   bool              DetectNewHammerBarPattern(structBarBlock &bb)
     {
      if(bb.timeFrame != PERIOD_M3 && bb.timeFrame != PERIOD_M1)
         return(false);

      // wir brauchen mindestens 5 Bars: 4 Historie + aktuellen
      if(bb.bars[4].time == 0)
         return(false);

      // BarShape des Bar1
      bool isLongHammer  = (bb.bars[1].shape == HAMMER);
      bool isShortHammer = (bb.bars[1].shape == INVHAMMER);

      if(!isLongHammer && !isShortHammer)
         return(false);

      // Bar-Indizes:
      const structBar b0 = bb.bars[0];
      const structBar b1 = bb.bars[1];
      const structBar b2 = bb.bars[2];
      const structBar b3 = bb.bars[3];
      const structBar b4 = bb.bars[4];

      // Punkte-System
      int score = 0;

      if(isLongHammer)
        {
         if(b4.low > b3.low)
            score++;
         if(b3.low > b2.low)
            score++;
         if(b2.low > b1.low)
            score++;

         if(b4.high > b3.high)
            score++;
         if(b3.high > b2.high)
            score++;
         if(b2.high > b1.high)
            score++;

         if(b2.high < b1.high ||
            b3.high < b1.high ||
            b4.high < b1.high)
            score = 0;
        }
      else
        {
         if(b4.high < b3.high)
            score++;
         if(b3.high < b2.high)
            score++;
         if(b2.high < b1.high)
            score++;

         if(b4.low < b3.low)
            score++;
         if(b3.low < b2.low)
            score++;
         if(b2.low < b1.low)
            score++;

         if(b2.low > b1.low ||
            b3.low > b1.low ||
            b4.low > b1.low)
            score = 0;
        }

      if(score < 4)
         return(false);

      // ---------------------------------------------------------
      // Referenz bestimmen - nur M1 und M3
      // ---------------------------------------------------------

      datetime refStartTime     = 0;
      int      refStartBarIndex = 0;
      double   refPrice         = 0;

      Direction OppDir = isLongHammer ? SHORT : LONG;

      // entferntesten OFFENEN DREIER in gegenrichtung suchen
      for(int i = patternCount - 1; i >= 0; i--)
        {
         if(patterns[i].core.timeFrame != PERIOD_M3)
            continue;
         if(patterns[i].core.type != DREIER)
            continue;
         if(patterns[i].core.direction != OppDir)
            continue;
         if(patterns[i].dynamic.status == OPEN)
           {
            refStartTime = patterns[i].core.startTime;
            refPrice  =    patterns[i].core.priceHigh;
           };
         if(patterns[i].dynamic.status != OPEN &&
            refPrice  > 0)
            break;
        };

      if(refPrice == 0)
        {
         refStartTime     = bb.bars[1].time;
         refStartBarIndex = bb.bars[1].barIndex;
         refPrice         = (isLongHammer ? bb.bars[1].high : bb.bars[1].low);
        };


      // ---------------------------------------------------------
      // HAMMER_BAR Pattern erzeugen
      // ---------------------------------------------------------
      structPattern     p;
      p.Init();

      p.core.patternId  = nextPatternId++;
      p.core.type       = HAMMER_BAR;
      p.core.direction  = (isLongHammer ? LONG : SHORT);
      p.core.timeFrame  = bb.timeFrame;
      p.dynamic.status     = OPEN;

      // Start/End/Valid
      p.core.startTime       = b1.time; // somStartTime;
      p.core.endTime         = b0.time;
      p.core.validFrom       = b0.time;
      p.dynamic.validUntil   = b0.time + 3 * bb.periodSec;

      p.core.startBarIndex     = b1.barIndex; // somStartBarIndex;
      p.core.endBarIndex       = b0.barIndex;
      p.core.validFromBarIndex = b0.barIndex;
      p.dynamic.breakBarIndex     = -1;

      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      if(isLongHammer)
        {
         p.core.priceHigh = refPrice;
         p.core.priceLow  = b1.low;
        }
      else
        {
         p.core.priceHigh = b1.high;
         p.core.priceLow  = refPrice;
        }

      p.core.width     = p.core.priceHigh - p.core.priceLow;

      int barsWidth = p.core.endBarIndex - p.core.startBarIndex;
      // p.core.priceSlopePerBar = (barsWidth > 0 ? p.core.width / barsWidth : 0.0);

      // ---------------------------------------------------------
      // Extremwerte
      // ---------------------------------------------------------
      p.dynamic.priceExtremeBeforeBreak = (isLongHammer ? b1.low : b1.high);

      // ---------------------------------------------------------
      // BAR A (Hammer-Bar)
      // ---------------------------------------------------------
      p.core.shapeBarA = b1.shape;
      p.core.rangeBarA = b1.high - b1.low;

      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      double bodyA  =   MathAbs(b1.close - b1.open);
      double upperA = b1.high - MathMax(b1.open, b1.close);
      double lowerA =   MathMin(b1.open, b1.close) - b1.low;

      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      if(bodyA == 0)
         bodyA = 1;

      p.core.wickRatio = (isLongHammer ? lowerA / bodyA : upperA / bodyA);

      // ---------------------------------------------------------
      // Neue Felder: Zeitliche Distanz
      // ---------------------------------------------------------
      int       tfIdx = TimeFrameToIndex(bb.timeFrame);
      int lastIdx = (isLongHammer ? meta[tfIdx].lastHammerBarLongIdx
                     : meta[tfIdx].lastHammerBarShortIdx);

      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      if(lastIdx >= 0)
        {
         structPattern prev = patterns[lastIdx];

         p.dynamic.sequenceSinceStartOfMove     = prev.dynamic.sequenceSinceStartOfMove + 1;
         p.core.barsSincePrevious = p.core.startBarIndex - prev.core.startBarIndex;
        }
      else
        {
         p.dynamic.sequenceSinceStartOfMove     = 0;
         p.core.barsSincePrevious = 0;
        }


      SetCommonPatternFields(p);

      this.Add(p);

      // ---------------------------------------------------------
      // Event erzeugen
      // ---------------------------------------------------------
      EmitEvent(p, IS_CREATED, b0.time, b1.close);

      // ---------------------------------------------------------
      // Index aktualisieren
      // ---------------------------------------------------------
      if(isLongHammer)
         meta[tfIdx].lastHammerBarLongIdx = patternCount - 1;
      else
         meta[tfIdx].lastHammerBarShortIdx = patternCount - 1;

      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      return(true);
     }


   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   bool              DetectNewTangentePattern(structBarBlock &bb)
     {
      if(bb.timeFrame != PERIOD_M3 && bb.timeFrame != PERIOD_H1)
         return(false);

      int c = TANGENTE_SWING_N + 1;   // Kandidat-Position im Ringpuffer (bars[1]=jüngste abgeschlossene Bar)

      // --- Swing-Low (Kandidat für LONG-Tangente) ---
      bool isSwingLow = true;
      for(int k = 1; k <= TANGENTE_SWING_N; k++)
        {
         if(bb.bars[c].low >= bb.bars[c-k].low || bb.bars[c].low >= bb.bars[c+k].low)
           {
            isSwingLow = false;
            break;
           }
        }
      if(isSwingLow)
         TryFormTangente(bb, LONG, bb.bars[c].low, bb.bars[c].barIndex, bb.bars[c].time);

      // --- Swing-High (Kandidat für SHORT-Tangente) ---
      bool isSwingHigh = true;
      for(int k = 1; k <= TANGENTE_SWING_N; k++)
        {
         if(bb.bars[c].high <= bb.bars[c-k].high || bb.bars[c].high <= bb.bars[c+k].high)
           {
            isSwingHigh = false;
            break;
           }
        }
      if(isSwingHigh)
         TryFormTangente(bb, SHORT, bb.bars[c].high, bb.bars[c].barIndex, bb.bars[c].time);

      return(false);
     };
   // ------------------------------------------------------------------
   // Prüft, ob der neue Swing mit dem zuletzt gespeicherten Swing gleicher
   // Richtung eine gültige Tangente ergibt, und aktualisiert den Speicher
   // für die nächste Paarbildung (unabhängig davon, ob eine TANGENTE entsteht).
   // ------------------------------------------------------------------
   void              TryFormTangente(structBarBlock &bb, Direction dir,
                                     double swingPrice, int swingBarIndex, datetime swingTime)
     {
      int tfIdx = TimeFrameToIndex(bb.timeFrame);

      double   prevPrice    = (dir == LONG ? meta[tfIdx].lastSwingLowPrice    : meta[tfIdx].lastSwingHighPrice);
      int      prevBarIndex = (dir == LONG ? meta[tfIdx].lastSwingLowBarIndex : meta[tfIdx].lastSwingHighBarIndex);
      datetime prevTime     = (dir == LONG ? meta[tfIdx].lastSwingLowTime     : meta[tfIdx].lastSwingHighTime);

      if(prevBarIndex >= 0)
        {
         int  barsBetween = swingBarIndex - prevBarIndex;
         bool slopeOk     = (dir == LONG ? (swingPrice > prevPrice) : (swingPrice < prevPrice));

         if(barsBetween >= TANGENTE_MIN_BARS_BETWEEN && slopeOk)
            CreateTangente(bb, dir, prevPrice, prevBarIndex, prevTime, swingPrice, swingBarIndex, swingTime);
        }

      // Swing-Speicher für die nächste Paarbildung aktualisieren
      if(dir == LONG)
        {
         meta[tfIdx].lastSwingLowPrice    = swingPrice;
         meta[tfIdx].lastSwingLowBarIndex = swingBarIndex;
         meta[tfIdx].lastSwingLowTime     = swingTime;
        }
      else
        {
         meta[tfIdx].lastSwingHighPrice    = swingPrice;
         meta[tfIdx].lastSwingHighBarIndex = swingBarIndex;
         meta[tfIdx].lastSwingHighTime     = swingTime;
        }
     };
   // ------------------------------------------------------------------
   void              CreateTangente(structBarBlock &bb, Direction dir,
                                    double price1, int barIndex1, datetime time1,
                                    double price2, int barIndex2, datetime time2)
     {
      // FIFO-Limit: max. TANGENTE_MAX_ACTIVE gleichzeitig je TF+Richtung,
      // sonst wird die älteste geschlossen (Verdrängung, kein Preis-Bruch)
      EvictOldestTangenteIfFull(bb, dir);

      structPattern p;
      p.Init();

      p.core.patternId  = nextPatternId++;
      p.core.type       = TANGENTE;
      p.core.direction  = dir;
      p.core.timeFrame  = bb.timeFrame;
      p.dynamic.status  = OPEN;

      // price1/barIndex1/time1 = älterer Swing-Punkt (Ursprung der Linie)
      // price2/barIndex2/time2 = neuerer Swing-Punkt (bestätigt die Linie)
      p.core.startTime         = time1;
      p.core.endTime           = time2;
      p.core.validFrom         = time2;
      p.dynamic.validUntil     = 0;

      p.core.startBarIndex     = barIndex1;
      p.core.validFromBarIndex = barIndex2;
      p.core.endBarIndex       = barIndex2;
      p.dynamic.breakBarIndex  = barIndex2;

      // priceLow=priceHigh=price1 (Ursprung), DistanceAndAtr extrapoliert von
      // startBarIndex aus mit priceSlopePerBar weiter -> ergibt bei barIndex2
      // wieder price2, danach die laufende Linie
      p.core.priceLow  = price1;
      p.core.priceHigh = price1;
      p.core.width     = 0.0;
      p.core.priceSlopePerBar = (price2 - price1) / (barIndex2 - barIndex1);

      SetCommonPatternFields(p);
      this.Add(p);

      EmitEvent(p, IS_CREATED, time2, price2);
     };
   // ------------------------------------------------------------------
   // Verdrängt die älteste offene TANGENTE gleicher TF+Richtung, wenn das
   // Limit TANGENTE_MAX_ACTIVE erreicht ist.
   // ------------------------------------------------------------------
   void              EvictOldestTangenteIfFull(structBarBlock &bb, Direction dir)
     {
      int oldestIdx = -1;
      int count     = 0;

      for(int i = 0; i < patternCount; i++)
        {
         if(patterns[i].core.type      != TANGENTE)   continue;
         if(patterns[i].core.timeFrame != bb.timeFrame) continue;
         if(patterns[i].core.direction != dir)        continue;
         if(patterns[i].dynamic.status != OPEN)       continue;

         count++;
         if(oldestIdx == -1 || patterns[i].core.startBarIndex < patterns[oldestIdx].core.startBarIndex)
            oldestIdx = i;
        }

      if(count >= TANGENTE_MAX_ACTIVE && oldestIdx != -1)
        {
         patterns[oldestIdx].dynamic.status     = CLOSED;
         patterns[oldestIdx].dynamic.validUntil = bb.bars[1].time;
        }
     };
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   bool              SetCommonPatternFields(structPattern &p)
     {
      // ---------------------------------------------------------
      // 0. immer berechnen
      // ---------------------------------------------------------
      double currPriceStart   = (p.core.direction == LONG ? p.core.priceLow : p.core.priceHigh);
      double currPriceNominal = (p.core.direction   == LONG ? p.core.priceHigh : p.core.priceLow);
      double  atr;
      DistanceAndAtr(p, currPriceStart, currPriceNominal, atr);

      p.core.width = p.core.priceHigh - p.core.priceLow;
      p.dynamic.priceExtremeBeforeBreak = currPriceNominal; // Anfangswert

      p.core.sessionAtCreate = engine.market.session;

      if(p.core.timeFrame == PERIOD_M3)
         p.core.trendContextAtCreate = engine.market.trendPatternM3;
      if(p.core.timeFrame == PERIOD_H1)
         p.core.trendContextAtCreate = engine.market.trendPatternH1;         // PatternManager: Pattern-basierter Trend (DREIER-Kontext).

      p.core.patternStrengthAtCreate = 0; // wird unten via ComputePatternStrength(p) befüllt

      // ---------------------------------------------------------
      // 1. Vorgänger suchen (rückwärts, zeitlich sortiertes Array)
      // ---------------------------------------------------------
      bool found = false;
      structPattern prev;   // lokale Kopie
      prev.Init();

      for(int i = patternCount - 1; i >= 0; i--)
        {
         if(patterns[i].core.patternId == p.core.patternId)           // Skip: aktuelles Pattern selbst
            continue;
         if(patterns[i].core.timeFrame != p.core.timeFrame)  // Skip: falscher TF
            continue;
         if(patterns[i].core.type != p.core.type)            // Skip: falscher Typ
            continue;
         if(patterns[i].core.direction != p.core.direction)  // Skip: falsche Richtung
            continue;

         prev = patterns[i];           // Treffer → Kopieren
         found = true;
         break;
        }
      // ---------------------------------------------------------
      if(!found)
        {
         p.core.patternStrengthAtCreate = ComputePatternStrength(p);  // Default-Werte aus .Init() für Relation-zu-Vorgänger-Terme
         return true;      // Kein Vorgänger → sonst Default-Werte aus .Init() stehen lassen
        }

      // ---------------------------------------------------------
      // 1. ok - und los !
      // ---------------------------------------------------------
      // Index seit SoM weiterzählen
      if(p.core.type == DREIER || p.core.type == HAMMER_BAR)
         p.dynamic.sequenceSinceStartOfMove = prev.dynamic.sequenceSinceStartOfMove  + 1;

      // ---------------------------------------------------------
      // 2. previousStartPriceRelation
      // ---------------------------------------------------------
      double prevLow  = prev.core.priceLow;
      double prevHigh = prev.core.priceHigh;

      // Even ist default
      // Beyond
      if((p.core.direction == LONG  && currPriceStart > prevHigh) ||
         (p.core.direction == SHORT && currPriceStart < prevLow))
        {
         p.core.previousStartPriceRelation = BEYOND;
        }
      // Behind
      if((p.core.direction == LONG  && currPriceStart < prevLow) ||
         (p.core.direction == SHORT && currPriceStart > prevHigh))
        {
         p.core.previousStartPriceRelation = BEHIND;
        }

      // ---------------------------------------------------------
      // 5. barsSincePrevious
      // ---------------------------------------------------------
      if(p.core.type == DREIER || p.core.type == HAMMER_BAR)
         p.core.barsSincePrevious = p.core.startBarIndex - prev.core.endBarIndex;

      // ---------------------------------------------------------
      // 6. priceDeltaToPreviousPattern
      // ---------------------------------------------------------
      double prevNominal = (prev.core.direction == LONG ? prev.core.priceHigh : prev.core.priceLow);

      p.core.priceDeltaToPreviousPattern = currPriceNominal - prevNominal;

      // ---------------------------------------------------------
      // 7. priceOffsetToPreviousPattern (ATR-normalisiert)
      // ---------------------------------------------------------
      if(atr != 0.0)
         p.core.priceOffsetToPreviousPattern = p.core.priceDeltaToPreviousPattern / atr;
      else
         p.core.priceOffsetToPreviousPattern = 0.0;

      // ---------------------------------------------------------
      // 8. Räumliche Relation
      // ---------------------------------------------------------
      double currLow  = p.core.priceLow;
      double currHigh = p.core.priceHigh;

      p.core.isOverlapingPrevious =
         (currLow <= prevHigh && currHigh >= prevLow);

      p.core.isInsidePrevious =
         (currLow >= prevLow && currHigh <= prevHigh);

      p.core.isOutsidePrevious =
         (currHigh < prevLow || currLow > prevHigh);

      p.core.patternStrengthAtCreate = ComputePatternStrength(p);

      return true;
     }
   // ####################################################################
   // ### C l e a r B r o k e n B u t N o t ##############################
   // ####################################################################

   //+------------------------------------------------------------------+
   void              ClearBrokenButNotConfirmed(structBarBlock &bb)
     {
      // M3-Bar-Close entscheidet über fake/break in ALLEN TF
      // alle anderen Bar CLose ignorieren
      if(bb.timeFrame != PERIOD_M3)
         return;

      for(int i = 0; i < patternCount; i++)
        {
         if(!patterns[i].temp.brokenButNotConfirmed &&
            !patterns[i].temp.postBreakRetestBrokenButNotConfirmed)
            continue;

         structPattern p = patterns[i];

         // Nominal & ATR bestimmen
         double start = 0.0,nominal = 0.0,atr = 0.0;
         DistanceAndAtr(p, start, nominal, atr);

         // ============================================================
         // CASE 1: Pattern war OPEN → FakeBreak oder echter Break
         // ============================================================
         if(p.dynamic.status == OPEN)
           {
            p.temp.brokenButNotConfirmed = false;

            bool fake = ((bb.bars[1].close - nominal) * p.core.direction) > 0;

            if(fake)
              {
               p.dynamic.status = OPEN;
               p.dynamic.hadFakeBreak = true;
               patterns[i] = p;
               EmitEvent(p, IS_FAKE_BREAK, bb.bars[0].time, bb.bars[1].close);
               continue;
              }

            // ---------------------------------------------------------
            // ECHTER BREAK
            // ---------------------------------------------------------
            p.dynamic.breakTime     = bb.bars[0].time;
            p.dynamic.breakBarIndex = bb.bars[0].barIndex;

            // DREIER/VTH: BROKEN (Postbreak-Retest kann noch CLOSED bestätigen)
            // TANGENTE: springt direkt zu CLOSED, kein Postbreak-Retest-Tracking
            p.dynamic.status = (p.core.type == DREIER || p.core.type == VTH) ? BROKEN : CLOSED;
            p.dynamic.validUntil = bb.bars[0].time;

            // das kann sein - oder?  p.dynamic.hadFakeBreak = false;

            if(p.core.timeFrame == PERIOD_H1 && p.core.direction == LONG)
               marketManager.TrendSet(bb.bars[0].time,"targetTrendH1",SHORT);
            if(p.core.timeFrame == PERIOD_H1 && p.core.direction == SHORT)
               marketManager.TrendSet(bb.bars[0].time,"targetTrendH1",LONG);

            // =================== prüfen auf trend bruch

            if(p.core.type == DREIER)             // causedOppositePatternBreak setzen
               OppositePatternBreak(p);

            bool trendJustBroke = false;
            if(p.core.type == DREIER)
               trendJustBroke = TrendBruch(p, bb.bars[0].time);

            // -------- p ist eine kopie
            patterns[i] = p;

            EmitEvent(p, IS_BROKEN, bb.bars[0].time, bb.bars[1].close);
            if(trendJustBroke)
               EmitEvent(p, IS_TREND_BREAK, bb.bars[0].time, bb.bars[1].close);
            continue;
           }

         // ============================================================
         // CASE 2: Pattern war BROKEN → FakeBackBreak oder CLOSED
         // ============================================================
         if(p.dynamic.status == BROKEN)
           {
            p.temp.postBreakRetestBrokenButNotConfirmed = false;

            bool fakeBack =
               ((bb.bars[1].close - nominal) * p.core.direction) < 0;

            // ---------------------------------------------------------
            // FAKE_BACKBREAK
            // ---------------------------------------------------------
            if(fakeBack)
              {
               p.dynamic.hadFakeRetestBreak = true;

               patterns[i] = p;
               EmitEvent(p, IS_POSTBREAK_RETEST_FAKE_BREAK, bb.bars[0].time, bb.bars[1].close);
               continue;
              }

            // ---------------------------------------------------------
            // CLOSED (echter BackBreak)
            // ---------------------------------------------------------
            p.dynamic.hadFakeRetestBreak= false;
            p.dynamic.status = CLOSED;
            p.dynamic.validUntil = bb.bars[0].time;

            patterns[i] = p;
            EmitEvent(p, IS_POSTBREAK_RETEST_BROKEN, bb.bars[0].time, bb.bars[1].close);
            continue;
           }
        }
     }
   // ---------------------------------------------------------------------
   void              OppositePatternBreak(structPattern &p)
     {
      for(int i = patternCount - 1; i >= 0; i--)
        {
         structPattern x = patterns[i];
         if(x.core.type != DREIER)
            continue;
         if(x.core.timeFrame != p.core.timeFrame)
            continue;
         if(x.core.direction == p.core.direction)
            continue;
         if(p.core.direction == SHORT)
           {
            if(x.core.priceLow < p.core.priceLow)
              {patterns[i].dynamic.causedOppositePatternBreak = true;}
            break;
           }
         else
           {
            if(x.core.priceLow > p.core.priceLow)
              {patterns[i].dynamic.causedOppositePatternBreak = true;}
            break;
           }
        }
     };

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   bool              TrendBruch(structPattern &p, datetime time)
     {
      // TrendBruch nur in M3 und H1
      if(p.core.timeFrame != PERIOD_M3 && p.core.timeFrame != PERIOD_H1)
         return false;

      int tfIdx = TimeFrameToIndex(p.core.timeFrame);

      // Nur wenn der gebrochene DREIER im aktuellen Trend lag
      if(p.core.direction != meta[tfIdx].trendPattern)
         return false;

      // Pattern kennzeichnen
      p.dynamic.isTrendBreak = true;

      // Trend umschalten
      meta[tfIdx].trendPattern  = (p.core.direction == LONG ? SHORT : LONG);

      // MarketManager aktualisieren
      if(p.core.timeFrame == PERIOD_M3)
         marketManager.TrendSet(time,"trendPatternM3",meta[tfIdx].trendPattern);

      if(p.core.timeFrame == PERIOD_H1)
         marketManager.TrendSet(time,"trendPatternH1",meta[tfIdx].trendPattern);

      // Neuen SoM suchen und setzen
      SomSuchenUndSetzen(p);

      return true;
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   void              SomSuchenUndSetzen(structPattern &p)
     {
      int tfIdx = TimeFrameToIndex(p.core.timeFrame);

      // Welcher SoM war zuletzt?
      int lastSomIdx =
         (p.core.direction == LONG ? meta[tfIdx].lastSoMLongIdx
          : meta[tfIdx].lastSoMShortIdx);

      if(lastSomIdx < 0)
         lastSomIdx = 0;

      double bestPrice = (p.core.direction == LONG ? DBL_MAX : -DBL_MAX);
      int newSomIdx = -1;

      // Suche nach dem tiefsten/höchsten DREIER seit letztem SoM
      for(int i = lastSomIdx + 1; i < patternCount; i++)
        {
         if(patterns[i].core.timeFrame != p.core.timeFrame)
            continue;

         if(patterns[i].core.type != DREIER)
            continue;

         if(patterns[i].core.direction != p.core.direction)
            continue;

         structPattern x = patterns[i];

         if(p.core.direction == LONG)
           {
            if(x.core.priceLow < bestPrice)
              {
               bestPrice = x.core.priceLow;
               newSomIdx = i;
              }
           }
         else
           {
            if(x.core.priceHigh > bestPrice)
              {
               bestPrice = x.core.priceHigh;
               newSomIdx = i;
              }
           }
        }

      if(newSomIdx < 0)
        {
         Print(__FUNCTION__, " Kein neuer SoM gefunden");
         return;
        }

      // ------------------------------------ SoM setzen
      if(p.core.direction == LONG)
         meta[tfIdx].lastSoMLongIdx = newSomIdx;
      else
         meta[tfIdx].lastSoMShortIdx = newSomIdx;

      // StartOfMove markieren
      patterns[newSomIdx].dynamic.isStartOfMove = true;
      patterns[newSomIdx].dynamic.sequenceSinceStartOfMove = 0;

      // EmitEvent(som, "START_OF_MOVE", som.core.validFrom, som.dynamic.priceExtremeBeforeBreak);

      int seq = 0;

      // StartOfMove setzt seq = 0
      seq = 0;

      int seqDreierLong  = 0;
      int seqDreierShort = 0;
      int seqHammerLong  = 0;
      int seqHammerShort = 0;

      for(int i = newSomIdx + 1; i < patternCount; i++)
        {
         if(patterns[i].core.timeFrame != p.core.timeFrame)
            continue;

         // DREIER LONG
         if(patterns[i].core.type == DREIER && patterns[i].core.direction == LONG)
           {
            seqDreierLong++;
            patterns[i].dynamic.sequenceSinceStartOfMove = seqDreierLong;
            continue;
           }

         // DREIER SHORT
         if(patterns[i].core.type == DREIER && patterns[i].core.direction == SHORT)
           {
            seqDreierShort++;
            patterns[i].dynamic.sequenceSinceStartOfMove = seqDreierShort;
            continue;
           }

         // HAMMER LONG
         if(patterns[i].core.type == HAMMER_BAR && patterns[i].core.direction == LONG)
           {
            seqHammerLong++;
            patterns[i].dynamic.sequenceSinceStartOfMove = seqHammerLong;
            continue;
           }

         // HAMMER SHORT
         if(patterns[i].core.type == HAMMER_BAR && patterns[i].core.direction == SHORT)
           {
            seqHammerShort++;
            patterns[i].dynamic.sequenceSinceStartOfMove = seqHammerShort;
            continue;
           }
        }
     }

   // ---------------------------------------------------------
   void              DistanceAndAtr(structPattern &p,
                                    double &start, // Rückgabe
                                    double &nominal,  // Rückgabe
                                    double &atr)    // Rückgabe
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

      nominal += p.core.priceSlopePerBar * (barIndex - p.core.startBarIndex);
      start   += p.core.priceSlopePerBar * (barIndex - p.core.startBarIndex);
     };
  }; // End class PatternManager

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double            ComputePatternStrength(structPattern &p)
  {
   double strength = 0.0;

// --- Mikrostruktur ---
   strength += (p.core.rangeBarA + p.core.rangeBarB + p.core.rangeBarC);
   strength += p.core.wickRatio;
   strength += MathAbs(p.core.priceSlopePerBar);
   strength += (p.core.priceHigh - p.core.priceLow);   // width

// --- Kontext ---
//   if(p.core.trendContextAtCreate == UP)   strength += 1.0;
//   if(p.core.trendContextAtCreate == DOWN) strength += 1.0;
//   if(p.core.sessionAtCreate == SESSION_US) strength += 0.5;

// --- Relation zum Vorgänger ---
   if(p.core.previousStartPriceRelation == BEYOND)
      strength += 1.0;
   if(p.core.previousStartPriceRelation == BEHIND)
      strength -= 1.0;

   strength += MathAbs(p.core.priceDeltaToPreviousPattern);
   strength += MathAbs(p.core.priceOffsetToPreviousPattern);

   if(p.core.isInsidePrevious)
      strength -= 0.5;
   if(p.core.isOutsidePrevious)
      strength += 0.5;
   if(p.core.isOverlapingPrevious)
      strength -= 0.2;

// --- ATR‑Normierung ---
//   double start, nominal, atr;
//   DistanceAndAtr(p, start, nominal, atr);

//  if(atr > 0.0)
//      strength /= atr;

   return strength;
  }


#endif


//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
