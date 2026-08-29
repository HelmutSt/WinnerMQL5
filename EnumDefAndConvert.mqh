//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __STRUCTNENUM_MQH__
#define __STRUCTNENUM_MQH__

// ----------------------------------------------------------------
// ENUMS STruct und ToFIle FromFile
// ----------------------------------------------------------------
enum EntryMode { AUTOENTRY, // errechnet
                 MANUALENTRY  // manuell bestimmt
               };

//--- Session Enums
enum SessionType
  {
   ASIA = 0,
   EU   = 1,
   US   = 2
  };

enum SessionPhase
  {
   SP_Overnight   = 0,   // 01:05 – 08:55
   SP_PreKassa    = 1,   // 08:00 – 08:55
   SP_KassaOpen   = 2,   // 09:05 – 14:30
   SP_EU_Open     = 3,   // 14:30 – 17:30
   SP_KassaClose  = 4,   // 17:30 – 21:50
   SP_LastMinutes = 5,   // 21:50 – 22:00
   SP_US_Open     = 6    // 14:30 – 17:30
  };

enum Direction        { SHORT = -1, FLAT = 0, LONG = 1 };

enum PreviousRelation { BEHIND = -1, EVEN = 0, BEYOND = +1 };

enum BarShape      { UNCLASSIFIED, DOJI, HAMMER, INVHAMMER };

enum PatternType   { PT_UNDEFINED, DREIER, RANGE, VTH, HAMMER_BAR, TANGENTE };   //

enum PatternStatus { PS_UNDEFINED = 0, OPEN = 1, BROKEN = 2, CLOSED = 3};

enum EventReason
  {
   IS_CREATED,
   IS_STRONGER_THAN_PREVIOUS,
   IS_NEAR_TOUCHED,
   IS_TOUCHED,
   IS_FAKE_BREAK,
   IS_BROKEN,
   IS_TREND_BREAK,
// nach BROKEN
   IS_POSTBREAK_RETEST_NEAR_TOUCHED,
   IS_POSTBREAK_RETEST_TOUCHED,
   IS_POSTBREAK_RETEST_FAKE_BREAK,
   IS_POSTBREAK_RETEST_BROKEN
  };

enum relationSlots
  {
   M3_EventOrigin = 0,
   M3_Last_SoM_SHORT = 1,
   M3_Last_DREIER_SHORT = 2,
   M3_Last_HAMMER_BAR_SHORT = 3,
   M3_Last_HAMMER_BAR_LONG = 4,
   M3_Last_DREIER_LONG = 5,
   M3_Last_SoM_LONG = 6,

   H1_NEXT_DREIER_SHORT = 7,
   H1_NEXT_VTH_SHORT,
   H1_NEXT_TANGENTE_SHORT,
   H1_NEXT_DREIER_LONG,
   H1_NEXT_VTH_LONG,
   H1_NEXT_TANGENTE_LONG,

   D1_NEXT_TANGENTE_SHORT,
   D1_NEXT_TANGENTE_LONG
  };

enum OrderType {LIMIT,STOP,TRAILING_STOP,MARKET};

enum TradeStatus
  {
   TRADE_WAITING,         // Variante existiert, aber noch kein Fill
   TRADE_RUNNING,         // Trade ist gefüllt und läuft
   TRADE_OUT              // Trade ist beendet (SL/TP/Exit)
  };
enum ExitReason
  {
   EXIT_NONE = 0,          // sollte nie vorkommen, aber sicherheitshalber
   EXIT_SL,                // StopLoss ausgelöst
   EXIT_TP,                // TakeProfit ausgelöst
   EXIT_ABORT_WAITING,     // wartende Order (LIMIT/STOP) nach x Bars ohne Fill gecancelt
   EXIT_ABORT_TRAILING,    // TrailingStopEntry bricht ab (Kurs läuft weg)
   EXIT_NOFILL,            // Order wurde nie gefillt (Limit/Stop)
   EXIT_TIME,              // Zeitlimit erreicht
   EXIT_SESSION,           // Session-Ende
   EXIT_RULE               // Regelbasierter Exit (z.B. PatternChange)
  };
