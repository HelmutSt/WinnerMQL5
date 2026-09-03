//+------------------------------------------------------------------+
//|         V I S U A L I S I E R E R                                |
//+------------------------------------------------------------------+
#include "RenderQueue.mqh"
#include "TimeZones.mqh"
#include "EnumDefAndConvert.mqh"
#include "Structures.mqh"

// --- Arrays; Ticks und Bars


int db = -1;
structPatternCore patterns[10000];
int patternCount;

structEvent events[1000];
int eventCount;

datetime mostLeftObjectTime;

CRenderQueue     renderQueue;

string selectedObjectName = "";
bool objectWasClicked = false;

//-------------------------------------------------------------------+
//| O N  I N I T                                                     |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Visualizer EA gestartet.");

// Alle ChartObjects löschen (nur visuelle Objekte)
   ObjectsDeleteAll(0);

// ---------------------------------------------------------
// Datenbank öffnen (READONLY, Common-Folder)
// ---------------------------------------------------------
   db = DatabaseOpen("FDAX.db",
                     DATABASE_OPEN_READONLY | DATABASE_OPEN_COMMON);

   if(db == INVALID_HANDLE)
     {
      Print("❌ FDAX.db konnte nicht geöffnet werden!");
      return(INIT_FAILED);
     }

   Print("✅ FDAX.DB geöffnet");

// ---------------------------------------------------------
// PatternCore + Events rendern
// ---------------------------------------------------------
   RenderTrendBands();
   LoadAndRenderPatterns();
   LoadAndRenderEvents();

// ---------------------------------------------------------
// Chart-Settings für Visualizer
// ---------------------------------------------------------
   ChartSetInteger(0, CHART_AUTOSCROLL, false);
   ChartSetInteger(0, CHART_SHIFT, false);

   ChartSetInteger(0, CHART_SHOW_TICKER, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, false);
   ChartSetInteger(0, CHART_SHOW_ONE_CLICK, false);

   ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);
   ChartSetInteger(0, CHART_SHOW_LAST_LINE, false);

   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, true);
   ChartSetInteger(0, CHART_SHOW_GRID, true);

   ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, false);
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);

// ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,1);

// ---------------------------------------------------------
// "Go to EventID" Eingabebox (oben rechts)
// ---------------------------------------------------------
   CreateGotoEventBox();

// ---------------------------------------------------------
// Chart auf das zuletzt gerenderte Objekt setzen
// ---------------------------------------------------------
   int  barIndex = Bars(_Symbol, _Period);
   barIndex = iBarShift(_Symbol, _Period, mostLeftObjectTime, false);
   ChartNavigate(0, CHART_END, -barIndex);
   ChartRedraw();
// ---------------------------------------------------------
// Timer aktivieren (RenderQueue)
// ---------------------------------------------------------
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  };

// ------------------------------------------------------------
// DEINIT
// ------------------------------------------------------------
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(db != INVALID_HANDLE)
      DatabaseClose(db);
   ObjectsDeleteAll(0);
  };
// ------------------------------------------------------------
void OnTick() {};// Visualizer braucht keine Tick-Logik
//+------------------------------------------------------------------+
void OnTimer(void)
  {
   renderQueue.Process();
  };
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
// ---------------------------------------------------------
// 0) "Go to EventID"-Box: Enter gedrueckt
// ---------------------------------------------------------
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == "GOTO_EVENTID")
     {
      string txt = ObjectGetString(0, "GOTO_EVENTID", OBJPROP_TEXT);
      GoToEvent((int)StringToInteger(txt));
      return;
     }

// ---------------------------------------------------------
// 1) Chart-Klick → Panel + Relations + Results löschen
// ---------------------------------------------------------
   if(id == CHARTEVENT_CLICK)
     {
      if(!objectWasClicked)
        {
         RenderAllEventsVisible();
         ObjectsDeleteAll(0, "R");   // Relations
         ObjectsDeleteAll(0, "T");   // Results/Trades
         ChartRedraw();
        }

      objectWasClicked = false;
      return;
     }

//      ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,OBJ_PERIOD_M10|OBJ_PERIOD_H4);

// ---------------------------------------------------------
// 2) Objekt-Klick
// ---------------------------------------------------------
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      objectWasClicked = true;
      if(StringSubstr(sparam,0,4) == "PNL_")
        {
         if(dparam < 100)
            Panel_Scroll(120);
         else
            if(dparam > 600)
               Panel_Scroll(-120);
            else
               Panel_Clear();
         return;
        }
      // altes Objekt deselektieren      // neues Objekt selektieren
      if(selectedObjectName != "")
         ObjectSetInteger(0, selectedObjectName, OBJPROP_SELECTED, false);
      selectedObjectName = sparam;
      ObjectSetInteger(0, selectedObjectName, OBJPROP_SELECTED, true);

      // Objekt-Typ bestimmen (P-/E-/R-/T-)
      string objType = StringSubstr(selectedObjectName, 0, 1);
      int    objId = (int)StringToInteger(StringSubstr(selectedObjectName, 2));

      if(objType == "P")
        {
         // alte Relations/Results löschen
         ObjectsDeleteAll(0, "R");
         ObjectsDeleteAll(0, "T");
         RenderAllEventsUnvisible();
         RenderSomeEventsVisible(objId);
        }

      // -----------------------------------------------------
      // Event angeklickt → Relations + Results neu rendern
      // -----------------------------------------------------
      if(objType == "E")
        {
         // alte Relations/Results löschen
         ObjectsDeleteAll(0, "R");
         ObjectsDeleteAll(0, "T");

         // neue laden + rendern
         LoadAndRenderRelations(objId);
         LoadAndRenderTrades(objId);
        }
      // alle falls panel offen
      if(ObjectFind(0, "PNL_BG") >= 0)
         OnChartEvent(0, (long)65, 0.0," "); // wie "A"

      ChartRedraw();
      return;
     }

// ---------------------------------------------------------
// 3) Taste A → Panel öffnen
// ---------------------------------------------------------
   if(id == CHARTEVENT_KEYDOWN && (char)lparam == 'A')
     {

      if(selectedObjectName == "")
         return;

      Panel_Clear();
      Panel_AddBackground();   // #################################

      string objType = StringSubstr(selectedObjectName, 0, 1);
      int objId      = (int)StringToInteger(StringSubstr(selectedObjectName, 2));

      // -----------------------------------------------------
      // PatternCore
      // -----------------------------------------------------
      if(objType == "P")
        {
         int patternId = objId;
         LoadAndListPatternCore(patternId);
         int eventId = LatestEventId(patternId); // Den aktzuellsten für patternID in patternDynamic finden
         if(eventId != -1)
            LoadAndListPatternDynamic(patternId, eventId);
        }
      // -----------------------------------------------------
      // Event → Event + Market
      // -----------------------------------------------------
      if(objType == "E")
        {
         LoadAndListEvent(objId);
         LoadAndListMarket(objId);
        }
      // -----------------------------------------------------
      // Relation → Relation + PatternDynamic
      // -----------------------------------------------------
      if(objType == "R")
        {
         int patternId=-1, eventId=-1; // Rückgabe werte
         LoadAndListRelations(objId,patternId, eventId);
         LoadAndListPatternDynamic(patternId, eventId);
        }
      // -----------------------------------------------------
      // Result → Variant + Result
      // -----------------------------------------------------
      if(objType == "T")
        {
         LoadAndListTrades(objId);
        }
      Panel_Scroll(0);
      ChartRedraw();
      return;
     }

