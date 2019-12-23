ECHO OFF

erl -compile sender transmitter receiver execute

:: Default parameters
SET NumOfFrames=10000
SET LossProb=0.25

IF "%1"=="" (
    echo No. of frames: %NumOfFrames%
    echo Prob. of frame loss: %LossProb%

    start cmd /C erl -sname receiver -pa ebin -eval "receiver:start_receiver_SaW(%LossProb%)"
    start cmd /C erl -sname sender -pa ebin -eval "sender:start_sender_SaW(%NumOfFrames%)"

) ELSE (
    echo No. of frames: %1
    echo Prob. of frame loss: %2

    start cmd /C erl -sname receiver -pa ebin -eval "receiver:start_receiver_SaW()"
    start cmd /C erl -sname sender -pa ebin -eval "sender:start_sender_SaW(%1)"
)

PAUSE