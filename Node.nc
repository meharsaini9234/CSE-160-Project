/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 */

#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/transportPacket.h"

module Node {
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface CommandHandler;

   uses interface Flooding;
   uses interface NeighborDiscovery;
   uses interface RoutingTable;
   uses interface IP;
   uses interface DVRecieve;
   
   uses interface MidTransport;
}

implementation {
   #define TCP_VERBOSE_APP 1

   pack sendPackage;
   uint16_t pingSequence = 0;

   uint8_t testActive = FALSE;
   uint8_t testEstablished = FALSE;

   uint16_t testRemoteAddress = 0;
   uint8_t testLocalPort = 0;
   uint8_t testRemotePort = 0;

   uint16_t testTransferBytes = 0;
   uint16_t testAccepted = 0;

   task void produceTestData();
   task void consumeTestData();

   typedef struct{
      uint8_t used;
      uint16_t remoteAddress;
      uint8_t localPort;
      uint8_t remotePort;
      uint8_t paused;
      uint16_t consumed;
      uint8_t failed;
      uint16_t expectedBytes;
      uint16_t mismatches;   
      uint8_t expectedSet;    
   }test_receiver_t;

   test_receiver_t testReceivers[2];

   test_receiver_t* getTestReceiver(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      uint8_t i;

      for(i = 0; i < 2; i++){
         if(testReceivers[i].used && testReceivers[i].remoteAddress == remoteAddress && testReceivers[i].localPort == localPort && testReceivers[i].remotePort == remotePort){
            return &testReceivers[i];
         }
      }  
      for(i = 0; i < 2; i++){
         if(!testReceivers[i].used){
            testReceivers[i].used = TRUE;
            testReceivers[i].remoteAddress = remoteAddress;
            testReceivers[i].localPort = localPort;
            testReceivers[i].remotePort = remotePort;
            testReceivers[i].paused = FALSE;
            testReceivers[i].consumed = 0; 
            testReceivers[i].failed = FALSE;
            testReceivers[i].expectedBytes = 0;
            testReceivers[i].mismatches = 0;
            testReceivers[i].expectedSet = FALSE;

            return &testReceivers[i];
         }
      }  
      return NULL;
   }

   void reportTestResult(test_receiver_t* r){
      uint8_t passed;

      passed = r->expectedSet && !r->failed && r->consumed == r->expectedBytes && r->mismatches == 0;

      dbg(TRANSPORT_CHANNEL, "node=%u APP_TRANSFER_RESULT peer=%u " "localPort=%u remotePort=%u " "expectedSet=%u expected=%u consumed=%u " "mismatches=%u result=%s\n", TOS_NODE_ID, r->remoteAddress, r->localPort, r->remotePort, r->expectedSet, r->expectedBytes, r->consumed, r->mismatches, passed ? "PASS" : "FAIL");
   }

   // Prototypes
   void makePack(
      pack *Package,
      uint16_t src,
      uint16_t dest,
      uint16_t TTL,
      uint16_t protocol,
      uint16_t seq,
      uint8_t *payload,
      uint8_t length
   );


   event void Boot.booted() {
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }


   event void AMControl.startDone(error_t err) {

      if (err == SUCCESS) {
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call NeighborDiscovery.start();
         call RoutingTable.start(); //initialize routing table
      }
      else {
         // Retry until successful
         call AMControl.start();
      }
   }


   event void AMControl.stopDone(error_t err) {}


   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    if(len == sizeof(pack)){
      pack* myMsg = (pack*) payload;

      if(myMsg->protocol == PROTOCOL_CMD && myMsg->payload[0] == 'N' && myMsg->payload[1] == 'D'){
         call NeighborDiscovery.receive(*myMsg);
      }

      else if(myMsg->protocol == PROTOCOL_PING || myMsg->protocol == PROTOCOL_PINGREPLY || myMsg->protocol == PROTOCOL_TCP){
         call IP.receive(*myMsg);
      }

        // DV stuff
      else if(myMsg->protocol == PROTOCOL_DV){
         call DVRecieve.recieve(*myMsg);
      }

      else{   
         call Flooding.receive(*myMsg);   
      }
   }

      return msg;
   }


   event void CommandHandler.ping(
      uint16_t destination,
      uint8_t *payload
   ) {

      dbg(GENERAL_CHANNEL, "PING EVENT\n");

      makePack(
         &sendPackage,
         TOS_NODE_ID,
         destination,
         MAX_TTL,
         PROTOCOL_PING,
         pingSequence++,
         payload,
         PACKET_MAX_PAYLOAD_SIZE
      );

      call IP.send(sendPackage);
   }
   event void CommandHandler.pingTTL(
      uint16_t destination,
      uint8_t ttl, 
      uint8_t *payload
   ){
      dbg(GENERAL_CHANNEL, "PING EVENT with TTL %u\n", ttl);

      makePack(
         &sendPackage,
         TOS_NODE_ID,
         destination,
         ttl,
         PROTOCOL_PING,
         pingSequence++,
         payload,
         PACKET_MAX_PAYLOAD_SIZE
      );

      call IP.send(sendPackage);
   }
   event void IP.delivered(pack msg){
      if(msg.protocol == PROTOCOL_PING){
         dbg(ROUTING_CHANNEL, "Node %u received PING from %u\n", TOS_NODE_ID, msg.src);
      }
    else if(msg.protocol == PROTOCOL_PINGREPLY){
        dbg(ROUTING_CHANNEL, "Node %u received PING REPLY from %u\n", TOS_NODE_ID, msg.src);
      }
   }


   event void CommandHandler.printNeighbors() {
      call NeighborDiscovery.print();
   }

   event void CommandHandler.printRouteTable() {
      call RoutingTable.printTable();
   }

   event void CommandHandler.printLinkState() {}

   event void CommandHandler.printDistanceVector() {}

   event void CommandHandler.setTestServer(uint8_t listenPort) {
      dbg(TRANSPORT_CHANNEL, "Node %u starting TCP server on port %u\n", TOS_NODE_ID, listenPort);
      call MidTransport.listen(listenPort);
   }

   event void CommandHandler.setTestClient(uint16_t serverAddress, uint8_t srcPort, uint8_t destPort, uint16_t transferBytes){
      if(transferBytes > TCP_MAX_TRANSFER){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_INVALID_TRANSFER_LENGTH bytes=%u max=%u\n", TOS_NODE_ID, transferBytes, TCP_MAX_TRANSFER);
         return;
      }

      if(testActive) {
         dbg(TRANSPORT_CHANNEL, "node=%u APP_BUSY\n", TOS_NODE_ID);
         return;
      }
      testActive = TRUE;
      testEstablished = FALSE;   
      testRemoteAddress = serverAddress;
      testLocalPort = srcPort;
      testRemotePort = destPort; 
      testTransferBytes = transferBytes;
      testAccepted = 0; 
      dbg(TRANSPORT_CHANNEL, "Node %u connecting to Node %u srcPort=%u destPort=%u bytes=%u\n", TOS_NODE_ID, serverAddress, srcPort, destPort, transferBytes); 
      if(call MidTransport.connect(serverAddress, srcPort, destPort) != SUCCESS){
         testActive = FALSE;
         testEstablished = FALSE;
         dbg(TRANSPORT_CHANNEL, "node=%u APP_CONNECT_REJECTED peer=%u\n",TOS_NODE_ID, serverAddress);
      }
   }

   event void MidTransport.connected(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      if(!testActive || remoteAddress != testRemoteAddress || localPort != testLocalPort || remotePort != testRemotePort){
         return;
      }
      testEstablished = TRUE;
      dbg(TRANSPORT_CHANNEL, "node=%u APP_CONNECTED peer=%u\n", TOS_NODE_ID, remoteAddress);
      post produceTestData();
   }

   event void MidTransport.writeReady(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      if(!testActive || !testEstablished || remoteAddress != testRemoteAddress || localPort != testLocalPort || remotePort != testRemotePort){
         return;
      }

      if(testAccepted < testTransferBytes){
         post produceTestData();
      }
   }

   event void MidTransport.connectionFailed(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      uint8_t i;

      if(remoteAddress == testRemoteAddress && localPort == testLocalPort && remotePort == testRemotePort){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_TRANSFER_FAILED peer=%u accepted=%u expected=%u\n", TOS_NODE_ID, remoteAddress, testAccepted, testTransferBytes);
         testActive = FALSE;
         testEstablished = FALSE;
      }

      for(i = 0; i < 2; i++){
         if(testReceivers[i].used && testReceivers[i].remoteAddress == remoteAddress && testReceivers[i].localPort == localPort && testReceivers[i].remotePort == remotePort){
            testReceivers[i].failed = TRUE;
            dbg(TRANSPORT_CHANNEL, "node=%u APP_RECEIVER_FAILED consumed=%u\n", TOS_NODE_ID, testReceivers[i].consumed);
         }
      }

      post consumeTestData();
   }

   event void MidTransport.dataReady(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      test_receiver_t* r = getTestReceiver(remoteAddress, localPort, remotePort);

      if(r == NULL){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_RECEIVER_FULL peer=%u\n", TOS_NODE_ID,remoteAddress);
         return;
      }
      if(r->paused){
         return;
      }

      post consumeTestData();
   }

   event void MidTransport.connectionClosed(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      uint8_t i;

      if(remoteAddress == testRemoteAddress && localPort == testLocalPort && remotePort == testRemotePort){
         testActive = FALSE;
         testEstablished = FALSE;
      }

      for(i = 0; i < 2; i++){
         if(testReceivers[i].used && testReceivers[i].remoteAddress == remoteAddress && testReceivers[i].localPort == localPort && testReceivers[i].remotePort == remotePort){
            dbg(TRANSPORT_CHANNEL, "node=%u APP_RECEIVER_CLOSED consumed=%u\n", TOS_NODE_ID, testReceivers[i].consumed);
            reportTestResult(&testReceivers[i]);
            testReceivers[i].used = FALSE;
         }
      }
   }
   
   task void consumeTestData(){
      uint8_t slot;
      uint8_t buffer[11];
      uint8_t count;
      uint8_t i;
      uint8_t expected;
      uint8_t readSomething = FALSE;

      for(slot = 0; slot < 2; slot++){
         test_receiver_t* r = &testReceivers[slot];

         if(!r->used || r->paused){
            continue;
         }

         count = call MidTransport.read(r->remoteAddress, r->localPort, r->remotePort, buffer, sizeof(buffer));

         if(count == 0){
            if(r->failed){
               dbg(TRANSPORT_CHANNEL, "node=%u APP_RECEIVER_RELEASED consumed=%u\n", TOS_NODE_ID, r->consumed);
               reportTestResult(r);
               r->used = FALSE;
            }
            continue;
         }

         readSomething = TRUE;

         for(i = 0; i < count; i++){
            expected = (uint8_t)(r->consumed % 256);

            if(buffer[i] != expected){
               r->mismatches++;
               dbg(TRANSPORT_CHANNEL, "node=%u DATA_MISMATCH peer=%u offset=%u got=%u expected=%u\n", TOS_NODE_ID, r->remoteAddress, r->consumed, buffer[i], expected);
            }
            r->consumed++;
        }
         #if TCP_VERBOSE_APP
         dbg(TRANSPORT_CHANNEL, "node=%u conn=%u:%u->%u:%u APP_CONSUMED total=%u expected=%u mismatches=%u\n" TOS_NODE_ID, TOS_NODE_ID, r->localPort, r->remoteAddress, r->remotePort, r->consumed, r->expectedBytes, r->mismatches);
         #endif
      }


      if(readSomething){
         post consumeTestData();
      }
   }
 
   task void produceTestData(){
      uint8_t buffer[11];
      uint8_t requested;
      uint8_t accepted;
      uint8_t i;
      uint8_t batch;
      uint16_t remaining;
      uint8_t bufferFull = FALSE;

      if(!testActive || !testEstablished){
         return;
      }

      for(batch = 0; batch < 8; batch++){
         if(testAccepted >= testTransferBytes){
            break;
          }

         remaining = testTransferBytes - testAccepted;

         requested = remaining > sizeof(buffer) ? sizeof(buffer) : (uint8_t)remaining;

         for(i = 0; i < requested; i++){
            buffer[i] = (uint8_t)((testAccepted + i) % 256);
         }

         accepted = call MidTransport.write(testRemoteAddress, testLocalPort, testRemotePort, buffer, requested);

         if(accepted == 0){
            bufferFull = TRUE;
            break;
         }

         testAccepted += accepted;

         #if TCP_VERBOSE_APP
            dbg(TRANSPORT_CHANNEL, "node=%u conn=%u:%u->%u:%u APP_WRITE accepted=%u total=%u expected=%u\n" TOS_NODE_ID, TOS_NODE_ID, testLocalPort, testRemoteAddress, testRemotePort, accepted, testAccepted, testTransferBytes);
         #endif
         
         if(accepted < requested){
            bufferFull = TRUE;
            break;
         }
      }

      if(testAccepted == testTransferBytes){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_ALL_BYTES_ACCEPTED total=%u\n", TOS_NODE_ID, testAccepted);
         testActive = FALSE;
         return;
      }

      if(!bufferFull){
          post produceTestData();
      }
   }

   event void CommandHandler.setClientClose(uint16_t serverAddress, uint8_t srcPort, uint8_t destPort){
      dbg(TRANSPORT_CHANNEL, "Node %u requesting TCP close with Node %u\n", TOS_NODE_ID,serverAddress);
      call MidTransport.close(serverAddress, srcPort, destPort);
   }

   event void CommandHandler.setPauseReceiver(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      test_receiver_t* r = getTestReceiver(remoteAddress, localPort, remotePort);

      if(r == NULL){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_PAUSE_FAILED no receiver slot\n", TOS_NODE_ID);
         return;
      }
      r->paused = TRUE;
      dbg(TRANSPORT_CHANNEL, "node=%u APP_PAUSED peer=%u localPort=%u remotePort=%u\n", TOS_NODE_ID, remoteAddress, localPort, remotePort);
   }

   event void CommandHandler.setResumeReceiver(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
      test_receiver_t* r = getTestReceiver(remoteAddress, localPort, remotePort);
      if(r == NULL){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_RESUME_FAILED no receiver slot\n", TOS_NODE_ID);
        return;
      }
      r->paused = FALSE;
      dbg(TRANSPORT_CHANNEL, "node=%u APP_RESUMED peer=%u localPort=%u remotePort=%u\n", TOS_NODE_ID, remoteAddress, localPort, remotePort);
      post consumeTestData();
   }

   event void CommandHandler.setExpectTransfer(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort, uint16_t expectedBytes){
      test_receiver_t* r;
      if(expectedBytes > TCP_MAX_TRANSFER){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_INVALID_EXPECTED_LENGTH bytes=%u max=%u\n", TOS_NODE_ID, expectedBytes, TCP_MAX_TRANSFER);
         return;
      }

      r = getTestReceiver(remoteAddress, localPort, remotePort);

      if(r == NULL){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_EXPECT_FAILED no receiver slot\n", TOS_NODE_ID);
         return;
      }

      if(r->expectedSet || r->consumed != 0 || r->failed){
         dbg(TRANSPORT_CHANNEL, "node=%u APP_EXPECT_REJECTED\n", TOS_NODE_ID);
         return;
      }

      r->expectedBytes = expectedBytes;
      r->expectedSet = TRUE;

      dbg(TRANSPORT_CHANNEL, "node=%u APP_EXPECT_TRANSFER peer=%u expected=%u\n", TOS_NODE_ID, remoteAddress, expectedBytes);
   }

   event void CommandHandler.setAppServer() {}

   event void CommandHandler.setAppClient() {}


   void makePack(
      pack *Package,
      uint16_t src,
      uint16_t dest,
      uint16_t TTL,
      uint16_t protocol,
      uint16_t seq,
      uint8_t *payload,
      uint8_t length
   ) {

      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;

      memcpy(
         Package->payload,
         payload,
         length
      );
   }
}