// ---------------------------------------------------------
// 4) Taste B → Pattern-Zone als Quadrat ein-/ausblenden
// ---------------------------------------------------------
   if(id == CHARTEVENT_KEYDOWN && (char)lparam == 'B')
     {
      if(selectedObjectName == "")
         return;
      if(StringSubstr(selectedObjectName, 0, 1) != "P")
         return;

      int patternId = (int)StringToInteger(StringSubstr(selectedObjectName, 2));
      TogglePatternBox(patternId);

      // Skala fix mit aktuellen Werten einschalten (Preisachse nicht mehr autoskalieren)
      ChartSetDouble(0, CHART_FIXED_MIN, ChartGetDouble(0, CHART_PRICE_MIN));
      ChartSetDouble(0, CHART_FIXED_MAX, ChartGetDouble(0, CHART_PRICE_MAX));
      ChartSetInteger(0, CHART_SCALEFIX, true);

      ChartRedraw();
      return;
     }

// ---------------------------------------------------------
// 5) Taste P → bei selektierter Relation zum Pattern springen
// ---------------------------------------------------------
   if(id == CHARTEVENT_KEYDOWN && (char)lparam == 'P')
     {
      if(selectedObjectName == "")
         return;
      if(StringSubstr(selectedObjectName, 0, 1) != "R")
         return;

      int relationId = (int)StringToInteger(StringSubstr(selectedObjectName, 2));

      string sql = StringFormat("SELECT patternId FROM relations WHERE relationId = %d;", relationId);
      int stmt = DatabasePrepare(db, sql);
      if(stmt == INVALID_HANDLE)
         return;

      if(DatabaseRead(stmt))
        {
         int patternId = -1;
         DatabaseColumnInteger(stmt, 0, patternId);
         DatabaseFinalize(stmt);
         if(patternId >= 0)
            GoToPattern(patternId);
        }
      else
         DatabaseFinalize(stmt);

      return;
     }
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int LatestEventId(const int patternId)
  {
   string sql = StringFormat(
                   "SELECT eventId "
                   "FROM patternDynamic "
                   "WHERE patternId = %d "
                   "ORDER BY eventId DESC "
                   "LIMIT 1;",
                   patternId
                );

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
      return -1;

   int latestEventId = -1;

   if(DatabaseRead(stmt))
      DatabaseColumnInteger(stmt, 0, latestEventId);

   DatabaseFinalize(stmt);
   return latestEventId;
  }
// ####################################################################
// ### L O A D    A N D     R E N D E R  ##############################
// ####################################################################
void LoadAndRenderPatterns()
  {
   string sqlCore =
      "SELECT * "
      "FROM patternCore "
      "WHERE type <> 'HAMMER_BAR' "
      "ORDER BY patternId;";

   int stmtCore = DatabasePrepare(db, sqlCore);
   if(stmtCore == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed: ", GetLastError());
      return;
     }

   while(DatabaseRead(stmtCore))
     {
      // ---------------------------------------------------------
      // 0) patternCore laden (NEUSTER Zustand)
      // ---------------------------------------------------------

      structPatternCore pc;
      pc.LoadAusSQL(stmtCore);

      // ---------------------------------------------------------
      // 1) Für die initiale positioonierung des Charts
      // ---------------------------------------------------------
      if(pc.patternId == 10)
         mostLeftObjectTime = pc.startTime;

      // ---------------------------------------------------------
      // 2) patternDynamic laden (NEUSTER Zustand) - für Break-Status/validUntil
      // ---------------------------------------------------------
      structPatternDynamic pd;
      pd.Init();
      int patternId, eventId;

      string sqlDyn = StringFormat(
                         "SELECT * "
                         "FROM patternDynamic "
                         "WHERE patternId = %d "
                         "ORDER BY eventId DESC "
                         "LIMIT 1;",
                         pc.patternId
                      );

      int stmtDyn = DatabasePrepare(db, sqlDyn);
      if(stmtDyn != INVALID_HANDLE && DatabaseRead(stmtDyn))
        {
         pd.LoadFromSQL(stmtDyn, eventId, patternId);
        }
      DatabaseFinalize(stmtDyn);

      // ---------------------------------------------------------
      // 3) Pattern zeichnen (Core + neuester Dynamic-Zustand)
      // ---------------------------------------------------------
      RenderPatternCore(pc, pd);

      // ---------------------------------------------------------
      // 4) isStartOfMove → Pfeil zeichnen
      // ---------------------------------------------------------
      if(pc.type == DREIER && pd.isStartOfMove)
         RenderStartOfMove(pc);

     }

   DatabaseFinalize(stmtCore);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndRenderEvents()
  {
   string sql =
      "SELECT e.*, "
      "CASE WHEN t.eventId IS NULL THEN 0 ELSE 1 END AS has_trade, "
      "IFNULL(t.profit, 0) AS trade_profit "
      "FROM events e "
      "LEFT JOIN trades t ON t.eventId = e.eventId "
      "WHERE e.isEntryEvent = 1 AND e.patternId > -1 "
      "AND e.patternType <> 'HAMMER_BAR' "
      "ORDER BY e.eventId;";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed: ", GetLastError());
      return;
     }

   while(DatabaseRead(stmt))
     {
      structEvent ev;
      ev.LoadFromSQL(stmt);

      int hasTrade;
      double tradeProfit;
      DatabaseColumnInteger(stmt, 10, hasTrade);
      DatabaseColumnDouble(stmt, 11, tradeProfit);

      RenderEvent(ev, hasTrade != 0, tradeProfit);        // ChartObject erzeugen
     }

   DatabaseFinalize(stmt);

  };
