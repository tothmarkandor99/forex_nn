//+----------------------------------------------------------------------------------------------------------+
//|                                                                                      Haar wavelet 01.mq4 |
//|                                                                                                   tetsuo |
//|                                              indicatore per la trasformazione di un segnale secondo Haar |
//|                                                                                                          |
//|             il lavoro che ho usato per scrivere il funzione principale del codice lo potete trovare qui: |
//|                                                                              http://dmr.ath.cx/gfx/haar/ |
//|                                                         L'idea di lavorare a tale indicatore è nata qui: |
//|http://www.finanzaonline.com/forum/analisi-tecnica-t-s-e-psicologia-del-trading/1279444-haar-wavelet.html |
//+----------------------------------------------------------------------------------------------------------+
#property copyright "tetsuo creative"
#property link      ""

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1 Red

//parametri
extern string label1="--->scegli la dimensione del campione campione<---"; 
extern int campione=64;
extern string label2="--->Scegli la profondità della trasformazione<---";
extern int livello=1;
extern string label3="--->Scegli vero per plottare la trasformata<---";
extern string label4="--->Scegli falso per plottare le differenze<---";
extern bool plot=true;

//variabili globali
string nomeindicatore="Haar wavelet test ";
string versione="versione 0.2 ";
string tempo="";
string nomefilelog="";
string errmsg="";
string lastlog="";

int loghandle=NULL;
int tick=0;
int distanza=1;

double serie[1];
double movingaverage[1];
double movingdifference[1];



//---- buffers
double Haar[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicators
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,Haar);

//apre il file di log
   aprilog();
   logmsg("Aperta sessione log");
   logmsg("Simbolo "+Symbol());
   logmsg("Time frame: minuti "+Period());

//controllo coerenza sulla dimensione del campione
   if (campione<=0)
   {
   Alert("La dimensione del campione deve essere maggiore di 0!");
   campione=MathAbs(campione);
   }
   int a=1;
   while(MathPow(2,a)<campione)
   {
   a++;
   }
   if ((campione-MathPow(2,a))!=0)
   {
   Alert("La dimensione del campione deve essere una potenza del 2");
   Alert("Arrotondo il campione alla potenza di 2 più prossima");
   campione=MathPow(MathFloor(MathSqrt(campione)),2);
   Alert("La dimensione del campione è stata cambiata in "+campione); 
   }
   logmsg("la dimensione del campione usata è "+campione);
   
   //cantrollo di coerenza sul livello
   if (livello>a)
   {
   Alert("Il livello impostato è errato");
   Alert("Il livello massimo per questo campione è "+a);
   livello=a;
   Alert("Nuovo valore di livello: "+livello);
   }
   logmsg("Il livello usato è: "+livello);
   if (plot==true)logmsg("Viene plottata la trasformazione della serie");
   else logmsg("Viene plottata la differenza sulla serie"); 
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
//chiude il file di log
   chiudilog();
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   tick++;
   int    counted_bars=IndicatorCounted();
   
   
   logmsg("barra numero "+Bars);
   int size=campione-1;
   int m=1;
   ArrayResize(serie,campione);
   
   //copia nell'array serie il campione
   for (int i=0;i<=size;i++)
   {
   serie[size-i]=Close[i];
   }
   
   //funzione principale per la trasformazione del campione
   //tramite la trasformata di Haar
   //si prendono due valori contigui e se ne calcola la media e la differenza
   //del primo valore con la media appena calcolata. Per fare ciò si utilizzo due array differenti 
   //uno per la edia e uno per la differenza. Il risultato dei due array viene poi trascritto nell'array serie[]
   //che fungerà da campione per il ciclo successivo
   //
   while (m<=livello)
   {
   int temp_camp;
   int temp_camp2;
   temp_camp=temp_camp2;
   if (m==1) temp_camp=campione;
   temp_camp2=temp_camp/2;
   ArrayResize(movingaverage,temp_camp2);
   ArrayResize(movingdifference, temp_camp2);
   int n=0;
   for (i=0;i<temp_camp-1;i=i+2)
   {
   movingaverage[n]=(serie[i]+serie[i+1])/2;
   movingdifference[n]=serie[i]-movingaverage[n];
   //logmsg("movingaverage["+n+"]="+movingaverage[n]);
   //logmsg("movingdifference["+n+"]="+movingdifference[n]);
   n++;
   }
   for (i=0;i<temp_camp2;i++)
   {
   serie[i]=movingaverage[i];
   //logmsg("serie["+i+"]="+serie[i]);
   }
   for (i=temp_camp2;i<temp_camp2*2;i++)
   {
   serie[i]=movingdifference[i-temp_camp2];
   //logmsg("serie["+i+"]="+serie[i]);
   }
   m++;
   }
   
   //una volta completata la trasformazione ed il trasferimento in un unico array 
   //questo è pronto per essere copiato nell'indicatore per la visualizzazione e il risultato loggato nel file
   //tenere presente che il programma indicizza gli indicatori da destra a sinistra
   
   if (plot==true)
   //viene plotttata la trasformazione della serie(segnale)
   {
   int b=ArraySize(movingaverage);
   distanza=campione/b;
   for (i=0;i<campione;i++)
   {
   if (i%distanza!=0)
   {
   logmsg(i+"%"+distanza+"="+(i%distanza));
   Haar[i]=Haar[i-1];
   }
   else
   {
   Haar[i]=movingaverage[b-1];
   b--;
   }
   logmsg("Haar["+i+"]="+Haar[i]);
   }
   }
   else
   {
   //viene plottata le differenze sulla serie (rumore)
   b=ArraySize(movingdifference);
   distanza=campione/b;
   for (i=0;i<campione;i++)
   {
   if (i%distanza!=0)
   {
   logmsg(i+"%"+distanza+"="+(i%distanza));
   Haar[i]=Haar[i-1];
   }
   else
   {
   Haar[i]=movingdifference[b-1];
   b--;
   }
   logmsg("Haar["+i+"]="+Haar[i]);
   }
   }
   for (i=campione;i<Bars;i++)
   {
   Haar[i]=EMPTY_VALUE;
   }
   return(0);
  }
//+------------------------------------------------------------------+



//-------------------------------------------------------------------+
// sezione gestione file log                                                 +
//-------------------------------------------------------------------+

//funzione di creazione del file log

bool aprilog()
{
   
   nomefilelog=nomeindicatore+versione+Symbol()+".log";
   loghandle=FileOpen(nomefilelog,FILE_WRITE | FILE_BIN);
   
   if (loghandle == -1)
   {
    errmsg = "[ERROR] Cannot create log file";
    Alert (errmsg);
    Print (errmsg);
    return (false);
   }
    
   FileSeek (loghandle, 0, SEEK_END);
   return(true);
   
}


//scrittura del messaggio di log

bool logmsg (string msg)
{
  lastlog = "#" + tick + ", "
            + TimeToStr(TimeCurrent(),TIME_DATE|TIME_MINUTES|TIME_SECONDS)
            +", "+Symbol()+", "+msg;
    
  string outmsg = lastlog + "\r\n";
  
  if (! FileWriteString (loghandle, outmsg, StringLen(outmsg)))
  {
    int ErrCode = GetLastError();
    errmsg = "Error writing to output file, error code " +ErrCode;
    Alert (errmsg);
    Print (errmsg);
    return (false);
  }
    
  FileFlush (loghandle);
  return (true);
}


//chiusura file di log

bool chiudilog()
{
  FileClose (loghandle);
  return (true);
}

//-----------------fine sezione gestione log---------------------+