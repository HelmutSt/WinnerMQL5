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
#define BarCloseId 1
#define DreierNeuId 2
#define DreierKaputtId 3

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
   int               timeFrame;
   long              idx;
   long              id;
   string            typ;          // H1; H1Kont; TBvEZ; H1Tang; M3Tang; Fake; 
   datetime          time;         // Anfangszeit
   double            level;        // Level
   double            pkt1;         // Punkte 1
   string            richtung;     // "L" oder "S"
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

// --- Situation aktuell
string aktullerTrend[4];
bool   dreierLongMoeglich[4];
bool   dreierShortMoeglich[4];

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
   for(int timeFrame=0;timeFrame<4;timeFrame++)
     {
      range[timeFrame].price0  = 0; // Range AUS!
      aktullerTrend[timeFrame] = "L";  // Erstmal falsch wird schnell korrigiert
      dreierLongMoeglich[timeFrame] = true;
      dreierShortMoeglich[timeFrame] = true;;
     };
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
   if(id == 1003)
     {DreierKaputt(lparam, dparam, sparam); return;}


//         EventChartCustom(ChartID(),eventID,lparam,dparam,sparam);


   return;
  };

//+------------------------------------------------------------------+