//+------------------------------------------------------------------+
//| "Go to EventID"-Box oben rechts erzeugen                         |
//+------------------------------------------------------------------+
void CreateGotoEventBox()
  {
   string lbl = "GOTO_LABEL";
   ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 10);
   ObjectSetString(0, lbl, OBJPROP_TEXT, "Go to EventID:");
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lbl, OBJPROP_ZORDER, 10001);

   string edit = "GOTO_EVENTID";
   ObjectCreate(0, edit, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, edit, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, edit, OBJPROP_XDISTANCE, 100);
   ObjectSetInteger(0, edit, OBJPROP_YDISTANCE, 8);
   ObjectSetInteger(0, edit, OBJPROP_XSIZE, 70);
   ObjectSetInteger(0, edit, OBJPROP_YSIZE, 18);
   ObjectSetString(0, edit, OBJPROP_TEXT, "");
   ObjectSetInteger(0, edit, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, edit, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, edit, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, edit, OBJPROP_ZORDER, 10001);
  };
//+------------------------------------------------------------------+
//| Event-Objekt selektieren und Chart darauf zentrieren             |
//+------------------------------------------------------------------+
void GoToEvent(int eventId)
  {
   string name = "E-" + IntegerToString(eventId);

   if(ObjectFind(0, name) < 0)
     {
      Print("GoToEvent: Objekt ", name, " nicht gefunden.");
      return;
     }

   datetime evTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);

   SelectObject(name);
   CenterChartOnBar(evTime);

   ObjectSetString(0, "GOTO_EVENTID", OBJPROP_TEXT, "");
   ChartRedraw();
  };
//+------------------------------------------------------------------+
//| Pattern-Objekt selektieren und Chart darauf zentrieren            |
//+------------------------------------------------------------------+
void GoToPattern(int patternId)
  {
   string name = "P-" + IntegerToString(patternId);

   if(ObjectFind(0, name) < 0)
     {
      Print("GoToPattern: Objekt ", name, " nicht gefunden.");
      return;
     }

   datetime patTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);

   SelectObject(name);
   CenterChartOnBar(patTime);

   ChartRedraw();
  };
//+------------------------------------------------------------------+
//| altes Objekt deselektieren, neues selektieren                     |
//+------------------------------------------------------------------+
void SelectObject(string name)
  {
   if(selectedObjectName != "")
      ObjectSetInteger(0, selectedObjectName, OBJPROP_SELECTED, false);
   selectedObjectName = name;
   ObjectSetInteger(0, name, OBJPROP_SELECTED, true);
  };
//+------------------------------------------------------------------+
//| Chart horizontal so verschieben, dass Zeitpunkt t mittig liegt    |
//+------------------------------------------------------------------+
void CenterChartOnBar(datetime t)
  {
   int targetBar    = iBarShift(_Symbol, _Period, t, false);
   int barsOnScreen = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int shift        = targetBar - barsOnScreen / 2;
   if(shift < 0)
      shift = 0;

   ChartNavigate(0, CHART_END, -shift);
  };
//+------------------------------------------------------------------+
//| Pattern-Preiszone als Quadrat ein-/ausblenden (Taste B)           |
//+------------------------------------------------------------------+
void TogglePatternBox(int patternId)
  {
   string boxName = "P-" + IntegerToString(patternId) + "-BOX";

   if(ObjectFind(0, boxName) >= 0)
     {
      ObjectDelete(0, boxName);
      return;
     }

   string sql = "SELECT * FROM patternCore WHERE patternId = " + IntegerToString(patternId) + ";";
   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed (TogglePatternBox): ", GetLastError());
      return;
     }
   if(!DatabaseRead(stmt))
     {
      Print("❌ PatternCore nicht gefunden: ", patternId);
      DatabaseFinalize(stmt);
      return;
     }

   structPatternCore pc;
   pc.LoadAusSQL(stmt);
   DatabaseFinalize(stmt);

   datetime newestBar = iTime(_Symbol, _Period, 0);

   ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, pc.startTime, pc.priceHigh, newestBar, pc.priceLow);

   // H1-Pattern werden in der M3-Ansicht DodgerBlue mit staerkerer Linie
   // dargestellt (siehe RenderPatternCore) - Box soll dazu passen.
   color boxColor = (pc.direction == LONG ? clrLimeGreen : clrRed);
   int   boxWidth = 2;
   if(pc.timeFrame == PERIOD_H1)
     {
      boxColor = clrDodgerBlue;
      boxWidth = 3;
     }

   ObjectSetInteger(0, boxName, OBJPROP_COLOR, boxColor);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, false);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, boxName, OBJPROP_TIMEFRAMES, OBJ_PERIOD_M1 | OBJ_PERIOD_M3 | OBJ_PERIOD_H1);
   ObjectSetString(0, boxName, OBJPROP_TOOLTIP, boxName);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndRenderRelations(int eventId)
  {
// wir brauchen den startpunkt im event und (loop) den endPunkt im pattern.
   string sql =
      "SELECT rel.relationId, rel.patternId, rel.slotName,  "
      "       ev.eventTime, ev.eventPrice,   "
      "       p.direction, p.endTime, p.priceLow, p.priceHigh     "
      "FROM events ev                                    "
      "JOIN relations rel ON rel.eventId = ev.eventId   "
      "JOIN patternCore p ON p.patternId = rel.patternId   "
      "WHERE ev.eventId = " + IntegerToString(eventId) + " ORDER BY rel.relationId;";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      MessageBox("Keine Relatrions");
      Print("❌ DB Prepare failed (relations for events): ", GetLastError());
      return;
     }

   string infoString = "E-" + IntegerToString(eventId) + "\n\n";

   while(DatabaseRead(stmt))
     {
      int         relationId;
      int         patternId;
      string      slotName;
      datetime    eventTime;
      double      eventPrice;
      string      direction;
      datetime    patternTime;
      double      lowPrice;
      double      highPrice;

      int tmp;
      // 0: relationId
      DatabaseColumnInteger(stmt, 0, relationId);
      // 0: patternId
      DatabaseColumnInteger(stmt, 1, patternId);
      // 1: slotName
      DatabaseColumnText(stmt, 2, slotName);

      // 2: eventTime (datetime → INTEGER)
      DatabaseColumnInteger(stmt,3, tmp);
      eventTime = (datetime)tmp;
      // 3: eventPrice
      DatabaseColumnDouble(stmt, 4, eventPrice);

      // 4: patternDirection
      DatabaseColumnText(stmt, 5, direction);
      // 5: patternTime
      DatabaseColumnInteger(stmt, 6, tmp);
      patternTime = (datetime)tmp;
      // 6: lowPrice
      DatabaseColumnDouble(stmt, 7, lowPrice);
      // 7: highPrice
      DatabaseColumnDouble(stmt, 8, highPrice);

      double      patternPrice = (direction == "L") ? lowPrice : highPrice;

      infoString += slotName + " " + IntegerToString(patternId) + " \n ";

      // ChartObject erzeugen
      RenderRelation(
         relationId,
         patternId,
         eventId,
         slotName,
         eventTime, eventPrice,
         patternTime,   patternPrice
      );
     }

   DatabaseFinalize(stmt);

   MessageBox(infoString);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndRenderTrades(int eventId)
  {
   string sql =
      "SELECT *  "
      "FROM trades  "
      "WHERE eventId = " + IntegerToString(eventId) + " "
      "ORDER BY tradeId;";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
      return;

   while(DatabaseRead(stmt))
     {
      structTrade tr;
      tr.Init();
      tr.FromSQL(stmt);

      RenderTrades(tr);
     }

   DatabaseFinalize(stmt);
  };
