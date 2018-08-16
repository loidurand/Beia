/*
    ---------------  Send frames to Meshlium   ---------------

    Explanation: This example shows how to use HTTP requests to send
    Waspmote frames from Waspmote to Meshlium. This code also allow 
    you to save the frames in a LOG file with an sd card. If the 
    connection to the Meshlium is lost, you could use this code 
    to send the unsend frames when the connection is set up again. 


    Version:           1.0
    Design:            Loic Durand
    Implementation:    Loic Durand


    // SD file datas output
    ///////////////////////////////////////

    *____________NEW FRAME____________*   - position 0 -> get the text   
    Sun, 00/01/01, 00:14:55               - position 1 -> get the date
    76                                    - position 2 -> get the lenght
    3C3D3E860323344135343 ...             - position 3 -> get the frame
    OK                                    - position 4 -> get the state      [modulo 5]
    
*/

#include <stdio.h>
#include <Wasp4G.h>
#include <WaspFrame.h>

uint8_t connection_status;
uint8_t sd_answer;
char buff_RSSI[20]= "";
int position = 4 ; 

// SD file settings
///////////////////////////////////////

// define folder and file to store data
char path[]="/data";
char filename[]="/data/log";
char flength[5]= "";
// buffer to write into Sd File
char toWrite[200];

// define variables to read stored frames 
uint8_t frameSD[MAX_FRAME+1];
uint16_t lengthSD;

// APN settings
///////////////////////////////////////
char apn[] = "net";
char login[] = "";
char password[] = "";
///////////////////////////////////////

// SERVER settings
///////////////////////////////////////
char host[] =  "82.78.81.163"; //"pruebas.libelium.com" ; // "meshlium.beia-telemetrie.ro" ; // "82.78.81.163";
uint16_t port = 80;
///////////////////////////////////////

// define the Waspmote ID
char moteID[] = "Gas_4G_Loic";
int error;


void setup()
{
  USB.ON();
  USB.println(F("Start program"));
  
  // SD file 
  ///////////////////////////////////////
  // Set SD ON
  SD.ON();
  
  // create path
  sd_answer = SD.mkdir(path);
  if( sd_answer == 1 )
  { 
    USB.println(F("path created"));
  }

   // Create file for Waspmote Frames
  sd_answer = SD.create(filename);
  if( sd_answer == 1 )
  { 
    USB.println(F("/data/log created"));
  }

   // Initialise position
   if( position < SD.numln(filename) )
       position = SD.numln(filename) + 4 ;
       

  ///////////////////////////////////////

  // Show the remaining battery level
  // it's safer to run the program with a battery level > 50%  
  USB.print(F("Battery Level: "));
  USB.print(PWR.getBatteryLevel(),DEC);
  USB.print(F("%\n"));

  // set the Waspmote ID
  frame.setID(moteID);
  RTC.ON();

  //////////////////////////////////////////////////
  // 1. sets operator parameters
  //////////////////////////////////////////////////
  _4G.set_APN(apn, login, password);

  //////////////////////////////////////////////////
  // 2. Show APN settings via USB port
  //////////////////////////////////////////////////
  _4G.show_APN();

}


