#====================================================================
#
#               j1Debug - Nim's J1 debugger
#               (c) Copyright 2020-2021 Citrusn
#
#====================================================================

import strformat
import strutils
import resource/resource
import wNim/[wApp, wFrame, wHotkeyCtrl, wIcon, wStatusBar, wPanel, wTypes, 
            wStaticText, wMenuBar, wMenu, wTextCtrl, wFont]

import j1n
import dissasm

const
  UseAutoLayout = not defined(legacy)
  Title = if UseAutoLayout: "Autolayout J1 debugger" else: "J1 debugger"

type
  MenuID = enum idLayout1 = wIdUser, idLayout2, idLayout3, idStart, idExit

let app = App(wSystemDpiAware)
let frame = Frame(title=Title, size=(800, 500))
frame.icon = Icon("", 0) # load icon from exe file.

#let statusbar = StatusBar(frame)
let panel = Panel(frame)

const style = wAlignCentre or wAlignMiddle or wBorderSimple
const txtStyle = wVScroll or wBorderStatic or wTeMultiLine or wTeRich
let font = Font(pointSize = 10.0, faceName = "Consolas" )

let label1 = StaticText(panel, label="Memory:" ) #, style=nil")
let text1 = TextCtrl(panel, value="", style=txtStyle )
text1.setFont(font)

let label2 = StaticText(panel, label="Code:" ) 
let text2 = TextCtrl(panel, value="", style=txtStyle )
text2.setFont(font)

let label3 = StaticText(panel, label="CPU:" ) 
let text3 = TextCtrl(panel, value="", style=txtStyle)
text3.setFont(font)

let label4 = StaticText(panel, label="Data stack:" ) 
let text4 = TextCtrl(panel, value="", style=txtStyle)
text4.setFont(font)

let label5 = StaticText(panel, label="Return stack:" )
let text5 = TextCtrl(panel, value="", style=txtStyle)
text5.setFont(font)

let termio = TextCtrl(panel, value="", style=txtStyle)
termio.setFont(font)

proc startCPU() 

let menuBar = MenuBar(frame)
let menu = Menu(menuBar, "Layout")
menu.appendRadioItem(idLayout1, "Layout1").check()
menu.appendRadioItem(idLayout2, "Layout2")
menu.appendRadioItem(idLayout3, "Layout3")
menu.appendSeparator()
menu.append(idStart, "Start CPU")
menu.appendSeparator()
menu.append(idExit, "Exit")

proc layout1() =
  when UseAutoLayout:
    panel.autolayout """
      spacing: 8
      H:|-[col1]-[label3..5, text3..5(text1/3)]-|      
      H:|-[termio]-|
      V:|-[col1:[label1][text1]-[label2(label1)][text2(text1)]]-|
      V:|-[col2:[label3][text3]-[label4][text4]-[label5(label1)][text5(text4)]]-|
      V:|-[col1..2(70%)]-[termio]-|
      
    """

  else:
    panel.layout:
      text1:
        left == panel.left + 8
        top == panel.top + 8
        right + 8 == text3.left
        bottom + 8 == text2.top

      text2:
        left == text1.left
        top == text1.bottom + 8
        right + 8 == text5.left
        bottom + 8 == panel.bottom
        height == text1.height

      text3:
        left == text1.right + 8
        top == panel.top + 8
        right + 8 == panel.right
        bottom + 8 == text4.top
        width == text1.width

      text4:
        left == text3.left
        top == text3.bottom + 8
        right == text3.right
        bottom + 8 == text5.top
        height == text3.height

      text5:
        left == text4.left
        top == text4.bottom + 8
        right == text4.right
        bottom + 8 == panel.bottom
        height == text4.height

proc layout2() =
  when UseAutoLayout:
    panel.autolayout """
      spacing: 8
      H:|~[text4..5(text1+text2+text3+16)]~|
      H:|~[text2(text1)]-[text1(<=200@STRONG)]-[text3(text1)]~|
      V:|~[text4(text1*0.66)]-[text1..3(<=100@STRONG)]-[text5(text1*0.66)]~|
      C: WEAK: text1.width = panel.width / 4
      C: WEAK: text1.height = panel.height / 3
    """

  else:
    panel.layout:
      text1:
        centerX == panel.centerX
        centerY == panel.centerY
        WEAK:
          width == panel.width / 4
          height == panel.height / 3
        STRONG:
          width <= 200
          height <= 100

      text2:
        width == text1.width
        height == text1.height
        top == text1.top
        right + 8 == text1.left

      text3:
        width == text1.width
        height == text1.height
        top == text1.top
        left == text1.right + 8

      text4:
        left == text2.left
        right == text3.right
        height == text1.height * 0.66
        bottom + 8 == text1.top

      text5:
        left == text2.left
        right == text3.right
        height == text1.height * 0.66
        top == text1.bottom + 8

