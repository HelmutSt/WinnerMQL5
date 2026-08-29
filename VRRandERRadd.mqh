    bool              EventShouldCreateTrades(string eventType)
     {
      for(int i=0; i < variantRoutingCount; i++)
        {
         if(variantRoutingRule[i].eventType == eventType)
            return true;
        }
        return false;
     }
     // -------------------------------
 void VRR_Add(string val)
{
   // Mehrere Blanks zu einem Blank reduzieren
   while(StringFind(val, "  ") != -1)
      StringReplace(val, "  ", " ");   // ACHTUNG: kein val = ... !

   string parts[];
   int count = StringSplit(val, ' ', parts);

   // Minimaler Schutz – Format hat immer 10 Felder
   if(count < 10)
      return;

   structVariantRoutingRule r;
   r.Init();
   
   r.vrrId = nextVrrId++;
   // 1. EventType
   r.eventType = parts[0];

   // 2. OrderType
   r.orderType = StringToOrderType(parts[1]);
   
   // 3. against
   r.against = (parts[2] == "X"); 
   
   // 4. TwoUnitMode
   r.twoUnitMode = (parts[3] == "X");

   // 5. Delta
   ParseDoubleList(parts[4], r.deltaList, r.deltaCount);

   // 6. SL
   ParseDoubleList(parts[5], r.slList, r.slCount);

   // 7. TP
   ParseDoubleList(parts[6], r.tpList, r.tpCount);

   // 8. Trailing
   ParseDoubleList(parts[7], r.trailingList, r.trailingCount);

   // 9. AbortDist
   int dummyCount = 0;
   ParseDoubleList(parts[8], r.trailingAbortDistanceList, dummyCount);

   // 10. AbortBars ("-" bzw. leer => genau ein Eintrag = 0 = kein Abort)
   ParseIntList(parts[9], r.abortBarsList, r.abortBarsCount);
   if(r.abortBarsCount == 0)
     {
      r.abortBarsList[0] = 0;
      r.abortBarsCount   = 1;
     }

   // In Tabelle einfügen
   variantRoutingRule[variantRoutingCount++] = r;
}

 
 
void ParseDoubleList(string txt, double &arr[], int &cnt)
{
   cnt = 0;

   if(txt == "-" || txt == "")
      return;

   string vals[];
   int n = StringSplit(txt, ',', vals);

   for(int i = 0; i < n && i < 10; i++)
      arr[cnt++] = (double)StringToDouble(vals[i]);
}

void ParseIntList(string txt, int &arr[], int &cnt)
{
   cnt = 0;

   if(txt == "-" || txt == "")
      return;

   string vals[];
   int n = StringSplit(txt, ',', vals);

   for(int i = 0; i < n && i < 10; i++)
      arr[cnt++] = (int)StringToInteger(vals[i]);
}
 // ---------------------------------------------------------------------
 