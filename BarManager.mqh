//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __BARMANAGER_MQH__
#define __BARMANAGER_MQH__

#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CBarManager
  {
private:
   structBarBlock    barBlocks[NUM_TIMEFRAMES];

public:
   // ---------------------------------------------------------
                     CBarManager()
     {
      for(int tfIdx = 0; tfIdx < NUM_TIMEFRAMES; tfIdx++)
         barBlocks[tfIdx].Init(tfIdx);
     }

   // ---------------------------------------------------------
   // OnTick
   // ---------------------------------------------------------
   void              OnTick(MqlTick &t)
     {
      for(int tfIdx = 0; tfIdx < NUM_TIMEFRAMES; tfIdx++)
        {
         // nur für debug ENUM_TIMEFRAMES tf = barBlocks[tfIdx].timeFrame;
         int periodSec      = barBlocks[tfIdx].periodSec;
         datetime barBegin = t.time - (t.time % periodSec);

         if(barBegin > barBlocks[tfIdx].bars[0].time)
            BarShift(tfIdx, t, barBegin);
         else
            BarAdd(tfIdx, t);
        }
     };

private:
   // ---------------------------------------------------------
   void              BarShift(int tfIdx, MqlTick &t, datetime barBegin)
     {
      for(int i = 20; i > 0; i--)
         barBlocks[tfIdx].bars[i] = barBlocks[tfIdx].bars[i-1];

      barBlocks[tfIdx].bars[1].shape = DetectBarShape(barBlocks[tfIdx].bars[1]);

      if(barBlocks[tfIdx].bars[3].time > 0 || barBlocks[tfIdx].timeFrame == PERIOD_D1)
         UpdateStats(tfIdx);

      // den neuen Initialisieren
      int barIdx = barBlocks[tfIdx].bars[1].barIndex  + 1;

      barBlocks[tfIdx].bars[0].time     = barBegin;
      barBlocks[tfIdx].bars[0].open     = t.last;
      barBlocks[tfIdx].bars[0].high     = t.last;
      barBlocks[tfIdx].bars[0].low      = t.last;
      barBlocks[tfIdx].bars[0].close    = t.last;
      barBlocks[tfIdx].bars[0].volume   = t.volume;
      barBlocks[tfIdx].bars[0].shape    = UNCLASSIFIED;
      barBlocks[tfIdx].bars[0].barIndex = barIdx;

      double sp0 = t.ask - t.bid;
      barBlocks[tfIdx].bars[0].spreadSum   = sp0;
      barBlocks[tfIdx].bars[0].spreadCount = 1;
      barBlocks[tfIdx].bars[0].spreadMax   = sp0;

      // Trend bestimmen
      barBlocks[tfIdx].trend = GetTrendFromBars(barBlocks[tfIdx]);

      // NewBar melden
      if(barBlocks[tfIdx].bars[2].time > 0 || barBlocks[tfIdx].timeFrame == PERIOD_D1)
         engine.OnNewBar(barBlocks[tfIdx]);
     }


   // ---------------------------------------------------------
   void              BarAdd(int tfIdx, MqlTick &t)
     {
      barBlocks[tfIdx].bars[0].high   = MathMax(barBlocks[tfIdx].bars[0].high, t.last);
      barBlocks[tfIdx].bars[0].low    = MathMin(barBlocks[tfIdx].bars[0].low,  t.last);
      barBlocks[tfIdx].bars[0].close  = t.last;
      barBlocks[tfIdx].bars[0].volume += t.volume;

      double sp = t.ask - t.bid;
      barBlocks[tfIdx].bars[0].spreadSum += sp;
      barBlocks[tfIdx].bars[0].spreadCount++;
      if(sp > barBlocks[tfIdx].bars[0].spreadMax)
         barBlocks[tfIdx].bars[0].spreadMax = sp;
     }

   // ---------------------------------------------------------
   BarShape          DetectBarShape(const structBar &b)
     {
      double body  = MathAbs(b.close - b.open);
      double range = b.high - b.low;

      if(range <= 5)
         return UNCLASSIFIED;

      double upperWick = b.high - MathMax(b.open, b.close);
      double lowerWick = MathMin(b.open, b.close) - b.low;

      if(body / range < 0.5 && MathAbs(upperWick - lowerWick) < 2)
         return DOJI;

      if(lowerWick >= body && upperWick <= 2)
         return HAMMER;

      if(upperWick >= body && lowerWick <= 2)
         return INVHAMMER;

      return UNCLASSIFIED;
     }
   // ---------------------------------------------------
   Direction         GetTrendFromBars(const structBarBlock &bb)
     {
     // Wir brauchen mindestens 3 abgeschlossene Bars
      // bars[0] = laufend, bars[1..20] = abgeschlossen
      if(bb.bars[2].time == 0)
         return FLAT;

      // Zähler für LONG/SHORT Signale
      int longCount  = 0;
      int shortCount = 0;

      // Wir prüfen die letzten 20 abgeschlossenen Bars:
      // Vergleich immer bars[i] vs bars[i+1]
      for(int i = 1; i <= 19; i++)
        {
         double highCurr = bb.bars[i].high;
         double lowCurr  = bb.bars[i].low;

         double highPrev = bb.bars[i+1].high;
         double lowPrev  = bb.bars[i+1].low;

         // LONG-Struktur: höhere Hochs + höhere Tiefs
         if(highCurr > highPrev && lowCurr > lowPrev)
            longCount++;

         // SHORT-Struktur: tiefere Hochs + tiefere Tiefs
         else
            if(highCurr < highPrev && lowCurr < lowPrev)
               shortCount++;
        }

      // Stabilisierung:
      // Wenn mindestens 5 der letzten 20 Vergleiche LONG sind → Trend LONG
      if(longCount >= 5 && longCount > shortCount)
         return LONG;

      // Wenn mindestens 5 der letzten 20 Vergleiche SHORT sind → Trend SHORT
      if(shortCount >= 5 && shortCount > longCount)
         return SHORT;

      // Sonst FLAT
      return FLAT;
     }

   // ---------------------------------------------------------
   // ATR + Volume + SpreadStats
   // ---------------------------------------------------------
   void              UpdateStats(int tfIdx)
     {
      // --- ATR ---
      double prevClose = barBlocks[tfIdx].bars[2].close;
      double high      = barBlocks[tfIdx].bars[1].high;
      double low       = barBlocks[tfIdx].bars[1].low;

      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low  - prevClose);
      double TR  = MathMax(tr1, MathMax(tr2, tr3));

      barBlocks[tfIdx].trHistory[barBlocks[tfIdx].pos] = TR;

      double sumTR = 0;
      for(int i=0; i<14; i++)
         sumTR += barBlocks[tfIdx].trHistory[i];

      barBlocks[tfIdx].atr = sumTR / 14.0;

      // --- Volume ---
      double volNow = (double) barBlocks[tfIdx].bars[1].volume;
      barBlocks[tfIdx].avHistory[barBlocks[tfIdx].pos] = volNow;

      double sumAV = 0;
      for(int i=0; i<14; i++)
         sumAV += barBlocks[tfIdx].avHistory[i];

      barBlocks[tfIdx].av = sumAV / 14.0;

      // --- SpreadStats (echter Bid/Ask-Spread, Ø/Max über die letzten 20 abgeschlossenen Bars) ---
      double sumAvgSpread = 0;
      double maxSpreadSeen = 0;

      for(int i=1; i<=20; i++)
        {
         structBar bar = barBlocks[tfIdx].bars[i];
         double barAvgSpread = (bar.spreadCount > 0 ? bar.spreadSum / bar.spreadCount : 0.0);
         sumAvgSpread += barAvgSpread;
         if(bar.spreadMax > maxSpreadSeen)
            maxSpreadSeen = bar.spreadMax;
        }

      barBlocks[tfIdx].avgSpread = sumAvgSpread / 20.0;
      barBlocks[tfIdx].maxSpread = maxSpreadSeen;

      // --- Position update ---
      barBlocks[tfIdx].pos = (barBlocks[tfIdx].pos + 1) % 14;

      if(barBlocks[tfIdx].pos == 0)
         barBlocks[tfIdx].atrReady = true;

      // --- Werte für MarketManager bereitstellen ---
      if(barBlocks[tfIdx].timeFrame == PERIOD_M1)
        {
         engine.market.barIndexM1   = barBlocks[tfIdx].bars[0].barIndex;
         engine.market.atrM1 = barBlocks[tfIdx].atr;
         // M1‑Trend wird nicht benötigt
        }

      if(barBlocks[tfIdx].timeFrame == PERIOD_M3)
        {
         engine.market.barIndexM3   = barBlocks[tfIdx].bars[0].barIndex;
         engine.market.atrM3        = barBlocks[tfIdx].atr;
         engine.market.avM3         = barBlocks[tfIdx].av;
         engine.market.avgSpreadM3  = barBlocks[tfIdx].avgSpread;
         engine.market.maxSpreadM3  = barBlocks[tfIdx].maxSpread;
         engine.market.relativeVolume = (engine.market.avM3 > 0 ? volNow / engine.market.avM3 : 0);
         engine.market.atrRatioM3_H1  = (engine.market.atrH1 > 0 ? engine.market.atrM3 / engine.market.atrH1 : 0.0);
         engine.market.lastUpdate     = barBlocks[tfIdx].bars[0].time;
         marketManager.TrendSet(barBlocks[tfIdx].bars[0].time,"trendMathM3",barBlocks[tfIdx].trend); // ✔ korrekt
        }
      if(barBlocks[tfIdx].timeFrame == PERIOD_H1)
        {
         engine.market.barIndexH1   = barBlocks[tfIdx].bars[0].barIndex;
         engine.market.atrH1        = barBlocks[tfIdx].atr;
         marketManager.TrendSet(barBlocks[tfIdx].bars[0].time,"trendMathH1",barBlocks[tfIdx].trend); // ✔ korrekt
        }
      if(barBlocks[tfIdx].timeFrame == PERIOD_D1)
        {
         engine.market.barIndexD1   = barBlocks[tfIdx].bars[0].barIndex;
         engine.market.atrD1        = barBlocks[tfIdx].atr;
         marketManager.TrendSet(barBlocks[tfIdx].bars[0].time,"trendMathD1",barBlocks[tfIdx].trend); // ✔ korrekt
        }
     };
  };
#endif

//+------------------------------------------------------------------+
