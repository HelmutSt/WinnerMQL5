//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |

#ifndef __STRUCTURES_MQH__
#define __STRUCTURES_MQH__

#include "EnumDefAndConvert.mqh"
// ####################################################################
// ### E N G I N E  #############################//+------------------------------------------------------------------+######################
// ####################################################################
struct structEngineConfig
  {
   bool              currentTfOnly;    // true = nur aktueller TF, false = alle TF
   bool              renderToChart;    // Objekte für Ausgabe im Chart rendern
   bool              backtestMode;     // Varianten erzeugen und Backtesten, alle Objecte als JSON für KI ausgeben

   void              Init()
     {
      currentTfOnly = false;
      renderToChart = false;
      backtestMode  = false;
     }
  };
// ####################################################################
// ### M A R K E T  ###################################################
// ####################################################################
struct structMarket
  {
   // Spread
   double            spread;                 // Tick-Ebene (MarketManager.OnTick): aktueller Tick-Spread (ask-bid), wichtig für EntryPrice, Slippage und Liquiditätsfilter.
   double            avgSpreadM3;            // BarManager.marketFeed: durchschnittlicher Bid/Ask-Spread über die letzten 20 abgeschlossenen M3-Bars, zeigt Marktqualität und chaotische Phasen.
   double            maxSpreadM3;            // BarManager.marketFeed: maximaler Bid/Ask-Spread über die letzten 20 abgeschlossenen M3-Bars, identifiziert extreme Illiquidität und News-Spikes.

   // Volatility (Preisvolatilität)
   double            atrM1;                  // BarManager.marketFeed: kurzfristige Preisvolatilität (M1).
   double            atrM3;                  // BarManager.marketFeed: kurzfristige Preisvolatilität (M3).
   double            atrH1;                  // BarManager.marketFeed: mittelfristige Preisvolatilität (H1).
   double            atrD1;                  // BarManager.marketFeed: langfristige Preisvolatilität (D1).
   double            atrRatioM3_H1;          // MarketManager: Verhältnis ATR(M3)/ATR(H1), Kernindikator für Volatilitätsregime.

   // Volatility Flags (Preisvolatilität)
   bool              isHighVolatility;       // MarketManager: hoher ATRRatio → nervöser Markt.
   bool              isLowVolatility;        // MarketManager: niedriger ATRRatio → ruhiger Markt.

   // Volume (Marktaktivität)
   double            avM3;                   // BarManager.marketFeed: durchschnittliches Tickvolumen der letzten M3-Bars.
   double            relativeVolume;         // BarManager.marketFeed: aktuelles Volumen relativ zum Durchschnitt.

   // Volume Flags (Marktaktivität)
   bool              isHighVolume;           // MarketManager: ungewöhnlich hohe Aktivität.
   bool              isLowVolume;            // MarketManager: dünner Markt.

   // Session
   SessionType       session;                // MarketManager.UpdateSession: Hauptsession (ASIA/EU/US).
   SessionPhase      sessionPhase;           // MarketManager.UpdateSessionPhase: feingranulare Marktphase (Overnight, PreKassa, Auction, US-Open etc.).
   datetime          sessionStart;
   bool              isAuction;              // MarketManager.UpdateAuctionStatus: Pre-, Kassa- oder Post-Auction.

   // News
   bool              isNews;                 // MarketManager.OnTick oder später NewsManager: zeigt aktive News.
   int               newsImpact;             // NewsManager (später): Impact-Level der News.
   int               newsType;               // NewsManager (später): Typ der News (CPI, NFP etc.).

   // Expiration
   bool              isSmallExpirationDay;   // MarketManager.UpdateExpirationFlags: kleiner Verfall (3. Freitag).
   bool              isBigExpirationDay;     // MarketManager.UpdateExpirationFlags: großer Quartalsverfall.
   bool              isExpirationDay;        // MarketManager.UpdateExpirationFlags: zusammengefasstes Flag.

   // Trend Mathematisch
   Direction         trendMathM3;            // BarManager.marketFeed: kurzfristiger Trend (M3).
   Direction         trendMathH1;                // BarManager.marketFeed: mittelfristiger Trend (H1).
   Direction         trendMathD1;                // BarManager.marketFeed: langfristiger Trend (D1).

   double            trendStrength;          // MarketManager: kombinierter Trendscore aus trendM3/H1/D1.
   bool              trendChange;            // MarketManager: Trendwechsel zwischen M3 und H1.
   datetime          trendStart;
   datetime          rangeStart;

   // Trend DREIER
   Direction         trendPatternM3;         // PatternManager: Pattern-basierter Trend (DREIER-Kontext).
   Direction         trendPatternH1;         // PatternManager: Pattern-basierter Trend (DREIER-Kontext).

   // Trend Start/Ziel
   Direction         targetTrendH1;         // PatternManager: Pattern-basierter Trend (DREIER-Kontext).

   // Meta
   datetime          lastUpdate;             // MarketManager: Zeitpunkt des letzten M3-Updates.

   // diese Felder nicht ToSQL()
   int               barIndexM1;
   int               barIndexM3;
   int               barIndexH1;
   int               barIndexD1;

   void              Init()
     {
      // Spread
      spread         = 0.0;
      avgSpreadM3    = 0.0;
      maxSpreadM3    = 0.0;

      // Volatility
      atrM1          = 0.0;
      atrM3          = 0.0;
      atrH1          = 0.0;
      atrD1          = 0.0;
      atrRatioM3_H1  = 0.0;

      // Volume
      avM3           = 0.0;
      relativeVolume = 0.0;

      // Session
      session        = ASIA;          // neutraler Startwert
      sessionPhase   = SP_Overnight;  // neutraler Startwert

      // News
      isNews         = false;
      newsImpact     = 0;
      newsType       = 0;

      // Expiration
      isSmallExpirationDay = false;
      isBigExpirationDay   = false;
      isExpirationDay      = false;

      // Auction
      isAuction      = false;

      // Volatility Flags
      isHighVolatility = false;
      isLowVolatility  = false;

      // Volume Flags
      isHighVolume     = false;
      isLowVolume      = false;

      // Trend Context (BarManager + PatternManager)
      trendMathM3        = FLAT;
      trendMathH1        = FLAT;
      trendMathD1        = FLAT;

      trendStrength  = 0.0;
      trendChange    = false;

      trendPatternM3 = FLAT;
      trendPatternH1 = FLAT;
      targetTrendH1 = FLAT;

      // Meta
      lastUpdate     = 0;
     }
   string            ToSQL(const int eventId) const
     {
      return StringFormat(
                "INSERT INTO market ("
                "eventId, "
                "spread, avgSpreadM3, maxSpreadM3, "
                "atrM1, atrM3, atrH1, atrD1, atrRatioM3_H1, "
                "avM3, relativeVolume, "
                "session, sessionPhase, "
                "isNews, newsImpact, newsType, "
                "isSmallExpirationDay, isBigExpirationDay, isExpirationDay, "
                "isAuction, "
                "isHighVolatility, isLowVolatility, "
                "isHighVolume, isLowVolume, "
                "trendMathM3, trendMathH1, trendMathD1, trendStrength, trendChange, "
                "trendPatternM3, trendPatternH1, targetTrendH1, "
                "trendStart, rangeStart, sessionStart, "
                "lastUpdate"
                ") VALUES ("
                "%d, "
                "%.5f, %.5f, %.5f, "
                "%.5f, %.5f, %.5f, %.5f, %.5f, "
                "%.5f, %.5f, "
                "'%s', '%s', "
                "%d, %d, %d, "
                "%d, %d, %d, "
                "%d, "
                "%d, %d, "
                "%d, %d, "
                "'%s', '%s', '%s', %.5f, %d, "
                "'%s', '%s', '%s', "
                "%I64d, %I64d, %I64d, "
                "%I64d"
                ");",
                eventId,
                spread,
                avgSpreadM3,
                maxSpreadM3,
                atrM1,
                atrM3,
                atrH1,
                atrD1,
                atrRatioM3_H1,
                avM3,
                relativeVolume,
                EnumToString(session),
                EnumToString(sessionPhase),
                (int)isNews,
                newsImpact,
                newsType,
                (int)isSmallExpirationDay,
                (int)isBigExpirationDay,
                (int)isExpirationDay,
                (int)isAuction,
                (int)isHighVolatility,
                (int)isLowVolatility,
                (int)isHighVolume,
                (int)isLowVolume,
                EnumToString(trendMathM3),
                EnumToString(trendMathH1),
                EnumToString(trendMathD1),
                trendStrength,
                (int)trendChange,
                EnumToString(trendPatternM3),
                EnumToString(trendPatternH1),
                EnumToString(targetTrendH1),
                (long)trendStart,
                (long)rangeStart,
                (long)sessionStart,
                (long)lastUpdate
             );
     }
   string            CreateSQL() const
     {
      return
         "CREATE TABLE market ("
         "    marketId INTEGER PRIMARY KEY,"
         "    eventId INTEGER NOT NULL,"
         "    spread REAL,"
         "    avgSpreadM3 REAL,"
         "    maxSpreadM3 REAL,"
         "    atrM1 REAL,"
         "    atrM3 REAL,"
         "    atrH1 REAL,"
         "    atrD1 REAL,"
         "    atrRatioM3_H1 REAL,"
         "    avM3 REAL,"
         "    relativeVolume REAL,"
         "    session TEXT,"
         "    sessionPhase TEXT,"
         "    isNews INTEGER,"
         "    newsImpact INTEGER,"
         "    newsType INTEGER,"
         "    isSmallExpirationDay INTEGER,"
         "    isBigExpirationDay INTEGER,"
         "    isExpirationDay INTEGER,"
         "    isAuction INTEGER,"
         "    isHighVolatility INTEGER,"
         "    isLowVolatility INTEGER,"
         "    isHighVolume INTEGER,"
         "    isLowVolume INTEGER,"
         "    trendMathM3 TEXT,"
         "    trendMathH1 TEXT,"
         "    trendMathD1 TEXT,"
         "    trendStrength REAL,"
         "    trendChange INTEGER,"
         "    trendPatternM3 TEXT,"
         "    trendPatternH1 TEXT,"
         "    targetTrendH1 TEXT,"
         "    trendStart INTEGER,"
         "    rangeStart INTEGER,"
         "    sessionStart INTEGER,"
         "    lastUpdate INTEGER,"
         "    FOREIGN KEY(eventId) REFERENCES events(eventId)"
         ");";
     }
   void              LoadFromSQL(const int stmt)
     {
      int intVal;
      string temp;

      // 0: marketId (ignorieren, Struktur hat es nicht)
      DatabaseColumnInteger(stmt, 0, intVal);

      // 1: eventId (extern verwaltet)
      DatabaseColumnInteger(stmt, 1, intVal);
      // eventId wird NICHT in die Struktur geschrieben

      // ---------------------------------------------------------
      // Spread
      // ---------------------------------------------------------
      DatabaseColumnDouble(stmt, 2, spread);
      DatabaseColumnDouble(stmt, 3, avgSpreadM3);
      DatabaseColumnDouble(stmt, 4, maxSpreadM3);

      // ---------------------------------------------------------
      // Volatility
      // ---------------------------------------------------------
      DatabaseColumnDouble(stmt, 5, atrM1);
      DatabaseColumnDouble(stmt, 6, atrM3);
      DatabaseColumnDouble(stmt, 7, atrH1);
      DatabaseColumnDouble(stmt, 8, atrD1);
      DatabaseColumnDouble(stmt, 9, atrRatioM3_H1);

      // ---------------------------------------------------------
      // Volume
      // ---------------------------------------------------------
      DatabaseColumnDouble(stmt, 10, avM3);
      DatabaseColumnDouble(stmt, 11, relativeVolume);

      // ---------------------------------------------------------
      // Session
      // ---------------------------------------------------------
      DatabaseColumnText(stmt, 12, temp);
      session = StringToSessionType(temp);

      DatabaseColumnText(stmt, 13, temp);
      sessionPhase = StringToSessionPhase(temp);

      DatabaseColumnInteger(stmt, 35, intVal);
      sessionStart = (datetime)intVal;

      // ---------------------------------------------------------
      // News
      // ---------------------------------------------------------
      DatabaseColumnInteger(stmt, 14, intVal);
      isNews = (intVal != 0);

      DatabaseColumnInteger(stmt, 15, newsImpact);
      DatabaseColumnInteger(stmt, 16, newsType);

      // ---------------------------------------------------------
      // Expiration
      // ---------------------------------------------------------
      DatabaseColumnInteger(stmt, 17, intVal);
      isSmallExpirationDay = (intVal != 0);

      DatabaseColumnInteger(stmt, 18, intVal);
      isBigExpirationDay = (intVal != 0);

      DatabaseColumnInteger(stmt, 19, intVal);
      isExpirationDay = (intVal != 0);

      // ---------------------------------------------------------
      // Auction
      // ---------------------------------------------------------
      DatabaseColumnInteger(stmt, 20, intVal);
      isAuction = (intVal != 0);

      // ---------------------------------------------------------
      // Volatility Flags
      // ---------------------------------------------------------
      DatabaseColumnInteger(stmt, 21, intVal);
      isHighVolatility = (intVal != 0);

      DatabaseColumnInteger(stmt, 22, intVal);
      isLowVolatility = (intVal != 0);

      // ---------------------------------------------------------
      // Volume Flags
      // ---------------------------------------------------------
      DatabaseColumnInteger(stmt, 23, intVal);
      isHighVolume = (intVal != 0);

      DatabaseColumnInteger(stmt, 24, intVal);
      isLowVolume = (intVal != 0);

      // ---------------------------------------------------------
      // Trend mathematisch
      // ---------------------------------------------------------
      DatabaseColumnText(stmt, 25, temp);
      trendMathM3 =  StringToDirection(temp);

      DatabaseColumnText(stmt, 26, temp);
      trendMathH1 =  StringToDirection(temp);

      DatabaseColumnText(stmt, 27, temp);
      trendMathD1 =  StringToDirection(temp);

      DatabaseColumnDouble(stmt, 28, trendStrength);

      DatabaseColumnInteger(stmt, 29, intVal);
      trendChange = (intVal != 0);

      // ---------------------------------------------------------
      // Trend DREIER
      // ---------------------------------------------------------
      DatabaseColumnText(stmt, 30, temp);
      trendPatternM3 =  StringToDirection(temp);

      DatabaseColumnText(stmt, 31, temp);
      trendPatternH1 =  StringToDirection(temp);

      DatabaseColumnText(stmt, 32, temp);
      targetTrendH1 =  StringToDirection(temp);

      // ---------------------------------------------------------
      // Zeitfelder
      // ---------------------------------------------------------
      DatabaseColumnInteger(stmt, 33, intVal);
      trendStart = (datetime)intVal;

      DatabaseColumnInteger(stmt, 34, intVal);
      rangeStart = (datetime)intVal;

      DatabaseColumnInteger(stmt, 36, intVal);
      lastUpdate = (datetime)intVal;

      return;
     }

  };
