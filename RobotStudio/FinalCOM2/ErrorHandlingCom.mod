MODULE ErrorHandlingCom    

    ! The socket connected to the client.
    VAR socketdev client_socket;
    
    ! The host and port that we will be listening for a connection on.
    PERS string hostCOM := "192.168.125.1";
    
    CONST num port := 1026;
    
    PROC Main ()
        IF RobOS() THEN
            hostCOM := "192.168.125.1";
        ELSE
            hostCOM := "127.0.0.1";
        ENDIF
        MainServer;
        
    ENDPROC

    PROC MainServer()
        
        ListenForAndAcceptConnection;   
        
        SetupInterrupts;
        
        WHILE TRUE DO
            WaitTime 1.0;
        ENDWHILE

        CloseConnection;
		
    ENDPROC

    PROC ListenForAndAcceptConnection()
        
        ! Create the socket to listen for a connection on.
        VAR socketdev welcome_socket;
        SocketCreate welcome_socket;
        
        ! Bind the socket to the host and port.
        SocketBind welcome_socket, hostCOM, port;
        
        ! Listen on the welcome socket.
        SocketListen welcome_socket;
        
        ! Accept a connection on the host and port.
        SocketAccept welcome_socket, client_socket \Time:=WAIT_MAX;
        
        ! Close the welcome socket, as it is no longer needed.
        SocketClose welcome_socket;
        
    ENDPROC
    
    ! Close the connection to the client.
    PROC CloseConnection()
        SocketClose client_socket;
    ENDPROC
    

ENDMODULE