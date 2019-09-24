#property copyright "Daniel"


#include <stdlib.mqh>

#define UP "UP"
#define DOWN "DOWN"
#define NONE "NONE"
#define OK "OK"
#define YES "YES"
#define NO "NO"
#define BUY "BUY"
#define SELL "SELL"
#define ALL "ALL"
#define ANY "ANY"


// --------------------------------------------------------------------------------------------------------------------------------------------------------------
//   danw2 "pending" codebase
// --------------------------------------------------------------------------------------------------------------------------------------------------------------


// designed for h4 or d1 ONLY

// last modified 2019-09-24
// removed trend detection
// fixed range bug
// did other stuff
// fixed increment lots bug



extern string           Expert_Name          = "Danw2 - Pending + IB multi breakout";


bool          EMERGENCY = false;
const int           cTARGET = 100;
const int           cMAX_ORDERS = 10;
const int           cBUFFER = 20;
const int           cMAX_SPREAD = 60;
const bool          cINCREMENT_LOTS = true;
const double        cINCREMENT_VALUE = 0.02;
const double        cLOT_SIZE = 0.02;
const int           cLOT_DIVISOR = 10;
const int           cSLIPPAGE = 2;
const int           cMIN_MARGIN = 1000;
const int           cMAX_PAIRS_OPEN = 2;




// ------------------------------------------------------------------------------------------

int NULL0;
double RANGE1, RANGE2 =0;

string ALLC[];
string SORTED[];

double HIGH1, LOW1 =0;
double HIGH2, LOW2 =0;

double OPEN1, CLOSE1 = 0;
double OPEN2, CLOSE2 = 0;

double BODY1, BODY2 = 0;


// ------------------------------------------------------------------------------------------

   double pointvalue = 0, spread = 0;

// ------------------------------------------------------------------------------------------


   int BUY_ORDERS_OPEN = 0; 
   int SELL_ORDERS_OPEN = 0;
   
   int BUY_ORDERS_PENDING = 0;
   int SELL_ORDERS_PENDING = 0;
   
   int TOTAL_ORDERS_PENDING = 0;
   int TOTAL_ORDERS_OPEN = 0;
   int TOTAL_ORDERS = 0;
         
   double BUY_PROFIT = 0;
   double SELL_PROFIT = 0;
   
   double PROFIT = 0;
   double ATR=0;
      
   double BUY_PIPS = 0;
   double SELL_PIPS = 0;
   
   // ------------------------------------------------------------------------------------------
   
   double gBIGGEST_BUY_LOT, gBIGGEST_SELL_LOT, gBUYLOTS2SEND, gSELLLOTS2SEND, gHIGHEST_PRICE, gLOWESTPRICE, gINCREMENT_VALUE;
      
   
// ------------------------------------------------------------------------------------------

int OnInit()
  {
   EventSetTimer(30);
   if(Digits==4 || Digits==2) pointvalue=Point;  else if(Digits==5 || Digits==3) pointvalue=10.0*Point;

return(INIT_SUCCEEDED);

  }

// ------------------------------------------------------------------------------------------

void OnDeinit(const int reason) {   EventKillTimer();  ObjectsDeleteAll();   return; }
// ------------------------------------------------------------------------------------------


void OnTick() { }


// ------------------------------------------------------------------------------------------

void OnTimer()
{

   if ( EMERGENCY )  { Comment("EMERGENCY!"); subCLOSE_ORDER(ANY); subDELETE_PENDING_ORDER(ANY); return; }
   if ( Period() < PERIOD_H4 ) { Comment(Period(), " Time frame too low!"); return; }
  
  
  
   subCLOSEDECISIONS();   // extra close logic
   subMAINLOGIC(); 
   subDISPLAY();
   
   
   Sleep(1000);
   return; // end of program

}


// ------------------------------------------------------------------------------------------
//  Main part
// ------------------------------------------------------------------------------------------