//+------------------------------------------------------------------+
//| Hilfsfunktion: Direction
//+------------------------------------------------------------------+
void Toogle(Direction &r)
  {
   if(r == LONG)
      r = SHORT;
   if(r == SHORT)
      r = LONG;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Direction  StringToDirection(string val)
  {
   if(val=="LONG"  || val=="L" || val=="DIR_LONG")
      return LONG;
   if(val=="SHORT" || val=="S" || val=="DIR_SHORT")
      return SHORT;
   return LONG;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string DirectionToString(Direction val)
  {
   if(val==LONG)
      return "LONG";
   if(val==SHORT)
      return "SHORT";
   return "-";
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ExitReason StringToExitReason(string val)
  {
   if(val == "EXIT_SL" || val == "SL")
      return EXIT_SL;

   if(val == "EXIT_TP" || val == "TP")
      return EXIT_TP;

   if(val == "EXIT_ABORT_WAITING" || val == "ABORT_WAITING")
      return EXIT_ABORT_WAITING;

   if(val == "EXIT_ABORT_TRAILING" || val == "ABORT_TRAILING")
      return EXIT_ABORT_TRAILING;

   if(val == "EXIT_NOFILL" || val == "NOFILL")
      return EXIT_NOFILL;

   if(val == "EXIT_TIME" || val == "TIME")
      return EXIT_TIME;

   if(val == "EXIT_SESSION" || val == "SESSION")
      return EXIT_SESSION;

   if(val == "EXIT_RULE" || val == "RULE")
      return EXIT_RULE;

   return EXIT_NONE;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ExitReasonToString(ExitReason val)
  {
   switch(val)
     {
      case EXIT_SL:
         return "SL";
      case EXIT_TP:
         return "TP";
      case EXIT_ABORT_WAITING:
         return "ABORT_WAITING";
      case EXIT_ABORT_TRAILING:
         return "ABORT_TRAILING";
      case EXIT_NOFILL:
         return "NOFILL";
      case EXIT_TIME:
         return "TIME";
      case EXIT_SESSION:
         return "SESSION";
      case EXIT_RULE:
         return "RULE";
     }
   return "NONE";
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SessionType StringToSessionType(string val)
  {
   if(val == "ASIA")
      return ASIA;
   if(val == "EU")
      return EU;
   if(val == "US")
      return US;

// Fallback
   return ASIA;   // oder ein anderer Default, je nach Systemdesign
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PreviousRelation StringToPreviousRelation(string val)
  {

   if(val=="BEYOND")
      return BEYOND;
   if(val=="BEHIND")
      return BEHIND;
   return EVEN;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SessionPhase StringToSessionPhase(string val)
  {
   if(val == "SP_Overnight")
      return SP_Overnight;  // 01:05 – 08:55
   if(val == "SP_PreKassa")
      return    SP_PreKassa;  //  // 08:00 – 08:55
   if(val == "SP_KassaOpen")
      return    SP_KassaOpen;  //  // 09:05 – 14:30
   if(val == "SP_EU_Open")
      return   SP_EU_Open;  //   // 14:30 – 17:30
   if(val == "SP_KassaClose")
      return    SP_KassaClose;  //  // 17:30 – 21:50
   if(val == "SP_LastMinutes")
      return   SP_LastMinutes;  //  // 21:50 – 22:00
   if(val == "SP_US_Open")
      return    SP_US_Open;  //  // 14:30 – 17:30
// Fallback
   return SP_Overnight;  ;   // oder ein anderer Default, je nach Systemdesign
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
TradeStatus StringToTradeStatus(string val)
  {
   if(val == "TRADE_WAITING")
      return TRADE_WAITING;
   if(val == "TRADE_RUNNING")
      return TRADE_RUNNING;
   if(val == "TRADE_OUT")
      return TRADE_OUT;
   return TRADE_OUT;
  };



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
BarShape StringToBarShape(string val)
  {
   if(val == "DOJI")
      return DOJI;
   if(val == "HAMMER")
      return HAMMER;
   if(val == "INVHAMMER")
      return INVHAMMER;

   return UNCLASSIFIED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PatternStatus StringToPatternStatus(string val)
  {
   if(val == "OPEN")
      return OPEN;
   if(val == "BROKEN")
      return BROKEN;
   if(val == "CLOSED")
      return CLOSED;
   return PS_UNDEFINED;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Timeframe
ENUM_TIMEFRAMES StringToTimeFrame(string val)
  {
   if(val=="M1" || val=="PERIOD_M1")
      return PERIOD_M1;
   if(val=="M3" || val=="PERIOD_M3")
      return PERIOD_M3;
   if(val=="H1" || val=="PERIOD_H1")
      return PERIOD_H1;
   if(val=="D1" || val=="PERIOD_D1")
      return PERIOD_D1;
   return (ENUM_TIMEFRAMES)0;
  };

//+------------------------------------------------------------------+
string TimeFrameToString(ENUM_TIMEFRAMES timeFrame)
  {
   switch(timeFrame)
     {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M3:
         return "M3";
      case PERIOD_H1:
         return "H1";
      case PERIOD_D1:
         return "D1";
      default:
         Print(__FUNCTION__ + " Unbekannter TimeFrame");
     };
   return "??";
  };

//+------------------------------------------------------------------+
int TimeFrameToIndex(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:
         return 0;
      case PERIOD_M3:
         return 1;
      case PERIOD_H1:
         return 2;
      case PERIOD_D1:
         return 3;
     }
   MessageBox("FATAL ERROR: TfToIndex() received invalid  = " + EnumToString(tf));
   ExpertRemove();   // EA sofort stoppen

   return -1; // wird nie erreicht
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES IndexToTimeFrame(int idx)
  {
   switch(idx)
     {
      case 0:
         return PERIOD_M1;
      case 1:
         return PERIOD_M3;
      case 2:
         return PERIOD_H1;
      case 3:
         return PERIOD_D1;
     }
   MessageBox("FATAL ERROR: IdxToTf() received invalid index = " + IntegerToString(idx));
   ExpertRemove();   // EA sofort stoppen
   return PERIOD_CURRENT; // wird nie erreicht
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PatternType StringToPatternType(string val)
  {
   if(val=="DREIER")
      return DREIER;
   if(val=="RANGE")
      return RANGE;
   if(val=="VTH")
      return VTH ;
   if(val=="HAMMER_BAR")
      return HAMMER_BAR;
   if(val=="TANGENTE")
      return TANGENTE;
   return PT_UNDEFINED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
EventReason StringToEventReason(const string &val)
  {
   if(val == "IS_CREATED")
      return IS_CREATED;
   if(val == "IS_STRONGER_THAN_PREVIOUS")
      return IS_STRONGER_THAN_PREVIOUS;
   if(val == "IS_NEAR_TOUCHED")
      return IS_NEAR_TOUCHED;
   if(val == "IS_TOUCHED")
      return IS_TOUCHED;
   if(val == "IS_FAKE_BREAK")
      return IS_FAKE_BREAK;
   if(val == "IS_BROKEN")
      return IS_BROKEN;
   if(val == "IS_TREND_BREAK")
      return IS_TREND_BREAK;
   if(val == "IS_POSTBREAK_RETEST_NEAR_TOUCHED")
      return IS_POSTBREAK_RETEST_NEAR_TOUCHED;
   if(val == "IS_POSTBREAK_RETEST_TOUCHED")
      return IS_POSTBREAK_RETEST_TOUCHED;
   if(val == "IS_POSTBREAK_RETEST_FAKE_BREAK")
      return IS_POSTBREAK_RETEST_FAKE_BREAK;
   if(val == "IS_POSTBREAK_RETEST_BROKEN")
      return IS_POSTBREAK_RETEST_BROKEN;
// Fallback
   return IS_CREATED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderType StringToOrderType(string val)
  {
   if(val=="LIMIT" || val=="L" || val=="ORDER_LIMIT")
      return LIMIT;

   if(val=="STOP" || val=="S" || val=="ORDER_STOP")
      return STOP;

   if(val=="TRAILING_STOP" || val=="TS" || val=="ORDER_TRAILING_STOP")
      return TRAILING_STOP;

   if(val=="MARKET" || val=="M" || val=="ORDER_MARKET")
      return MARKET;

   return LIMIT;   // Default wie bei Direction
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


#endif
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
