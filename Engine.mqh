//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __ENGINE_MQH__
#define __ENGINE_MQH__

#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"

//+------------------------------------------------------------------+
//|  E N G I N E                                                     |
//|  TODO(HE): average und trend im BarMananger und generell planen
//+------------------------------------------------------------------+
class CEngine
  {

public:
   structEngineConfig      config;
   structMarket           market;
   int                     db;
   // -------------------------------------------------------------------
                     CEngine()
     {
      config.Init();
      market.Init();
     };
                    ~CEngine()   {};
   // -------------------------------------------------------------------
   bool              Init(const structEngineConfig &cfg)
     {
      // Konfiguration übernehmen
      config = cfg;
      if(!DatabaseOpenAndRebuild())
         return(false);

      eventManager.Init();

      Print(__FUNCTION__ + " --- Init() finished ---");
      return(true);
     };
   // -------------------------------------------------------------------------------------
   void              DeInit()
     {
      tradeManager.OnSessionClose();//datetime time, double price
      DatabaseReport();
      DatabaseClose(db);
     };
   // ##############################################################################
   void              OnEaTick(MqlTick &t)
     {
      marketManager.OnTick(t);
      barManager.OnTick(t);         // bildet Bars; in H1 und M1 nur eigenen TF
      patternManager.OnTick(t);     // ändert Status
      tradeManager.OnTick(t);       // sim. fill/sl/tp + ändert Status
     };
   // -------------------------------------------------------------------------------------
   void              OnNewBar(structBarBlock &bb)
     {
     // Print(">>> OnNewBar: ",EnumToString(bb.timeFrame));

      if(bb.timeFrame == PERIOD_D1 && tradeManager.GetCount() > 0)
        {
         // Tageswechsel = Trades schliessen, waiting = NoFill
         Print("OnSession: " + TimeToString(bb.bars[1].time,TIME_DATE) +
               " Trades: " + IntegerToString(tradeManager.GetCount()));
         tradeManager.OnSessionClose();
        }
      marketManager.OnNewBar(bb);
      patternManager.OnNewBar(bb);  // bildet Pattern - finalisiert tempkaputt
      tradeManager.OnNewBar(bb);
     };
   // -------------------------------------------------------------------------------------
   void              OnPattern(structPattern &p)
     {
    //  Print(">>> OnPattern: ",EnumToString(p.core.timeFrame)+" "+EnumToString(p.core.type));
     };
   // -------------------------------------------------------------------------------------
   void              OnEvent(structEvent &ev)
     {
      Print(">>> OnEvent: "+EnumToString(ev.patternTF)+" "+EnumToString(ev.patternType)+" "+EnumToString(ev.eventReason));
      eventManager.OnEvent(ev);
      tradeManager.OnEvent(ev);
     }
   // -------------------------------------------------------------------
   bool              DatabaseOpenAndRebuild(bool clear = false)
     {
      // Datenbank im Common-Folder öffnen
      db = INVALID_HANDLE;
      db = DatabaseOpen("FDAX.db",
                        DATABASE_OPEN_READWRITE |
                        DATABASE_OPEN_CREATE |
                        DATABASE_OPEN_COMMON);

      if(db == INVALID_HANDLE)
        {
         Print("❌ FDAX.db konnte nicht geöffnet werden!");
         return(false);
        }

      Print("✅ FDAX.db erfolgreich geöffnet.");

      // Reihenfolge wegen FK-Abhängigkeiten
      const string drop_sql[]
      =
        {
         "DROP TABLE IF EXISTS trends;",
         "DROP TABLE IF EXISTS trades;",
         "DROP TABLE IF EXISTS variants;",
         "DROP TABLE IF EXISTS market;",
         "DROP TABLE IF EXISTS patternDynamic;",
         "DROP TABLE IF EXISTS relations;",
         "DROP TABLE IF EXISTS events;",
         "DROP TABLE IF EXISTS patternCore;",
        };
      // Drop
      for(int i=0; i<ArraySize(drop_sql); i++)
        {
         if(!DBExecute(__FUNCTION__, drop_sql[i]))
           {
            Print("DB DROP failed: ", drop_sql[i]);
            return false;
           }
        }

      // Creates (man muss die struktur erzeugen bevor man die funktion rufen kann,
      string create_sql[8];
      int i=0;
      structMarket m;
      create_sql[i++] = m.CreateSQL();
      structPattern p;
      create_sql[i++] = p.core.CreateSQL();
      create_sql[i++] = p.dynamic.CreateSQL();
      structEvent e;
      create_sql[i++] = e.CreateSQL();
      structRelation r;
      create_sql[i++] = r.CreateSQL();
      structVariant v;
      create_sql[i++] = v.CreateSQL();
      structTrade t;
      create_sql[i++] = t.CreateSQL();
      structTrend  tr;
      create_sql[i++] = tr.CreateSQL();

      for(int i = 0; i < 8; i++)
        {
         Print(IntegerToString(i)+" DBExecute: " + create_sql[i]);
         if(!DBExecute(__FUNCTION__,create_sql[i]))
           {
            Print("DB CREATE failed: ", create_sql[i]);
            return false;
           }
        }

      Print(__FUNCTION__ + " --- DataBaseRebuild finished ---");

      return true;
     };

   // -------------------------------------------------------------------
   void              DatabaseReport()
     {
      DatabaseClose(db);

      db = DatabaseOpen("FDAX.db",
                        DATABASE_OPEN_READWRITE |
                        DATABASE_OPEN_CREATE |
                        DATABASE_OPEN_COMMON);

      if(db == INVALID_HANDLE)
        {
         Print("❌ FDAX.db konnte nicht geöffnet werden!");
         return;
        }
      Print(earning("market"));
      Print(earning("patternCore"));
      Print(earning("patternDynamic"));
      Print(earning("events"));
      Print(earning("relations"));
      Print(earning("variants"));
      Print(earning("trades"));
      Print(earning("trends"));
     };

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   string            earning(string tableName)
     {
      if(db == INVALID_HANDLE)
        {
         Print("❌ FDAX.db nicht geöffnet!");
         return("error");
        }
      ResetLastError();
      string sql = "SELECT count(*) FROM " + tableName;
      int r2 = DatabasePrepare(db, sql);
      if(r2==INVALID_HANDLE)
        {
         Print("DB: " + sql + "  request failed with LastError-code ", GetLastError());
         DatabaseClose(db);
         return("err");
        }

      DatabaseRead(r2);

      int tCount = -1;
      DatabaseColumnInteger(r2,0,tCount);

      DatabaseFinalize(r2);
      string txt = StringSubstr(tableName+" .................",0,25) + IntegerToString(tCount);
      return(txt);
     };
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool              DBExecute(string funktion, string sql)
  {
// 1. Prüfen ob DB-Handle gültig ist
   if(engine.db == INVALID_HANDLE)
     {
      Print("❌ DBExecute(", funktion, "): Datenbank-Handle ist INVALID_HANDLE.");
      ExpertRemove();   // EA abbrechen
      return(false);
     }

// 2. SQL ausführen
   if(!DatabaseExecute(engine.db, sql))
     {
      int err = GetLastError();
      string meaning = DBErrorMeaning(err);

      Print("---------------------------------------------");
      Print("❌ DBExecute(", funktion, ") fehlgeschlagen.");
      Print("   ➤ SQL: ", sql);
      Print("   ➤ ErrorCode: ", err, " (", meaning, ")");
      Print("   ➤ DB wird geschlossen, EA wird beendet.");

      DatabaseClose(engine.db);
      engine.db = INVALID_HANDLE;

      TesterStop();
      ExpertRemove();   // EA abbrechen
      return(false);
     }

// 4. Erfolgsmeldung (optional)
//    Print("✔ DBExecute(", funktion, ") OK: ", sql);
   return(true);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string            DBErrorMeaning(int code)
  {
   switch(code)
     {
      case 5120:
         return "Database not opened / invalid handle";
      case 5121:
         return "Statement could not be prepared (Prepare-Fehler)";
      case 5122:
         return "Execution failed (Execute-Fehler)";
      case 5123:
         return "Column index invalid";
      case 5124:
         return "Bind failed";
      case 5125:
         return "Read failed";
      case 5601 :
         return "table already exists";
      case 5619:
         return "FOREIGN KEY constraint failed";

      default:
         return "Unknown DB error";
     }
  };

#endif
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
