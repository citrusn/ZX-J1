import strformat, tables

type 
  forthWord = ref forthWordObj
  forthWordObj = object
    la, len, ca : uint
    name: string
  
  TypeWordField = enum
    lfa, nfa, cfa

  sourceLine = ref sourceLineObj
  sourceLineObj = object
    idx: int
    field: TypeWordField
    fw: forthWord

proc disasmWithLabels (insn: uint16, 
                  tbl: TableRef[int, sourceLine]): string =
  var 
    sx: array[0..3, string] = ["", "+1", "-2", "-1"]
  
  if (insn and 0x8000) > 0:
    #var lit = 
    result = fmt("push {insn and 0x7fff:04x}")
  else:
    let target = insn and 0x1fff
    let op = insn shr 13
    let ca=(target*2).int
    # echo "ca target:", ca
    let lbl = ( if tbl.hasKey(ca): tbl[ca].fw.name else: "" )
    case op:
      of 0: # jump
        result = fmt("branch {lbl} ({ca:04x})")
      of 1:  # conditional jump
        result = fmt("0branch {lbl} ({ca:04x})")
      of 2: # call
        result = fmt("call {lbl} ({ca:04x})")
      of 3: #alu
        if (insn and 0x1000)>0: #  r->pc 
          result = "RS/2->PC | "
        var alu = (insn shr 8) and 0xf
        case alu:
          of 0: result = result # & "noop"   # noop
          of 1: result = result & "copy"     # copy
          of 2: result = result & "+"  # +
          of 3: result = result & "and" # and
          of 4: result = result & "or" # or
          of 5: result = result & "xor" # xor
          of 6: result = result & "invert"   # invert
          of 7: result = result & "=" # =          
          of 8: result = result & "<" # < as signed        
          of 9: result = result & ">>"  # rshift
          of 10: result = result & "1-" # 1-
          of 11: result = result & "r@"  # r@          
          of 12: result = result & "@ [T/2]"   # @
          of 13: result = result & "<<" # lshift          
          of 14: result = result & "status" # dsp
          of 15: result = result & "u<"  # u<
          else: 
            raiseAssert "No correct ALU code"
        
        if sx[insn and 3'u16] != "":
          result = result & " | DS" & sx[insn and 3'u16]     # dstack +-
        if sx[(insn shr 2) and 3] != "" :
          result = result & " | RS" & sx[(insn shr 2) and 3] # rstack +-

        if (insn and 0x80)>0: # top->second
          result = result & " | T->S"
        if (insn and 0x40)>0: # top->return
          result = result &  " | T->Ret"
        if (insn and 0x20)>0: # second->[t]
          result = result & " | ! S->[T/2]"  
      
      else:
        result = fmt("error OP: {op}")

# четное?
proc even(i: int) : bool =
  if (i and 1) == 0:  true else: false

proc align(i: int): int =
  if even i: i+1 else: i

proc int2Hex(i: int): string = fmt("{i:04x}")

proc buildNameTable(start: int, buffer: openArray[uint8], 
                    tbl: TableRef[int, sourceLine] ) = 
  var cntWords = 0
  var st = start
  while st > 0:
    var ln = buffer[st].int and 0x1f  # длина имени 
    #echo "ln: " & $ln
    var nameWord=""
    for i in (st+1)..(st+ln):
      nameWord.add (chr buffer[i])
    
    var la = buffer[st-1]*256 + buffer[st-2] # адрес пред слова
    #echo "la: " & int2Hex(la.int)    
    var ca = st + 1 + ln + (if even ln: 1 else:0) # address calling(body)        
    cntWords = cntWords + 1
    # echo "ca: " , int2Hex(ca), " name: " ,  nameWord
    var w = forthWord( la:la, len:ln.uint, name:nameWord, ca:ca.uint )
    tbl[st-2.int] = sourceLine(field: lfa, fw: w)
    tbl[st] = sourceLine(field: nfa, fw: w)
    tbl[ca.int] = sourceLine(field: cfa, fw: w)
    st = la.int

  echo "Total words: ", cntWords
  echo "Table of labels len: ", tbl.len
  var w = forthWord( la:0, len:2.uint, name:"start", ca:0 )
  tbl[0] = sourceLine(field: cfa, fw: w)
  #echo repr tbl[0x1b44]
  
var
  wordsTable* = newTable[int, sourceLine](900)
  fn: string
  lastWord: int

proc disasm*(w: uint16) : string = 
  disasmWithLabels(w, wordsTable)

proc initDissasm*(fileName: string, lastAddress: int) =   
  ## Инициализует декомпилятор из файла образа
  ## с адреса NFA последнего определенного слова

  fn = fileName
  lastWord = lastAddress
  var btmem: array[0..0x4000, uint8]
  var f = open(fn)
  var sz = f.getFileSize().int32  
  echo "Readed bytes: ", f.readBuffer(btmem[0].addr, sz)
  f.close()  
  buildNameTable(lastWord, btmem, wordsTable)
  
proc main =
  initDissasm("j1.bin", 0x1b3e)

  var wdmem: array[0..0x4000, uint16]  
  var f = open("j1.bin")
  var sz = f.getFileSize().int32
  echo "Readed bytes: ", f.readBuffer(wdmem[0].addr, sz)
  f.close()  
  
  f=open("j1n.lst", fmWrite)
  var i=0
  while i < (sz shr 1):
    var w= wdmem[i]
    if wordsTable.hasKey((i*2).int):
      var sl = wordsTable[(i*2).int]
      case sl.field
      of lfa:         
        f.writeLine "---------- " & sl.fw.name & " ----------"
        f.writeLine fmt("{i*2:04x} {w:04x} ") & "lfa"
      of nfa:
        var l = sl.fw.len.int        
        f.writeLine fmt("{i*2:04x} {w:04x} nfa ") & $l
        l = (align(l)-1) shr 1
        for j in i+1..(i+l):
          w = wdmem[j]
          f.writeLine fmt("{j*2:04x} {w:04x} ")  
        i = i + l 
      of cfa:
        f.writeLine "\\ " & sl.fw.name & " cfa"
        f.writeLine fmt("{i*2:04x} {w:04x} ") & disasm(w)
    else:
        f.writeLine fmt("{i*2:04x} {w:04x} ") & disasm(w)
    i=i+1

if isMainModule:   
  main()
  