// ####################################################################
// ### L O A D   A N D    L I S T  ####################################
// ####################################################################
void LoadAndListPatternCore(int patternId)
  {

   string sql =
      "SELECT * "
      "FROM patternCore "
      "WHERE patternId = " + IntegerToString(patternId) + ";";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed (PatternCore): ", GetLastError());
      return;
     }

   if(!DatabaseRead(stmt))
     {
      Print("❌ PatternCore nicht gefunden: ", patternId);
      DatabaseFinalize(stmt);
      return;
     }

   structPatternCore pc;
   pc.LoadAusSQL(stmt);

   DatabaseFinalize(stmt);

// ---------------------------------------------------------
// patternDynamic laden (NEUSTER Zustand) - für validUntil
// ---------------------------------------------------------
   structPatternDynamic pd;
   pd.Init();
   int pdPatternId, pdEventId;

   string sqlDyn = StringFormat(
                      "SELECT * "
                      "FROM patternDynamic "
                      "WHERE patternId = %d "
                      "ORDER BY eventId DESC "
                      "LIMIT 1;",
                      patternId
                   );

   int stmtDyn = DatabasePrepare(db, sqlDyn);
   if(stmtDyn != INVALID_HANDLE && DatabaseRead(stmtDyn))
     {
      pd.LoadFromSQL(stmtDyn, pdEventId, pdPatternId);
     }
   DatabaseFinalize(stmtDyn);

// ---------------------------------------------------------
// Panel füllen
// ---------------------------------------------------------
   Panel_AddField("PatternCore","",true);

   Panel_AddField("patternId", IntegerToString(pc.patternId));
   Panel_AddField(TimeFrameToString(pc.timeFrame) + "-" +
                  EnumToString(pc.type) +  " " +
                  DirectionToString(pc.direction)," ");

   Panel_AddField("startTime", TimeToString(pc.startTime));
   Panel_AddField("endTime", TimeToString(pc.endTime));
   Panel_AddField("validFrom", TimeToString(pc.validFrom));
   Panel_AddField("validUntil (dynamic)", TimeToString(pd.validUntil));
   Panel_AddField(" "," ");
   Panel_AddField("priceHigh", DoubleToString(pc.priceHigh, 1));
   Panel_AddField("priceLow", DoubleToString(pc.priceLow, 1));

   Panel_AddField("width", DoubleToString(pc.width, 1));
   Panel_AddField("priceSlopePerBar", DoubleToString(pc.priceSlopePerBar, 3));

   Panel_AddField("direction", DirectionToString(pc.direction));
   Panel_AddField("sessionAtCreate", EnumToString(pc.sessionAtCreate));
   Panel_AddField("trendContextAtCreate", DirectionToString(pc.trendContextAtCreate));

   Panel_AddField("shapeBarA", EnumToString(pc.shapeBarA));
   Panel_AddField("shapeBarB", EnumToString(pc.shapeBarB));
   Panel_AddField("shapeBarC", EnumToString(pc.shapeBarC));

   Panel_AddField("rangeBarA", DoubleToString(pc.rangeBarA, 1));
   Panel_AddField("rangeBarB", DoubleToString(pc.rangeBarB, 1));
   Panel_AddField("rangeBarC", DoubleToString(pc.rangeBarC, 1));

   Panel_AddField("wickRatio", DoubleToString(pc.wickRatio, 3));
   Panel_AddField("patternStrengthAtCreate", DoubleToString(pc.patternStrengthAtCreate, 3));

   Panel_AddField(" "," ");
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndListEvent(int eventId)
  {
   string sql =
      "SELECT * "
      "FROM events "
      "WHERE eventId = " + IntegerToString(eventId) + ";";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed (Event): ", GetLastError());
      return;
     }

   if(!DatabaseRead(stmt))
     {
      Print("❌ Event nicht gefunden: ", eventId);
      DatabaseFinalize(stmt);
      return;
     }

   structEvent ev;
   ev.LoadFromSQL(stmt);

   DatabaseFinalize(stmt);

// ---------------------------------------------------------
// Panel füllen
// ---------------------------------------------------------
   Panel_AddField("Event","",true);

   Panel_AddField("eventId", IntegerToString(ev.eventId));
   Panel_AddField("patternId", IntegerToString(ev.patternId));

   Panel_AddField(TimeFrameToString(ev.patternTF) + " " +
                  EnumToString(ev.patternType) + " " +
                  EnumToString(ev.patternDirection)," ");

   Panel_AddField("eventReason", EnumToString(ev.eventReason));

   Panel_AddField("eventDirection", EnumToString(ev.eventDirection));

   Panel_AddField("eventTime", TimeToString(ev.eventTime));
   Panel_AddField("eventPrice", DoubleToString(ev.eventPrice, 5));

   Panel_AddField("isEntryEvent", ev.isEntryEvent ? "true" : "false");

   Panel_AddField(" ",  " ");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndListMarket(int eventId)
  {


   string sql =
      "SELECT * "
      "FROM market "
      "WHERE eventId = " + IntegerToString(eventId) + ";";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed (Market): ", GetLastError());
      return;
     }

   if(!DatabaseRead(stmt))
     {
      Print("❌ Market nicht gefunden: eventId=", eventId);
      DatabaseFinalize(stmt);
      return;
     }

   structMarket mk;
   mk.LoadFromSQL(stmt);

   DatabaseFinalize(stmt);

// ---------------------------------------------------------
// Panel füllen
// ---------------------------------------------------------
   Panel_AddField("Market","",true);
// Spread
   Panel_AddField("spread", DoubleToString(mk.spread, 5));
   Panel_AddField("avgSpreadM3", DoubleToString(mk.avgSpreadM3, 5));
   Panel_AddField("maxSpreadM3", DoubleToString(mk.maxSpreadM3, 5));

// Volatility
   Panel_AddField("atrM1", DoubleToString(mk.atrM1, 5));
   Panel_AddField("atrM3", DoubleToString(mk.atrM3, 5));
   Panel_AddField("atrH1", DoubleToString(mk.atrH1, 5));
   Panel_AddField("atrD1", DoubleToString(mk.atrD1, 5));
   Panel_AddField("atrRatioM3_H1", DoubleToString(mk.atrRatioM3_H1, 5));

// Volatility Flags
   Panel_AddField("isHighVolatility", mk.isHighVolatility ? "true" : "false");
   Panel_AddField("isLowVolatility", mk.isLowVolatility ? "true" : "false");

