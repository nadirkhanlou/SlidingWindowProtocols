# SlidingWindowProtocols
Simulation of Sliding Window Protocols of the computer networks Data Link layer in Erlang

Implemented protocols
  - Stop-and-Wait
  - Go-Back-N
  - Selective Repeat

To run the simulation of each protocol, run the .bat file associated with that protocol. You can pass your desired parameters as command line argument to each .bat file.
Arguments:
  - Number of frames to be sent
  - Packet loss probability
  - Window Size

For example:
```
./run-selective-repeat.bat 10000 0.05 64
./run-stop-and-wait.bat 2500 0.10
```
  
