#Persistent
#SingleInstance, Force

DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

global pspeaker := ComObjCreate("SAPI.SpVoice")
plistener:= ComObjCreate("SAPI.SpInprocRecognizer")
paudioinputs := plistener.GetAudioInputs()
plistener.AudioInput := paudioinputs.Item(0)
ObjRelease(paudioinputs)
pcontext := plistener.CreateRecoContext()
pgrammar := pcontext.CreateGrammar()
pgrammar.DictationSetState(0)
prules := pgrammar.Rules()
prulec := prules.Add("wordsRule", 0x1|0x20)
prulec.Clear()
pstate := prulec.InitialState()

global responses :={"run notepad": "runNotepad"
  , "Cortana": "cortana"
  , "Stop Cortana": "stopCortana"
  , "Listen Cortana": "listenCortana"}

  for Text, v in Responses
    pstate.AddWordTransition(ComObjParameter(13,0), Text)

  prules.Commit()
  pgrammar.CmdSetRuleState("wordsRule",1)
  prules.Commit()
  ComObjConnect(pcontext, "On")
  if (pspeaker && plistener && pcontext && pgrammar && prules && prulec && pstate){
    SplashTextOn,300,50,,Voice recognition OK
  } else {
    MsgBox, Sorry, voice recognition FAILED
  }
  sleep, 2000
  SplashTextOff
  return

  OnRecognition(StreamNum,StreamPos,RecogType,Result){
    sText:= Result.PhraseInfo().GetText()

    if (Responses[sText])
      gosub % Responses[sText]
    ObjRelease(sText)
  }

  ; ----------------------------------

  stopCortana:
    Coordmode, Mouse, Screen
    MouseGetPos, X, Y

    Click, 3585, 1998 ; input
    Click
    Send ^a
    Send {Delete}

    MouseMove, X, Y
  return

  listenCortana:
    Coordmode, Mouse, Screen
    MouseGetPos, X, Y

    Click, 3585, 1998 ; input
    Click
    Send ^a
    Send {Delete}

    Click, 3791, 1996 ; listen

    MouseMove, X, Y
  return

  cortana:
    Coordmode, Mouse, Screen
    MouseGetPos, X, Y

    Click 3556, 2090 ; focus
    Sleep, 50

    Click, 3436, 1994 ; reset

    Click, 3585, 1998 ; input
    Send ^a
    Send {Delete}

    Click, 3791, 1996 ; listen

    MouseMove, X, Y
  return

  runNotepad:
    Run Notepad
  return

  ; ^Escape::ExitApp

