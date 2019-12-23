-module(receiver).
-export([start_receiver_SaW/1, receiver_SaW/4, start_receiver_GBN/2,
        start_receiver_GBN_Timeout/2, receiver_GBN/5, receiver_GBN/6,
        start_receiver_SR/2, receiver_SR/6]).
% TIMEOUT: Determines how long (in milliseconds) the receiver process must wait before
% deciding to terminate.

-define(TIMEOUT, 5000).
-define(TIMEOUT_ACK, 500).
-define(SENDER_NODE, list_to_atom("sender@" ++ element(2, net_adm:dns_hostname(net_adm:localhost())))).

get_time() ->
    os:system_time(millisecond). 

% Start the Send and Wait receiver process
start_receiver_SaW(LossProb) ->
     case (0 =< LossProb) and (LossProb < 1) of
        true ->
            register(receiverProcess, spawn(receiver, receiver_SaW, [[], 0, 0, LossProb])),
	        io:format("***Stop and Wait receiver is up & running***~n", []);

        false ->
            io:format("Invalid frame loss probability. The value must be in range [0, 1).~n"),
            exit(self(), kill)
    end.

% Start the Go-Back-N receiver process
start_receiver_GBN(WindowSize, LossProb) ->
    case (0 =< LossProb) and (LossProb < 1) of
        true ->
            register(receiverProcess, spawn(receiver, receiver_GBN, [[], WindowSize, 0, 0, LossProb])),
	io:format("***Go-Back-N receiver is up & running***~n", []);

        false ->
            io:format("Invalid frame loss probability. The value must be in range [0, 1).~n"),
            exit(self(), kill)
    end.

% Start the Go-Back-N with timeout process
start_receiver_GBN_Timeout(WindowSize, LossProb) ->
    case (0 =< LossProb) and (LossProb < 1) of
        true ->
            register(receiverProcess, spawn(receiver, receiver_GBN, [[], WindowSize, 0, 0, LossProb, get_time()])),
	io:format("***Go-Back-N receiver with timeout is up & running***~n", []);

        false ->
            io:format("Invalid frame loss probability. The value must be in range [0, 1).~n"),
            exit(self(), kill)
    end.

% Start the Go-Back-N receiver process
start_receiver_SR(WindowSize, LossProb) ->
    case (0 =< LossProb) and (LossProb < 1) of
        true ->
            register(receiverProcess, spawn(receiver, receiver_SR, [[], WindowSize, 0, [], 0, LossProb])),
	io:format("***Selective Reapeat receiver is up & running***~n", []);

        false ->
            io:format("Invalid frame loss probability. The value must be in range [0, 1).~n"),
            exit(self(), kill)
    end.
    