void subMAINLOGIC() {
      

   subSetParams();
   subDRAW();   


   if ( TOTAL_ORDERS == 0 && subCURRENCIESOPEN() >= cMAX_PAIRS_OPEN ) return;   // don't open if there are many other pairs open


   // if there's no orders but margin is low (ie, other currencies have trades open) DON'T EVEN START!
   // this is close logic, but we need these checks to cause new orders not to be opened!

   if ( TOTAL_ORDERS == 0 && subMARGINCHECK() < cMIN_MARGIN ) return; 
   if ( TOTAL_ORDERS_PENDING > 0 && TOTAL_ORDERS_OPEN == 0 && subMARGINCHECK() < cMIN_MARGIN ) {  subDELETE_PENDING_ORDER(ANY);  return; }


      
   // if there's any orders at all, we need to make sure there's enough pending orders in case of market movement. Should recover from errors?
   // send a single trade. We will recheck on next loop
   if ( BUY_ORDERS_PENDING < cMAX_ORDERS  && TOTAL_ORDERS > 0 && PROFIT < cTARGET ) subBUY(); // buy  can figure out it's own parameters
   if ( SELL_ORDERS_PENDING < cMAX_ORDERS && TOTAL_ORDERS > 0 && PROFIT < cTARGET ) subSELL(); // buy  can figure out it's own parameters    

   
   
   
   
   // if we find an inside bar, we want to make sure we have pending orders set up ready   
   if ( subINSIDEBAR() && BUY_ORDERS_PENDING < cMAX_ORDERS  )   subBUY(); 
   if ( subINSIDEBAR() && SELL_ORDERS_PENDING < cMAX_ORDERS  )   subSELL(); 
   
   
      
}


// ------------------------------------------------------------------------------------------
// IB ? 
// ------------------------------------------------------------------------------------------

bool subINSIDEBAR() {
   
      HIGH1 = iHigh(NULL,0,1);
      LOW1 = iLow(NULL,0,1);
      
      HIGH2 = iHigh(NULL,0,2);
      LOW2 = iLow(NULL,0,2);
      
      
      OPEN1 = iOpen(NULL,0,1);
      CLOSE1 = iClose(NULL,0,1);
      
      OPEN2 = iOpen(NULL,0,2);
      CLOSE2 = iClose(NULL,0,2);
      
               
      
      
      RANGE1 = ( HIGH1-LOW1 );
      RANGE2 = ( HIGH2-LOW2 );


      BODY1 = MathAbs(OPEN1 - CLOSE1);
      BODY2 = MathAbs(OPEN2 - CLOSE2); 
      

      // not interested in the inside bar if it's bigger than ATR
      ATR=iATR(NULL,0,20,1);
      
           
      if ( RANGE1 > ATR ) return(false);
   
      // let's just check bar 1 for insidebar-ness against bar 2 - we still have to place orders when price is within bar 1
      //if ( ( iHigh(NULL,0,2) > HIGH && iLow(NULL,0,2) < LOW ) && Bid < HIGH && Ask > LOW   ) return(true);
      
      if (  BODY1 < BODY2 && RANGE1 < RANGE2 && Bid < HIGH1 && Ask > LOW1   ) return(true);
           

   return(false);
   
}



// ------------------------------------------------------------------------------------------
// Draw Stuff
// ------------------------------------------------------------------------------------------

void subDRAW() {

   double BOXCOLOR = 0;
   string BOXNAME = "BreakOut";

   if ( subINSIDEBAR() ) BOXCOLOR = Yellow; else BOXCOLOR = LightBlue;

   ObjectsDeleteAll();

   ObjectDelete(BOXNAME);
   ObjectCreate(BOXNAME, OBJ_RECTANGLE, 0, iTime(NULL,0,1), iHigh(NULL,0,1), iTime(NULL,0,1), iLow(NULL,0,1) );
   ObjectSet(BOXNAME, OBJPROP_COLOR, BOXCOLOR); 


}


// ------------------------------------------------------------------------------------------
// Set the orders
// ------------------------------------------------------------------------------------------

void subSETORDER(string fORDER_TYPE, double fPRICE, double fLOTS) {

   if ( subMARGINCHECK() < cMIN_MARGIN ) { Print("Not enough margin"); return; }
   //if (spread > cMAX_SPREAD) return;

   fLOTS = NormalizeDouble(fLOTS,2);
   if ( fLOTS < 0.01 ) fLOTS = 0.01;
   if ( fLOTS > 10 ) fLOTS = 10;

   fPRICE = NormalizeDouble(fPRICE,Digits);

   if (!IsTradeAllowed() || IsTradeContextBusy() ) { Print("Busy ... ");  return; }
   
      subSetParams();
      if (fORDER_TYPE == BUY && Ask < fPRICE ) { NULL0=OrderSend(Symbol(),OP_BUYSTOP,fLOTS,fPRICE,cSLIPPAGE,0,0," ",0,0,Blue); }
      
      subSetParams();
      if (fORDER_TYPE == SELL && Bid > fPRICE ) { NULL0=OrderSend(Symbol(),OP_SELLSTOP,fLOTS,fPRICE,cSLIPPAGE,0,0," ",0,0,Red);  }
      
}