// ####################################################################
// ### B A R S ########################################################
// ####################################################################
struct structBar
  {
   datetime          time;      // Anfangszeit der Bar
   double            open;
   double            high;
   double            low;
   double            close;
   ulong             volume;
   BarShape          shape;
   int               barIndex;
   double            spreadSum;    // Summe der Tick-Spreads (ask-bid) während dieser Bar, für avgSpread-Berechnung
   int               spreadCount;  // Anzahl Ticks, die in spreadSum eingeflossen sind
   double            spreadMax;    // Maximaler Tick-Spread während dieser Bar
   void              Init()
     {
      time        = 0;
      open        = 0.0;
      high        = 0.0;
      low         = 0.0;
      close       = 0.0;
      volume      = 0;
      shape       = UNCLASSIFIED;
      barIndex    = -1;
      spreadSum   = 0.0;
      spreadCount = 0;
      spreadMax   = 0.0;
     }
  };
struct structBarBlock
  {
   ENUM_TIMEFRAMES   timeFrame;
   int               periodSec;
   structBar         bars[21];         // 0 = laufend 1-20 = abgeschlossen
   double            avgSpread;        // Average Spread für diesen TF
   double            maxSpread;        // Maximum Spread für diesen TF
   double            atr;              // Average True Range
   double            trHistory[14];    // for ATR calculation - klassisch nach wilderer
   int               pos ;             // zeiger auf ringbuffer
   double            av;               // Average Volume
   double            avHistory[14];    // for ATR calculation - klassisch nach wilderer
   bool              atrReady;         // for ATR calculation
   Direction         trend;

   void              Init(int tfIdx)
     {
      timeFrame = IndexToTimeFrame(tfIdx);
      periodSec = PeriodSeconds(timeFrame);

      for(int i = 0; i < 21; i++)
         bars[i].Init();
      avgSpread = 0.0;
      maxSpread = 0.0;
      atr = 0.0;
      for(int i = 0; i < 14; i++)
         trHistory[i] = 0.0;
      pos = 0;
      av = 0.0;
      for(int i = 0; i < 14; i++)
         avHistory[i] = 0.0;
      atrReady = false;
      trend    = FLAT;
     }
  };