receiver_SaW(ReceivedFrames, ExpectedSeqNo, TotalReceivedFramesCount, LossProb) ->
    receive
        {{Frame, ExpectedSeqNo}} ->
            case rand:uniform() < LossProb of
                true ->
                    io:format("[RECEIVER]   : Frame lost.~n", []),
                    receiver_SaW(ReceivedFrames, ExpectedSeqNo, TotalReceivedFramesCount, LossProb);
                false ->
                    io:format("[RECEIVER]   : Received frame ~p.~n", [{Frame, ExpectedSeqNo}]),
                    % Now send acknowledgement
                    io:format("[RECEIVER]   : Sending Ack of frame ~p.~n", [{Frame, ExpectedSeqNo}]),
                    {senderProcess, ?SENDER_NODE} ! {ack, (ExpectedSeqNo + 1) rem 2},
                    receiver_SaW(ReceivedFrames ++ [Frame], (ExpectedSeqNo + 1) rem (2), TotalReceivedFramesCount + 1, LossProb)
            end;

        {{Frame, InvalidSeqNo}} ->
            case rand:uniform() < LossProb of
                true ->
                    io:format("[RECEIVER]   : Frame lost.~n", []),
                    receiver_SaW(ReceivedFrames, ExpectedSeqNo, TotalReceivedFramesCount, LossProb);
                false ->
                    io:format("[RECEIVER]   : Received INVALID frame ~p (Expected Seq. No.: ~p).~n",
                                [{Frame, InvalidSeqNo}, ExpectedSeqNo]),
                    io:format("[RECEIVER]   : Sending VALID Ack ~p.~n", [ExpectedSeqNo]),
                    {senderProcess, ?SENDER_NODE} ! {ack, ExpectedSeqNo},
                    receiver_SaW(ReceivedFrames, ExpectedSeqNo, TotalReceivedFramesCount + 1, LossProb)
            end
    after
        ?TIMEOUT ->
            io:format("[RECEIVER]   : No frames received for ~pms. Assuming end of transmission.~n", [?TIMEOUT]),
            io:format("[RECEIVER]   : Total number of frames received: ~p~n", [TotalReceivedFramesCount]),
            io:format("[RECEIVER]   : Actual data frames received: ~p (Count: ~p)~n",
                        [ReceivedFrames, length(ReceivedFrames)]),
            io:format("[RECEIVER]   : Terminating process.~n", []),
            exit(self(), kill)
    end.

receiver_GBN(ReceivedFrames, WindowSize, ExpectedSeqNo, TotalReceivedFramesCount, LossProb) ->
    receive
        {{Frame, ExpectedSeqNo}} ->
            case rand:uniform() < LossProb of
                true ->
                    io:format("[RECEIVER]   : Frame lost.~n"),
                    receiver_GBN(ReceivedFrames, WindowSize, ExpectedSeqNo, TotalReceivedFramesCount, LossProb);
                false ->
                    io:format("[RECEIVER]   : Received frame ~p.~n", [{Frame, ExpectedSeqNo}]),
                    % Now send acknowledgement
                    io:format("[RECEIVER]   : Sending Ack of frame ~p.~n", [{Frame, ExpectedSeqNo}]),
                    {senderProcess, ?SENDER_NODE} ! {ack, (ExpectedSeqNo + 1) rem (WindowSize + 1)},
                    receiver_GBN(ReceivedFrames ++ [Frame], WindowSize, (ExpectedSeqNo + 1) rem (WindowSize + 1),
                                TotalReceivedFramesCount + 1, LossProb)
            end;

        {{Frame, InvalidSeqNo}} ->
            case rand:uniform() < LossProb of
                true ->
                    io:format("[RECEIVER]   : Frame lost.~n"),
                    receiver_GBN(ReceivedFrames, WindowSize, ExpectedSeqNo, TotalReceivedFramesCount, LossProb);
                false ->
                    io:format("[RECEIVER]   : Received INVALID frame ~p (Expected Seq. No.: ~p).~n",
                                [{Frame, InvalidSeqNo}, ExpectedSeqNo]),
                    io:format("[RECEIVER]   : Sending VALID Ack ~p.~n", [ExpectedSeqNo]),
                    {senderProcess, ?SENDER_NODE} ! {ack, ExpectedSeqNo},
                    receiver_GBN(ReceivedFrames, WindowSize, ExpectedSeqNo, TotalReceivedFramesCount + 1, LossProb)
            end
    after
        ?TIMEOUT ->
            io:format("[RECEIVER]   : No frames received for ~pms. Assuming end of transmission.~n", [?TIMEOUT]),
            io:format("[RECEIVER]   : Total number of frames received: ~p~n", [TotalReceivedFramesCount]),
            io:format("[RECEIVER]   : Actual data frames received: ~p (Count: ~p)~n",
                        [ReceivedFrames, length(ReceivedFrames)]),
            io:format("[RECEIVER]   : Terminating process.~n", []),
            exit(self(), kill)
    end.

