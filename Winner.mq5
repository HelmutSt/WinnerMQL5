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
MqlRates rates[6];
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


struct dreierStruct
  {
   datetime          time;         // Anfangszeit 
   double            level;        // Level
   double            pkt1;         // Punkte 1
   double            richtung;     // "L" oder "S"
   string            status;       // off, ang, tkp, kpt, fake, aus
  };
dreierStruct dreier[100];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
// EventSetTimer(60);

// -- arrays leeren
   for(int timeframe=0;timeframe<4;timeframe++)
     {
      for(int pos=0;pos<4;pos++)
        {
         bar[timeframe,pos].time   = 0;
         bar[timeframe,pos].open   = 0;
         bar[timeframe,pos].high   = 0;
         bar[timeframe,pos].low    = 0;
         bar[timeframe,pos].close  = 0;
         bar[timeframe,pos].volume = 0;
        }
     };

//---
   lastTick.time = TimeLocal();
   lastTick.last = 77;

   for(int i=0;i<5;i++)
     {
      TickVerarbeiten(__FUNCTION__);
      lastTick.time = lastTick.time +60;
      lastTick.last++;
     };

   ExpertRemove();

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   Print("---------- ONDEINIT------------");
   EventKillTimer();
   return;
  };
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   /*
      lastTick.time = 0;
      lastTick.bid   = 0;
      lastTick.ask    = 0;
      lastTick.last    = 0;
      lastTick.volume   = 0;
      lastTick.time_msc  = 0;
      lastTick.flags      = 0;
      lastTick.volume_real  = 0;
   */
   if(!SymbolInfoTick(Symbol(),lastTick)) // Tick lesen - Cont&Replay arbeiten mit Remote Tick
      return;

   TickVerarbeiten(__FUNCTION__);
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---

  }
//+------------------------------------------------------------------+
bool TickVerarbeiten(string xCaller)
  {
// --- newBar ?
   if(lastTick.time  >= bar[M1,lfd].time + 60)
     {BarsRollen();};


   return(true);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BarsRollen()
  {
   Print("------- ROLLEN ---------");
   int barBreit; // sekunden
   for(int timeframe=0;timeframe<4;timeframe++)
     {
      switch(timeframe)
        {
         case D1:
            barBreit = 24 * 60 * 60;
            break;
         case H1:
            barBreit = 60 * 60;
            break;
         case M3:
            barBreit = 3 * 60;
            break;
         default:
            barBreit = 60;
            break;
        };
      // --- Rollen
      if(lastTick.time  >= bar[timeframe,lfd].time + barBreit)
        {
         for(int pos=3;pos>0;pos--)
           {
            double test = bar[timeframe,pos-1].open   ;
            bar[timeframe,pos].time   = bar[timeframe,pos-1].time;
            bar[timeframe,pos].open   = bar[timeframe,pos-1].open   ;
            bar[timeframe,pos].high   = bar[timeframe,pos-1].high   ;
            bar[timeframe,pos].low    = bar[timeframe,pos-1].low    ;
            bar[timeframe,pos].close  = bar[timeframe,pos-1].close  ;
            bar[timeframe,pos].volume = bar[timeframe,pos-1].volume ;
           };
         // --- neuen Bar initialisieren
         datetime nextTime = (datetime) MathRound(lastTick.time/barBreit)* barBreit;
         bar[timeframe,lfd].time   = (datetime) MathRound(lastTick.time/barBreit)* barBreit;
         bar[timeframe,lfd].open   = lastTick.last;
         bar[timeframe,lfd].high   = lastTick.last;
         bar[timeframe,lfd].low    = lastTick.last;
         bar[timeframe,lfd].close  = lastTick.last;
         bar[timeframe,lfd].volume = (long) lastTick.volume;
        };
     };

   BarDump();

   return(true);
  };
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void BarDump()
  {
   Print("tf  pos   time       open  high  low  close");
   Print("---------------------------------");
// --- Dumpen
  for(int timeframe=0;timeframe<4;timeframe++)
      {
      string tf = "M1";
      if(timeframe==1)
         tf = "M3";
      if(timeframe==2)
         tf = "H1";
      if(timeframe==3)
         tf = "D1";
      for(int pos=0;pos<4;pos++)
        {
         PrintFormat("%s   %d    %s     %.0f %.0f %.0f %.0f %.0f",
                     tf,
                     pos,
                     TimeToString(bar[timeframe,pos].time,TIME_MINUTES|TIME_SECONDS),
                     bar[timeframe,pos].open,
                     bar[timeframe,pos].high,
                     bar[timeframe,pos].low,
                     bar[timeframe,pos].close,
                     bar[timeframe,pos].volume);
        };
     };
   return;
  };
//+------------------------------------------------------------------+