// ####################################################################
// ###  P A T T E R N   C O R E #######################################
// ####################################################################
struct structPatternCore
  {
   int               patternId;                     // Eindeutige Pattern‑ID (Primärschlüssel in patternCore)

   ENUM_TIMEFRAMES   timeFrame;                     // Timeframe, in dem das Pattern entstanden ist (M1/M3/M5/…)
   PatternType       type;                          // Klassifikation des Patterns (Range, Swing, Trend, Dreier, etc.)

   datetime          startTime;                     // Zeitpunkt des ersten Bars des Patterns
   datetime          endTime;                       // Zeitpunkt des letzten Bars des Patterns
   datetime          validFrom;                     // Zeitpunkt, ab dem das Pattern gültig ist (Break/Activation)

   int               startBarIndex;                 // Bar‑Index des Startbars relativ zum Chart
   int               validFromBarIndex;             // Bar‑Index des Validierungsbars (Break/Activation)
   int               endBarIndex;                   // Bar‑Index des Endbars

   double            priceLow;                      // Tiefster Preis des Patterns
   double            priceHigh;                     // Höchster Preis des Patterns
   double            width;                         // Preisbreite des Patterns (priceHigh - priceLow)
   double            priceSlopePerBar;              // Steigung des Patterns pro Bar (Trendneigung)

   PreviousRelation  previousStartPriceRelation;    // Relation des Startpreises zum vorherigen Pattern (Above/Below/Inside)

   // --- Zeitliche Distanz ---
   int               barsSincePrevious;             // Anzahl Bars seit dem vorherigen Pattern

   // --- Räumliche Distanz ---
   double            priceDeltaToPreviousPattern;   // Preisabstand zum vorherigen Pattern (absolute Differenz)
   double            priceOffsetToPreviousPattern;  // Preisversatz relativ zur ATR (normiert)

   // --- Räumliche Relation ---
   bool              isOverlapingPrevious;          // Überlappt dieses Pattern den Preisbereich des vorherigen?
   bool              isInsidePrevious;              // Liegt dieses Pattern vollständig im vorherigen?
   bool              isOutsidePrevious;             // Liegt dieses Pattern vollständig außerhalb des vorherigen?

   Direction         direction;                     // Richtung des Patterns (Up/Down/Flat)

   SessionType       sessionAtCreate;               // Session zum Zeitpunkt der Pattern‑Erstellung (Asia/Europe/US)
   Direction         trendContextAtCreate;          // Trendrichtung des Marktes beim Pattern‑Start (Up/Down/Flat)

   BarShape          shapeBarA;                     // Form des ersten Bars beim Pattern‑Start
   BarShape          shapeBarB;                     // Form des zweiten Bars beim Pattern‑Start
   BarShape          shapeBarC;                     // Form des dritten Bars beim Pattern‑Start

   double            rangeBarA;                     // Range des Bars A (High-Low)
   double            rangeBarB;                     // Range des Bars B
   double            rangeBarC;                     // Range des Bars C

   double            wickRatio;                     // Verhältnis der Dochte zur Gesamtrange (Marktstärke/Unsicherheit)

   double            patternStrengthAtCreate;       // Stärke des Patterns zum Erstellungszeitpunkt (Score für KI)

   int               h1FormationParentId;           // nur M3-DREIER: patternId des gleichgerichteten H1-DREIER, waehrend
                                                      // dessen Formation dieses M3-Pattern entstand (-1 = keiner)

   // ---------------------------------------------------------
   // Init
   // ---------------------------------------------------------
   void              Init()
     {
      patternId                        = -1;

      timeFrame                        = PERIOD_CURRENT;
      type                             = PT_UNDEFINED;

      startTime                        = 0;
      endTime                          = 0;
      validFrom                        = 0;

      startBarIndex                    = -1;
      validFromBarIndex                = -1;
      endBarIndex                      = -1;

      priceLow                         = 0.0;
      priceHigh                        = 0.0;
      width                            = 0.0;
      priceSlopePerBar                 = 0.0;

      previousStartPriceRelation       = EVEN;

      barsSincePrevious                = 0;

      priceDeltaToPreviousPattern      = 0.0;
      priceOffsetToPreviousPattern     = 0.0;

      isOverlapingPrevious             = false;
      isInsidePrevious                 = false;
      isOutsidePrevious                = false;

      direction                        = FLAT;

      sessionAtCreate                  = EU;
      trendContextAtCreate             = FLAT;

      shapeBarA                        = UNCLASSIFIED;
      shapeBarB                        = UNCLASSIFIED;
      shapeBarC                        = UNCLASSIFIED;

      rangeBarA                        = 0.0;
      rangeBarB                        = 0.0;
      rangeBarC                        = 0.0;

      wickRatio                        = 0.0;

      patternStrengthAtCreate          = 0.0;

      h1FormationParentId              = -1;
     }

   // ---------------------------------------------------------
   // ToSQL
   // ---------------------------------------------------------
   string            ToSQL() const
     {
      return StringFormat(
                "INSERT INTO patternCore ("
                "patternId, timeFrame, type, startTime, endTime, "
                "validFrom, "
                "startBarIndex, validFromBarIndex, endBarIndex, "
                "priceLow, priceHigh, width, priceSlopePerBar, "
                "previousStartPriceRelation, "
                "barsSincePrevious, "
                "priceDeltaToPreviousPattern, priceOffsetToPreviousPattern, "
                "isOverlapingPrevious, isInsidePrevious, isOutsidePrevious, "
                "direction, sessionAtCreate, trendContextAtCreate, "
                "shapeBarA, shapeBarB, shapeBarC, "
                "rangeBarA, rangeBarB, rangeBarC, "
                "wickRatio, patternStrengthAtCreate, h1FormationParentId"
                ") VALUES ("
                "%d, '%s', '%s', %I64d, %I64d, "
                "%I64d, "
                "%d, %d, %d, "
                "%.5f, %.5f, %.5f, %.5f, "
                "'%s', "
                "%d, "
                "%.5f, %.5f, "
                "%d, %d, %d, "
                "'%s', '%s', '%s', "
                "'%s', '%s', '%s', "
                "%.5f, %.5f, %.5f, "
                "%.5f, %.5f, "
                "%d"
                ");",
                patternId,
                TimeFrameToString(timeFrame),
                EnumToString(type),
                (long)startTime, (long)endTime,
                (long)validFrom,
                startBarIndex, validFromBarIndex, endBarIndex,
                priceLow, priceHigh, width, priceSlopePerBar,
                EnumToString(previousStartPriceRelation),
                barsSincePrevious,
                priceDeltaToPreviousPattern, priceOffsetToPreviousPattern,
                (int)isOverlapingPrevious, (int)isInsidePrevious, (int)isOutsidePrevious,
                EnumToString(direction),
                EnumToString(sessionAtCreate),
                EnumToString(trendContextAtCreate),
                EnumToString(shapeBarA), EnumToString(shapeBarB), EnumToString(shapeBarC),
                rangeBarA, rangeBarB, rangeBarC,
                wickRatio, patternStrengthAtCreate,
                h1FormationParentId
             );
     }

   // ---------------------------------------------------------
   // CreateSQL
   // ---------------------------------------------------------
   string            CreateSQL() const
     {
      return
         "CREATE TABLE patternCore ("
         "patternId INTEGER PRIMARY KEY,"
         "timeFrame TEXT,"
         "type TEXT,"
         "startTime INTEGER,"
         "endTime INTEGER,"
         "validFrom INTEGER,"
         "startBarIndex INTEGER,"
         "validFromBarIndex INTEGER,"
         "endBarIndex INTEGER,"
         "priceLow REAL,"
         "priceHigh REAL,"
         "width REAL,"
         "priceSlopePerBar REAL,"
         "previousStartPriceRelation TEXT,"
         "barsSincePrevious INTEGER,"
         "priceDeltaToPreviousPattern REAL,"
         "priceOffsetToPreviousPattern REAL,"
         "isOverlapingPrevious INTEGER,"
         "isInsidePrevious INTEGER,"
         "isOutsidePrevious INTEGER,"
         "direction TEXT,"
         "sessionAtCreate TEXT,"
         "trendContextAtCreate TEXT,"
         "shapeBarA TEXT,"
         "shapeBarB TEXT,"
         "shapeBarC TEXT,"
         "rangeBarA REAL,"
         "rangeBarB REAL,"
         "rangeBarC REAL,"
         "wickRatio REAL,"
         "patternStrengthAtCreate REAL,"
         "h1FormationParentId INTEGER DEFAULT -1"
         ");";
     }

   // ---------------------------------------------------------
   // LoadAusSQL
   // ---------------------------------------------------------
   bool              LoadAusSQL(const int stmt)
     {
      string temp;
      int    intVal;

      DatabaseColumnInteger(stmt, 0, patternId);

      DatabaseColumnText(stmt, 1, temp);
      timeFrame = StringToTimeFrame(temp);

      DatabaseColumnText(stmt, 2, temp);
      type = StringToPatternType(temp);

      DatabaseColumnInteger(stmt, 3, intVal);
      startTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, 4, intVal);
      endTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, 5, intVal);
      validFrom = (datetime)intVal;

      DatabaseColumnInteger(stmt, 6, startBarIndex);
      DatabaseColumnInteger(stmt, 7, validFromBarIndex);
      DatabaseColumnInteger(stmt, 8, endBarIndex);

      DatabaseColumnDouble(stmt, 9, priceLow);
      DatabaseColumnDouble(stmt, 10, priceHigh);
      DatabaseColumnDouble(stmt, 11, width);
      DatabaseColumnDouble(stmt, 12, priceSlopePerBar);

      DatabaseColumnText(stmt, 13, temp);
      previousStartPriceRelation = StringToPreviousRelation(temp);

      DatabaseColumnInteger(stmt, 14, barsSincePrevious);

      DatabaseColumnDouble(stmt, 15, priceDeltaToPreviousPattern);
      DatabaseColumnDouble(stmt, 16, priceOffsetToPreviousPattern);

      DatabaseColumnInteger(stmt, 17, intVal);
      isOverlapingPrevious = (intVal != 0);

      DatabaseColumnInteger(stmt, 18, intVal);
      isInsidePrevious = (intVal != 0);

      DatabaseColumnInteger(stmt, 19, intVal);
      isOutsidePrevious = (intVal != 0);

      DatabaseColumnText(stmt, 20, temp);
      direction = StringToDirection(temp);

      DatabaseColumnText(stmt, 21, temp);
      sessionAtCreate = StringToSessionType(temp);

      DatabaseColumnText(stmt, 22, temp);
      trendContextAtCreate = StringToDirection(temp);

      DatabaseColumnText(stmt, 23, temp);
      shapeBarA = StringToBarShape(temp);

      DatabaseColumnText(stmt, 24, temp);
      shapeBarB = StringToBarShape(temp);

      DatabaseColumnText(stmt, 25, temp);
      shapeBarC = StringToBarShape(temp);

      DatabaseColumnDouble(stmt, 26, rangeBarA);
      DatabaseColumnDouble(stmt, 27, rangeBarB);
      DatabaseColumnDouble(stmt, 28, rangeBarC);

      DatabaseColumnDouble(stmt, 29, wickRatio);

      DatabaseColumnDouble(stmt, 30, patternStrengthAtCreate);

      DatabaseColumnInteger(stmt, 31, h1FormationParentId);

      return true;
     }
  };
