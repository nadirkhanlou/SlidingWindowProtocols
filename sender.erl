-module(sender).
-export([start_sender_SaW/1, sender_SaW/2, make_frames_SaW/1,
        start_sender_GBN/2, sender_GBN/3,make_frames_GBN/3,
        start_sender_SR/2, sender_SR/5, make_frames_SR/2]).

-define(Default_Directory, "C:/Users/InVaderrr/source/repos/network-erlang/").
-define(TIMEOUT_SaW, 50).
-define(TIMEOUT_GBN, 400).
-define(TIMEOUT_SR, 300).
-define(RECEIVER_NODE, list_to_atom("receiver@" ++ element(2, net_adm:dns_hostname(net_adm:localhost())))).


% cd("C:/users/invaderrr/source/repos/network-erlang").

% Get current time in milliseconds
get_time() ->
    os:system_time(millisecond). 

% Generate frames for Stop and Wait
make_frames_SaW(N) ->
    make_frames_SaW(N, []).
make_frames_SaW(0, FrameList) ->
    [{0, 0}] ++ FrameList;
make_frames_SaW(N, FrameList) ->
    make_frames_SaW(N-1, [{N, N rem 2}] ++ FrameList).

% Start the Send and Wait sender process
start_sender_SaW(NumOfFrames) ->
    register(senderProcess, spawn(sender, sender_SaW, [make_frames_SaW(NumOfFrames - 1), 0])),
	io:format("***Stop and Wait sender is up & running***~n", []).

sender_SaW([], SentFramesNo) ->
    io:format("[SENDER]     : Data transmission successful!~n", []),
    io:format("[SENDER]     : Number of times a frame was sent: ~p!~n", [SentFramesNo]),
    io:format("[SENDER]     : Terminating process.~n", []),
    exit(self(), kill);

sender_SaW([{CurrentFrame, SeqNo} | FrameList], SentFramesNo) ->
    case rpc:call(?RECEIVER_NODE, erlang, whereis, [receiverProcess]) of
        undefined ->
            io:format("[SENDER]     : Receiver process is not up. Killing process.~n", []),
            exit(self(), kill);
        _ ->
            io:format("[SENDER]     : Sending frame ~p (Seq. No. ~p).~n", [CurrentFrame, SeqNo]),
            {receiverProcess, ?RECEIVER_NODE} ! {{CurrentFrame, SeqNo}},
            % c:flush(),
            await_result_SaW({CurrentFrame, SeqNo}, FrameList, SentFramesNo)
    end.

await_result_SaW({CurrentFrame, SeqNo}, FrameList, SentFramesNo) ->
    Ack = (SeqNo + 1) rem 2,
    receive
        {ack, Ack} ->
            io:format("[SENDER]     : Ack ~p received.~n", [Ack]),
            sender_SaW(FrameList, SentFramesNo + 1);

        {ack, _} ->
            io:format("[SENDER]     : Frame sent to receiver was duplicate.~n", []),
            io:format("[SENDER]     : Sending next frame.~n", []),
            sender_SaW(FrameList, SentFramesNo + 1)
    after
        ?TIMEOUT_SaW ->
           io:format("[SENDER]     : Timeout! Ack for frame ~p was not received.~n", [CurrentFrame]),
           io:format("[SENDER]     : Resending frame ~p.~n", [CurrentFrame]),
           sender_SaW([{CurrentFrame, SeqNo}] ++ FrameList, SentFramesNo + 1)

    end.

% Sliding Window protocols

send_frame(Frame) ->
    io:format("[SENDER]     : Sending frame ~p.~n", [Frame]),
    {receiverProcess, ?RECEIVER_NODE}  ! {Frame}.

send_window(Window) ->
    c:flush(),
    io:format("[SENDER]     : Sending window ~p.~n", [Window]),
    lists:foreach(fun send_frame/1, Window).

send_window_SR(Window, Timers) ->
    c:flush(),
    send_window_SR(Window, Timers, []).

send_window_SR([], _, NewTimers) ->
    NewTimers;

