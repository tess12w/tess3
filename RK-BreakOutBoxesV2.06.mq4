//+------------------------------------------------------------------+
//|                                             BreakOutBoxes.mq4    |
//|                                             Copyright © 2009 DA  |
//|                                                                  |
//| 4 June 2009 v1.1                                                 |
//|      Modified to cope with all three major sessions:             |
//|           Tokyo                                                  |
//|           Europe (called 'London')                               |
//|           USA                                                    |
//|      Modified to cope with 5-digit prices.                       |
//|      Modified to cope with Daylight Saving Time in UK and USA.   |
//|      Stop Loss selection re-instated.                            |
//|      Box width is now fixed:                                     |
//|          7 hours for London (00:00-07:00 BST)                    |
//|          2 hours for New York (11:00-13:00 BST)                  |
//|          5 hours for Tokyo (19:00-00:00 GMT)                     |
//|      These work for GMT data sources (IBFX, ODL, etc.).          |
//|                                                                  |
//| 5 June 2009  v1.2                                                |
//|      Modified to cope with all three major sessions:             |
//|                                                                  |
//| 6 June 2009 v1.21                                                |
//|      Selection of Digits made automatic                          |
//|      Selection of session other than 1, 2 or 3 protected         |
//|      1 fewer bars selected for calculation of box top & bottom   |
//|      Operation in timeframes above H1 inhibited                  |
//|                                                                  |
//| 7 June 2009 v1.22                                                |
//|      Added code for ADR - Average Daily Range (last 30 days)     |
//|                                                                  |
//| 8 June 2009 v1.23                                                |
//|      Fix for 5-digit code error                                  |
//|                                                                  |
//| 8 June 2009 v1.24                                                |
//|      Fix to get The Box to draw for next session before time     |
//|                                                                  |
//| 14 June 2009 v1.25                                               |
//|      New architecture copes with look-back.                      |
//|      Added switch for non-Black background colours.              |
//|                                                                  |
//| 15 June 2009 v1.26                                               |
//|      Asian session box no display on Sundays                     |
//|      Box begin/end vertical lines added                          |
//|                                                                  |
//| 15 June 2009 v1.27                                               |
//|      Fixed Box Range numeric error                               |
//|                                                                  |
//| 19 June 2009 v1.28                                               |
//|      Fixed GMT offset problem when box spans two days            |
//|      Added the broker's spread to all buy prices                 |
//|                                                                  |
//| 22 June 2009 v2.0                                                |
//|      Added alerts for Buy/Sell levels being reached during       |
//|      the active trading box.                                     |
//|                                                                  |
//| 23 June 2009 v2.01 & v2.02                                       |
//|      Architectural changes to try to avoid having to change      |
//|      timeframe to get ADR and Spread to calculate on open.       |
//|                                                                  |
//| 26 June 2009 v2.03                                               |
//|      Bug fix - Box Range data now collected from only the box    |
//|      for the current session (instead of the oldest one drawn    |
//|      if NumberOfDays is greater than 1)                          |
//|                                                                  |
//| 29 June 2009 v2.04                                               |
//|      Bug in Spread calculation on 5-digit data fixed             |
//|      Vertical line for London open added to iSession = 2         |
//|                                                                  |
//| 11 July 2009 v2.05                                               |
//|      Changed trading box width - added an hour                   |
//|      Added Stop Loss to items on display on the charts           |
//|                                                                  |
//| 18 July 2009 v2.06                                               |
//|      Added Auto_Stop_Loss facility                               |
//|                                                                  |
//|                                                                  |
//|  Grath (DA)                                                      |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, YourSource Ltd"
#property link      ""

#property indicator_separate_window

//+------------------------------------------------------------------+

extern int    Margin        = 0;
extern int    TP1           = 25;
extern int    TP2           = 50;
extern int    TP3           = 80;
extern int    SL            = 30;
extern bool   Auto_SL       = true;

extern string IIIIIIIIIII = "1=Asia 2=LON 3=NY";  
extern int  iSession      = 2;
extern int  GMT_Offset    = -5;
extern bool UK_DST        = false;      
extern bool US_DST        = false;      
extern int  NumberOfDays  = 10;         
extern int  iMaxNoOfDays  = 14; 

extern int SL_GU = 45;    
extern int SL_GJ = 50;    
extern int SL_EU = 35;    
extern int SL_EJ = 35;    
extern int SL_GBPCHF = 30;    
extern int SL_USDCHF = 30;    

extern bool   ChartHasBlkBgd   = true;
extern color  BoxColor         = LightGoldenrod;      
extern color  TradingBoxColor  = DarkSalmon; 

extern bool     Pop_Up_Box    = true;
extern double  Alert_Time_Out = 16;
extern string        IIIIIIII = "..if TP1 false, alert @ Buy/Sell levels.";
extern bool      Alert_On_TP1 = false;
extern bool      Alert_on     = false;

string   editor="Grath 2.06";
double   top, bottom;
string   sLeft, sBoxEnd, sBoxEndNew, temp, WindowName;
string   sFridayClose = "22:00", sTimeLondonOpen;
datetime dtRight, dtLeft, dtTempTime, dtTradingBoxEnd, dtFridayClose;
int      BoxLength, TradingBoxWidth, iSpread ;
bool     IsAllowed = true;
bool     twiddle = false;
bool     twiddle2 = false;

double bep, btp1, btp2, btp3, btp4, bsl;
double sep, stp1, stp2, stp3, stp4, ssl;
double drange, dLinePrice, dHeight, dSpread;
double AVG = 0;
string average;            // for ADR

