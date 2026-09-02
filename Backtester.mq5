//+---------------------------------------------------------------------------+
//|                                                                           |
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2022, Helmut Stallmann"
#property version   "3.000"

#define NUM_TIMEFRAMES 4

#include "RenderQueue.mqh"
#include "TimeZones.mqh"

// --- das Engine Paket ---
#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"
#include "Engine.mqh"

// Manager-Klassen
#include "MarketManager.mqh"
#include "BarManager.mqh"
#include "PatternManager.mqh"
#include "EventManager.mqh"
#include "TradeManager.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
// --- Arrays; Ticks und Bars
MqlTick tick;
int tickCount;

CRenderQueue      renderQueue;

CEngine           engine;
CMarketManager    marketManager;
CBarManager       barManager;
CPatternManager   patternManager;
CEventManager     eventManager;
CTradeManager     tradeManager;

//-------------------------------------------------------------------+
//| O N  I N I T                                                     |
//+------------------------------------------------------------------+
int OnInit()
  {
// engine init
   structEngineConfig config;
   config.Init();
   config.currentTfOnly = false;    // true = nur aktueller TF, false = alle TF
   config.renderToChart = true;    // Objekte für Ausgabe im Chart rendern
   config.backtestMode = true;      // Varianten erzeugen und Backtesten, Ausgabe für rule induction

   engine.Init(config);

   tickCount = 0;
   return(INIT_SUCCEEDED);
  };
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print(__FUNCTION__,"--- OnDeinit");
   EventKillTimer();
   engine.DeInit();
  };
//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(SymbolInfoTick(Symbol(),tick)) // Tick lesen - Cont&Replay arbeiten mit Remote Tick
      if((tick.flags&TICK_FLAG_LAST) == TICK_FLAG_LAST)
         engine.OnEaTick(tick);

   tickCount++;
   if(tickCount > 500)
     {
      tickCount = 0;
      renderQueue.Process();
     }
  };
//+------------------------------------------------------------------+
