ECHO OFF

erl -compile sender transmitter receiver execute

:: Default parameters
SET NumOfFrames=1000
SET LossProb=0.05
SET WindowSize=31

IF "%1"=="" (
    echo No. of frames: %NumOfFrames%
    echo Prob. of frame loss: %LossProb%
    echo Window size: %WindowSize%

    start cmd /C erl -sname receiver -pa ebin -eval "receiver:start_receiver_GBN(%WindowSize%, %LossProb%)"
    start cmd /C erl -sname sender -pa ebin -eval "sender:start_sender_GBN(%NumOfFrames%,  %WindowSize%)"

) ELSE (
    echo No. of frames: %1
    echo Prob. of frame loss: %2
    echo Window size: %3

    start cmd /C erl -sname receiver -pa ebin -eval "receiver:start_receiver_GBN(%3, %2)"
    start cmd /C erl -sname sender -pa ebin -eval "sender:start_sender_GBN(%1, %3)"
)

PAUSE