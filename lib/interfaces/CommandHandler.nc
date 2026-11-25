interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint8_t listenPort);
   event void setTestClient(uint16_t serverAddress, uint8_t srcPort, uint8_t destPort, uint16_t transferBytes);
   event void setClientClose(uint16_t serverAddress, uint8_t srcPort, uint8_t destPort);
   event void setAppServer();
   event void setAppClient();
   event void pingTTL(uint16_t destination, uint8_t ttl, uint8_t * payload);
   event void setPauseReceiver(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
   event void setResumeReceiver(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
}