double timecur=-1; //this is the time current for the pauses between movements
double timeloc=-1;
double timeloc2= -1;//this is a smaller lock out just for displaying the breach message


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void init()
   {
      if (NumberOfDays > iMaxNoOfDays) NumberOfDays = iMaxNoOfDays;
      switch(iSession)
      {
      case 1: 
         IndicatorShortName("Tokyo Box"); 
         WindowName = "Tokyo Box";
         sBoxEnd = "23:00";   
         BoxLength = 5;
         break;
      case 2: 
         IndicatorShortName("London Box"); 
         WindowName = "London Box";
         if (UK_DST)
         {
            sBoxEnd = "06:00";
            BoxLength = 6;
            sTimeLondonOpen = "07:00";
         }
         else 
         {
            sBoxEnd = "07:00";
            BoxLength = 7;
            sTimeLondonOpen = "08:00";
         }
         break;
      case 3: 
         IndicatorShortName("New York Box"); 
         WindowName = "New York Box";
         if (US_DST)
         {
            sBoxEnd = "12:00";
         }
         else 
         {
            sBoxEnd = "13:00";
         }
         BoxLength = 2;
         break;
      default:
         IsAllowed = false;  // We don't respond to wild inputs
      } //switch(iSession)
   
      switch (iSession)
      {
         case 1: TradingBoxWidth = 6; break;
         case 2: TradingBoxWidth = 4; break;    // was 3, but now trying 4
         case 3: TradingBoxWidth = 3; break;    // was 2, but now trying 3
      }

      // Take care of input parameters
      // Stop Loss first
      if (Auto_SL)
      {
         string sTemp = Symbol() ;
         if (sTemp == "GBPUSD") SL = SL_GU;
         if (sTemp == "EURUSD") SL = SL_EU;
         if (sTemp == "EURJPY") SL = SL_EJ;
         if (sTemp == "GBPJPY") SL = SL_GJ;
         if (sTemp == "GBPCHF") SL = SL_GBPCHF;
         if (sTemp == "USDCHF") SL = SL_USDCHF;

      }
      if (Digits == 5 || Digits == 3)
      {
         TP1 = TP1 * 10;
         TP2 = TP2 * 10;
         TP3 = TP3 * 10;
         SL  = SL * 10;
         Margin = Margin * 10;
      }

      //----Author
      ObjectCreate("Ydb", OBJ_LABEL, 0, 0, 0);
      if (ChartHasBlkBgd)
      {
         ObjectSetText("Ydb", editor, 8, "Gungsuh", DimGray);
      }
      else
      {
         ObjectSetText("Ydb", editor, 8, "Gungsuh", Blue);
      }
      ObjectSet("Ydb", OBJPROP_CORNER, 1);
      ObjectSet("Ydb", OBJPROP_XDISTANCE,  5);
      ObjectSet("Ydb", OBJPROP_YDISTANCE,  5);  
      
      //-----Average Daily Range
      getADR(ChartHasBlkBgd);
      
      //-----Broker's Spread
      iSpread = getSpread(ChartHasBlkBgd);

      //  Let's see at a glance which Box we're trading
      ObjectCreate ("WHICHBOX",OBJ_LABEL, 0,0,0);
      if (ChartHasBlkBgd)
      {
         ObjectSetText("WHICHBOX", WindowName, 10,"Arial Bold", DimGray);
      }
      else 
      {
         ObjectSetText("WHICHBOX", WindowName, 10,"Arial Bold", Blue);
      }
      ObjectSet("WHICHBOX", OBJPROP_CORNER, 0);
      ObjectSet("WHICHBOX", OBJPROP_XDISTANCE, 5);
      ObjectSet("WHICHBOX", OBJPROP_YDISTANCE, 280);
      
      // We need to know if Alerts are ON or OFF
      ObjectCreate ("ALERT_ONOFF",OBJ_LABEL, 0,0,0);
      if (Alert_on)
      {
         if (ChartHasBlkBgd)
         {
            ObjectSetText("ALERT_ONOFF", "Alerts ON", 10,"Arial Bold", DimGray);
         }
         else
         {
            ObjectSetText("ALERT_ONOFF", "Alerts ON", 10,"Arial Bold", Blue);
         }
      }
      else 
      {
         if (ChartHasBlkBgd)
         {
            ObjectSetText("ALERT_ONOFF", "Alerts OFF", 10,"Arial Bold", DimGray);
         }
         else
         {
            ObjectSetText("ALERT_ONOFF", "Alerts OFF", 10,"Arial Bold", Blue);
         }
      }
      ObjectSet("ALERT_ONOFF", OBJPROP_CORNER, 0);
      ObjectSet("ALERT_ONOFF", OBJPROP_XDISTANCE, 5);
      ObjectSet("ALERT_ONOFF", OBJPROP_YDISTANCE, 300);
      
      
      //----- and now a reminder of what the Margin is set at:
      ObjectCreate ("SHOW_MARGIN",OBJ_LABEL, 0,0,0);
      if (ChartHasBlkBgd)
      {
         ObjectSetText("SHOW_MARGIN", "Margin is: " + Margin, 10,"Arial Bold", DimGray);
      }
      else
      {
         ObjectSetText("SHOW_MARGIN", "Margin is: " + Margin, 10,"Arial Bold", Blue);
      }
      ObjectSet("SHOW_MARGIN", OBJPROP_CORNER, 0);
      ObjectSet("SHOW_MARGIN", OBJPROP_XDISTANCE, 5);
      ObjectSet("SHOW_MARGIN", OBJPROP_YDISTANCE, 320);
      
      
      //----- and finally a reminder of what the Stop Loss is set at:
      ObjectCreate ("SHOW_SL",OBJ_LABEL, 0,0,0);
      if (ChartHasBlkBgd)
      {
         ObjectSetText("SHOW_SL", "Stop Loss: " + SL, 10,"Arial Bold", DimGray);
      }
      else
      {
         ObjectSetText("SHOW_SL", "Stop Loss: " + SL, 10,"Arial Bold", Blue);
      }
      ObjectSet("SHOW_SL", OBJPROP_CORNER, 0);
      ObjectSet("SHOW_SL", OBJPROP_XDISTANCE, 5);
      ObjectSet("SHOW_SL", OBJPROP_YDISTANCE, 340);
      
   }  // init()

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void deinit() 
{
  DeleteObjects();
}   