send_window_SR([H_W|T_W], [H_T|T_T], NewTimers) ->
    case get_time() - H_T > 100 of
        true ->
            io:format("[SENDER]     : Frame ~p timed out. Resending.~n", [H_W]),
            send_frame(H_W),
            send_window_SR(T_W, T_T, NewTimers ++ [get_time()]);
        false ->
            io:format("[SENDER]     : Not sending frame ~p.~n", [H_W]),
            send_window_SR(T_W, T_T, NewTimers ++ [H_T])
    end.

first_of(_, []) ->
    not_found;

first_of(Func, [H|T]) ->
    case Func(H) of
        true ->
            H;
        false ->
            first_of(Func, T)
    end.

% Generate frames for Stop and Wait
make_frames_GBN(N, WindowSize) ->
    make_frames_GBN(N, WindowSize, []).

make_frames_GBN(0, _, FrameList) ->
    [{0, 0}] ++ FrameList;

make_frames_GBN(N, WindowSize, FrameList) ->
    make_frames_GBN(N-1, WindowSize, [{N, N rem (WindowSize + 1)}] ++ FrameList).

% Start the Send and Wait sender process
start_sender_GBN(NumOfFrames, WindowSize) -> 
    register(senderProcess, spawn(sender, sender_GBN, [make_frames_GBN(NumOfFrames - 1, WindowSize), WindowSize, 0])),
	io:format("***Go-Back-N sender is up & running***~n", []).

sender_GBN([], _, SentFramesNo) ->
    receive
        _ ->
            sender_GBN([], 0, SentFramesNo)
    after
        ?TIMEOUT_GBN ->
            io:format("[SENDER]     : Data transmission successful!~n", []),
            io:format("[SENDER]     : Number of times a frame was sent: ~p!~n", [SentFramesNo]),
            io:format("[SENDER]     : Terminating process.~n", []),
            exit(self(), kill)
    end;

sender_GBN(FramesList, WindowSize, SentFramesNo) ->
    case rpc:call(?RECEIVER_NODE, erlang, whereis, [receiverProcess]) of
        undefined ->
            io:format("[SENDER]     : Receiver process is not up. Killing process.~n", []),
            exit(self(), kill);

        {badrpc,nodedown} ->
            io:format("[SENDER]     : Receiver node is not up. Killing process.~n", []),
            exit(self(), kill);

        _ ->
            Window = lists:sublist(FramesList, 1, WindowSize),
            WindowSeqNums = [SeqNum || {_, SeqNum} <- Window],
            send_window(Window),
            % c:flush(),

            await_result_GBN(FramesList, WindowSize, WindowSeqNums, SentFramesNo + length(Window))
    end.

await_result_GBN(FramesList, WindowSize, WindowSeqNums, SentFramesNo) ->
    S_n = (lists:last(WindowSeqNums) + 1) rem (WindowSize + 1),
    Temp = WindowSeqNums ++ [S_n],
    receive
        {ack, Ack} ->
            case string:chr(Temp, Ack) of
                0 ->
                    io:format("[SENDER]     : INVALID Ack ~p received.~n", [Ack]),
                    await_result_GBN(FramesList, WindowSize, WindowSeqNums, SentFramesNo);

                Idx ->
                    io:format("[SENDER]     : VALID Ack ~p recevied.~n", [Ack]),
                    sender_GBN(lists:sublist(FramesList, Idx, length(FramesList)), WindowSize, SentFramesNo)
            end
    after
        ?TIMEOUT_GBN ->
            io:format("[SENDER]     : TIMEOUT! Resending window.~n", []),
            sender_GBN(FramesList, WindowSize, SentFramesNo)
    end.

% Generate frames for Stop and Wait
make_frames_SR(N, WindowSize) ->
    make_frames_SR(N, WindowSize, []).

make_frames_SR(0, _, FrameList) ->
    [{0, 0}] ++ FrameList;

make_frames_SR(N, WindowSize, FrameList) ->
    make_frames_SR(N-1, WindowSize, [{N, N rem (2*WindowSize)}] ++ FrameList).

% Start the Send and Wait sender process
start_sender_SR(NumOfFrames, WindowSize) -> 
    register(senderProcess, spawn(sender, sender_SR,
            [make_frames_SR(NumOfFrames - 1, WindowSize), WindowSize, lists:duplicate(WindowSize, 0), 0, 0])),
	io:format("***Selective Repeat sender is up & running***~n", []).

