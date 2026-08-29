//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __MARKETMANAGER_MQH__
#define __MARKETMANAGER_MQH__

#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMarketManager
  {
public:
   Direction         previoustrend;
   bool firstTick;
   // -------------------------------------------------------------------
                     CMarketManager()
                     {engine.market.Init();firstTick = true;previoustrend = LONG;}
   // -------------------------------------------------------------------
   void              OnTick(MqlTick &t)    // Tick-basierte Dinge (Spread, News etc.)
     {
      engine.market.spread = t.ask - t.bid;
      // News / Auction / Volatility können hier später ergänzt werden
     }

   // -------------------------------------------------------------------
   void              OnNewBar(structBarBlock &bb)
     {
     //if(firstTick) {firstTick = false;}
     
      if(bb.timeFrame == PERIOD_M1)     return;

      // TrendStrength
      engine.market.trendStrength =
         (int)engine.market.trendMathM3 +
         (int)engine.market.trendMathH1 +
         (int)engine.market.trendMathD1;

      // TrendChange
      engine.market.trendChange =
         (engine.market.trendMathM3 != FLAT &&
          engine.market.trendMathH1 != FLAT &&
          engine.market.trendMathM3 != engine.market.trendMathH1);

      // -------------------------------------------------------------------
      // TrendStart
      if(engine.market.trendMathM3 == engine.market.trendMathH1 &&
         engine.market.trendMathM3 != previoustrend)
        {
         previoustrend = engine.market.trendMathM3;
         engine.market.trendStart = bb.bars[1].time;
        }

      // -------------------------------------------------------------------
      // RangeStart
      bool isRange =
         engine.market.isLowVolatility &&
         engine.market.trendStrength < 0.3 &&
         !engine.market.trendChange;

      if(isRange)
        {
         if(engine.market.rangeStart == 0)
            engine.market.rangeStart = bb.bars[1].time;
        }
      else
        {
         engine.market.rangeStart = 0;
        }

      // -------------------------------------------------------------------
      // Session / Auction / Expiration
      datetime nowUTC = bb.bars[0].time;
      datetime nowCET = UtcToCet(nowUTC);
      datetime nowET  = UtcToEt(nowUTC);

      MqlDateTime nowUTCdt;
      TimeToStruct(nowUTC, nowUTCdt);
      MqlDateTime nowCETdt;
      TimeToStruct(nowCET, nowCETdt);
      MqlDateTime nowETdt;
      TimeToStruct(nowET,  nowETdt);

      UpdateSession(nowUTCdt);
      UpdateSessionPhase(nowUTCdt, nowCETdt, nowETdt);
      UpdateExpirationFlags(nowCETdt); //  verfall

      // Volatility Flags (Preisvolatilität)
      engine.market.isHighVolatility = (engine.market.atrRatioM3_H1 > 1.2);
      engine.market.isLowVolatility  = (engine.market.atrRatioM3_H1 < 0.6);

      // Volume Flags (Marktaktivität)
      engine.market.isHighVolume     = (engine.market.relativeVolume > 1.5);
      engine.market.isLowVolume      = (engine.market.relativeVolume < 0.7);

     }
     // -------------------------------------------------------------------
   void              TrendSet(datetime time, string trendName, Direction newTrend)
     {
      bool write = false;

      if(trendName == "trendMathM3" && newTrend != engine.market.trendMathM3)
        {engine.market.trendMathM3 = newTrend;write=true;};
      if(trendName == "trendMathH1"&& newTrend != engine.market.trendMathH1)
        {engine.market.trendMathH1 = newTrend;write=true;};
      if(trendName == "trendMathD1"&& newTrend != engine.market.trendMathD1)
        {engine.market.trendMathD1 = newTrend;write=true;};
        
      if(trendName == "trendPatternM3"&& newTrend != engine.market.trendPatternM3)
        {engine.market.trendPatternM3 = newTrend;write=true;};
      if(trendName == "trendPatternH1"&& newTrend != engine.market.trendPatternH1)
        {engine.market.trendPatternH1 = newTrend;write=true;};
        
      if(trendName == "targetTrendH1"&& newTrend != engine.market.targetTrendH1)
        {engine.market.targetTrendH1 = newTrend;write=true;};

      if(!write)
         return;

      structTrend t;
      t.time      = time;
      t.trendName = trendName;
      t.trend     = newTrend;

      DBExecute(__FUNCTION__, t.ToSQL());
     };
     
private:
   // --- Session ---------------------------------------------------------------
   void              UpdateSession(MqlDateTime &nowUTCdt)
     {
      SessionType previousSession = engine.market.session;

      int hour = nowUTCdt.hour;

      if(hour >= 1 && hour < 8)
         engine.market.session = ASIA;
      else
         if(hour >= 8 && hour < 14)
            engine.market.session = EU;
         else
            engine.market.session = US;

      // Sessionwechsel erkannt?
      if(engine.market.session != previousSession)
         engine.market.sessionStart = (datetime)StructToTime(nowUTCdt);
     };

   // -------------------------------------------------------------------
   void              UpdateSessionPhase(MqlDateTime &nowUTCdt, MqlDateTime &nowCETdt, MqlDateTime &nowETdt)
     {
      int tCET = nowCETdt.hour * 100 + nowCETdt.min;
      int tET  = nowETdt.hour  * 100 + nowETdt.min;   // ← korrekt

      if(tCET < 800)
         engine.market.sessionPhase = SP_Overnight;
      else
         if(tCET < 855)
            engine.market.sessionPhase = SP_PreKassa;
         else
            if(tCET < 905)
               engine.market.sessionPhase = SP_KassaOpen;
            else
               if(tCET < 1700)
                  engine.market.sessionPhase = SP_EU_Open;
               else
                  if(tCET < 2150)
                     engine.market.sessionPhase = SP_KassaClose;
                  else
                     if(tCET < 2200)
                        engine.market.sessionPhase = SP_LastMinutes;
                     else
                        engine.market.sessionPhase = SP_Overnight;

      if(tET >= 930 && tET < 1130)
         engine.market.sessionPhase = SP_US_Open;

      engine.market.isAuction = (engine.market.sessionPhase == SP_PreKassa ||
                                 engine.market.sessionPhase == SP_KassaOpen ||
                                 engine.market.sessionPhase == SP_KassaClose);
     }

// --- Expiration ------------------------------------------------------------------
   void              UpdateExpirationFlags(MqlDateTime &nowCETdt)
     {
      int dow   = nowCETdt.day_of_week;
      int month = nowCETdt.mon;
      int dom   = nowCETdt.day;

      bool isQuarter     = (month == 3 || month == 6 || month == 9 || month == 12);
      bool isThirdFriday = (dow == 5 && dom >= 15 && dom <= 21);

      engine.market.isSmallExpirationDay = isThirdFriday;
      engine.market.isBigExpirationDay   = (isQuarter && isThirdFriday);
      engine.market.isExpirationDay      = (engine.market.isSmallExpirationDay || engine.market.isBigExpirationDay);
     }
  };

#endif

