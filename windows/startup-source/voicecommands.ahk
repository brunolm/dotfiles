#Persistent
#SingleInstance, Force

DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
SetMouseDelay, -1

; Voice Command state
toggle := false
Menu, Tray, Icon, %A_ScriptDir%\IconFalse.ico

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

global responses :={"Shutdown Cortana": "shutdownCortana"
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
  sleep, 500
  SplashTextOff
  return

  OnRecognition(StreamNum,StreamPos,RecogType,Result) {
    global toggle

    if (!toggle)
      return

    sText:= Result.PhraseInfo().GetText()

    if (Responses[sText])
      gosub % Responses[sText]
    ObjRelease(sText)
  }

  ; ----------------------------------

  shutdownCortana:
    global toggle
    toggle := false
    Menu, Tray, Icon, %A_ScriptDir%\IconFalse.ico
    SplashTextOn,300,50,,Cortana is OFF
    sleep, 500
    SplashTextOff
  return

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

  ; runNotepad:
  ;   Run Notepad
  ; return

  ; ----------------------------------
  ; ^Escape::ExitApp

  #F1::
    toggle := !toggle
    if (toggle) {
      SplashTextOff
      Menu, Tray, Icon, %A_ScriptDir%\IconTrue.ico
      SplashTextOn,300,50,,Cortana is ON
      sleep, 400
      SplashTextOff
    } else {
      SplashTextOff
      Menu, Tray, Icon, %A_ScriptDir%\IconFalse.ico
      SplashTextOn,300,50,,Cortana is OFF
      sleep, 400
      SplashTextOff
    }
  return
