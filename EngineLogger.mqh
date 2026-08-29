//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLogger
  {
private:
   string filename ;

public:
                     CLogger()
     {

      if(Period() != PERIOD_M3)
         return;

      filename       = "_logger.csv";

      FileDelete(filename);
      int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI,';');

      if(handle == INVALID_HANDLE)
        {
         MessageBox("Cannot open log file - try again: ", filename,MB_ICONWARNING);
         FileDelete(filename);
         handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI,';');
         if(handle == INVALID_HANDLE)
           {
            MessageBox(" Cannot open log file! ", filename,MB_ICONWARNING);
            return;
           }
        }

      FileWrite(handle,
                "Time",
                "EntryName",
                "idx",
                "Type",
                "changeReason",
                "status",
                "activ",
                "time (ab/fill)",
                "time (bis/exit)",
                "level/fill",
                "sl",
                "pl",
                "nearby",
                "story");

      FileClose(handle);
     }
   void              Info(string text)
     {}
   // ---------------------------------------------------------
   // Logging für Trades
   // ---------------------------------------------------------
   void              Log(structPattern &p)
     {

      if(Period() != PERIOD_M3)
         return;

      if(p.core.timeFrame == PERIOD_M1)
         return;

      int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI,";");

      if(handle == INVALID_HANDLE)
        {Print("ERROR: Cannot open log file: ", filename);return;}

      FileSeek(handle, 0, SEEK_END);
/*
      FileWrite(handle,
                TimeCPU(),
                p.name,
                " ",                     // EntryName
                "PATTERN",                         // Type
                EnumToString(p.status),
                TimeToString(p.startTime, TIME_DATE|TIME_SECONDS),
                TimeToString(p.validUntil, TIME_DATE|TIME_SECONDS),
                DoubleToString(p.priceNominal, 0),
                DoubleToString(p.priceStart, 0),
                " ",
                " ",
                " "
               );
*/
      FileClose(handle);
     }
};
   //+------------------------------------------------------------------+

