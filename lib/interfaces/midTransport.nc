interface MidTransport{

    command void listen(uint8_t port);

    command void connect(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);

}