// ####################################################################
// ###  P A T T E R N   D Y N A M I C  ################################
// ####################################################################
struct structPatternDynamic      // last Chance 20.07.2026 — mit BreakTime & breakBarIndex
  {
   PatternStatus     status;

   datetime          breakTime;        // Zeitpunkt des Breaks (aus Sicht dieses Events)
   int               breakBarIndex;    // BarIndex des Breaks (aus Sicht dieses Events)

   datetime          validUntil;       // Zeitpunkt, bis wann das Pattern gültig bleibt (Invalidation) — Lifetime-Fakt, aus patternCore verschoben

   int               touches;
   int               nearTouches;

   int               postBreakRetestTouches;
   int               nearPostBreakRetestTouches;

   bool              isTrendBreak;
   bool              isStartOfMove;
   int               sequenceSinceStartOfMove;      // Laufende Nummer des Patterns seit StartOfMove

   bool              hadFakeBreak;
   bool              hadFakeRetestBreak;
   bool              causedOppositePatternBreak;

   double            priceExtremeBeforeBreak;
   double            priceExtremeAfterBreak;
   double            priceExtremePrevious;

   PreviousRelation  previousExtremeBeforeBreakPriceRelation;

   // ---------------------------------------------------------
   // Init
   // ---------------------------------------------------------
   void              Init()
     {
      status                         = OPEN;

      breakTime                      = 0;
      breakBarIndex                  = -1;

      validUntil                     = 0;

      touches                        = 0;
      nearTouches                    = 0;

      postBreakRetestTouches         = 0;
      nearPostBreakRetestTouches     = 0;

      isTrendBreak                   = false;
      isStartOfMove                  = false;
      sequenceSinceStartOfMove       = 0;

      hadFakeBreak                   = false;
      hadFakeRetestBreak             = false;
      causedOppositePatternBreak     = false;

      priceExtremeBeforeBreak        = 0.0;
      priceExtremeAfterBreak         = 0.0;
      priceExtremePrevious           = 0.0;

      previousExtremeBeforeBreakPriceRelation = EVEN;
     }

   // ---------------------------------------------------------
   // ToSQL
   // ---------------------------------------------------------
   string            ToSQL(int patternId, int eventId) const
     {
      return StringFormat(
                "INSERT INTO patternDynamic ("
                "status, eventId, patternId, "
                "breakTime, breakBarIndex, "
                "touches, nearTouches, "
                "postBreakRetestTouches, nearPostBreakRetestTouches, "
                "isTrendBreak, isStartOfMove, sequenceSinceStartOfMove, "
                "hadFakeBreak, hadFakeRetestBreak, causedOppositePatternBreak, "
                "priceExtremeBeforeBreak, priceExtremeAfterBreak, priceExtremePrevious, "
                "previousExtremeBeforeBreakPriceRelation, "
                "validUntil"
                ") VALUES ("
                "'%s', %d, %d, "
                "%I64d, %d, "
                "%d, %d, "
                "%d, %d, "
                "%d, %d, %d, "
                "%d, %d, %d, "
                "%.5f, %.5f, %.5f, "
                "'%s', "
                "%I64d"
                ");",
                EnumToString(status),
                eventId,
                patternId,
                (long)breakTime,
                breakBarIndex,
                touches,
                nearTouches,
                postBreakRetestTouches,
                nearPostBreakRetestTouches,
                (int)isTrendBreak,
                (int)isStartOfMove,
                sequenceSinceStartOfMove,
                (int)hadFakeBreak,
                (int)hadFakeRetestBreak,
                (int)causedOppositePatternBreak,
                priceExtremeBeforeBreak,
                priceExtremeAfterBreak,
                priceExtremePrevious,
                EnumToString(previousExtremeBeforeBreakPriceRelation),
                (long)validUntil
             );
     }

   // ---------------------------------------------------------
   // CreateSQL
   // ---------------------------------------------------------
   string            CreateSQL() const
     {
      return
         "CREATE TABLE patternDynamic ("
         "    dynamicId INTEGER PRIMARY KEY,"
         "    status TEXT,"
         "    eventId INTEGER NOT NULL,"
         "    patternId INTEGER NOT NULL,"

         "    breakTime INTEGER,"
         "    breakBarIndex INTEGER,"

         "    touches INTEGER,"
         "    nearTouches INTEGER,"

         "    postBreakRetestTouches INTEGER,"
         "    nearPostBreakRetestTouches INTEGER,"

         "    isTrendBreak INTEGER,"
         "    isStartOfMove INTEGER,"
         "    sequenceSinceStartOfMove INTEGER,"
         "    hadFakeBreak INTEGER,"
         "    hadFakeRetestBreak INTEGER,"
         "    causedOppositePatternBreak INTEGER,"

         "    priceExtremeBeforeBreak REAL,"
         "    priceExtremeAfterBreak REAL,"
         "    priceExtremePrevious REAL,"

         "    previousExtremeBeforeBreakPriceRelation TEXT,"

         "    validUntil INTEGER"
         ");";
     }

   // ---------------------------------------------------------
   // LoadFromSQL
   // ---------------------------------------------------------
   bool              LoadFromSQL(const int stmt, int &eventId, int &patternId)
     {
      int    intVal;
      string temp;

      // 0 dynamicId (ignorieren)
      // 1 status
      // 2 eventId
      // 3 patternId

      DatabaseColumnText(stmt, 1, temp);
      status = StringToPatternStatus(temp);

      DatabaseColumnInteger(stmt, 2, eventId);
      DatabaseColumnInteger(stmt, 3, patternId);

      DatabaseColumnInteger(stmt, 4, intVal);
      breakTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, 5, breakBarIndex);

      DatabaseColumnInteger(stmt, 6, touches);
      DatabaseColumnInteger(stmt, 7, nearTouches);

      DatabaseColumnInteger(stmt, 8, postBreakRetestTouches);
      DatabaseColumnInteger(stmt, 9, nearPostBreakRetestTouches);

      DatabaseColumnInteger(stmt, 10, intVal);
      isTrendBreak = (intVal != 0);

      DatabaseColumnInteger(stmt, 11, intVal);
      isStartOfMove = (intVal != 0);

      DatabaseColumnInteger(stmt, 12, sequenceSinceStartOfMove);

      DatabaseColumnInteger(stmt, 13, intVal);
      hadFakeBreak = (intVal != 0);

      DatabaseColumnInteger(stmt, 14, intVal);
      hadFakeRetestBreak = (intVal != 0);

      DatabaseColumnInteger(stmt, 15, intVal);
      causedOppositePatternBreak = (intVal != 0);

      DatabaseColumnDouble(stmt, 16, priceExtremeBeforeBreak);
      DatabaseColumnDouble(stmt, 17, priceExtremeAfterBreak);
      DatabaseColumnDouble(stmt, 18, priceExtremePrevious);

      DatabaseColumnText(stmt, 19, temp);
      previousExtremeBeforeBreakPriceRelation =
         StringToPreviousRelation(temp);

      DatabaseColumnInteger(stmt, 20, intVal);
      validUntil = (datetime)intVal;

      return true;
     }
  };