// Volume
   Panel_AddField("avM3", DoubleToString(mk.avM3, 5));
   Panel_AddField("relativeVolume", DoubleToString(mk.relativeVolume, 5));

// Volume Flags
   Panel_AddField("isHighVolume", mk.isHighVolume ? "true" : "false");
   Panel_AddField("isLowVolume", mk.isLowVolume ? "true" : "false");

// Session
   Panel_AddField("session", EnumToString(mk.session));
   Panel_AddField("sessionPhase", EnumToString(mk.sessionPhase));
   Panel_AddField("sessionStart", TimeToString(mk.sessionStart));
   Panel_AddField("isAuction", mk.isAuction ? "true" : "false");

// News
   Panel_AddField("isNews", mk.isNews ? "true" : "false");
   Panel_AddField("newsImpact", IntegerToString(mk.newsImpact));
   Panel_AddField("newsType", IntegerToString(mk.newsType));

// Expiration
   Panel_AddField("isSmallExpirationDay", mk.isSmallExpirationDay ? "true" : "false");
   Panel_AddField("isBigExpirationDay", mk.isBigExpirationDay ? "true" : "false");
   Panel_AddField("isExpirationDay", mk.isExpirationDay ? "true" : "false");

// Trend mathematisch
   Panel_AddField("trendM3", EnumToString(mk.trendMathM3));
   Panel_AddField("trendH1", EnumToString(mk.trendMathH1));
   Panel_AddField("trendD1", EnumToString(mk.trendMathD1));

   Panel_AddField("trendStrength", DoubleToString(mk.trendStrength, 5));
   Panel_AddField("trendChange", mk.trendChange ? "true" : "false");
   Panel_AddField("trendStart", TimeToString(mk.trendStart));
   Panel_AddField("rangeStart", TimeToString(mk.rangeStart));

// Trend DREIER
   Panel_AddField("trendPatternM3", EnumToString(mk.trendPatternM3));
   Panel_AddField("trendPatternH1", EnumToString(mk.trendPatternH1));

// Trend Star/Ziel
   Panel_AddField("targetTrendH1", EnumToString(mk.targetTrendH1));

// Meta
   Panel_AddField("lastUpdate", TimeToString(mk.lastUpdate));

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndListRelations(int relationId, int &patternId, int &eventId)
  {
   string sql =
      "SELECT * "
      "FROM relations "
      "WHERE relationId = " + IntegerToString(relationId) + ";";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed (Relation): ", GetLastError());
      return;
     }

   if(!DatabaseRead(stmt))
     {
      Print("❌ Relation nicht gefunden: ", relationId);
      DatabaseFinalize(stmt);
      return;
     }

   structRelation rel;
   rel.LoadFromSQL(stmt);
   patternId = rel.patternId;
   eventId= rel.eventId;
   DatabaseFinalize(stmt);

// ---------------------------------------------------------
// Panel füllen
// ---------------------------------------------------------

   Panel_AddField("Relation","",true);

   Panel_AddField("relationId", IntegerToString(relationId));
   Panel_AddField("eventId", IntegerToString(rel.eventId));
   Panel_AddField("patternId", IntegerToString(rel.patternId));
   Panel_AddField("slotName", rel.slotName);

// Zeitliche Distanz
   Panel_AddField("barsSinceStart", IntegerToString(rel.barsSinceStart));
   Panel_AddField("barsSinceBreak", IntegerToString(rel.barsSinceBreak));

// Räumliche Distanz
   Panel_AddField("priceDistance", DoubleToString(rel.priceDistance, 5));
   Panel_AddField("priceDistanceToBreakLevel", DoubleToString(rel.priceDistanceToBreakLevel, 5));
   Panel_AddField("priceDistanceExtremeBeforeBreak", DoubleToString(rel.priceDistanceExtremeBeforeBreak, 5));
   Panel_AddField("priceDistanceExtremeAfterBreak", DoubleToString(rel.priceDistanceExtremeAfterBreak, 5));

// Relative Lage
   Panel_AddField("eventSlopeRelation", DoubleToString(rel.eventSlopeRelation, 5));
   Panel_AddField("eventPositionRelative", DoubleToString(rel.eventPositionRelative, 5));

// Flags
   Panel_AddField("isOriginPattern", rel.isOriginPattern ? "true" : "false");
   Panel_AddField("isInPatternNow", rel.isInPatternNow ? "true" : "false");
   Panel_AddField("isTouchingNow", rel.isTouchingNow ? "true" : "false");
   Panel_AddField("isNearTouchingNow", rel.isNearTouchingNow ? "true" : "false");
   Panel_AddField("isBreakingNow", rel.isBreakingNow ? "true" : "false");

// Relevanz
   Panel_AddField("patternRelevanceAtEvent", DoubleToString(rel.patternRelevanceAtEvent, 5));

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndListPatternDynamic(int patternId, int eventId)
  {
   string sql =
      "SELECT * "
      "FROM patternDynamic "
      "WHERE patternId = " + IntegerToString(patternId) +
      " AND  eventId = " + IntegerToString(eventId) + ";";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed (PatternDynamic): ", GetLastError());
      return;
     }

   if(!DatabaseRead(stmt))
     {
      Print("❌ PatternDynamic nicht gefunden: patternId = " + IntegerToString(patternId) +
            " eventId = " + IntegerToString(eventId));
      DatabaseFinalize(stmt);
      return;
     }

   structPatternDynamic pd;
   eventId = -1;     // rückgabewert
   patternId = -1;   // rückgabewert
   pd.LoadFromSQL(stmt, eventId, patternId);

   DatabaseFinalize(stmt);

