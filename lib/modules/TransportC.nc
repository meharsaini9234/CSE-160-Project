configuration TransportC{
    provides interface MidTransport;
}

implementation{
    components TransportP;
    components IPC;

    components new TimerMilliC() as TcpRetryTimer;

    MidTransport = TransportP.MidTransport;

    TransportP.IP -> IPC.IP;
    TransportP.RetryTimer -> TcpRetryTimer;
}