// ------------------------------------------------------------------------------------------
// close decision
// ------------------------------------------------------------------------------------------

void subCLOSEDECISIONS() {

   subSetParams();
   
   // we really want to make sure all orders are closed so we don't loop back and start placing more
   // but at the same time, if we get failures to close/delete, we want more orders placed to recover. So, hmmm
   // possibly using a big enough target will help avoid this issue
   
   // also really want a trailing stop to be set if orders are in profit and > profit target to milk profit as long as we can
   
   if ( PROFIT > cTARGET ) { subCLOSE_AND_DELETE_ALL_ORDERS();  return; }
   
   
   
  
   
// kills off trades forcably if margin is low or too many trades only if the baskets are making money
   if (subMARGINCHECK() < cMIN_MARGIN      && PROFIT  > ( cTARGET * 0.1 ) )     subCLOSE_AND_DELETE_ALL_ORDERS();    
   if (TOTAL_ORDERS_OPEN > cMAX_ORDERS && PROFIT  > ( cTARGET * 0.1 ) )  subCLOSE_AND_DELETE_ALL_ORDERS();    
   if (subMARGINCHECK() < cMIN_MARGIN && AccountProfit() > 1  ) subCLOSE_AND_DELETE_ALL_PAIRS(); 

}


// ------------------------------------------------------------------------------------------
// display
// ------------------------------------------------------------------------------------------

// some of this was 'borrowed' from somewhere a long time ago, hmmm
// possibly from Steve Hopwood, sorry :(


void subDISPLAY() {

if (IsTesting()) return;

subSetParams();

   string sComm   = "";
   string MS = "        ";
   string sp         = MS + "----------------------------------------\n";
   string NL         = "\n";
   string spacer     = " | ";
   

   sComm = sp + MS;
   sComm = sComm + "Server -> " + AccountServer() + spacer;
   sComm = sComm + "Lots -> " + DoubleToStr(cLOT_SIZE,2) + spacer;
   sComm = sComm + "Spread -> " + DoubleToStr(spread,0) + spacer;
   sComm = sComm + "Leverage -> " + AccountLeverage() + spacer;
   sComm = sComm + "Digits -> " + Digits + spacer;
   sComm = sComm + "Currency -> " + AccountCurrency() + spacer;
   sComm = sComm + "Profit -> " + DoubleToStr(AccountProfit(),2) + spacer;
   sComm = sComm + "Equity -> " + DoubleToStr(AccountEquity(),2) + spacer;
   sComm = sComm + "Margin -> " + DoubleToStr(AccountMargin(),2);

sComm = sComm + NL + sp;   
sComm = sComm + MS + subNextBar();
sComm = sComm + MS + "Profit -> " + DoubleToStr(PROFIT,2) + NL;
sComm = sComm + MS + "Margin Check -> " + DoubleToStr(subMARGINCHECK(),2) + NL;

sComm = sComm + sp; 
sComm = sComm + MS + "Max Orders -> " + cMAX_ORDERS + NL; 
sComm = sComm + MS + "Biggest Buy Lot  -> " + DoubleToStr(gBIGGEST_BUY_LOT,2) + NL; 
sComm = sComm + MS + "Biggest Sell Lot  -> " + DoubleToStr(gBIGGEST_SELL_LOT,2) + NL; 
sComm = sComm + MS + "Lots2send -> " + DoubleToStr(gBUYLOTS2SEND,2) + " / " + DoubleToStr(gBUYLOTS2SEND,2) + NL; 
sComm = sComm + MS + "Highest/Lowest Price -> " + DoubleToStr(gHIGHEST_PRICE,Digits) + " / " + DoubleToStr(gLOWESTPRICE,Digits) + NL; 
sComm = sComm + MS + "Range -> "  + DoubleToStr(RANGE1,Digits)+ NL; 
sComm = sComm + MS + "cBUFFER -> "  + cBUFFER + NL;   // buffer actually v. important. Don't want it to be too small 
sComm = sComm + MS + "ATR -> "  + DoubleToStr(ATR/pointvalue,1)+ NL; 
sComm = sComm + MS + "RANGE -> "  + DoubleToStr(RANGE1/pointvalue,1)+ NL; 
sComm = sComm + MS + "BODY 1/2 -> "  + BODY1 + " / " + BODY2 + NL;


sComm = sComm + MS + "INSIDE BAR? -> "  + subINSIDEBAR() + NL; 


sComm = sComm + MS + "Pairs Open -> " + subCURRENCIESOPEN() + " / " + subSHOWSORTED()+ NL;

if ( EMERGENCY ) sComm = sComm + MS + "Emergency!" + NL; 

sComm = sComm + sp;
sComm = sComm + MS + "Orders Pending -> " + "(Total " + TOTAL_ORDERS_PENDING + ") (Buy " + BUY_ORDERS_PENDING + ") (Sell " + SELL_ORDERS_PENDING + ")" + NL; 
sComm = sComm + MS + "Orders Open -> " + "(Total " + TOTAL_ORDERS_OPEN + ") (Buy " + BUY_ORDERS_OPEN + ") (Sell " + SELL_ORDERS_OPEN + ")" + NL; 
sComm = sComm + MS + "Buy Profit -> " + DoubleToStr(BUY_PROFIT,2) + " / " + DoubleToStr(BUY_PIPS,2) + " / " + DoubleToStr(BUY_PIPS*pointvalue,Digits) + NL; 
sComm = sComm + MS + "Sell Profit -> " + DoubleToStr(SELL_PROFIT,2) + " / " + DoubleToStr(SELL_PIPS,2) + " / " + DoubleToStr(SELL_PIPS*pointvalue,Digits); 

Comment(sComm);

}