// ---------------------------------------------------------
// Panel füllen — exakt passend zur Struktur
// ---------------------------------------------------------
   Panel_AddField("PatternDynamic","",true);

   Panel_AddField("status",  EnumToString(pd.status));

   Panel_AddField("touches", IntegerToString(pd.touches));
   Panel_AddField("nearTouches", IntegerToString(pd.nearTouches));

   Panel_AddField("postBreakRetestTouches", IntegerToString(pd.postBreakRetestTouches));
   Panel_AddField("nearPostBreakRetestTouches", IntegerToString(pd.nearPostBreakRetestTouches));

   Panel_AddField("isTrendBreak", pd.isTrendBreak ? "true" : "false");
   Panel_AddField("isStartOfMove", pd.isStartOfMove ? "true" : "false");
   Panel_AddField("hadFakeBreak", pd.hadFakeBreak ? "true" : "false");
   Panel_AddField("hadFakeRetestBreak", pd.hadFakeRetestBreak ? "true" : "false");
   Panel_AddField("causedOppositePatternBreak", pd.causedOppositePatternBreak ? "true" : "false");

   Panel_AddField("priceExtremeBeforeBreak", DoubleToString(pd.priceExtremeBeforeBreak, 5));
   Panel_AddField("priceExtremeAfterBreak", DoubleToString(pd.priceExtremeAfterBreak, 5));
   Panel_AddField("priceExtremePrevious", DoubleToString(pd.priceExtremePrevious, 5));

   Panel_AddField(
      "previousExtremeBeforeBreakPriceRelation",
      EnumToString(pd.previousExtremeBeforeBreakPriceRelation)
   );

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadAndListTrades(int variantId)
  {
   string sql =
      "SELECT * "
      "FROM trades "
      "WHERE tradeId = " + IntegerToString(variantId) + ";";

   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
     {
      Print("❌ DB Prepare failed (Variant): ", GetLastError());
      return;
     }

   if(!DatabaseRead(stmt))
     {
      Print("❌ Variant nicht gefunden: ", variantId);
      DatabaseFinalize(stmt);
      return;
     }

   structTrade tr;
   tr.Init();                 // wichtig: alle Felder sauber initialisieren
   tr.FromSQL(stmt);  // lädt nur den Variant‑Teil

   DatabaseFinalize(stmt);

// ---------------------------------------------------------
// Panel füllen
// ---------------------------------------------------------
   Panel_AddField("Trade","",true);

   Panel_AddField("tradeId", IntegerToString(tr.tradeId));
   Panel_AddField("eventId", IntegerToString(tr.eventId));

   Panel_AddField("direction", EnumToString(tr.direction));
   Panel_AddField("orderType", EnumToString(tr.orderType));

   Panel_AddField("entryPrice", DoubleToString(tr.entryPrice, 0));
   Panel_AddField("initialSLPrice", DoubleToString(tr.initialSLPrice, 0));
   Panel_AddField("initialTPPrice", DoubleToString(tr.initialTPPrice, 0));
   Panel_AddField("trailingDist", DoubleToString(tr.trailingDist, 0));

   Panel_AddField("twoUnitMode", tr.twoUnitMode ? "true" : "false");

     Panel_AddField("---------------", "---------------");

   Panel_AddField("profit", DoubleToString(tr.profit, 5));
   Panel_AddField("mae", DoubleToString(tr.mae, 5));
   Panel_AddField("mfe", DoubleToString(tr.mfe, 5));

   Panel_AddField("exitReason", ExitReasonToString(tr.exitReason));
   Panel_AddField("barsHeldUntilExit", IntegerToString(tr.barsHeldUntilExit));

   Panel_AddField("twoUnitFilled (TP1)", tr.twoUnitFilled ? "true" : "false");
   Panel_AddField("twoUnitExited (TP2)", tr.twoUnitExited ? "true" : "false");

   Panel_AddField("exitPrice", DoubleToString(tr.exitPrice, 5));
   Panel_AddField("exitTime", TimeToString(tr.exitTime));

   Panel_AddField("exitBarIndex", IntegerToString(tr.exitBarIndex));
  };
