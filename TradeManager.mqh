//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __TRADEMANAGER_MQH__
#define __TRADEMANAGER_MQH__

#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTradeManager
  {

   // ToDO(HE): EXIT_ABORT / EXIT_NOFILL / EXIT_TIME / EXIT_SESSION / EXIT_RULE  setzen
private:
   structTrade       trades[200000];
   int               tradeCount;

   MqlTick           tempTick;
public:
   // ----------------------------------------------------
                     CTradeManager() {tradeCount = 0;};
   // ----------------------------------------------------
   void              DeInit() {};
   // ################################################################################
   void              AddTrade(structTrade &tr)
     {
      trades[tradeCount++] = tr;
      return;
     }
   // ################################################################################
   int               GetCount() const
     {
      return tradeCount;
     }
   // ############################################################
   void              OnTick(const MqlTick &t)
     {
      tempTick = t;
      for(int i = 0; i < tradeCount; i++)
        {
         // enum TradeStatus: TRADE_WAITING, TRADE_RUNNING, TRADE_OUT

         // WAITING → prüfen ob Fill
         if(trades[i].status == TRADE_WAITING)
            OnTick_Waiting(t, trades[i]);

         if(trades[i].status == TRADE_RUNNING)
            OnTick_Running(t,  trades[i]);

         // TRADE_OUT → fertig !  ignorieren

         // MFE = Maximum Favorable Excursion
         // → der größte Gewinn, den ein Trade zwischen Einstieg und Ausstieg irgendwann erreicht hat.

         // MAE = Maximum Adverse Excursion
         // → der größte Verlust, den ein Trade zwischen Einstieg und Ausstieg irgendwann erreicht hat.

         // MFE - rechnen - activ wird in running gesetzt und bleibt solange bis hit_SL
         if(trades[i].mfeActive)
           {
            double diff = (t.last - trades[i].fillPrice) * trades[i].direction;
            if(diff > trades[i].mfe)
              {
               trades[i].mfe = diff;
               trades[i].mfeTime = t.time;
               trades[i].mfeBarIndex =  engine.market.barIndexM3;
              }
            if(-diff >= trades[i].slPoints)
               trades[i].mfeActive = false;
           }
        } // Loop
     };
   // ############################################################
   void              OnNewBar(const structBarBlock &bb)
     {
      if(bb.timeFrame == PERIOD_M3)
         for(int i = 0; i < tradeCount; i++)
            if(trades[i].status == TRADE_RUNNING)
               trades[i].barsHeldUntilExit++; // <-----------------bars zaehlen

     }
   // ################################################################################
   void              OnEvent(const structEvent &ev)
     {
      if(!ev.isEntryEvent)
         return;

      return; // Wir arbeiten noch ohne Positionsmanagement - SL nciht nachziehen

      // SL nachziehen bei neuen M3-DREIER uoder M3 o M1 Hammer
      /*
            bool go = false;

            if(ev.core.type == DREIER && ev.core.timeFrame == PERIOD_M3)
               go = true;
            if(ev.core.type == HAMMER_BAR &&
               (ev.core.timeFrame == PERIOD_M1 || ev.core.timeFrame == PERIOD_M3))
               go = true;

            if(!go)
               return;

            for(int i = 0; i < tradeCount; i++)
              {
               // Nur laufende Trades
               if(trades[i].status != TRADE_RUNNING)
                  continue;

               // DREIER → gleiche Richtung
               bool isDreier =
                  (ev.core.type == DREIER &&
                   trades[i].direction == ev.core.direction);

               // HAMMER → entgegengesetzte Richtung
               bool isHammer =
                  (ev.core.type == HAMMER_BAR &&
                   trades[i].direction != ev.core.direction);

               // Wenn Event nicht relevant → weiter
               if(!isDreier && !isHammer)
                  continue;

               // LONG-Trade
               if(trades[i].direction == LONG)
                 {
                  double newSL = ev.core.priceLow - 1;

                  if(newSL > trades[i].currentSLPrice)
                     trades[i].currentSLPrice = newSL;
                 }

               // SHORT-Trade
               if(trades[i].direction == SHORT)
                 {
                  double newSL = ev.core.priceHigh + 1;

                  if(newSL < trades[i].currentSLPrice)
                     trades[i].currentSLPrice = newSL;
                 }
              } */
     }
   // ############################################################
   void              OnSessionClose() // datetime time, double price
     {
      // schliessen aller Trades und Ausgeben der results
      for(int i = 0; i < tradeCount; i++)
        {
         if(trades[i].status == TRADE_WAITING)
            trades[i].exitReason = EXIT_NOFILL;

         // MFE - in STATUS RUNNING und OUT , nun beenden
         if(trades[i].mfeActive)
            trades[i].mfeActive = false;  // Ende der mfe Berechnung

         if(trades[i].status == TRADE_RUNNING)
           {
            trades[i].exitPrice  = tempTick.last;
            trades[i].exitReason = EXIT_SESSION;
            Out_Setzen(tempTick.time, trades[i]);
           }

         DBExecute(__FUNCTION__,trades[i].ToSQL());

        } // loop

      tradeCount = 0; // Trades Array leer für nächste session
     }
private:
   // ----------------------------------------------------------------

   void              OnTick_Waiting(const MqlTick &t, structTrade &tr)
     {
      // -------------------------
      // ABORT nach X Bars (WAITING, einheitlich für LIMIT/STOP/TRAILING_STOP)
      // -------------------------
      if(tr.abortBars > 0 &&
         (engine.market.barIndexM3 - tr.createBarIndex) >= tr.abortBars)
        {
         Abort_Setzen(t, tr);
         return;
        }

      // -------------------------
      // LIMIT BUY (LONG)
      // -------------------------
      if(tr.orderType == LIMIT &&
         tr.direction == LONG &&
         t.last >= tr.entryPrice)
        {
         Running_Setzen(tr, t);
         return;
        }

      // -------------------------
      // LIMIT SELL (SHORT)
      // -------------------------
      if(tr.orderType == LIMIT &&
         tr.direction == SHORT &&
         t.last <= tr.entryPrice)
        {
         Running_Setzen(tr, t);
         return;
        }

      // -------------------------
      // STOP BUY (LONG)
      // -------------------------
      if(tr.orderType == STOP &&
         tr.direction == LONG &&
         t.last >= tr.entryPrice)
        {
         Running_Setzen(tr, t);
         return;
        }

      // -------------------------
      // STOP SELL (SHORT)
      // -------------------------
      if(tr.orderType == STOP &&
         tr.direction == SHORT &&
         t.last <= tr.entryPrice)
        {
         Running_Setzen(tr, t);
         return;
        }

      // -------------------------
      // TRAILING_STOP ENTRY
      // -------------------------
      if(tr.orderType == TRAILING_STOP)
        {
         // LONG → StopBuy folgt fallendem Kurs
         if(tr.direction == LONG)
           {
            double newEntry = t.last + tr.trailingDist;

            if(newEntry < tr.entryPrice)
               tr.entryPrice = newEntry;

            if(t.last >= tr.entryPrice) // Sofort prüfen ob filled
              {
               Running_Setzen(tr, t);
              }
           }

         // SHORT → StopSell folgt steigendem Kurs
         if(tr.direction == SHORT)
           {
            double newEntry = t.last - tr.trailingDist;

            if(newEntry > tr.entryPrice)
               tr.entryPrice = newEntry;

            if(t.last <= tr.entryPrice)   // Sofort prüfen ob filled
              {
               Running_Setzen(tr, t);
              }
           }
        }
      return;
     };
   // ----------------------------------------------------------------
   void              Running_Setzen(structTrade &tr, const MqlTick &t)
     {
      // Fill-Daten setzen
      tr.fillPrice = tr.entryPrice;
      tr.fillTime  = t.time;
      tr.fillBarIndex = engine.market.barIndexM3;

      tr.barsWaitedForFill = tr.fillBarIndex - tr.createBarIndex;
      
      tr.status    = TRADE_RUNNING;

      tr.mfeActive = true; // ab jetzt tracen

      // SL als Preis berechnen
      if(tr.direction == LONG)
         tr.currentSLPrice = tr.fillPrice - tr.slPoints;   // sl = Distanz
      else
         tr.currentSLPrice = tr.fillPrice + tr.slPoints;

      // TP als Preis berechnen
      if(tr.direction == LONG)
         tr.currentTPPrice = tr.fillPrice + tr.tpPoints;   // tp = Distanz
      else
         tr.currentTPPrice = tr.fillPrice - tr.tpPoints;

      // initial* = unveränderlicher Ursprungswert bei Fill (current* wird später vom Positionsmanagement verändert)
      tr.initialSLPrice = tr.currentSLPrice;
      tr.initialTPPrice = tr.currentTPPrice;
     }
   // ---------------------------------------------------------------------
   void              OnTick_Running(const MqlTick &t, structTrade &tr)
     {
      // -------------------------
      // MAE
      // -------------------------
      double diff = (t.last - tr.fillPrice) * tr.direction;

      if(diff < tr.mae)
        {
         tr.mae = diff;
         tr.maeTime = t.time;
         tr.maeBarIndex =  engine.market.barIndexM3;
        }


      // -------------------------
      // TP1 wird gesetzOutt, wenn currentTPPrice erreicht wird
      // -------------------------

      if((tr.direction == LONG  && t.last >= tr.currentTPPrice) ||
         (tr.direction == SHORT && t.last <= tr.currentTPPrice))
        {
         tr.exitReason = EXIT_TP;
         tr.exitPrice  = tr.currentTPPrice;
         Out_Setzen(t.time, tr);
        }

      // Wenn TwoUNits TP2 aus SL -------------------------------------------

      double slDist = MathAbs(tr.fillPrice - tr.slPoints); // tp2Distance ist immer slDistance
      double tp1Level = tr.fillPrice + slDist * tr.direction;

      if((tr.direction == LONG  && t.last >= tp1Level)    ||
         (tr.direction == SHORT && t.last <= tp1Level))
         tr.twoUnitFilled  = true; // Auswertung im OUT_setzen

      // -------------------------
      // SL
      // -------------------------
      // SL-Exit
      if((tr.direction == LONG  && t.last <= tr.currentSLPrice) ||
         (tr.direction == SHORT && t.last >= tr.currentSLPrice))
        {
         tr.exitReason = EXIT_SL;
         tr.exitPrice  = tr.currentSLPrice;
         Out_Setzen(t.time, tr);
        }
     };


   // ---------------------------------------------------------------------
   void              Abort_Setzen(const MqlTick &t, structTrade &tr)
     {
      // WAITING-Order wird abgebrochen, bevor sie je gefüllt wurde
      tr.status        = TRADE_OUT;
      tr.exitReason     = (tr.orderType == TRAILING_STOP) ? EXIT_ABORT_TRAILING : EXIT_ABORT_WAITING;
      tr.exitPrice      = t.last;
      tr.exitTime       = t.time;
      tr.exitBarIndex   = engine.market.barIndexM3;
      tr.barsHeldUntilAbort = tr.exitBarIndex - tr.createBarIndex;
      tr.profit         = 0.0;   // kein Fill -> kein P/L
     }
   // ---------------------------------------------------------------------
   void                 Out_Setzen(const datetime &time, structTrade &tr)
     {
      // Exit-Daten setzen
      tr.status     = TRADE_OUT;
      tr.exitTime   = time;
      tr.exitBarIndex =  engine.market.barIndexM3;
      tr.barsHeldUntilExit = tr.exitBarIndex - tr.fillBarIndex;

      // Profit berechnen (inkl. TwoUnitMode)
      tr.profit = (tr.exitPrice - tr.fillPrice) * tr.direction;

      if(tr.twoUnitMode)
        {
         if(tr.twoUnitFilled )
            tr.profit += tr.slPoints;   // zweite Unit bei TP1 = SL abgegeben
         else
            tr.profit -= tr.slPoints;   // zweite Unit auch verloren
        }
     }


  }; // Ende CTRADEyManager

#endif
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