//+------------------------------------------------------------------+
//| Remove all indicator Rectangles                                  |
//+------------------------------------------------------------------+
void DeleteObjects() 
{
   datetime dtTradeDate=TimeCurrent();

   for (int i=0; i<iMaxNoOfDays; i++) 
   {
      if ( TimeDayOfWeek(dtTradeDate) == 5 && dtTradingBoxEnd > dtFridayClose ) dtTradeDate = decrementTradeDate(dtTradeDate);     // Tokyo on Fridays!
 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBAT");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBATL");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBTP1");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBTP1L");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBTP2");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBTP2L");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBTP3");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineBTP3L");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSAT");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSATL");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSTP1");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSTP1L");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSTP2");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSTP2L");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSTP3");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " LineSTP3L");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " TheBox");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " TheBox2");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " TimevlActiveRight");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " TimevlLeft");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " TimevlRight");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " TimevlLondonOpen");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneBuyTP1");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneBuyTP2");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneBuyTP3");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneBuyZone");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneSellTP1");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneSellTP2");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneSellTP3");   // 
      ObjectDelete(TimeToStr(dtTradeDate,TIME_DATE) + " ZoneSellZone");   // 
    
      dtTradeDate=decrementTradeDate(dtTradeDate);
      while (TimeDayOfWeek(dtTradeDate) > 5 || TimeDayOfWeek(dtTradeDate) < 1 ) dtTradeDate = decrementTradeDate(dtTradeDate);     // Removed Sundays from plots
   }
   ObjectsDeleteAll(0,OBJ_TEXT);
   ObjectDelete("B1");
   ObjectDelete("B11");
   ObjectDelete("B12");
   ObjectDelete("B13");
   ObjectDelete("B14");
   ObjectDelete("B15");
   ObjectDelete("B16");
   ObjectDelete("B17");
   ObjectDelete("B18");
   ObjectDelete("B19");
   ObjectDelete("B2");
   ObjectDelete("B20");
   ObjectDelete("B210");
   ObjectDelete("B3");
   ObjectDelete("B4");
   ObjectDelete("B5");
   ObjectDelete("B6");
   ObjectDelete("B7");
   ObjectDelete("B8");
   ObjectDelete("ADR");
   ObjectDelete("SPREAD");
   ObjectDelete("Ydb");
   ObjectDelete("sBoxRange");
   ObjectDelete("sPricelabel");
   ObjectDelete("sPrice");
   ObjectDelete("WHICHBOX");
   ObjectDelete("ALERT_ONOFF");
   ObjectDelete("SHOW_MARGIN");
   
   //Comment("");  
        
}  // DeleteObjects()


//+------------------------------------------------------------------+
//| Calculate 30-day average daily range for the price pair          |
//+------------------------------------------------------------------+
void getADR(bool ChartHasBlkBgd)
{
      //------ Average Daily Range
      AVG = (iHigh(NULL,PERIOD_D1,30)-iLow(NULL,PERIOD_D1,30));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,29)-iLow(NULL,PERIOD_D1,29));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,28)-iLow(NULL,PERIOD_D1,28));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,27)-iLow(NULL,PERIOD_D1,27));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,26)-iLow(NULL,PERIOD_D1,26));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,25)-iLow(NULL,PERIOD_D1,25));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,24)-iLow(NULL,PERIOD_D1,24));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,23)-iLow(NULL,PERIOD_D1,23));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,22)-iLow(NULL,PERIOD_D1,22));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,21)-iLow(NULL,PERIOD_D1,21));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,20)-iLow(NULL,PERIOD_D1,20));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,19)-iLow(NULL,PERIOD_D1,19));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,18)-iLow(NULL,PERIOD_D1,18));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,17)-iLow(NULL,PERIOD_D1,17));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,16)-iLow(NULL,PERIOD_D1,16));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,15)-iLow(NULL,PERIOD_D1,15));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,14)-iLow(NULL,PERIOD_D1,14));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,13)-iLow(NULL,PERIOD_D1,13));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,12)-iLow(NULL,PERIOD_D1,12));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,11)-iLow(NULL,PERIOD_D1,11));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,10)-iLow(NULL,PERIOD_D1,10));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,9)-iLow(NULL,PERIOD_D1,9));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,8)-iLow(NULL,PERIOD_D1,8));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,7)-iLow(NULL,PERIOD_D1,7));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,6)-iLow(NULL,PERIOD_D1,6));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,5)-iLow(NULL,PERIOD_D1,5));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,4)-iLow(NULL,PERIOD_D1,4));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,3)-iLow(NULL,PERIOD_D1,3));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,2)-iLow(NULL,PERIOD_D1,2));
      AVG = AVG + (iHigh(NULL,PERIOD_D1,1)-iLow(NULL,PERIOD_D1,1));
      AVG = AVG/30;
      switch(Digits)
      {
         case 5: AVG = AVG*10000;  break;   // Deal with the extra one
         case 4: AVG = AVG*10000;  break;
         case 3: AVG = AVG*100;  break;    // Deal with the extra one
         case 2: AVG = AVG*100;  break;
      }
      ObjectCreate ("ADR",OBJ_LABEL, 0,0,0);
      if (ChartHasBlkBgd)
      {
         ObjectSetText("ADR", "ADR: "+ DoubleToStr(AVG,0) + " pips.", 9,"Georgia", Aqua);
      }
      else 
      {
         ObjectSetText("ADR", "ADR: "+ DoubleToStr(AVG,0) + " pips.", 9,"Georgia", Blue);
      }
      ObjectSet("ADR", OBJPROP_CORNER, 1);
      ObjectSet("ADR", OBJPROP_XDISTANCE, 80);
      ObjectSet("ADR", OBJPROP_YDISTANCE, 0);
}      