// ####################################################################
// ### R E N D E R N   ################################################
// ####################################################################
void RenderPatternCore(const structPatternCore &pc, const structPatternDynamic &pd)
  {
   RenderRequest r;
   r.Init();

   r.name       = "P-" + IntegerToString(pc.patternId); // IntegerToString(pc.patternId);   // neue Namenslogik: ID-basiert
   r.hidden     = false;
   r.selectable = true;
   r.zorder     = 0;
   r.font       = "Arial";
   r.fontsize   = 10;
   r.anchor     = ANCHOR_LEFT;
   r.text       = TimeFrameToString(pc.timeFrame) + " " + EnumToString(pc.type) + " " + EnumToString(pc.direction);
   r.tooltip    = r.name + " " + TimeFrameToString(pc.timeFrame) + " " + EnumToString(pc.type);

   switch(pc.type)
     {
      // ---------------------------------------------------------
      // ⭐ DREIER
      // ---------------------------------------------------------
      case DREIER:
        {
         r.type   = OBJ_TREND;
         // Zeitfenster
         r.time0  = pc.startTime;
         r.time1 = pc.startTime + 3 * PeriodSeconds(pc.timeFrame);
         r.price0 = (pc.direction == LONG ? pc.priceHigh : pc.priceLow);
         r.price1 = r.price0;
         r.width =  2;
         r.style = STYLE_SOLID;

         if(pc.timeFrame == PERIOD_H1)
           {
            // H1-Chart-Ansicht: Richtungsfarbe
            RenderRequest rH1 = r;
            rH1.name       = r.name + "-H1";
            rH1.clr        = (pc.direction == LONG ? clrLimeGreen : clrRed);
            rH1.timeframes = OBJ_PERIOD_H1;
            renderQueue.Add(rH1);

            // M3-Chart-Ansicht: DodgerBlue
            r.clr        = clrDodgerBlue;
            r.timeframes = OBJ_PERIOD_M3;
           }
         else
           {
            // M3-Pattern: nur in M3-Ansicht, Richtungsfarbe
            r.clr        = (pc.direction == LONG ? clrLimeGreen : clrRed);
            r.timeframes = OBJ_PERIOD_M1 | OBJ_PERIOD_M3;
           }
         break;
        }
      case HAMMER_BAR:
        {
         r.type   = OBJ_RECTANGLE;
         // Zeitfenster
         r.time0  = pc.startTime;
         r.time1 = pc.endTime;
         r.price0 = pc.priceHigh;
         r.price1 = pc.priceLow;
         color clr = (pc.direction == LONG ? clrPaleGreen : clrMistyRose);
         r.clr   = clr;
         r.width =  1;
         r.style = STYLE_SOLID;
         r.fill   = true;
         r.timeframes = OBJ_PERIOD_M1 | OBJ_PERIOD_M3;   // nicht in H1-Ansicht

         break;
        }

      // ---------------------------------------------------------
      // ⭐ RANGE
      // ---------------------------------------------------------
      case RANGE:
        {
         r.type   = OBJ_RECTANGLE;

         r.time0  = pc.validFrom;
         r.time1  = (pd.status == CLOSED && pd.validUntil > 0) ? pd.validUntil : TimeCurrent();

         r.price0 = pc.priceLow;
         r.price1 = pc.priceHigh;

         r.fill   = false;
         r.width  = 1;
         r.clr    = clrLightBlue;
         r.style  = STYLE_SOLID;

         r.tooltip = "Range: " +
                     DoubleToString(pc.priceLow, 1) + " - " +
                     DoubleToString(pc.priceHigh, 1);

         break;
        }

      case VTH:
        {
         r.type   = OBJ_TREND;

         r.time0  = pc.validFrom;
         r.time1  = (pd.status == CLOSED && pd.validUntil > 0) ? pd.validUntil : TimeCurrent();

         double priceNominal = (pc.direction == LONG ? pc.priceHigh : pc.priceLow);

         r.price0 = priceNominal ;
         r.price1 = priceNominal ;

         r.fill   = false;
         r.width  = 2;
         r.clr    = clrDarkGray;
         r.style  = STYLE_DASH;

         break;
        }

      // ---------------------------------------------------------
      // ⭐ TANGENTE (Trendlinie durch die beiden Swing-Punkte)
      // ---------------------------------------------------------
      case TANGENTE:
        {
         r.type   = OBJ_TREND;

         r.time0  = pc.startTime;
         r.price0 = pc.priceLow;   // priceLow==priceHigh: Ursprungspreis am älteren Swing

         r.time1  = pc.endTime;
         r.price1 = pc.priceLow + pc.priceSlopePerBar * (pc.validFromBarIndex - pc.startBarIndex);

         r.width  = 2;
         r.style  = STYLE_DASH;

         if(pc.timeFrame == PERIOD_H1)
           {
            // H1-Chart-Ansicht: Schwarz
            RenderRequest rH1 = r;
            rH1.name       = r.name + "-H1";
            rH1.clr        = clrBlack;
            rH1.timeframes = OBJ_PERIOD_H1;
            renderQueue.Add(rH1);

            // M3-Chart-Ansicht: DodgerBlue
            r.clr        = clrDodgerBlue;
            r.timeframes = OBJ_PERIOD_M3;
           }
         else
           {
            // M3-Pattern: nur in M3-Ansicht, Schwarz
            r.clr        = clrBlack;
            r.timeframes = OBJ_PERIOD_M1 | OBJ_PERIOD_M3;
           }

         break;
        }

      default:
         return ;
     }

   renderQueue.Add(r);
   return ;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderStartOfMove(const structPatternCore &pc)
  {
   if(pc.timeFrame != PERIOD_M3)
      return;

   RenderRequest r;
   r.Init();

// ---------------------------------------------------------
// Name & Meta
// ---------------------------------------------------------
   r.name       = "P-" + IntegerToString(pc.patternId) + "-SoM";
   r.hidden     = false;
   r.selectable = true;
   r.anchor     = ANCHOR_CENTER;
   r.text       = "";                // kein Text, nur Symbol
   r.tooltip    = "P-" + IntegerToString(pc.patternId) + " Start of Move";

   r.type = OBJ_ARROWED_LINE;;

// ---------------------------------------------------------
// Positionierung
// ---------------------------------------------------------
   int bar = pc.startBarIndex;

   double price0;
   double price1;
   if(pc.direction == LONG)
     {
      price1 = pc.priceLow - 5;     // Pfeil unter LONG}
      price0 = pc.priceLow - 20;
     }
   else
     {
      price1 = pc.priceHigh + 5;    // Pfeil über SHORT
      price0 = pc.priceHigh + 20;
     }

   r.time0  = pc.startTime;
   r.time1  = pc.startTime;
   r.price0 = price0;
   r.price1 = price1;

// ---------------------------------------------------------
// Farbe & Stil
// ---------------------------------------------------------
   r.clr   = clrBlack;
   r.width = 2;
   r.style = STYLE_SOLID;

   renderQueue.Add(r);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderEvent(const structEvent &ev, const bool hasTrade, const double tradeProfit)
  {

   RenderRequest r;
   r.Init();

   r.name       = "E-" + IntegerToString(ev.eventId);
   r.hidden     = false;
   r.selectable = true;
   r.zorder     = 1;
   r.font       = "Arial";
   r.fontsize   = 8;

   r.type       = OBJ_ARROWED_LINE;

   r.time0      = ev.eventTime+ PeriodSeconds(Period());
   r.time1      = ev.eventTime;

   double priceNominal = ev.eventPrice;

   if(ev.eventDirection == LONG)
     {
      //        r.anchor     = ANCHOR_TOP;
      r.price0 = priceNominal - 15;
      r.price1 = priceNominal;
     }
   else
     {
      //        r.anchor     = ANCHOR_BOTTOM;
      r.price0 = priceNominal + 15;
      r.price1 = priceNominal;
     }

   r.clr        = clrDarkGray;
   r.width      = 3;

   if(hasTrade)
      r.clr = (tradeProfit > 0 ? clrLimeGreen : (tradeProfit < 0 ? clrRed : clrDarkGray));

   r.style      = STYLE_SOLID;

   string label = "E-" + IntegerToString(ev.eventId) + " " + " P-" + IntegerToString(ev.patternId) +
                  " " + EnumToString(ev.eventReason);

   r.text       = label;
   r.tooltip    = label;

   renderQueue.Add(r);
   return ;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderRelation(const int relationId,
                    const int patternId,
                    const int eventId,
                    const string slotName,
                    const datetime startTime, const double startPrice,
                    const datetime endTime,   const double endPrice)
  {

// ---------------------------------------------------------
// Objektname
// ---------------------------------------------------------
   string name = "R-" + IntegerToString(relationId);

// Vorheriges Objekt löschen
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

// ---------------------------------------------------------
// Trendlinie zeichnen
// ---------------------------------------------------------
   ObjectCreate(0, name, OBJ_TREND, 0, startTime, startPrice, endTime, endPrice);

// Farbe: einfache Logik
// Start < End → grün (steigend)
// Start > End → rot (fallend)
   color col = clrBlack; // (endPrice >= startPrice ? clrLime : clrRed);

   if(StringSubstr(slotName,0,2) == "H1")
      col = clrBlue; // (endPrice >= startPrice ? clrLime : clrRed);

   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);

// ---------------------------------------------------------
// Tooltip
// ---------------------------------------------------------
   string tip =
      "patternID: " + IntegerToString(patternId) + "\n" +
      "eventId: " + IntegerToString(eventId) + "\n" +
      "slotName: "   + slotName + "\n" +
      "relationId: " + IntegerToString(relationId);



   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   return;
// ---------------------------------------------------------
// Textlabel
// ---------------------------------------------------------
   string labelName = name + "_LBL";

   if(ObjectFind(0, labelName) >= 0)
      ObjectDelete(0, labelName);

   ObjectCreate(0, labelName, OBJ_TEXT, 0, endTime, endPrice);

   ObjectSetString(0, labelName, OBJPROP_TEXT, slotName);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderTrades(const structTrade &tr)
  {
// ---------------------------------------------------------
// Filter: Nur OUT + exitReason != NOFILL
// ---------------------------------------------------------
   if(tr.status != TRADE_OUT)
      return;

   if(tr.exitReason == EXIT_NOFILL)
      return;

// ---------------------------------------------------------
// Name des ChartObjects
// ---------------------------------------------------------
   string name = "T-" + IntegerToString(tr.tradeId);

// Vorheriges Objekt löschen
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

// ---------------------------------------------------------
// Trendlinie zeichnen
// ---------------------------------------------------------
   ObjectCreate(0, name, OBJ_TREND, 0, tr.fillTime, tr.fillPrice, tr.exitTime, tr.exitPrice);

// Farbe abhängig vom Profit
   color col = (tr.profit >= 0.0 ? clrLime : clrMagenta);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_PERIOD_M1 | OBJ_PERIOD_M3);   // nicht in H1-Ansicht
// ---------------------------------------------------------
// Tooltip
// ---------------------------------------------------------
   string tip =      "tradeId: " + IntegerToString(tr.tradeId) + "\n" +
                     "eventId: "   + IntegerToString(tr.eventId)   + "\n" +
                     "profit: "    + DoubleToString(tr.profit, 2)  + "\n" +
                     "exitReason: "+ EnumToString(tr.exitReason);

   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
return;
// ---------------------------------------------------------
// Textlabel (direction, orderType, profit)
// ---------------------------------------------------------
   string labelName = name + "_LBL";

   if(ObjectFind(0, labelName) >= 0)
      ObjectDelete(0, labelName);

   string txt =
      EnumToString(tr.direction) + " / " +
      EnumToString(tr.orderType) + " / " +
      DoubleToString(tr.profit, 2) + " pkte";

   ObjectCreate(0, labelName, OBJ_TEXT, 0, tr.exitTime, tr.exitPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderSomeEventsVisible(int patternId)
  {
// Alle eventIds des Patterns aus DB holen
   string sql = StringFormat(
                   "SELECT eventId, patternTF, patternType, eventReason FROM events WHERE patternId = %d;", patternId
                );
   int stmt = DatabasePrepare(db, sql);
   if(stmt == INVALID_HANDLE)
      return;

   string infoString  = "P-" + IntegerToString(patternId) + "\n\n";
   while(DatabaseRead(stmt))
     {
      int eventId;
      DatabaseColumnInteger(stmt, 0, eventId);

      string patternTF="";
      DatabaseColumnText(stmt, 1, patternTF);
      string patternType="";
      DatabaseColumnText(stmt, 2, patternType);
      string eventReason="";
      DatabaseColumnText(stmt, 3, eventReason);

      string name = StringFormat("E-%d", eventId);
      // Sichtbar in M1, M3, H1
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES,
                       OBJ_PERIOD_M1 | OBJ_PERIOD_M3 | OBJ_PERIOD_H1);

      infoString += name + " " +
                    patternTF   + "_" +
                    patternType + "_" +
                    eventReason +  " \n ";
     }

   DatabaseFinalize(stmt);
   MessageBox(infoString);
   ChartRedraw();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderAllEventsVisible()
  {
   int total = ObjectsTotal(0);
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i);

      if(StringSubstr(name, 0, 2) == "E-")
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_PERIOD_H1|OBJ_PERIOD_M3|OBJ_PERIOD_M1);
     }
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderAllEventsUnvisible()
  {
   int total = ObjectsTotal(0);
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i);

      if(StringSubstr(name, 0, 2) == "E-")
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES,  OBJ_PERIOD_M1);
     }
  };