sender_SR([], _, _, SentFramesNo, _) ->
    receive
        _ ->
            sender_SR([], 0, [], SentFramesNo, 0)
    after
        ?TIMEOUT_SR ->
            io:format("[SENDER]     : Data transmission successful!~n", []),
            io:format("[SENDER]     : Number of times a frame was sent: ~p!~n", [SentFramesNo]),
            io:format("[SENDER]     : Terminating process.~n", []),
            exit(self(), kill)
    end;

% End transmission if stalled for 10 iterations
sender_SR(_, _, _, SentFramesNo, 10) ->
    sender_SR([], 0, 0, SentFramesNo, 0);

sender_SR(FramesList, WindowSize, Timers, SentFramesNo, Stalled) ->
    case rpc:call(?RECEIVER_NODE, erlang, whereis, [receiverProcess]) of
        undefined ->
            io:format("[SENDER]     : Receiver process is not up. Killing process.~n", []),
            exit(self(), kill);
        _ ->
            Window = lists:sublist(FramesList, 1, WindowSize),
            WindowSeqNums = [SeqNum || {_, SeqNum} <- Window],
            CurrentTimers = send_window_SR(Window, Timers),

            S_n = (lists:last(WindowSeqNums) + 1) rem (2*WindowSize),
            receive
                {ack, Ack} ->
                    case string:chr(WindowSeqNums, Ack) of
                        0 ->
                            io:format("[SENDER]     : INVALID Ack ~p received.~n", [Ack]),
                            sender_SR(FramesList, WindowSize, CurrentTimers, SentFramesNo, Stalled + 1);

                        Idx ->

                            io:format("[SENDER]     : VALID Ack ~p recevied.~n", [Ack]),
                            NewTimers = lists:duplicate(Idx - 1, get_time()) ++ lists:nthtail(Idx - 1, CurrentTimers),
                            sender_SR(lists:nthtail(Idx - 1,FramesList), WindowSize, NewTimers, SentFramesNo, 0)
                    end;
                {ackk, S_n} ->
                   io:format("[SENDER]     : VALID Ack ~p recevied.~n", [S_n]),
                    NextWindowSize = min(WindowSize, length(FramesList) - WindowSize + 1),
                    io:format("***MIN:~p~n", [NextWindowSize]),
                    NewTimers = lists:duplicate(NextWindowSize, get_time()),
                    sender_SR(lists:nthtail(WindowSize, FramesList), NextWindowSize, NewTimers, SentFramesNo, 0);

                {nak, S_n} ->
                    io:format("[SENDER]     : IN RANGE Nak ~p recevied.~n", [S_n]),
                    NextWindowSize = min(WindowSize, length(FramesList) - WindowSize + 1),
                    io:format("***MIN:~p~n", [NextWindowSize]),
                    NewTimers = lists:duplicate(NextWindowSize, get_time()),
                    sender_SR(lists:nthtail(WindowSize, FramesList), NextWindowSize, NewTimers, SentFramesNo, 0);

                {nak, Nak} ->
                    case string:chr(WindowSeqNums, Nak) of
                        0 ->
                            io:format("[SENDER]     : OUT OF RANGE Nak ~p received.~n", [Nak]),
                            sender_SR(FramesList, WindowSize, CurrentTimers, SentFramesNo, Stalled + 1);

                        Idx ->
                            io:format("[SENDER]     : IN RANGE Nak ~p recevied.~n", [Nak]),
                            Frame = first_of(fun({_,SeqNo}) -> SeqNo == Nak end, FramesList),
                            send_frame(Frame),
                            NewTimers = lists:sublist(CurrentTimers,Idx - 1) ++ [get_time()] ++ lists:nthtail(Idx,CurrentTimers),
                            sender_SR(FramesList, WindowSize, NewTimers, SentFramesNo + 1, 0)
                    end

            after
                ?TIMEOUT_SR ->
                    io:format("[SENDER]     : TIMEOUT! Resending window.~n", []),
                    sender_SR(FramesList, WindowSize, CurrentTimers, SentFramesNo, Stalled + 1)
            end
    end.