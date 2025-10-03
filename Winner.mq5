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
   long              id;
   datetime          time;         // Anfangszeit
   double            level;        // Level
   double            pkt1;         // Punkte 1
   double            richtung;     // "L" oder "S"
   string            status;       // off, ang, tkp, kpt, fake, aus
  };
dreierStruct dreier[100];
int dreierMax = 0;

struct rangeStruct
  {
   double            price0;       // Unten
   double            price1;       // Oben
  };
rangeStruct range[4];

// --- KOnstanten
int barBreit[4];


string aktullerTrend[4];


// --- includes
#include "Dreier.mqh"
#include "Bars.mqh"
#include "Ticks.mqh"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
// EventSetTimer(60);

// --- Initialisierung
   range[M1].price0  = 0; // Range AUS!
   range[M3].price0  = 0;
   range[H1].price0  = 0;
   range[D1].price0  = 0;
   aktullerTrend[M1] = "L";  // Erstmal falsch wird schnell korrigiert
   aktullerTrend[M3] = "L";
   aktullerTrend[H1] = "L";
   aktullerTrend[D1] = "L";
   barBreit[M1]      = 60 * 1;   // sek
   barBreit[M3]      = 60 * 3; 
   barBreit[H1]      = 60 * 60;
   barBreit[D1]      = 60 * 60 * 24; 
   BarsArrayInit();

//--- alte M1-Bars als pseudo ticks durchlaufen lassen
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
//| E v e n t s                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == 1001)
     {BarClose(lparam, dparam, sparam); return;}

   if(id == 1002)
     {DreierNeu(lparam, dparam, sparam); return;}

//         EventChartCustom(currChart,eventID,lparam,dparam,sparam);


   return;
  };

//+------------------------------------------------------------------+