// ####################################################################
// ### P A N E L  #####################################################
// ####################################################################
int panelFieldIndex = 0;
int scrollOffset = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Panel_Clear()
  {

   ObjectsDeleteAll(0, "PNL_");
   panelFieldIndex = 0;
   scrollOffset = 0;

  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Panel_AddBackground()
  {
   string name = "PNL_BG";

   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 10);

   ObjectSetInteger(0, name, OBJPROP_XSIZE, 300);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 800);

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);



  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Panel_AddField(string name, string value, bool header = false)
  {
   string objName = "PNL_" + IntegerToString(panelFieldIndex);

   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);

   int y = 30 + panelFieldIndex * 20;

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);

   ObjectSetString(0, objName, OBJPROP_TEXT, name + ": " + value);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 12);
   if(header)
     {
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 16);
      panelFieldIndex++;
     }
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10001);

   panelFieldIndex++;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Panel_Scroll(int delta)
  {
   scrollOffset -= delta;

// Begrenzen
   if(scrollOffset < 0)
      scrollOffset = 0;
   if(scrollOffset > (panelFieldIndex-25) * 20)
      scrollOffset = (panelFieldIndex-25) * 20;

// Felder verschieben
   for(int idx = 0; idx < panelFieldIndex; idx++)
     {
      string name = "PNL_" + IntegerToString(idx);
      int y = 30 + idx * 22;
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - scrollOffset);
     }
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CreateTrendWindow()
  {
// Trendbänder werden als eigene Chart-Objekte gezeichnet (DrawTrendSegment),
// dafür reicht ein leeres Subfenster - kein Indikator nötig.
// Eigenes Fenster ans Ende anhängen (nicht Fenster 1 annehmen - das könnte
// bereits von der nativen "Show Volumes"-Anzeige belegt sein, deren
// Wertebereich unsere Bänder am Boden zusammenquetschen würde).
   int total    = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   int trendWnd = total;

   ChartSetInteger(0, CHART_WINDOWS_TOTAL, total + 1);
   ChartSetInteger(0, CHART_HEIGHT_IN_PIXELS, trendWnd, 200);

   return trendWnd;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTrendSegment(int wnd, string name, datetime t1, datetime t2, int level, int trend)
  {
   color col = (trend == -1 ? clrRed : (trend == 0 ? clrGray : clrGreen));

   ObjectCreate(0, name, OBJ_TREND, wnd, t1, level+1, t2, level+1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderTrendBands()
  {
   int wnd = CreateTrendWindow();

// Trendnamen in Reihenfolge
   string names[5] =
     {
      "trendMathM3",
      "trendPatternM3",
      "trendMathH1",
      "trendPatternH1",
      "targetTrendH1"
     };

   for(int i = 0; i < 5; i++)
     {
      RenderSingleTrendBand(wnd, names[i], i);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderSingleTrendBand(int wnd, string trendName, int level)
  {
   string sql = StringFormat(
                   "SELECT time, trendName, trend FROM trends "
                   "WHERE trendName = '%s' ORDER BY time ASC;",
                   trendName
                );

   int stmt = DatabasePrepare(db, sql);

   structTrend t;
   structTrend prev;
   bool first = true;
   int cnt = 0;
   while(DatabaseRead(stmt))
     {
      t.FromSQL(stmt);
      cnt++;
      if(first)
        {
         prev = t;
         first = false;
         continue;
        }

//      string name = StringFormat("TB_%s_%I64d", trendName, t.time);
      string name = StringFormat("TB_%s_%I64d_%I64d", trendName, prev.time, t.time);

      DrawTrendSegment(
         wnd,
         name,
         prev.time,
         t.time,
         level,
         prev.trend
      );

      prev = t;
     }

   DatabaseFinalize(stmt);
  };
  
//+------------------------------------------------------------------+
