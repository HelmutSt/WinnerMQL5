//+------------------------------------------------------------------+
//|                                                       Winner.mq5 |
//|                            Copyright 2020,www.HelmutStallmann.de |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020,www.HelmutStallmann.de"
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Konstanten                                                       |
//+------------------------------------------------------------------+
#define M1 0
#define M3 1
#define H1 2
#define D1 3

#define lfd 0


//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
MqlTick lastTick;
MqlDateTime dtStruct;

struct strucBar
  {
   datetime          time;         // Anfangszeit der Periode
   double            open;         // Eroeffnungspreis
   double            high;         // der hoechste Preis der Periode
   double            low;          // der niedrigste Preis der Periode
   double            close;        // Schlusspreis
   long              volume;       // volumen
  };
strucBar bar[4,4];
int barMax = 4;


struct dreierStruct
  {
   datetime          time;         // Anfangszeit
   double            level;        // Level
   double            pkt1;         // Punkte 1
   double            richtung;     // "L" oder "S"
   string            status;       // off, ang, tkp, kpt, fake, aus
  };
dreierStruct dreier[100];

// --- includes
#include "Bars.mqh"
#include "Ticks.mqh"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
// EventSetTimer(60);

   BarsArrayInit();

//^--- alte M1-BArs als pseudo ticks durchlaufen lassen
   AlteBarsGenerieren();

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("---------- ONDEINIT------------");
   EventKillTimer(); //--- destroy timer
   return;
  };
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!SymbolInfoTick(Symbol(),lastTick)) // Tick lesen - Cont&Replay arbeiten mit Remote Tick
      return;
   TickVerarbeiten(__FUNCTION__);
  };
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {  };


//+------------------------------------------------------------------+