receiver_GBN(ReceivedFrames, WindowSize, ExpectedSeqNo, TotalReceivedFramesCount, Timer, LossProb) ->
    receive
        {SenderPid, {Frame, ExpectedSeqNo}} ->
            io:format("[RECEIVER]   : Received frame ~p from ~p.~n", [{Frame, ExpectedSeqNo}, SenderPid]),
            % Now send acknowledgement
            case get_time() - Timer > ?TIMEOUT_ACK of
                true ->
                    io:format("[RECEIVER]   : Timeout! Sending expecting Ack ~p to ~p.~n", [ExpectedSeqNo, SenderPid]),
                    {senderProcess, ?SENDER_NODE} ! {receiverProcess, sent_ack, SenderPid, (ExpectedSeqNo + 1) rem (WindowSize + 1)},
                    receiver_GBN(ReceivedFrames ++ [Frame],
                                WindowSize, (ExpectedSeqNo + 1) rem (WindowSize + 1),
                                TotalReceivedFramesCount + 1, get_time(), LossProb);
                false ->
                    receiver_GBN(ReceivedFrames ++ [Frame],
                                WindowSize, ((ExpectedSeqNo + 1) rem (WindowSize + 1)),
                                TotalReceivedFramesCount + 1, Timer, LossProb)
            end;
            
        {SenderPid, {Frame, InvalidSeqNo}} ->
            io:format("[RECEIVER]   : Received INVALID frame ~p (Expected Seq. No.: ~p ) from ~p.~n",
                        [{Frame, InvalidSeqNo}, ExpectedSeqNo, SenderPid]),
            case get_time() - Timer > ?TIMEOUT_ACK of
                true ->
                    io:format("[RECEIVER]   : Sending expecting Ack ~p to ~p.~n", [ExpectedSeqNo, SenderPid]),
                    {senderProcess, ?SENDER_NODE} ! {receiverProcess, sent_ack, SenderPid, ExpectedSeqNo},
                    receiver_GBN(ReceivedFrames, WindowSize, ExpectedSeqNo,
                                TotalReceivedFramesCount + 1, get_time(), LossProb);
                false ->
                    receiver_GBN(ReceivedFrames, WindowSize, ExpectedSeqNo, TotalReceivedFramesCount + 1, Timer, LossProb)
            end
    after
        ?TIMEOUT ->
            io:format("[RECEIVER]   : No frames received for ~pms. Assuming end of transmission.~n", [?TIMEOUT]),
            io:format("[RECEIVER]   : Total number of frames received: ~p~n", [TotalReceivedFramesCount]),
            io:format("[RECEIVER]   : Actual data frames received: ~p (Count: ~p)~n",
                        [ReceivedFrames, length(ReceivedFrames)]),
            io:format("[RECEIVER]   : Terminating process.~n", []),
            exit(self(), kill)
    end.

current_receiver_window(ExpectedSeqNo, WindowSize) ->
    current_receiver_window(ExpectedSeqNo, WindowSize - 1, WindowSize, []).

current_receiver_window(ExpectedSeqNo, 0, _, ReceiverWindow) ->
    [ExpectedSeqNo] ++ ReceiverWindow;

current_receiver_window(ExpectedSeqNo, N, WindowSize, ReceiverWindow) ->
    current_receiver_window(ExpectedSeqNo, N-1, WindowSize, [(ExpectedSeqNo + N) rem (2*WindowSize)] ++ ReceiverWindow).

append_buffer(Frames, []) ->
    {Frames, []};

append_buffer([], Buffer) ->
    Temp = append_buffer(-1, Buffer, []),
    {[] ++ Temp, Buffer -- Temp};

append_buffer(Frames, Buffer) ->
    case lists:last(Frames) + 1 == hd(Buffer) of
        true ->
            Temp = append_buffer(lists:last(Frames), Buffer, []),
            {Frames ++ Temp, Buffer -- Temp};
        false ->
            []
    end.

append_buffer(_, [], List) ->
    List;