void loop()
{

  
  //////////////////////////////////////////////////
  // 1. Switch ON
  //////////////////////////////////////////////////
  SD.ON();
  RTC.ON();
  
  error = _4G.ON();
  if(error == 0)
  {
    USB.println(F("1. 4G module ready..."));

     ////////////////////////////////////////////////
    // 1.1. Check connection to network and continue
    ////////////////////////////////////////////////
    connection_status = _4G.checkDataConnection(30);
    
    if (connection_status == 0)
    {
      USB.println(F("1.1. Module connected to network"));

      // delay for network parameters stabilization
      //delay(5000);

      //////////////////////////////////////////////
      // 1.2. Get RSSI
      //////////////////////////////////////////////
      error = _4G.getRSSI();
      if (error == 0)
      {
        USB.print(F("1.2. RSSI: "));
        USB.print(_4G._rssi, DEC);
        USB.println(F(" dBm"));
        sprintf(buff_RSSI,"RSSI : %d dBm",_4G._rssi);
       // USB.print(buff_RSSI);
        
    ////////////////////////////////////////////////
    // 2. Create new frame
    ////////////////////////////////////////////////
    
    // Create new frame (ASCII)
    frame.createFrame(ASCII);

    
    // add frame fields
    frame.addSensor(SENSOR_TIME, RTC.hour, RTC.minute, RTC.second);
    frame.addSensor(SENSOR_STR, buff_RSSI);
    frame.addSensor(SENSOR_BAT, PWR.getBatteryLevel()); 

  /////////////////////////////////////////////////////   
  // 2. Append data into file
  /////////////////////////////////////////////////////  
  
  // Conversion from Binary to ASCII
  Utils.hex2str( frame.buffer, toWrite, frame.length);
  
  sd_answer = SD.appendln(filename, "*____________NEW FRAME____________*");
  sd_answer = SD.appendln(filename,RTC.getTime());
  sprintf(flength, "%d",frame.length);
  sd_answer = SD.appendln(filename,flength);
  sd_answer = SD.appendln(filename,toWrite);
  //sd_answer = SD.appendln(filename,frame.buffer);
  if( sd_answer == 1 )
  {
    USB.println(F("New frame appended to file"));
  }
  else 
  {
    USB.println(F("New frame append failed"));
  }

  
    ////////////////////////////////////////////////
    // 3. Send to Meshlium
    ////////////////////////////////////////////////
    USB.print(F("Sending the frame..."));
    error = _4G.sendFrameToMeshlium( host, port, frame.buffer, frame.length);

    // check the answer
    if ( error == 0)
    {
      USB.print(F("Done. HTTP code: "));
      USB.println(_4G._httpCode);
      USB.print("Server response: ");
      USB.println(_4G._buffer, _4G._length);

      sd_answer = SD.appendln(filename,"OK");
      if( sd_answer == 1 )
       {
         USB.println(F("OK"));
       }
      else 
      {
        USB.println(F("New frame append failed"));
      }
      
    }
    else
    {
      USB.print(F("Failed. Error code: "));
      USB.println(error, DEC);

      sd_answer = SD.appendln(filename,"NOK");
      if( sd_answer == 1 )
       {
         USB.println(F("NOK"));
       }
      else 
      {
        USB.println(F("New frame append failed"));
      }
    }
    
  }
      else
      {
        USB.println(F("1.2. Error calling 'getRSSI' function"));
      }
  }
  else
      {
        USB.println(F("1.3. Error calling 'getNetworkType' function"));
      }
      
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Send the unsend frames
    do
    {
    // Get 'OK/NOK' line -> SD.buffer
    SD.catln( filename, position, 1);
    if( (SD.buffer[0] == 'N') && (SD.buffer[1] == 'O') && (SD.buffer[2] == 'K') )
       {
         // Get frame.length line -> SD.buffer
        // SD.catln( filename, position − 2 , 1);
        // lengthSD = (uint16_t)atoi(SD.buffer) ;
         
         // Get frame line -> SD.buffer
         SD.catln( filename, position - 1 , 1);
         // initialize frameSD
         memset(frameSD, 0x00, sizeof(frameSD) ); 
    
        // conversion from ASCII to Binary 
        lengthSD = Utils.str2hex(SD.buffer, frameSD );
        USB.print(F("Sending the frame... again ..."));
        error = _4G.sendFrameToMeshlium( host, port, frameSD , lengthSD);
        if ( error == 0)
    {
      //add a function : write a frame in the sd card
      USB.println(F(" Done !"));
      position = position + 5 ;
    }
     else
    {
      USB.print(F("Failed. Error code: "));
      USB.println(error, DEC);
    }
    
       }
      else 
      {
        position = position + 5 ;
      }
    }
    while( (SD.buffer[0] == 'O') && (SD.buffer[1] == 'K') && (position < (SD.numln(filename) + 5)) );
        
  }
  else
  {
    // Problem with the communication with the 4G module
    USB.println(F("4G module not started"));
    USB.print(F("Error code: "));
    USB.println(error, DEC);
  }


  
  ////////////////////////////////////////////////
  // 4. Powers off the 4G module
  ////////////////////////////////////////////////
  USB.println(F("4. Switch OFF 4G module"));
  _4G.OFF();


  ////////////////////////////////////////////////
  // 5. Sleep
  ////////////////////////////////////////////////
   USB.println(F("enter sleep"));
  // Go to sleep disconnecting all the switches and modules
  // After 8 seconds, Waspmote wakes up thanks to internal watchdog
  PWR.sleep(WTD_8S, ALL_OFF);
  //PWR.deepSleep(“00:00:00:10”, RTC_OFFSET, RTC_ALM1_MODE2,ALL_OFF);

  USB.ON();
  USB.println(F("6. Wake up!!\n\n"));

}