// ####################################################################
// ###  P A T T E R N   T E M P ########################################
// ####################################################################
struct structPatternTemp      // last Chance 07.07.2026
  {
   bool              isTouching;                        // Gerade im Touch - nicht neu zählen
   bool              isNearTouching;                    // Gerade im NearTouch - nicht neu zählen

   bool              isPostBreakRetestTouching;         // Runtime: Retest-Touch nach Break
   bool              isNearPostBreakRetestTouching;     // Runtime: NearRetest-Touch nach Break

   bool              brokenButNotConfirmed;             // Runtime: Break erkannt, aber noch nicht bestätigt
   bool              postBreakRetestBrokenButNotConfirmed; // Runtime: Retest-Break erkannt, aber noch nicht bestätigt

   int               previousPatternIdx; // same type und direction

   void              Init()
     {
      isTouching                           = true; // wird erst nach away schaft geschaltet
      isNearTouching                       = true;

      isPostBreakRetestTouching            = false;
      isNearPostBreakRetestTouching        = false;

      brokenButNotConfirmed                = false;
      postBreakRetestBrokenButNotConfirmed = false;

      previousPatternIdx                   = -1;
     }
  };
// ####################################################################
// ###  P A T T E R N   W R A P P E R ##################################
// ####################################################################
struct structPattern
  {
   structPatternCore    core;
   structPatternDynamic dynamic;
   structPatternTemp    temp;

   void              Init()
     {
      core.Init();
      dynamic.Init();
      temp.Init();
     }
  };