append_buffer(Prev, [H_B|T_B], List) ->
    case Prev + 1 == H_B of
        true ->
            append_buffer(H_B, T_B, List ++ [H_B]);
        false ->
            List
    end.

receiver_SR(ReceivedFrames, WindowSize, ExpectedSeqNo, Buffer, TotalReceivedFramesCount,
            LossProb) ->
        receive
        {{Frame, ExpectedSeqNo}} ->
            case rand:uniform() < LossProb of
                true ->
                    io:format("[RECEIVER]   : Frame lost.~n"),
                    receiver_SR(ReceivedFrames, WindowSize, ExpectedSeqNo, Buffer, TotalReceivedFramesCount, LossProb);
                false ->
                    io:format("[RECEIVER]   : Received EXPECTED frame ~p.~n", [{Frame, ExpectedSeqNo}]),
                    % Now send acknowledgement
                    io:format("[RECEIVER]   : Sending Ack of frame ~p.~n", [{Frame, ExpectedSeqNo}]),
                    {senderProcess, ?SENDER_NODE} ! {ack, (ExpectedSeqNo + 1) rem (2*WindowSize)},
                    {NewReceivedFrames, NewBuffer} = append_buffer(ReceivedFrames, lists:sort([Frame] ++ Buffer)),
                    receiver_SR(NewReceivedFrames, WindowSize, (lists:last(NewReceivedFrames) + 1) rem (2*WindowSize),
                                NewBuffer, TotalReceivedFramesCount + 1, LossProb)
            end;

        {{Frame, SeqNo}} ->
            case rand:uniform() < LossProb of
                true ->
                    io:format("[RECEIVER]   : Frame lost.~n"),
                    receiver_SR(ReceivedFrames, WindowSize, ExpectedSeqNo, Buffer, TotalReceivedFramesCount, LossProb);

                false ->
                    % Receiveable sequence numbers
                    ReceiverWindow = current_receiver_window(ExpectedSeqNo, WindowSize) -- [X rem (2*WindowSize) || X <- Buffer],
                    case lists:delete(SeqNo, ReceiverWindow) of
                        ReceiverWindow ->
                            io:format("[RECEIVER]   : Received OUT OF WINDOW frame ~p (Expected Window: [~p:~p]).~n",
                                        [{Frame, SeqNo}, hd(ReceiverWindow), lists:last(ReceiverWindow)]),
                            io:format("[RECEIVER]   : Sending Nak ~p.~n", [ExpectedSeqNo]),
                            {senderProcess, ?SENDER_NODE} ! {nak, ExpectedSeqNo},
                            receiver_SR(ReceivedFrames, WindowSize, ExpectedSeqNo,
                                        Buffer, TotalReceivedFramesCount + 1, LossProb);
                        _ ->
                            io:format("[RECEIVER]   : Received IN RANGE frame ~p.~n",
                            [{Frame, SeqNo}]),
                            io:format("[RECEIVER]   : Sending Nak ~p.~n", [ExpectedSeqNo]),
                            {senderProcess, ?SENDER_NODE} ! {nak, ExpectedSeqNo},
                            receiver_SR(ReceivedFrames, WindowSize, ExpectedSeqNo,
                                        lists:sort(Buffer ++ [Frame]), TotalReceivedFramesCount + 1, LossProb)
                    end
            end
    after
        ?TIMEOUT ->
            io:format("[RECEIVER]   : No frames received for ~pms. Assuming end of transmission.~n", [?TIMEOUT]),
            io:format("[RECEIVER]   : Total number of frames received: ~p~n", [TotalReceivedFramesCount]),
            io:format("[RECEIVER]   : Actual data frames received: ~p (Count: ~p)~n",
                        [ReceivedFrames, length(ReceivedFrames)]),
            io:format("[RECEIVER]   : Terminating process.~n", []),
            exit(self(), kill)
    end.