// --------------------------------------------------------------------------------
// Order Status
// --------------------------------------------------------------------------------

void subORDERSTATUS()    // one of the most important functions in this whole thing
{
   
   BUY_ORDERS_OPEN = 0; 
   SELL_ORDERS_OPEN = 0;
   
   BUY_ORDERS_PENDING = 0;
   SELL_ORDERS_PENDING = 0;
   
   TOTAL_ORDERS_PENDING = 0;
   TOTAL_ORDERS_OPEN = 0;
   TOTAL_ORDERS = 0;
         
   BUY_PROFIT = 0;
   SELL_PROFIT = 0;
   
   PROFIT = 0;
      
   BUY_PIPS = 0;
   SELL_PIPS = 0;
   
      
   
   for(int COUNTER=0;COUNTER<OrdersTotal();COUNTER++)
   {
      NULL0 = OrderSelect(COUNTER,SELECT_BY_POS,MODE_TRADES);
      if(OrderSymbol()==Symbol()  )
      {
         if(OrderType()==OP_BUY ) { BUY_ORDERS_OPEN++; BUY_PROFIT = BUY_PROFIT +  OrderSwap() + OrderCommission() + OrderProfit(); BUY_PIPS = BUY_PIPS + (Bid - OrderOpenPrice()); }
         if(OrderType()==OP_SELL) { SELL_ORDERS_OPEN++; SELL_PROFIT = SELL_PROFIT +  OrderSwap() + OrderCommission() + OrderProfit(); SELL_PIPS = SELL_PIPS + (OrderOpenPrice() - Ask); } 
         
         if(OrderType()==OP_BUYSTOP || OrderType() == OP_BUYLIMIT ) { BUY_ORDERS_PENDING++;  }
         if(OrderType()==OP_SELLSTOP || OrderType() == OP_SELLLIMIT ) { SELL_ORDERS_PENDING++; } 
      }         
   }
   
   BUY_PIPS = BUY_PIPS / pointvalue; 
   SELL_PIPS = SELL_PIPS / pointvalue;
   
   TOTAL_ORDERS_PENDING = BUY_ORDERS_PENDING+SELL_ORDERS_PENDING;
   TOTAL_ORDERS_OPEN = BUY_ORDERS_OPEN + SELL_ORDERS_OPEN;
   TOTAL_ORDERS = TOTAL_ORDERS_PENDING + TOTAL_ORDERS_OPEN;
   
   PROFIT = BUY_PROFIT+SELL_PROFIT;         
   
   return;
}


// --------------------------------------------------------------------------------
// Delete Pending Orders
// --------------------------------------------------------------------------------
 