//+------------------------------------------------------------------+
//| Calculate the broker's spread for the price pair                 |
//+------------------------------------------------------------------+
int getSpread(bool ChartHasBlkBgd)
{
      //  What's the spread on this pair?
      //  -------------------------------
      
      iSpread=MarketInfo(Symbol(),MODE_SPREAD);
      if (Digits==5 || Digits==3)
      {
         iSpread = iSpread/10;
      }
      
      ObjectCreate ("SPREAD",OBJ_LABEL, 0,0,0);
      if (ChartHasBlkBgd)
      {
         ObjectSetText("SPREAD", "Spread: "+ iSpread + " pips.", 9,"Georgia", DimGray);
      }
      else 
      {
         ObjectSetText("SPREAD", "Spread: "+ iSpread + " pips.", 9,"Georgia", Blue);
      }
      ObjectSet("SPREAD", OBJPROP_CORNER, 1);
      ObjectSet("SPREAD", OBJPROP_XDISTANCE, 5);
      ObjectSet("SPREAD", OBJPROP_YDISTANCE, 60);
      
      return(iSpread);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void start()
{
   if (Period() < 61)
   {
      if (IsAllowed) 
      {
         int counted_bars=IndicatorCounted();
         
         //getADR(ChartHasBlkBgd);
         //iSpread = getSpread(ChartHasBlkBgd);
         
         datetime dtTradeDate=TimeCurrent();  //Sets up date/time of last bar displayed
         
         // Create the box times 
         //---------------------
         // Change sBoxEnd according to GMT_Offset
         dtTempTime = StrToTime(TimeToStr(D'1970.01.01 ',TIME_DATE ) + " " + sBoxEnd);
         dtTempTime = dtTempTime + (3600 * GMT_Offset);
         sBoxEndNew = TimeToStr(dtTempTime, TIME_MINUTES);
         dtRight = StrToTime (TimeToStr (dtTradeDate, TIME_DATE) + " " + sBoxEndNew);  
         
         sLeft = TimeToStr( dtRight - D'1970.01.01 1'* BoxLength, TIME_MINUTES );
         dtLeft  = StrToTime (TimeToStr (dtTradeDate, TIME_DATE) + " " + sLeft);  
         
         string periodB_end   = TimeToStr( dtRight + D'1970.01.01 1'* TradingBoxWidth, TIME_MINUTES );
         dtTradingBoxEnd = StrToTime (TimeToStr (dtTradeDate, TIME_DATE) + " " + periodB_end);  
         
         dtTempTime = StrToTime(TimeToStr(D'1970.01.01 ',TIME_DATE ) + " " + sFridayClose);
         dtTempTime = dtTempTime + (3600 * GMT_Offset);
         sFridayClose = TimeToStr(dtTempTime, TIME_MINUTES);
         dtFridayClose = StrToTime(TimeToStr(dtTradeDate,TIME_DATE ) + " " + sFridayClose);
         
         if (dtLeft > dtRight) twiddle = true; // to set DateFix in the for loop
         if (dtRight > dtTradingBoxEnd) twiddle2 = true; // to set DateFix in the for loop
         if (twiddle2) dtFridayClose = dtFridayClose - 86400;


         // --------  This is where we start drawing boxes and lines  -----------------//
      
         for (int i=0; i<NumberOfDays; i++) 
         {
            if ( TimeDayOfWeek(dtTradeDate) == 5 && dtTradingBoxEnd > dtFridayClose ) dtTradeDate = decrementTradeDate(dtTradeDate);     // Tokyo on Fridays!
            DrawObjects(dtTradeDate, TimeToStr(dtTradeDate,TIME_DATE) + " TheBox", sLeft, sBoxEndNew, periodB_end, ChartHasBlkBgd, BoxColor, TradingBoxColor, Margin, iSession, GMT_Offset, iSpread, twiddle, twiddle2, i, Alert_on, Pop_Up_Box, Alert_Time_Out, 1);  // draws The Box 
            DrawObjects(dtTradeDate, WindowName, sLeft, sBoxEndNew, periodB_end, ChartHasBlkBgd,DimGray, DimGray, Margin, iSession, GMT_Offset, iSpread, twiddle, twiddle2, i, Alert_on, Pop_Up_Box, Alert_Time_Out, 5);  // Draw the separate window 
            DrawObjects(dtTradeDate, TimeToStr(dtTradeDate,TIME_DATE) + " Line", sLeft, sBoxEndNew, periodB_end, ChartHasBlkBgd, DimGray, DimGray, Margin, iSession, GMT_Offset, iSpread, twiddle, twiddle2, i, Alert_on, Pop_Up_Box, Alert_Time_Out, 2);
            DrawObjects(dtTradeDate, TimeToStr(dtTradeDate,TIME_DATE) + " Time", sLeft, sBoxEndNew, periodB_end, ChartHasBlkBgd, DimGray, DimGray, Margin, iSession, GMT_Offset, iSpread, twiddle, twiddle2, i, Alert_on, Pop_Up_Box, Alert_Time_Out, 6);  // vertical lines
            DrawObjects(dtTradeDate, TimeToStr(dtTradeDate,TIME_DATE) + " Zone", sLeft, sBoxEndNew, periodB_end, ChartHasBlkBgd, DimGray, DimGray, Margin, iSession, GMT_Offset, iSpread, twiddle, twiddle2, i, Alert_on, Pop_Up_Box, Alert_Time_Out, 4);  // Draw buy and sell zones
    
            dtTradeDate=decrementTradeDate(dtTradeDate);
            while (TimeDayOfWeek(dtTradeDate) > 5 || TimeDayOfWeek(dtTradeDate) < 1 ) dtTradeDate = decrementTradeDate(dtTradeDate);     // Remove Sat/Sun from plots
         }  //for
      }  //if IsAllowed
      else
      {
         Print("iSession can only be 1, 2 or 3!");
      }
   }   //if Period() < 61
   else
   {
      Print("Period over H1 not supported!");
   }
}    //start()



   
//+------------------------------------------------------------------+
//| Create Objects - Rectangles and Trend lines                      |
//+------------------------------------------------------------------+

void DrawObjects(datetime dtTradeDate, string sObjName, string sTimeBegin, string sTimeEnd, string sTimeTradeEnd, bool BlkBgd, color cObjColor1, color cObjColor2, int iMargin, int Session, int iGMT_Offset, int iSpread, bool DateFix, bool DateFix2, int iCtr, bool Alert_on, bool Pop_Up_Box, double Time_Out, int iForm) 
{ 
   datetime dtTimeBegin, dtTimeEnd, dtTimeObjEnd, dtLineEnd, dtTimeLondonOpen;
   double   dPriceHigh,  dPriceLow, dPriceOpen, dPriceClose, dPriceMid;
   int      iBarBegin,   iBarEnd;
   string   sObjDesc;


   dtTimeBegin = StrToTime(TimeToStr(dtTradeDate, TIME_DATE) + " " + sTimeBegin);
   dtTimeEnd = StrToTime(TimeToStr(dtTradeDate, TIME_DATE) + " " + sTimeEnd);
   if (DateFix) dtTimeBegin = dtTimeBegin - 86400;
   dtTimeObjEnd = StrToTime(TimeToStr(dtTradeDate, TIME_DATE) + " " + sTimeTradeEnd);
   if (DateFix2) dtTimeObjEnd = dtTimeObjEnd + 86400;
   
   dtLineEnd = StrToTime(TimeToStr ( dtTimeEnd + D'1970.01.01 1'* 3 ));   // for the price trendlines
   dtTimeLondonOpen = StrToTime(TimeToStr(dtTradeDate, TIME_DATE) + " " + sTimeLondonOpen);
   
      iBarBegin = iBarShift(NULL, 0, dtTimeBegin) + 1;  
      iBarEnd = iBarShift(NULL, 0, dtTimeEnd) + 1;  
  
      dPriceHigh  = High[Highest(NULL, 0, MODE_HIGH, (iBarBegin)-iBarEnd, iBarEnd)];
      dPriceLow   = Low [Lowest (NULL, 0, MODE_LOW , (iBarBegin)-iBarEnd, iBarEnd)];
   
      top    = dPriceHigh;
      bottom = dPriceLow;
      
      bep  = top+(iMargin * Point);
      btp1 = bep+(TP1*Point);
      btp2 = bep+(TP2*Point); 
      btp3 = bep+(TP3*Point);
      if (Digits==5 || Digits==3)
      {
         btp4 = btp3+(200*Point);
      }
      else
      {
         btp4 = btp3+(20*Point);
      }
      bsl  = bep-(SL*Point); 
  
      sep  = bottom-(iMargin*Point);
      stp1 = sep-(TP1*Point);
      stp2 = sep-(TP2*Point); 
      stp3 = sep-(TP3*Point);
      if (Digits==5 || Digits==3)
      {
         stp4 = stp3-(200*Point);
      }
      else
      {
         stp4 = stp3-(20*Point);
      }
      ssl  = sep+(SL*Point); 

   if (iCtr == 0)
   {
      drange = (top-bottom)/Point;
      switch (Digits)
      {
       case 5: drange = drange/10; dSpread = iSpread*Point*10; break; 
       case 4: drange = drange;    dSpread = iSpread*Point; break;
       case 3: drange = drange/10; dSpread = iSpread*Point*10; break;
       case 2: drange = drange;    dSpread = iSpread*Point; break;
      }
   }
  
//------------------------------------------------------------------------------------------------------+
//   Alerts - From Chin Breakout Alert                                                                           |
//------------------------------------------------------------------------------------------------------+
   
   if (Alert_On_TP1)
   {
   if (Close[0] >= btp1  &&  TimeCurrent() > timeloc  && Alert_on == true  && iCtr == 0 && TimeCurrent() >= dtTimeEnd &&  TimeCurrent() <= dtTimeObjEnd)
     {
      timeloc2=TimeCurrent()+4.5; //this is a smaller lock out just for displaying the breech message           
      timeloc= TimeCurrent();  //done just for a slight pause
      if (Pop_Up_Box==False)
        {
         PlaySound("Alert2.wav");
         for(double asdfff =1;asdfff <1900.0239 ;) asdfff+=.91231; //a little pause
         while(TimeCurrent()<=timeloc) asdfff=0; //another little pause
         PlaySound("Alert.wav");
        }
      else {Alert("Breakout North ", Symbol()," ",DoubleToStr(bep, Digits));}
      timeloc=TimeCurrent()+Time_Out;   //how many seconds do we lock out the Alert
     }
   if (Close[0] <= stp1  &&  TimeCurrent() > timeloc  && Alert_on ==true && iCtr == 0 && TimeCurrent() >= dtTimeEnd &&  TimeCurrent() <= dtTimeObjEnd)
     {
      timeloc2=TimeCurrent()+4.5;//this is a smaller lock out just for displaying the breech message
      timeloc =TimeCurrent();   //just for a slight, unofficial pause
      if (Pop_Up_Box==False)
        {
         PlaySound("Alert.wav");
         for(double asdf =1;asdf <1200.0239 ;) asdf+=.91231; //a little pause
         while(TimeCurrent()<=timeloc) asdf=0; //another little pause
         PlaySound("Alert2.wav");
        }
      else {Alert("Breakout South ",Symbol()," ",DoubleToStr(sep, Digits));}
      timeloc=TimeCurrent()+Time_Out;   //how many seconds do we lock out the Alert
     }
   }
   else
   {
   if (Close[0] >= bep  &&  TimeCurrent() > timeloc  && Alert_on == true  && iCtr == 0 && TimeCurrent() >= dtTimeEnd &&  TimeCurrent() <= dtTimeObjEnd)
     {
      timeloc2=TimeCurrent()+4.5; //this is a smaller lock out just for displaying the breech message           
      timeloc= TimeCurrent();  //done just for a slight pause
      if (Pop_Up_Box==False)
        {
         PlaySound("Alert2.wav");
         for(double lasdfff =1;lasdfff <1900.0239 ;) lasdfff+=.91231; //a little pause
         while(TimeCurrent()<=timeloc) lasdfff=0; //another little pause
         PlaySound("Alert.wav");
        }
      else {Alert("Breakout North ", Symbol()," ",DoubleToStr(bep, Digits));}
      timeloc=TimeCurrent()+Time_Out;   //how many seconds do we lock out the Alert
     }
   if (Close[0] <= sep  &&  TimeCurrent() > timeloc  && Alert_on ==true && iCtr == 0 && TimeCurrent() >= dtTimeEnd &&  TimeCurrent() <= dtTimeObjEnd)
     {
      timeloc2=TimeCurrent()+4.5;//this is a smaller lock out just for displaying the breech message
      timeloc =TimeCurrent();   //just for a slight, unofficial pause
      if (Pop_Up_Box==False)
        {
         PlaySound("Alert.wav");
         for(double lasdf =1;lasdf <1200.0239 ;) lasdf+=.91231; //a little pause
         while(TimeCurrent()<=timeloc) lasdf=0; //another little pause
         PlaySound("Alert2.wav");
        }
      else {Alert("Breakout South ",Symbol()," ",DoubleToStr(sep, Digits));}
      timeloc=TimeCurrent()+Time_Out;   //how many seconds do we lock out the Alert
     }
   }
   
   
//------------------------------------------------------------------------------------------------------

   

   //---- Rectangles - The Box and the Trading Box
   if(iForm==1)
   {
      //Comment("\nCounter: ", iCtr);
      //Comment("\nTime begin: ", TimeToStr(dtTimeBegin, 1), "  ", TimeToStr(dtTimeBegin, 2), "\nTime end: ",
      // TimeToStr(dtTimeEnd, 1), "  ", TimeToStr(dtTimeEnd, 2), "\nTime 2nd end: ", TimeToStr(dtTimeObjEnd, 1),
      // "  ", TimeToStr(dtTimeObjEnd, 2), "\nTop: ", DoubleToStr(dPriceHigh,5), "\nBottom: ", DoubleToStr(dPriceLow,5),
      // "\nsTimeBegin: ", sTimeBegin , "\nsTimeEnd: ", sTimeEnd, "\nsTimeTradeEnd: ", sTimeTradeEnd ) ;  

      ObjectCreate(sObjName, OBJ_RECTANGLE, 0, 0, 0, 0);
      ObjectSet(sObjName, OBJPROP_TIME1 , dtTimeBegin);
      ObjectSet(sObjName, OBJPROP_TIME2 , dtTimeEnd);
      ObjectSet(sObjName, OBJPROP_PRICE1, dPriceHigh);
      ObjectSet(sObjName, OBJPROP_PRICE2, dPriceLow);
      ObjectSet(sObjName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(sObjName, OBJPROP_COLOR, cObjColor1);
      ObjectSet(sObjName, OBJPROP_WIDTH, 1);
      
      ObjectCreate(sObjName+"2", OBJ_RECTANGLE, 0, 0, 0, 0);
      ObjectSet(sObjName+"2", OBJPROP_TIME1 , dtTimeEnd);
      ObjectSet(sObjName+"2", OBJPROP_TIME2 , dtTimeObjEnd);  //dtTimeObjEnd
      ObjectSet(sObjName+"2", OBJPROP_PRICE1, dPriceHigh);  
      ObjectSet(sObjName+"2", OBJPROP_PRICE2, dPriceLow);
      ObjectSet(sObjName+"2", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(sObjName+"2", OBJPROP_COLOR, cObjColor2);
      ObjectSet(sObjName+"2", OBJPROP_BACK, 1);


      //------ Box Range and some labels in main window 
      if(ObjectFind("sBoxRange") == -1) 
      {
         ObjectCreate ("sBoxRange",OBJ_LABEL, 0, 0, 0);
      }
      if (BlkBgd)
      {
         ObjectSetText("sBoxRange", "Box Range: "+ DoubleToStr(drange,Point) + " pips.", 10,"Georgia", DimGray);
      }
      else 
      {
         ObjectSetText("sBoxRange", "Box Range: "+ DoubleToStr(drange,Point) + " pips.", 10,"Georgia", Blue);
      }
      ObjectSet("sBoxRange", OBJPROP_CORNER, 1);
      ObjectSet("sBoxRange", OBJPROP_XDISTANCE, 5);
      ObjectSet("sBoxRange", OBJPROP_YDISTANCE, 20);
      
   
      if(ObjectFind("sPriceLabel") == -1)
      { 
         ObjectCreate ("sPriceLabel",OBJ_LABEL, 0, 0, 0);
         if (BlkBgd)
         {
            ObjectSetText("sPriceLabel", "PRICE", 10,"Arial Bold", Black);
         }
         else 
         {
            ObjectSetText("sPriceLabel", "PRICE", 10,"Arial Bold", SlateGray);
         }
         ObjectSet("sPriceLabel", OBJPROP_CORNER, 0);
         ObjectSet("sPriceLabel", OBJPROP_XDISTANCE, 5);
         ObjectSet("sPriceLabel", OBJPROP_YDISTANCE, 255);
      }
   
      if(ObjectFind("sPrice") == -1)
      {
         ObjectCreate ("sPrice",OBJ_LABEL, 0, 0, 0);
      }
      if (BlkBgd)
      {
      ObjectSetText("sPrice",DoubleToStr (Bid,Digits), 15,"Arial Bold", DimGray);
      }
      else
      { 
      ObjectSetText("sPrice",DoubleToStr (Bid,Digits), 15,"Arial Bold", SlateGray);
      }
      ObjectSet("sPrice", OBJPROP_CORNER, 0);
      ObjectSet("sPrice", OBJPROP_XDISTANCE, 55);
      ObjectSet("sPrice", OBJPROP_YDISTANCE, 250);
      
      
   }   // if(iForm==1)


   
   if(iForm==2)  // draw the price lines
   {
      if (iCtr == 0)
      {   
         //------ Draw the lines and text
         double SetOff = 8*Point;
         if (Digits == 5 || Digits == 3) SetOff = SetOff * 10;  // Put the text above the line
         ObjectCreate(sObjName+"BATL", OBJ_TEXT, 0, Time[5], bep);
         ObjectSetText(sObjName+"BATL", " "+DoubleToStr(bep+dSpread,Digits)+"", 8, "Arial", DimGray);
         ObjectMove(sObjName+"BATL", 0, dtTimeBegin, bep + SetOff + dSpread );  // Put the text above the line

         ObjectCreate (sObjName+"BAT", OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"BAT", OBJPROP_STYLE, STYLE_SOLID);
         ObjectSet(sObjName+"BAT", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"BAT", OBJPROP_TIME1 , dtTimeBegin);
         ObjectSet(sObjName+"BAT", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"BAT", OBJPROP_PRICE1, bep+dSpread);
         ObjectSet(sObjName+"BAT", OBJPROP_PRICE2, bep+dSpread);
         ObjectSet(sObjName+"BAT", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"BAT", OBJPROP_BACK, 1);
         //ObjectMove("BAT", bep, Time[0], bep );
         
         ObjectCreate(sObjName+"BTP1L", OBJ_TEXT, 0, Time[0], btp1+dSpread);
         ObjectSetText(sObjName+"BTP1L", " : "+DoubleToStr(btp1+dSpread,Digits)+"", 8, "Arial", Silver);
         ObjectMove(sObjName+"BTP1L", 0, dtTimeBegin, btp1+dSpread );

         ObjectCreate (sObjName+"BTP1",OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"BTP1", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(sObjName+"BTP1", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"BTP1", OBJPROP_TIME1 , dtTimeBegin);
         ObjectSet(sObjName+"BTP1", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"BTP1", OBJPROP_PRICE1, btp1+dSpread);
         ObjectSet(sObjName+"BTP1", OBJPROP_PRICE2, btp1+dSpread);
         ObjectSet(sObjName+"BTP1", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"BTP1", OBJPROP_BACK, 1);
         //ObjectMove("BTP1", 0, Time[0], btp1+dSpread );

         ObjectCreate(sObjName+"BTP2L", OBJ_TEXT, 0, Time[0], btp2+dSpread);
         ObjectSetText(sObjName+"BTP2L", " : "+DoubleToStr(btp2+dSpread,Digits)+"", 8, "Arial", Silver);
         ObjectMove(sObjName+"BTP2L", 0, dtTimeBegin, btp2+dSpread );

         ObjectCreate (sObjName+"BTP2",OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"BTP2", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(sObjName+"BTP2", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"BTP2", OBJPROP_TIME1 , dtTimeBegin);    //--  
         ObjectSet(sObjName+"BTP2", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"BTP2", OBJPROP_PRICE1, btp2+dSpread);
         ObjectSet(sObjName+"BTP2", OBJPROP_PRICE2, btp2+dSpread);
         ObjectSet(sObjName+"BTP2", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"BTP2", OBJPROP_BACK, 1);              //--
         //ObjectMove("BTP2",btp2, Time[0],btp2 );
  
         ObjectCreate(sObjName+"BTP3L", OBJ_TEXT, 0, Time[0], btp3+dSpread);
         ObjectSetText(sObjName+"BTP3L", " : "+DoubleToStr(btp3+dSpread,Digits)+"", 8, "Arial", Silver);
         ObjectMove(sObjName+"BTP3L", 0, dtTimeBegin, btp3+dSpread );

         ObjectCreate (sObjName+"BTP3",OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"BTP3", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(sObjName+"BTP3", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"BTP3", OBJPROP_TIME1 , dtTimeBegin);    //--  
         ObjectSet(sObjName+"BTP3", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"BTP3", OBJPROP_PRICE1, btp3+dSpread);
         ObjectSet(sObjName+"BTP3", OBJPROP_PRICE2, btp3+dSpread);
         ObjectSet(sObjName+"BTP3", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"BTP3", OBJPROP_BACK, 1);              //--
         //ObjectMove(sObjName+"BTP3", 0, dtTimeBegin, btp3 + dSpread );

         ObjectCreate(sObjName+"SATL", OBJ_TEXT, 0, Time[5], sep);
         ObjectSetText(sObjName+"SATL", " "+DoubleToStr(sep,Digits)+"", 8, "Arial", DimGray);
         ObjectMove(sObjName+"SATL",0, dtTimeBegin, sep );
  
         ObjectCreate (sObjName+"SAT",OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"SAT", OBJPROP_STYLE, STYLE_SOLID);
         ObjectSet(sObjName+"SAT", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"SAT", OBJPROP_TIME1 , dtTimeBegin);    //--  
         ObjectSet(sObjName+"SAT", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"SAT", OBJPROP_PRICE1, sep);
         ObjectSet(sObjName+"SAT", OBJPROP_PRICE2, sep);
         ObjectSet(sObjName+"SAT", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"SAT", OBJPROP_BACK, 1);              //--
         //ObjectMove("SAT",sep, Time[0],sep );
  
         ObjectCreate(sObjName+"STP1L", OBJ_TEXT, 0, Time[0], stp1);
         ObjectSetText(sObjName+"STP1L", " : "+DoubleToStr(stp1,Digits)+"", 8, "Arial", Silver);
         ObjectMove(sObjName+"STP1L", 0, dtTimeBegin, stp1 );

         ObjectCreate (sObjName+"STP1",OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"STP1", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(sObjName+"STP1", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"STP1", OBJPROP_TIME1 , dtTimeBegin);    //--  
         ObjectSet(sObjName+"STP1", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"STP1", OBJPROP_PRICE1, stp1);
         ObjectSet(sObjName+"STP1", OBJPROP_PRICE2, stp1);
         ObjectSet(sObjName+"STP1", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"STP1", OBJPROP_BACK, 1);              //--
         //ObjectMove(sObjName+"STP1",stp1, Time[0],stp1 );

         ObjectCreate(sObjName+"STP2L", OBJ_TEXT, 0, Time[0], stp2);
         ObjectSetText(sObjName+"STP2L", " : "+DoubleToStr(stp2,Digits)+"", 8, "Arial", Silver);
         ObjectMove(sObjName+"STP2L", 0, dtTimeBegin, stp2 );

         ObjectCreate (sObjName+"STP2",OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"STP2", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(sObjName+"STP2", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"STP2", OBJPROP_TIME1 , dtTimeBegin);    //--  
         ObjectSet(sObjName+"STP2", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"STP2", OBJPROP_PRICE1, stp2);
         ObjectSet(sObjName+"STP2", OBJPROP_PRICE2, stp2);
         ObjectSet(sObjName+"STP2", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"STP2", OBJPROP_BACK, 1);              //--
         //ObjectMove(sObjName+"STP2",stp2, Time[0],stp2 );
  
         ObjectCreate(sObjName+"STP3L", OBJ_TEXT, 0, Time[0], stp3);
         ObjectSetText(sObjName+"STP3L", " : "+DoubleToStr(stp3,Digits)+"", 8, "Arial", Silver);
         ObjectMove(sObjName+"STP3L", 0, dtTimeBegin, stp3 );

         ObjectCreate (sObjName+"STP3",OBJ_TREND, 0, 0, 0);
         ObjectSet(sObjName+"STP3", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(sObjName+"STP3", OBJPROP_COLOR,DimGray );
         ObjectSet(sObjName+"STP3", OBJPROP_TIME1 , dtTimeBegin);    //--  
         ObjectSet(sObjName+"STP3", OBJPROP_TIME2 , dtLineEnd);
         ObjectSet(sObjName+"STP3", OBJPROP_PRICE1, stp3);
         ObjectSet(sObjName+"STP3", OBJPROP_PRICE2, stp3);
         ObjectSet(sObjName+"STP3", OBJPROP_WIDTH, 1);
         ObjectSet(sObjName+"STP3", OBJPROP_BACK, 1);              //--
         //ObjectMove(sObjName+"STP3",stp3, Time[0],stp3 );

      }  //if (TimeToStr( dtTimeBegin, 1) == TimeToStr( TimeCurrent(), 1))
   }  //   if(iForm==2) 


   //----- The Zones
   if(iForm==4) 
   {
      if (ObjectFind(sObjName+"BuyZone")<0) ObjectCreate(sObjName+"BuyZone", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"BuyZone", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"BuyZone", OBJPROP_PRICE1  , btp1+dSpread);
      ObjectSet(sObjName+"BuyZone", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"BuyZone", OBJPROP_PRICE2  , bep+dSpread);
      ObjectSet(sObjName+"BuyZone", OBJPROP_COLOR   , DimGray);

      if (ObjectFind(sObjName+"BuyTP1")<0) ObjectCreate(sObjName+"BuyTP1", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"BuyTP1", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"BuyTP1", OBJPROP_PRICE1  , btp2+dSpread);
      ObjectSet(sObjName+"BuyTP1", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"BuyTP1", OBJPROP_PRICE2  , btp1+dSpread);
      ObjectSet(sObjName+"BuyTP1", OBJPROP_COLOR   , DimGray);
      
      if (ObjectFind(sObjName+"BuyTP2")<0) ObjectCreate(sObjName+"BuyTP2", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"BuyTP2", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"BuyTP2", OBJPROP_PRICE1  , btp3+dSpread);
      ObjectSet(sObjName+"BuyTP2", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"BuyTP2", OBJPROP_PRICE2  , btp2+dSpread);
      ObjectSet(sObjName+"BuyTP2", OBJPROP_COLOR   , DimGray);
      
      if (ObjectFind(sObjName+"BuyTP3")<0) ObjectCreate(sObjName+"BuyTP3", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"BuyTP3", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"BuyTP3", OBJPROP_PRICE1  , btp4+dSpread);
      ObjectSet(sObjName+"BuyTP3", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"BuyTP3", OBJPROP_PRICE2  , btp3+dSpread);
      ObjectSet(sObjName+"BuyTP3", OBJPROP_COLOR   , DimGray);
      
      if (ObjectFind(sObjName+"SellZone")<0) ObjectCreate(sObjName+"SellZone", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"SellZone", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"SellZone", OBJPROP_PRICE1  , stp1);
      ObjectSet(sObjName+"SellZone", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"SellZone", OBJPROP_PRICE2  , sep);
      ObjectSet(sObjName+"SellZone", OBJPROP_COLOR   , DimGray);
      
      if (ObjectFind(sObjName+"SellTP1")<0) ObjectCreate(sObjName+"SellTP1", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"SellTP1", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"SellTP1", OBJPROP_PRICE1  , stp2);
      ObjectSet(sObjName+"SellTP1", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"SellTP1", OBJPROP_PRICE2  , stp1);
      ObjectSet(sObjName+"SellTP1", OBJPROP_COLOR   , DimGray);
   
      if (ObjectFind(sObjName+"SellTP2")<0) ObjectCreate(sObjName+"SellTP2", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"SellTP2", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"SellTP2", OBJPROP_PRICE1  , stp3);
      ObjectSet(sObjName+"SellTP2", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"SellTP2", OBJPROP_PRICE2  , stp2);
      ObjectSet(sObjName+"SellTP2", OBJPROP_COLOR   , DimGray);
      
      if (ObjectFind(sObjName+"SellTP3")<0) ObjectCreate(sObjName+"SellTP3", OBJ_RECTANGLE, 0,0, 0,0);
      ObjectSet(sObjName+"SellTP3", OBJPROP_TIME1   , dtTimeEnd);
      ObjectSet(sObjName+"SellTP3", OBJPROP_PRICE1  , stp4);
      ObjectSet(sObjName+"SellTP3", OBJPROP_TIME2   , dtTimeObjEnd);
      ObjectSet(sObjName+"SellTP3", OBJPROP_PRICE2  , stp3);
      ObjectSet(sObjName+"SellTP3", OBJPROP_COLOR   , DimGray);
         
         if (iSession == 3)
         {
            if(ObjectFind(sObjName+"vlLondonOpen") == -1) 
            {
               ObjectCreate (sObjName+"vlLondonOpen", OBJ_VLINE, 0, dtTimeLondonOpen, 0);
               ObjectSet(sObjName+"vlLondonOpen", OBJPROP_STYLE, STYLE_DOT);
               ObjectSet(sObjName+"vlLondonOpen", OBJPROP_COLOR,Red );
            }
         }
         
      }  //if(iForm==6)

}  //  void DrawObjects()

//+------------------------------------------------------------------+
//| Decrement Date to draw objects in the past                       |
//+------------------------------------------------------------------+

datetime decrementTradeDate(datetime dtTimeDate) 
{
   int iTimeYear=TimeYear(dtTimeDate);
   int iTimeMonth=TimeMonth(dtTimeDate);
   int iTimeDay=TimeDay(dtTimeDate);
   int iTimeHour=TimeHour(dtTimeDate);
   int iTimeMinute=TimeMinute(dtTimeDate);

   iTimeDay--;
   if (iTimeDay==0) 
   {
     iTimeMonth--;
     if (iTimeMonth==0) 
     {
       iTimeYear--;
       iTimeMonth=12;
     }
    
     // Thirty days hath September...  
     if (iTimeMonth==4 || iTimeMonth==6 || iTimeMonth==9 || iTimeMonth==11) iTimeDay=30;
     // ...all the rest have thirty-one...
     if (iTimeMonth==1 || iTimeMonth==3 || iTimeMonth==5 || iTimeMonth==7 || iTimeMonth==8 || iTimeMonth==10 || iTimeMonth==12) iTimeDay=31;
     // ...except...
     if (iTimeMonth==2) if (MathMod(iTimeYear, 4)==0) iTimeDay=29; else iTimeDay=28;
   }
  return(StrToTime(iTimeYear + "." + iTimeMonth + "." + iTimeDay + " " + iTimeHour + ":" + iTimeMinute));
}
  