// ####################################################################
// ###  R E L A T I O N   ######################################
// ####################################################################
struct structRelation
  {
   int               relationId;          // PK
   int               eventId;             // Event-ID
   string            slotName;            // Slot (M3_SoM_Under, D1_Tang1_Over, ...)
   int               patternId;           // >0 = Pattern, -1 = Tangente/VTH

   // ---------------------------------------------------------
   // UNIVERSAL: Distanz zwischen Event und Slot-Bezugspunkt
   // ---------------------------------------------------------
   double            priceDistance;       // Für Pattern: Startpreis / Für Tangente: priceAtEvent

   // ---------------------------------------------------------
   // PATTERN-FELDER (nur gültig wenn patternId > 0)
   // ---------------------------------------------------------

   int               barsSinceStart;      // Bars seit Pattern-Start
   int               barsSinceBreak;      // Bars seit Break

   double            priceDistanceToBreakLevel;
   double            priceDistanceExtremeBeforeBreak;
   double            priceDistanceExtremeAfterBreak;

   double            eventSlopeRelation;      // Verhältnis Event-Preis zur Pattern-Slope
   double            eventPositionRelative;   // Position im Pattern-Fenster (0..1)

   bool              isOriginPattern;
   bool              isInPatternNow;
   bool              isTouchingNow;
   bool              isNearTouchingNow;
   bool              isBreakingNow;

   double            patternRelevanceAtEvent;

   // ---------------------------------------------------------
   // TANGENTEN-FELDER (nur gültig wenn patternId == -1)
   // ---------------------------------------------------------

   int               tangenteIndex;       // 1 oder 2
   double            tangSlope;           // Steigung der Tangente
   double            tangAngle;           // Winkel der Tangente
   double            tangLength;          // Länge der Tangente bis zum Event
   double            tangPriceAtEvent;    // Preis der Tangente am Event

   // ---------------------------------------------------------
   // Init()
   // ---------------------------------------------------------
   void              Init()
     {
      relationId = -1;
      eventId = -1;
      slotName = "int";
      patternId = -1;

      barsSinceStart = 0;
      barsSinceBreak = 0;


      priceDistanceToBreakLevel       = DBL_MAX;
      priceDistanceExtremeBeforeBreak = DBL_MAX;
      priceDistanceExtremeAfterBreak  = DBL_MAX;

      eventSlopeRelation    = 0.0;
      eventPositionRelative = 0.0;

      isOriginPattern   = false;
      isInPatternNow    = false;
      isTouchingNow     = false;
      isNearTouchingNow = false;
      isBreakingNow     = false;

      patternRelevanceAtEvent = 0.0;

      tangenteIndex= 0;       // 1 oder 2
      tangSlope= 0;           // Steigung der Tangente
      tangAngle= 0;           // Winkel der Tangente
      tangLength= 0;          // Länge der Tangente bis zum Event
      tangPriceAtEvent= 0;    // Preis der Tangente am Event
     }

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   string            CreateSQL() const
     {
      return
         "CREATE TABLE relations ("
         "    relationId INTEGER PRIMARY KEY,"
         "    eventId INTEGER NOT NULL,"
         "    patternId INTEGER,"                 // >0 = Pattern, -1 = Tangente/VTH
         "    slotName TEXT NOT NULL,"

         // Universal Distanz
         "    priceDistance REAL,"

         // Pattern-Felder
         "    barsSinceStart INTEGER,"
         "    barsSinceBreak INTEGER,"
         "    priceDistanceToBreakLevel REAL,"
         "    priceDistanceExtremeBeforeBreak REAL,"
         "    priceDistanceExtremeAfterBreak REAL,"
         "    eventSlopeRelation REAL,"
         "    eventPositionRelative REAL,"
         "    isOriginPattern INTEGER,"
         "    isInPatternNow INTEGER,"
         "    isTouchingNow INTEGER,"
         "    isNearTouchingNow INTEGER,"
         "    isBreakingNow INTEGER,"
         "    patternRelevanceAtEvent REAL,"

         // Tangenten-Felder
         "    tangenteIndex INTEGER,"
         "    tangSlope REAL,"
         "    tangAngle REAL,"
         "    tangLength REAL,"
         "    tangPriceAtEvent REAL"
         ");";
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   string            ToSQL() const
     {
      return StringFormat(
                "INSERT INTO relations ("
                "    relationId,"
                "    eventId,"
                "    patternId,"
                "    slotName,"
                "    priceDistance,"
                "    barsSinceStart,"
                "    barsSinceBreak,"
                "    priceDistanceToBreakLevel,"
                "    priceDistanceExtremeBeforeBreak,"
                "    priceDistanceExtremeAfterBreak,"
                "    eventSlopeRelation,"
                "    eventPositionRelative,"
                "    isOriginPattern,"
                "    isInPatternNow,"
                "    isTouchingNow,"
                "    isNearTouchingNow,"
                "    isBreakingNow,"
                "    patternRelevanceAtEvent,"
                "    tangenteIndex,"
                "    tangSlope,"
                "    tangAngle,"
                "    tangLength,"
                "    tangPriceAtEvent"
                ") VALUES ("
                "%d,"          // relationId
                "%d,"          // eventId
                "%s,"          // patternId (NULL oder Zahl)
                "'%s',"        // slotName
                "%.5f,"        // priceDistance
                "%d,"          // barsSinceStart
                "%d,"          // barsSinceBreak
                "%.5f,"        // priceDistanceToBreakLevel
                "%.5f,"        // priceDistanceExtremeBeforeBreak
                "%.5f,"        // priceDistanceExtremeAfterBreak
                "%.5f,"        // eventSlopeRelation
                "%.5f,"        // eventPositionRelative
                "%d,"          // isOriginPattern
                "%d,"          // isInPatternNow
                "%d,"          // isTouchingNow
                "%d,"          // isNearTouchingNow
                "%d,"          // isBreakingNow
                "%.5f,"        // patternRelevanceAtEvent
                "%d,"          // tangenteIndex
                "%.5f,"        // tangSlope
                "%.5f,"        // tangAngle
                "%.5f,"        // tangLength
                "%.5f"         // tangPriceAtEvent
                ");",

                relationId,
                eventId,
                (patternId == -1 ? "NULL" : IntegerToString(patternId)),
                slotName,
                priceDistance,
                barsSinceStart,
                barsSinceBreak,
                priceDistanceToBreakLevel,
                priceDistanceExtremeBeforeBreak,
                priceDistanceExtremeAfterBreak,
                eventSlopeRelation,
                eventPositionRelative,
                (int)isOriginPattern,
                (int)isInPatternNow,
                (int)isTouchingNow,
                (int)isNearTouchingNow,
                (int)isBreakingNow,
                patternRelevanceAtEvent,
                tangenteIndex,
                tangSlope,
                tangAngle,
                tangLength,
                tangPriceAtEvent
             );
     }
   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   bool              LoadFromSQL(const int stmt)
     {
      int intVal;

      DatabaseColumnInteger(stmt, 0, relationId);
      DatabaseColumnInteger(stmt, 1, eventId);
      DatabaseColumnInteger(stmt, 2, patternId);
      DatabaseColumnText(stmt,    3, slotName);

      DatabaseColumnDouble(stmt,  4, priceDistance);

      DatabaseColumnInteger(stmt, 5, barsSinceStart);
      DatabaseColumnInteger(stmt, 6, barsSinceBreak);

      DatabaseColumnDouble(stmt,  7, priceDistanceToBreakLevel);
      DatabaseColumnDouble(stmt,  8, priceDistanceExtremeBeforeBreak);
      DatabaseColumnDouble(stmt,  9, priceDistanceExtremeAfterBreak);

      DatabaseColumnDouble(stmt, 10, eventSlopeRelation);
      DatabaseColumnDouble(stmt, 11, eventPositionRelative);

      DatabaseColumnInteger(stmt, 12, intVal);
      isOriginPattern = (intVal != 0);

      DatabaseColumnInteger(stmt, 13, intVal);
      isInPatternNow = (intVal != 0);

      DatabaseColumnInteger(stmt, 14, intVal);
      isTouchingNow = (intVal != 0);

      DatabaseColumnInteger(stmt, 15, intVal);
      isNearTouchingNow = (intVal != 0);

      DatabaseColumnInteger(stmt, 16, intVal);
      isBreakingNow = (intVal != 0);

      DatabaseColumnDouble(stmt, 17, patternRelevanceAtEvent);

      DatabaseColumnInteger(stmt, 18, tangenteIndex);
      DatabaseColumnDouble(stmt, 19, tangSlope);
      DatabaseColumnDouble(stmt, 20, tangAngle);
      DatabaseColumnDouble(stmt, 21, tangLength);
      DatabaseColumnDouble(stmt, 22, tangPriceAtEvent);

      return true;
     }
  };
// ####################################################################
// ###  E v e n t ########################################
// ####################################################################
struct structEvent
  {
   int               eventId;
   int               patternId;

   ENUM_TIMEFRAMES   patternTF;
   PatternType       patternType;
   EventReason       eventReason;
   Direction         patternDirection;
   Direction         eventDirection;

   datetime          eventTime;
   double            eventPrice;

   bool              isEntryEvent;

   void              Init()
     {
      eventId          = -1;
      patternId        = -1;

      patternTF        = PERIOD_CURRENT;
      patternType      = PT_UNDEFINED;
      eventReason      = IS_CREATED;

      patternDirection = FLAT;
      eventDirection   = FLAT;

      eventTime        = 0;
      eventPrice       = 0.0;

      isEntryEvent     = false;
     }

   string            ToSQL() const
     {
      return StringFormat(
                "INSERT INTO events ("
                "eventId, patternId, "
                "patternTF, patternType, eventReason, "
                "patternDirection, eventDirection, "
                "eventTime, eventPrice, "
                "isEntryEvent"
                ") VALUES ("
                "%d, %d, "
                "'%s', '%s', '%s', "
                "'%s', '%s', "
                "%I64d, %.5f, "
                "%d"
                ");",
                eventId,
                patternId,
                TimeFrameToString(patternTF),
                EnumToString(patternType),
                EnumToString(eventReason),
                EnumToString(patternDirection),
                EnumToString(eventDirection),
                (long)eventTime,
                eventPrice,
                (int)isEntryEvent
             );
     }

   string            CreateSQL() const
     {
      return
         "CREATE TABLE events ("
         "    eventId INTEGER PRIMARY KEY,"
         "    patternId INTEGER NOT NULL,"
         "    patternTF TEXT,"
         "    patternType TEXT,"
         "    eventReason TEXT,"
         "    patternDirection TEXT,"
         "    eventDirection TEXT,"
         "    eventTime INTEGER,"
         "    eventPrice REAL,"
         "    isEntryEvent INTEGER NOT NULL DEFAULT 0"
         ");";
     }

   void              LoadFromSQL(int stmt)
     {
      string temp;
      int intVal;

      // 0: eventId
      DatabaseColumnInteger(stmt, 0, eventId);

      // 1: patternId
      DatabaseColumnInteger(stmt, 1, patternId);

      // 2: patternTF
      DatabaseColumnText(stmt, 2, temp);
      patternTF = StringToTimeFrame(temp);

      // 3: patternType
      DatabaseColumnText(stmt, 3, temp);
      patternType = StringToPatternType(temp);

      // 4: eventReason
      DatabaseColumnText(stmt, 4, temp);
      eventReason = StringToEventReason(temp);

      // 5: patternDirection
      DatabaseColumnText(stmt, 5, temp);
      patternDirection = StringToDirection(temp);

      // 6: eventDirection
      DatabaseColumnText(stmt, 6, temp);
      eventDirection = StringToDirection(temp);

      // 7: eventTime
      DatabaseColumnInteger(stmt, 7, intVal);
      eventTime = (datetime)intVal;

      // 8: eventPrice
      DatabaseColumnDouble(stmt, 8, eventPrice);

      // 9: isEntryEvent
      DatabaseColumnInteger(stmt, 9, intVal);
      isEntryEvent = (intVal != 0);
     }
  };
// ####################################################################
// ### V A R I A N T   ################################################
// ####################################################################
struct structVariant
  {
   int               variantId;
   OrderType         orderType;
   bool              against;            // finalOrderDirection = against ? invert(eventDirection) : eventDirection
   bool              twoUnitMode;
   double            delta;              // Zugabe auf eventPrice zum Order-Limit-Preis
   double            slPoints;
   double            tpPoints;
   double            trailingDist;
   int               abortBars;          // Bars bis Waiting/Trailing abgebrochen wird; 0 = kein Abort

   void              Init()
     {
      variantId         = -1;
      orderType         = LIMIT;
      against           = false;
      twoUnitMode       = false;
      delta             = 0.0;
      slPoints          = 0.0;
      tpPoints          = 0.0;
      trailingDist      = 0.0;
      abortBars         = 0;
     }

   string            CreateSQL() const
     {
      return
         "CREATE TABLE variants ("
         " variantId INTEGER PRIMARY KEY,"
         " orderType TEXT,"
         " against INTEGER,"
         " twoUnitMode INTEGER,"
         " delta REAL,"
         " slPoints REAL,"
         " tpPoints REAL,"
         " trailingDist REAL,"
         " abortBars INTEGER"
         ");";
     }

   string            ToSQL() const
     {
      return StringFormat(
                "INSERT INTO variants ("
                "variantId, orderType, against, twoUnitMode, delta, "
                "slPoints, tpPoints, trailingDist, abortBars"
                ") VALUES ("
                "%d, '%s', %d, %d, %.5f, "
                "%.5f, %.5f, %.5f, %d"
                ");",

                variantId,
                EnumToString(orderType),
                (int)against,
                (int)twoUnitMode,
                delta,

                slPoints,
                tpPoints,
                trailingDist,
                abortBars
             );
     }

   bool              FromSQL(const int stmt)
     {
      int col = 0;
      string temp;
      int intVal;

      DatabaseColumnInteger(stmt, col++, variantId);

      DatabaseColumnText(stmt, col++, temp);
      orderType = StringToOrderType(temp);

      DatabaseColumnInteger(stmt, col++, intVal);
      against = (intVal != 0);

      DatabaseColumnInteger(stmt, col++, intVal);
      twoUnitMode = (intVal != 0);

      DatabaseColumnDouble(stmt, col++, delta);
      DatabaseColumnDouble(stmt, col++, slPoints);
      DatabaseColumnDouble(stmt, col++, tpPoints);
      DatabaseColumnDouble(stmt, col++, trailingDist);
      DatabaseColumnInteger(stmt, col++, abortBars);

      return true;
     }
  };
// ####################################################################
// ### T r a d e     ##################################################
// ####################################################################
struct structTrade
  {
   int               tradeId;
   int               variantId;
   int               eventId;

   Direction         direction;

   double            entryPrice;
   datetime          createTime;
   int               createBarIndex;

   TradeStatus       status;

   //---------------- waiting or trailing Order Abort -----------
   int               barsHeldUntilAbort;

   //---------------- fill -----------
   double            fillPrice;
   datetime          fillTime;
   int               fillBarIndex;
   int               barsWaitedForFill;

   double            initialSLPrice;   // fillPrice - slPoints
   double            initialTPPrice;   // fillPrice + tpPoints

   //---------------- trade life -----------
   double            currentSLPrice;   // maintaned by position management
   double            currentTPPrice;   // maintaned by position management

   double            mae;  // Maximum Adverse Excursion - from FILL until EXIT
   datetime          maeTime;
   int               maeBarIndex;

   double            mfe;  // Maximum Favorable Excursion  - from FILL until Hit-SL or Session-End
   datetime          mfeTime;
   int               mfeBarIndex;

   // --- Two Unit -----------------------------------------
   bool              twoUnitExited;
   double            twoUnitExitPrice;
   datetime          twoUnitExitTime;
   int               twoUnitExitBarIndex;
   ExitReason        twoUnitExitReason;
   double            twoUnitProfit;

   // --- EXIT  -----------------------------------------
   double            exitPrice;
   datetime          exitTime;
   int               exitBarIndex;
   int               barsHeldUntilExit;
   ExitReason        exitReason;    //
   double            profit;

// intern  array only - not in SQLite.db
   OrderType         orderType;
   bool              twoUnitMode;
   double            slPoints;   // DISTANZ
   double            tpPoints;   // DISTANZ
   double            trailingDist;
   bool              mfeActive;
   bool              twoUnitFilled;   // TP1 wurde erreicht (Auswertung in Out_Setzen)
   int               abortBars;       // 0 = kein Abort; siehe structVariant.abortBars

   void              Init()
     {
      tradeId              = -1;
      variantId            = -1;
      eventId              = -1;

      direction            = FLAT;

      entryPrice           = 0.0;
      createTime           = 0;
      createBarIndex       = -1;

      status               = TRADE_WAITING;

      barsHeldUntilAbort   = 0;

      fillPrice            = 0.0;
      fillTime             = 0;
      fillBarIndex         = -1;
      barsWaitedForFill    = 0;

      initialSLPrice       = 0.0;
      initialTPPrice       = 0.0;

      currentSLPrice       = 0.0;
      currentTPPrice       = 0.0;

      mae                  = 0.0;
      maeTime              = 0;
      maeBarIndex          = -1;

      mfe                  = 0.0;
      mfeTime              = 0;
      mfeBarIndex          = -1;

      twoUnitExited        = false;
      twoUnitExitPrice     = 0.0;
      twoUnitExitTime      = 0;
      twoUnitExitBarIndex  = -1;
      twoUnitExitReason    = EXIT_NONE;
      twoUnitProfit        = 0.0;

      orderType            = LIMIT;
      twoUnitMode          = false;

      exitPrice            = 0.0;
      exitTime             = 0;
      exitBarIndex         = -1;
      barsHeldUntilExit    = 0;
      exitReason           = EXIT_NONE;
      profit               = 0.0;

      slPoints             = 0.0;
      tpPoints             = 0.0;
      trailingDist         = 0.0;
      mfeActive            = false;
      twoUnitFilled        = false;
      abortBars            = 0;
     }
   string            CreateSQL() const
     {
      return
         "CREATE TABLE trades ("
         " tradeId INTEGER PRIMARY KEY AUTOINCREMENT,"
         " variantId INTEGER NOT NULL,"
         " eventId INTEGER NOT NULL,"

         " direction TEXT,"

         " entryPrice REAL,"
         " createTime INTEGER,"
         " createBarIndex INTEGER,"

         " status TEXT,"
         " barsHeldUntilAbort INTEGER,"

         " fillPrice REAL,"
         " fillTime INTEGER,"
         " fillBarIndex INTEGER,"
         " barsWaitedForFill INTEGER,"

         " initialSLPrice REAL,"
         " initialTPPrice REAL,"

         " currentSLPrice REAL,"
         " currentTPPrice REAL,"

         " mae REAL,"
         " maeTime INTEGER,"
         " maeBarIndex INTEGER,"

         " mfe REAL,"
         " mfeTime INTEGER,"
         " mfeBarIndex INTEGER,"

         " twoUnitExited INTEGER,"
         " twoUnitExitPrice REAL,"
         " twoUnitExitTime INTEGER,"
         " twoUnitExitBarIndex INTEGER,"
         " twoUnitExitReason TEXT,"
         " twoUnitProfit REAL,"

         " orderType TEXT,"
         " twoUnitMode INTEGER,"

         " exitPrice REAL,"
         " exitTime INTEGER,"
         " exitBarIndex INTEGER,"
         " barsHeldUntilExit INTEGER,"
         " exitReason TEXT,"
         " profit REAL,"

         " FOREIGN KEY(eventId) REFERENCES events(eventId),"
         " FOREIGN KEY(variantId) REFERENCES variants(variantId)"
         ");";
     }
   string            ToSQL() const
     {
      return StringFormat(
                "INSERT INTO trades ("
                "variantId, eventId, "
                "direction, "
                "entryPrice, createTime, createBarIndex, "
                "status, barsHeldUntilAbort, "
                "fillPrice, fillTime, fillBarIndex, barsWaitedForFill, "
                "initialSLPrice, initialTPPrice, "
                "currentSLPrice, currentTPPrice, "
                "mae, maeTime, maeBarIndex, "
                "mfe, mfeTime, mfeBarIndex, "
                "twoUnitExited, twoUnitExitPrice, twoUnitExitTime, twoUnitExitBarIndex, twoUnitExitReason, twoUnitProfit, "
                "orderType, twoUnitMode, "
                "exitPrice, exitTime, exitBarIndex, barsHeldUntilExit, exitReason, profit"
                ") VALUES ("
                "%d, %d, "
                "'%s', "
                "%.5f, %I64d, %d, "
                "'%s', %d, "
                "%.5f, %I64d, %d, %d, "
                "%.5f, %.5f, "
                "%.5f, %.5f, "
                "%.5f, %I64d, %d, "
                "%.5f, %I64d, %d, "
                "%d, %.5f, %I64d, %d, '%s', %.5f, "
                "'%s', %d, "
                "%.5f, %I64d, %d, %d, '%s', %.5f"
                ");",

                variantId,
                eventId,

                EnumToString(direction),

                entryPrice,
                (long)createTime,
                createBarIndex,

                EnumToString(status),
                barsHeldUntilAbort,

                fillPrice,
                (long)fillTime,
                fillBarIndex,
                barsWaitedForFill,

                initialSLPrice,
                initialTPPrice,

                currentSLPrice,
                currentTPPrice,

                mae,
                (long)maeTime,
                maeBarIndex,

                mfe,
                (long)mfeTime,
                mfeBarIndex,

                (int)twoUnitExited,
                twoUnitExitPrice,
                (long)twoUnitExitTime,
                twoUnitExitBarIndex,
                EnumToString(twoUnitExitReason),
                twoUnitProfit,

                EnumToString(orderType),
                (int)twoUnitMode,

                exitPrice,
                (long)exitTime,
                exitBarIndex,
                barsHeldUntilExit,
                EnumToString(exitReason),
                profit
             );
     }
   bool              FromSQL(const int stmt)
     {
      int col = 0;
      int intVal;
      string temp;

      DatabaseColumnInteger(stmt, col++, tradeId);
      DatabaseColumnInteger(stmt, col++, variantId);
      DatabaseColumnInteger(stmt, col++, eventId);

      DatabaseColumnText(stmt, col++, temp);
      direction = StringToDirection(temp);

      DatabaseColumnDouble(stmt, col++, entryPrice);

      DatabaseColumnInteger(stmt, col++, intVal);
      createTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, col++, createBarIndex);

      DatabaseColumnText(stmt, col++, temp);
      status = StringToTradeStatus(temp);

      DatabaseColumnInteger(stmt, col++, barsHeldUntilAbort);

      DatabaseColumnDouble(stmt, col++, fillPrice);

      DatabaseColumnInteger(stmt, col++, intVal);
      fillTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, col++, fillBarIndex);
      DatabaseColumnInteger(stmt, col++, barsWaitedForFill);

      DatabaseColumnDouble(stmt, col++, initialSLPrice);
      DatabaseColumnDouble(stmt, col++, initialTPPrice);

      DatabaseColumnDouble(stmt, col++, currentSLPrice);
      DatabaseColumnDouble(stmt, col++, currentTPPrice);

      DatabaseColumnDouble(stmt, col++, mae);

      DatabaseColumnInteger(stmt, col++, intVal);
      maeTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, col++, maeBarIndex);

      DatabaseColumnDouble(stmt, col++, mfe);

      DatabaseColumnInteger(stmt, col++, intVal);
      mfeTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, col++, mfeBarIndex);

      DatabaseColumnInteger(stmt, col++, intVal);
      twoUnitExited = (intVal != 0);

      DatabaseColumnDouble(stmt, col++, twoUnitExitPrice);

      DatabaseColumnInteger(stmt, col++, intVal);
      twoUnitExitTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, col++, twoUnitExitBarIndex);

      DatabaseColumnText(stmt, col++, temp);
      twoUnitExitReason = StringToExitReason(temp);

      DatabaseColumnDouble(stmt, col++, twoUnitProfit);

      DatabaseColumnText(stmt, col++, temp);
      orderType = StringToOrderType(temp);

      DatabaseColumnInteger(stmt, col++, intVal);
      twoUnitMode = (intVal != 0);

      DatabaseColumnDouble(stmt, col++, exitPrice);

      DatabaseColumnInteger(stmt, col++, intVal);
      exitTime = (datetime)intVal;

      DatabaseColumnInteger(stmt, col++, exitBarIndex);

      DatabaseColumnInteger(stmt, col++, barsHeldUntilExit);

      DatabaseColumnText(stmt, col++, temp);
      exitReason = StringToExitReason(temp);

      DatabaseColumnDouble(stmt, col++, profit);

      return true;
     }
  };
// ####################################################################
// ### T r e n d     ##################################################
// ####################################################################
struct structTrend
  {
   datetime          time;        // Zeitpunkt des Trendwechsels
   string            trendName;   // M3T, M3P, H1T, H1P, H1H
   int               trend;       // -1 short, 0 flat, +1 long

   void              Init()
     {
      time      = 0;
      trendName = "";
      trend     = 0;
     }

   string            ToSQL() const
     {
      return StringFormat(
                "INSERT INTO trends (time, trendName, trend) "
                "VALUES (%I64d, '%s', %d);",
                time,
                trendName,
                trend
             );
     }

   bool              FromSQL(const int stmt)
     {
      int intVal = 0;

      DatabaseColumnInteger(stmt, 0, intVal);
      time = (datetime)intVal;
      DatabaseColumnText(stmt,  1,trendName);
      DatabaseColumnInteger(stmt, 2, trend);

      return true;
     }

   string            CreateSQL() const
     {
      return
         "CREATE TABLE trends ("
         "time       DATETIME NOT NULL,"
         "trendName  TEXT NOT NULL,"
         "trend      INTEGER NOT NULL"
         ");";
     }
  };

#endif

//+------------------------------------------------------------------+