void subDELETE_PENDING_ORDER(string MYTYPE)   // deletes one single pending order
{
   
   subORDERSTATUS();
   
   for(int COUNTER=0;COUNTER<OrdersTotal();COUNTER++)
   {
      if (!IsTradeAllowed() || IsTradeContextBusy() ) { Print("Busy ... ");  return; }
      NULL0 = OrderSelect(COUNTER,SELECT_BY_POS,MODE_TRADES);
      if ( OrderSymbol() == Symbol() ) {
            if( MYTYPE == BUY   && OrderType() == OP_BUYSTOP  ) NULL0 = OrderDelete(OrderTicket(),Green);
            if( MYTYPE == SELL  && OrderType() == OP_SELLSTOP ) NULL0 =  OrderDelete(OrderTicket(),Green);
            if( MYTYPE == ANY ) NULL0 = OrderDelete(OrderTicket(),Green);
            if ( GetLastError() != 0 ) Print("Last error while deleting = " + GetLastError());
         }
    }
   
   return;
}


// --------------------------------------------------------------------------------------------
//  CLOSE ORDER FUNCTION
// --------------------------------------------------------------------------------------------

void subCLOSE_ORDER(string MYTYPE)    // closes one single open order
{

   if ( spread > cMAX_SPREAD*10) { Print("Spread too high"); return; }   // something really crazy is happening
   
   for(int COUNTER=0;COUNTER<OrdersTotal();COUNTER++)
      {
         NULL0 = OrderSelect(COUNTER,SELECT_BY_POS,MODE_TRADES);
         if (IsTradeContextBusy() || !IsTradeAllowed()) { Print("Busy ... ");  return; }
         
         
         if ( OrderSymbol()==Symbol() )  {
         
            if(MYTYPE == BUY  && OrderType() == OP_BUY  )  NULL0=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),10,Violet);
            if(MYTYPE == SELL && OrderType() == OP_SELL )  NULL0=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),10,Violet);
            if(MYTYPE == ANY  )  NULL0=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),10,Violet);
         
            }
            
         if ( GetLastError() != 0 ) Print("Last error while closing = " + GetLastError());
      }
      
}


// --------------------------------------------------------------------------------------------
//  CLOSE AND DELETE
// --------------------------------------------------------------------------------------------


void subCLOSE_AND_DELETE_ALL_ORDERS()   // includes retries. Uses the single order close/delete functions to do the actual closing/deleting

   {

   int MAXTRIES, TRIES=0;

   subORDERSTATUS(); 


   MAXTRIES = TOTAL_ORDERS_OPEN * 5;
   TRIES = 0;

   while (TOTAL_ORDERS_OPEN > 0 ) { subCLOSE_ORDER(ANY); subORDERSTATUS(); TRIES++; if (TRIES > MAXTRIES) break;   }   // Give up after a while 


   subORDERSTATUS(); 
   MAXTRIES = TOTAL_ORDERS_PENDING * 3;
   TRIES = 0;

   while (TOTAL_ORDERS_PENDING > 0 ) { subDELETE_PENDING_ORDER(ANY); subORDERSTATUS(); TRIES++; if (TRIES > MAXTRIES) break;   }   // Give up after a while 
   

}

// --------------------------------------------------------------------------------------------
//  DELETES AND CLOSES ALL PAIRS 
// --------------------------------------------------------------------------------------------


// needs doing

void subCLOSE_AND_DELETE_ALL_PAIRS() {



}



//------------------------------------------------------------------
// time to next bar
//------------------------------------------------------------------

string subNextBar() {
//Code for time to bar-end display from Candle Time by Nick Bilak
   double i;
   int m,s;
   m=Time[0]+Period()*60-CurTime();
   i=m/60.0;
   s=m%60;
   m=(m-m%60)/60;
   
   string TTNB;
   
   TTNB = "Time to Next Bar -> " + m + ":" + s + "\n";
   
   return(TTNB);

}




//-----------------------------------------------------------
//  margin check
//-----------------------------------------------------------

double subMARGINCHECK()     {
     double am;
     if ( AccountMargin()==0 ) return(cMIN_MARGIN+1);
      else if ( AccountMargin() > 0 ) { am = (AccountEquity()/AccountMargin())*100; return(am); }
return(0);     
}



//-----------------------------------------------------------
//  PriceCheck
//-----------------------------------------------------------

// could possibly break this into 4 subroutines 


