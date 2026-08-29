//+------------------------------------------------------------------+
//| CRenderQueue      Julei im Jahre des Herrn 2026                  |
//| ===============================================                  |
//+------------------------------------------------------------------+

#ifndef __RENDERQUEUE_MQH__
#define __RENDERQUEUE_MQH__

enum RenderState
  {
   RENDER_IDLE = 0,
   RENDER_CREATE = 1,
   RENDER_APPLY = 2
  };

struct RenderRequest
  {
   string            name;
   ENUM_OBJECT       type;

   datetime          time0;
   double            price0;
   datetime          time1;
   ENUM_LINE_STYLE   style;
   double            price1;

   color             clr;
   bool              fill;
   int               width;
   int               zorder;

   string            text;
   string            tooltip;

   string            font;
   int               fontsize;
   double            angle;
 /*  
   OBJPROP_ANCHOR akzeptiert ENUM_ANCHOR_POINT  
      ( ANCHOR_LEFT, ANCHOR_CENTER, ANCHOR_RIGHT_UPPER usw.)
   
   OBJPROP_ARROW_ANCHOR akzeptiert ENUM_ARROW_ANCHOR  
      (also ANCHOR_TOP, ANCHOR_BOTTOM)
*/    
 //  ENUM_ARROW_ANCHOR arrowAnchor; // ANCHOR_TOP  ANCHOR_BOTTOM
   
   ENUM_ANCHOR_POINT anchor; // ANCHOR_LEFT_UPPER; ANCHOR_LEFT; ANCHOR_LEFT_LOWER; ANCHOR_LOWER; ANCHOR_RIGHT_LOWER; ANCHOR_RIGHT; ANCHOR_RIGHT_UPPER;ANCHOR_UPPER; ANCHOR_CENTER
   
   bool              hidden ;
   bool              selectable ;

   int               phase;        // 0 = Create, 1 = Apply
   string            art;          // MgL, NTH, 3er usw

void Init()
{
   name        = "";
   type        = OBJ_HLINE;

   time0       = 0;
   price0      = 0.0;
   time1       = 0;
   price1      = 0.0;
   style       = STYLE_SOLID;

   clr         = clrNONE;
   fill        = false;
   width       = 1;
   zorder      = 0;

   text        = "";
   tooltip     = "";

   font        = "Arial";
   fontsize    = 10;
   angle       = 0.0;

   anchor      = ANCHOR_LEFT;

   hidden      = false;
   selectable  = true;

   phase       = 0;        // 0 = Create
   art         = "";
}

};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CRenderQueue
  {
private:
   RenderRequest     queue[30000];
   int               count;
   int               cursor;
   RenderState       loadState;

public:
                     CRenderQueue()
     {
      count     = 0;
      cursor    = 0;
      loadState = RENDER_IDLE;
     }

   void              Clear()
     {
      count     = 0;
      cursor    = 0;
      loadState = RENDER_IDLE;
     }
/*
   void              Beispiel()
     {
      RenderRequest r = {}; // alle Felder auf 0 / "" / false
      r.name = "name";
      r.type = OBJ_TREND;
      r.time0 = 0;
      r.price0 = 0;
      r.time1 = 0;
      r.style = STYLE_SOLID; // STYLE_DOT
      r.price1 =  0;
      r.clr = clrBlack;
      r.fill = true;
      r.width = 2;
      r.zorder = 50;
      r.text = "";
      r.tooltip = "";
      r.font = "ARIAL";
      r.fontsize = 14;
      r.angle = 0;
 s.o.
      
      r.hidden  = true;
      r.selectable  = true;
      r.phase = 1;  // nur ändern                                      |
      //RenderQueue.Add(r);
     };
     */
     
   //+------------------------------------------------------------------+
   void              Add(RenderRequest &r)
     {

      if(count >= ArraySize(queue))
        {Print("RenderQueue overflow!");return;}

      queue[count] = r;
      count++;

      loadState = RENDER_CREATE;
     }
private:
   //+------------------------------------------------------------------+
   int               CalculateBatch()
     {
      static int batch = 300;

      ulong t0 = GetMicrosecondCount();
      ChartRedraw();
      ulong dt = GetMicrosecondCount() - t0;

      if(dt < 500)
         batch = 1000;
      else
         if(dt < 1000)
            batch = 500;
         else
            if(dt < 2000)
               batch = 200;
            else
               batch = 100;

      return batch;
     }
   int               CalculateBatchNew()
     {
      ulong t0 = GetMicrosecondCount();
      ChartRedraw();
      ulong dt = GetMicrosecondCount() - t0;

      // Quadratische Interpolationsfunktion
      double batch = 0.00002 * dt * dt - 0.3 * dt + 500;

      // Begrenzen auf sinnvolle Werte
      if(batch < 20)
         batch = 20;
      if(batch > 1000)
         batch = 1000;
      string message =StringFormat("*** count = %d cursor = %d dt = %d ms also batch = %d",count,cursor,dt,batch);
      Print(message);
      ObjectSetString(0,"PeridoLabel",OBJPROP_TEXT,message);  //--- Textschrift setzen
      ChartRedraw();
      return (int)batch;
     }
   //+------------------------------------------------------------------+
   void              ProcessCreate()
     {
      Print("CREATE: " + IntegerToString(cursor) + ":" + IntegerToString(count));
      int batch = CalculateBatch();

      for(int i=0; i<batch && cursor<count; i++)
        {
         if(queue[cursor].phase == 0)
           {
            queue[cursor].phase = 1;

            ObjectCreate(0,
                         queue[cursor].name,
                         queue[cursor].type,
                         0,
                         queue[cursor].time0,
                         queue[cursor].price0,
                         queue[cursor].time1,
                         queue[cursor].price1);

            queue[cursor].time0  = 0;
            queue[cursor].price0 = 0;
            queue[cursor].time1  = 0;
            queue[cursor].price1 = 0;
           }

         cursor++;
        }

      if(cursor >= count)
        {
         cursor    = 0;
         loadState = RENDER_APPLY;
        }
     }
   //+------------------------------------------------------------------+
   void              ProcessApply()
     {
      Print("APPLY: " + IntegerToString(cursor) + ":" + IntegerToString(count));
      int batch = CalculateBatch();
      batch = 30000;

      for(int i=0; i<batch && cursor<count; i++)
        {
         if(queue[cursor].phase == 1)
           {
            if(queue[cursor].time0  != 0)
               ObjectSetInteger(0, queue[cursor].name, OBJPROP_TIME, 0, queue[cursor].time0);
            if(queue[cursor].price0 != 0)
               ObjectSetDouble(0, queue[cursor].name, OBJPROP_PRICE,0, queue[cursor].price0);
            if(queue[cursor].time1  != 0)
               ObjectSetInteger(0, queue[cursor].name, OBJPROP_TIME, 1, queue[cursor].time1);
            if(queue[cursor].price1 != 0)
               ObjectSetDouble(0, queue[cursor].name, OBJPROP_PRICE,1, queue[cursor].price1);
            // ------------------------------------------------------------------------------
            //            if(queue[cursor].clr  != 0)
            ObjectSetInteger(0, queue[cursor].name, OBJPROP_COLOR,  queue[cursor].clr);

            if(queue[cursor].width  != 0)
               ObjectSetInteger(0, queue[cursor].name, OBJPROP_WIDTH,  queue[cursor].width);

            if(queue[cursor].zorder != 0)
               ObjectSetInteger(0, queue[cursor].name, OBJPROP_ZORDER, queue[cursor].zorder);

            if(queue[cursor].text   != "")
               ObjectSetString(0, queue[cursor].name, OBJPROP_TEXT,   queue[cursor].text);
            if(queue[cursor].tooltip != "")
               ObjectSetString(0, queue[cursor].name, OBJPROP_TOOLTIP,   queue[cursor].tooltip);

            if(queue[cursor].font   != "")
               ObjectSetString(0, queue[cursor].name,OBJPROP_FONT,queue[cursor].font);
            if(queue[cursor].fontsize  != 0)
               ObjectSetInteger(0, queue[cursor].name,OBJPROP_FONTSIZE,queue[cursor].fontsize);
            if(queue[cursor].angle   != 0)
               ObjectSetDouble(0, queue[cursor].name,OBJPROP_ANGLE,queue[cursor].angle);

    //        if(queue[cursor].arrowAnchor != 0)
   //            ObjectSetInteger(0, queue[cursor].name,OBJPROP_ARROW_ANCHOR,queue[cursor].arrowAnchor);
               
            if(queue[cursor].anchor != 0)
               ObjectSetInteger(0, queue[cursor].name,OBJPROP_ANCHOR,queue[cursor].anchor);
         
         
  // OBJPROP_ANCHOR akzeptiert ENUM_ANCHOR_POINT  ( ANCHOR_LEFT, ANCHOR_CENTER, ANCHOR_RIGHT_UPPER usw.)
  // OBJPROP_ARROW_ANCHOR akzeptiert ENUM_ARROW_ANCHOR   (also ANCHOR_TOP, ANCHOR_BOTTOM)         
               

            if(queue[cursor].fill)
               ObjectSetInteger(0, queue[cursor].name,OBJPROP_FILL,queue[cursor].fill);

            //          if(queue[cursor].hidden)
            ObjectSetInteger(0, queue[cursor].name,OBJPROP_HIDDEN,queue[cursor].hidden);
            //          if(queue[cursor].selectable)
            ObjectSetInteger(0, queue[cursor].name,OBJPROP_SELECTABLE,queue[cursor].selectable);
           }
         queue[cursor].phase = 2;
         cursor++;
        }

      if(cursor >= count)
        {
         cursor    = 0;
         count     = 0;
         loadState = RENDER_IDLE;
        }
     }
public:
   //+------------------------------------------------------------------+
   void              Process()
     {
      if(loadState == RENDER_CREATE)
         ProcessCreate();
      else
         if(loadState == RENDER_APPLY)
            ProcessApply();
      if(count < 10 && loadState == RENDER_APPLY)
         ProcessApply();
     }
     
  }; // ende der Klasse

#endif
//+------------------------------------------------------------------+