proc layout3() =
  when UseAutoLayout:
    panel.autolayout """
      spacing: 8
      H:|-[text1(60)]-[text2]-|
      H:|-[text1]-[text3(60)]-[text4]-|
      H:|-[text1]-[text3]-(>=8)-[text5(text5.height@WEAK1)]-|
      V:|-[text1]-|
      V:|-[text2(60@WEAK1)]-[text3]-|
      V:|-[text2]-[text4(60@WEAK1)]-[text5]-|
      V:[text4]-(>=8)-|
    """

  else:
    panel.layout:
      text1:
        STRONG:
          width == 60
          left == panel.left + 8
          top == panel.top + 8
          bottom + 8 == panel.bottom

      text2:
        STRONG:
          left == text1.right + 8
          right + 8 == panel.right
          top == panel.top + 8
          bottom + 8 <= panel.bottom
        WEAK:
          height == 60

      text3:
        STRONG:
          width == 60
          top == text2.bottom + 8
          left == text1.right + 8
          bottom + 8 == panel.bottom

      text4:
        STRONG:
          left == text3.right + 8
          top == text2.bottom + 8
          right + 8 == panel.right
          bottom + 8 <= panel.bottom
        WEAK:
          height == 60

      text5:
        STRONG:
          top == text4.bottom + 8
          bottom + 8 == panel.bottom
          right + 8 == panel.right
          left >= text3.right + 8
        WEAK:
          height == width

proc layout() =
  if menu.isChecked(idLayout1): layout1()
  elif menu.isChecked(idLayout2): layout2()
  elif menu.isChecked(idLayout3): layout3()

frame.idLayout1 do (): layout()
frame.idLayout2 do (): layout()
frame.idLayout3 do (): layout()
frame.idStart do (): startCPU()
frame.idExit do (): frame.close()
panel.wEvent_Size do (): layout()


proc Uint2Char(ui : uint16, nb: int) : char = 
  case nb
  of 0:
    if isAlphaNumeric(chr(ui and 0xFF)):
      chr(ui and 0xFF) 
    else:
      '.'
  of 1: 
    if isAlphaNumeric(chr(ui shr 8)):
      chr(ui shr 8)
    else:
      '.'
  else:
    raise newException(RangeDefect, "nb is wrong")
    
proc dumpTo(txtCtrl: wTextCtrl, buf_size: int, buffer : seq[uint16]) =  
  var
    h: string
    s: string
    c1, c2: char
  for i in 0..(buf_size):
    h = h & fmt("{i*16:04x}:  ")
    s = ""
    for j in (i*8)..(i*8+7):
      h = h &  fmt("{buffer[j]:04x}  ")
      c1 = Uint2Char(buffer[j], 0)
      c2 = Uint2Char(buffer[j], 1)
      s=s & c1 & c2
    h = h & "  " & s & "\r\n"
  txtCtrl.value = h

proc dumpFile(cpu: j1Cpu) = 
  let sz = (0x4000 shr 1 - 1) shr 3
  dumpTo(text1, sz, @(cpu.memory))

proc putcharww(c: uint16) =
  termio.appendText $(chr c and 0xff)

proc initCpuMem(cpu: j1Cpu, prg: string) = 
  var
    df: File    
  assert df.open(prg), "File " & prg & " not found"
  defer: df.close()
  assert df.readBuffer(cpu.memory[0].addr, 0x4000) == df.getFilesize  

proc displayCpu(cpu: j1Cpu ) = 
  var 
    h: string
  h =     fmt("top:{cpu.top:04x}\r\n")
  h = h & fmt("dsp:{cpu.dsp:04x}\r\n")
  h = h & fmt("rsp:{cpu.rsp:04x}\r\n")
  h = h & fmt(" pc:{cpu.pc:04x}\r\n")
  text3.value = h

proc showAsm(lst: string ) = 
  var 
    buf: string  
  buf = readFile(lst)
  text2.value = buf

proc helper (ctrl: wTextCtrl, dsp : int32, ar: openarray[uint16]) =
    var h: string
    ctrl.value = ""
    for i in 0..ar.len-1:
      h = fmt("{i+1:02d}  {ar[i]:04x}\r\n")
      if i <= dsp:
        ctrl.setFormat(font=nil, fgColor= -1, bgColor = wMediumGoldenrod)
      else: ctrl.setFormat(font=nil, fgColor= -1, bgColor = wWhite)
      ctrl.appendText h
    ctrl.showPosition 0

proc dumpRegsMemory(cpu: j1Cpu ) =
  var ctrl = text4
  var ar = cpu.ds
  var dsp = int32(cpu.dsp)-1
  helper(ctrl, dsp, ar)

  ctrl = text5
  ar = cpu.rs
  dsp = int32(cpu.rsp)-1
  helper(ctrl, dsp, ar)

var 
  cpu: j1Cpu
  insn: uint16

proc startCPU() =
  #while cpu.start:
  for i in 0..5000:
    cpu.pc = cpu.pc + 1
    cpu.executeCommand(insn)     
    app.setMessageLoopWait()
    insn = cpu.memory[cpu.pc]
  displayCpu(cpu)
  dumpRegsMemory(cpu)

cpu = j1Cpu.new
cpu.top = 0x0
cpu.dsp = 0x0
cpu.rsp = 0x0
cpu.pc  = 0x0
cpu.start = true
cpu.putch = putcharww
cpu.getch = j1n.getchar
insn = 0

initCpuMem(cpu, "j1.bin")
dumpFile(cpu)
initDissasm("j1.bin", 0x1b3e)
showAsm("j1n.lst")

layout()
frame.center()
frame.show()
app.mainLoop()