void  subPriceCheck()     {

   gHIGHEST_PRICE = 0; gLOWESTPRICE = 10000; gBIGGEST_BUY_LOT = 0; gBIGGEST_SELL_LOT = 0;
   
  
   for(int COUNTER=0;COUNTER<OrdersTotal();COUNTER++)
      {
         NULL0 = OrderSelect(COUNTER,SELECT_BY_POS,MODE_TRADES);
         if ( OrderSymbol() == Symbol() ) {
            if ( OrderOpenPrice() > gHIGHEST_PRICE) gHIGHEST_PRICE = OrderOpenPrice();
            if ( OrderOpenPrice() < gLOWESTPRICE ) gLOWESTPRICE  = OrderOpenPrice();

            if ( (OrderType() == OP_BUY || OrderType() == OP_BUYSTOP) &&  OrderLots() > gBIGGEST_BUY_LOT )       gBIGGEST_BUY_LOT = OrderLots();
            if ( (OrderType() == OP_SELL || OrderType() == OP_SELLSTOP) && OrderLots() > gBIGGEST_SELL_LOT ) gBIGGEST_SELL_LOT = OrderLots();
            
         }
      }

   if ( Ask > gHIGHEST_PRICE ) gHIGHEST_PRICE = Ask;
   if ( Bid < gLOWESTPRICE ) gLOWESTPRICE = Bid;
   
   // unsure about this for setting initial orders on IB detection
   
   if ( iHigh(NULL,0,1) > gHIGHEST_PRICE ) gHIGHEST_PRICE = iHigh(NULL,0,1);
   if ( iLow(NULL,0,1) < gLOWESTPRICE ) gLOWESTPRICE = iLow(NULL,0,1);


   

}




// --------------------------------------------------------------------------------
// Special Delete/Close ( all orders, no symbol, mn)
// --------------------------------------------------------------------------------

// needs to be fixed up


void subSpecialDeleteClose()
{
   
   
   while ( OrdersTotal() > 0 ) {
      
   for(int COUNTER=0;COUNTER<OrdersTotal();COUNTER++)
   {
      if (!IsTradeAllowed() || IsTradeContextBusy() ) { Print("Busy ...");  return; }
      NULL0 = OrderSelect(COUNTER,SELECT_BY_POS,MODE_TRADES);
      
            if( OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP ) NULL0 = OrderDelete(OrderTicket(),Green);
            if (GetLastError() != 0) Print("Last error while deleting = " + GetLastError());
            
            if ( spread > cMAX_SPREAD*10) return;
            //if( OrderType() == OP_BUY || OrderType() == OP_SELL )  ticket=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),10,Violet);
            
            
            
            if ( OrderType() == OP_BUY ) NULL0 = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID),MarketInfo(OrderSymbol(),MODE_DIGITS)),5,White);
            if (GetLastError() != 0) Print("Last error while closing = " + GetLastError());
            
            if ( OrderType() == OP_SELL ) NULL0 = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(MarketInfo(OrderSymbol(),MODE_ASK),MarketInfo(OrderSymbol(),MODE_DIGITS)),5,White);
            if (GetLastError() != 0) Print("Last error while closing = " + GetLastError());
      
      
      
      }
   }
   
   return;
}





//-----------------------------------------------------------
//  buy/sell
//-----------------------------------------------------------

void subBUY() {
   subSetParams();
   subSETORDER(BUY,gHIGHEST_PRICE+(cBUFFER*pointvalue),gBUYLOTS2SEND);   
   return;
}


void subSELL() {
   subSetParams();
   subSETORDER(SELL,gLOWESTPRICE-(cBUFFER*pointvalue),gSELLLOTS2SEND);   
   return;
 }
 

// ----------------------------------
// additional close routine
// ----------------------------------

// to do - fix this up

void CloseAll() {
   
for (int i = 0; i < OrdersTotal(); i++) {
    NULL0 = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if (IsTradeContextBusy()) { Print("Busy ...");  return; }
    RefreshRates();
    
    if (OrderType() == OP_BUY && OrderSymbol() == Symbol() ) { 
        NULL0 = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID),MarketInfo(OrderSymbol(),MODE_DIGITS)),cSLIPPAGE,White);
    }
    
    if (OrderType() == OP_SELL  && OrderSymbol() == Symbol() ) { 
        NULL0 = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(MarketInfo(OrderSymbol(),MODE_ASK),MarketInfo(OrderSymbol(),MODE_DIGITS)),cSLIPPAGE,White);
    }
}
}


// ----------------------------------
// set important parameters
// ----------------------------------


void subSetParams() {


   
   RefreshRates();     
   spread = MarketInfo(Symbol(),MODE_SPREAD);
   
   subORDERSTATUS();
   subPriceCheck();

   ATR = iATR(NULL,0,20,1);
   
     
      
   if (cLOT_SIZE == 0) gBUYLOTS2SEND = (AccountEquity()/10000)/cLOT_DIVISOR; else gBUYLOTS2SEND = cLOT_SIZE; gBUYLOTS2SEND = NormalizeDouble(gBUYLOTS2SEND,2);
   if (cLOT_SIZE == 0) gSELLLOTS2SEND = (AccountEquity()/10000)/cLOT_DIVISOR; else gSELLLOTS2SEND = cLOT_SIZE; gSELLLOTS2SEND = NormalizeDouble(gSELLLOTS2SEND,2);

   gINCREMENT_VALUE = cINCREMENT_VALUE;
   if ( cINCREMENT_VALUE == 0 ) gINCREMENT_VALUE = cLOT_SIZE / cMAX_ORDERS;
   if ( cINCREMENT_VALUE < 0.01 ) gINCREMENT_VALUE = 0.01;
   if ( cINCREMENT_VALUE > 1 ) gINCREMENT_VALUE = 1;
   
   //if ( cMAX_ORDERS < 1 || cMAX_ORDERS > 100 ) cMAX_ORDERS = 100;
   
   if ( cINCREMENT_LOTS ) gBUYLOTS2SEND = gBIGGEST_BUY_LOT + gINCREMENT_VALUE; else gBUYLOTS2SEND = cLOT_SIZE;
   if ( cINCREMENT_LOTS ) gSELLLOTS2SEND = gBIGGEST_SELL_LOT + gINCREMENT_VALUE; else gSELLLOTS2SEND = cLOT_SIZE;
  

}





// -------------------------------------------------------------------------------------------------------------------------
// # of currencies open
// -------------------------------------------------------------------------------------------------------------------------



// I've totally forgotten how this works


// the idea is that every open order is parsed and the currency type is saved to an array. But it's random. So then we need to compare the strings
// somehow. So we just loop through the array, and compare a value to the next value. If they don't match, then add the difference to another array
// I think 

int subCURRENCIESOPEN() 
  {

   int NUMBEROFCURRENCIES=0;
   
   
   int NUM=0;
   string first_string;
   string second_string;
   int exists=0;
   int exists_counter=0;
   
   ArrayResize(ALLC,OrdersTotal(),0);
   ArrayResize(SORTED,0,0);
   
   
// load symbols from open orders into the ALLC array
   for(int counter0=0;counter0<OrdersTotal();counter0++)
     {
      NULL0=OrderSelect(counter0,SELECT_BY_POS,MODE_TRADES);
      ALLC[counter0]=OrderSymbol();
      NUM++;
     }

//compare   
   int sorted_counter=0;
   for(int counter1=0;counter1<ArraySize(ALLC);counter1++)
     {
      
      first_string = ALLC[counter1];
      exists = -1;
      exists_counter = 0;
      
      for (int counter2=0;counter2<ArraySize(SORTED);counter2++) {
         second_string = SORTED[counter2];
         exists = StringCompare(first_string, second_string, false);
         if ( exists == 0 ) exists_counter++;
      
      }
      
      if ( exists_counter == 0 ) { ArrayResize(SORTED,ArraySize(SORTED)+1,0); SORTED[sorted_counter] = first_string; sorted_counter++;    }
      //SORTED[counter1] = first_string;
      

     }


   return(ArraySize(SORTED));   

  }




  
//-------------------------------------------------------------------------------------------------------------------------
  
   
  
  string subSHOWALLC()   // this simply takes the contents of array ALLC and returns a nice string for display purposes
  {


string STRING ="";

   for(int COUNTER=0;COUNTER<ArraySize(ALLC);COUNTER++)
     {
      STRING = STRING + ALLC[COUNTER] + ", ";

     }

   return(STRING);

  }
  
//-------------------------------------------------------------------------------------------------------------------------
 
string subSHOWSORTED() // this returns a nice string for display purposes of the array called SORTED
  {


   string STRING ="";

   for(int COUNTER=0;COUNTER<ArraySize(SORTED);COUNTER++)
     {
      STRING = STRING + SORTED[COUNTER] + ", ";

     }

   return(STRING);

  }
  
  
    