import strformat

proc disassembled (insn: uint16): string =
  var sx: array[0..3, string] = ["", "+1", "-2", "-1"]

  if (insn and 0x8000) > 0:
    #var lit = 
    result = fmt"push {insn and 0x7fff:#04x}"
  else:
    let target = insn and 0x1fff
    let op = insn shr 13
    case op:
      of 0: # jump
        result = fmt"branch {target:#04x}"
      of 1:  # conditional jump
        result = fmt"0branch {target:#04x}"
      of 2: # call
        result = fmt"call {target:#04x}"
      of 3: #alu
        if (insn and 0x1000)>0: #  r->pc 
          result = "RS/2->PC | "
        var alu = (insn shr 8) and 0xf
        case alu:
          of 0: result = result & "noop"   # noop
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
          of 12: result = result & "@ [top/2]"   # @
          of 13: result = result & "<<" # lshift          
          of 14: result = result & "dsp&rsp" # dsp
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
          result = result & " | ! S/2->[T]"  
      
      else:
        result = fmt"error OP: {op}"

proc main() =
  var
    f: File
    sz: int64
    memory:array[0..0x4000, uint16]
  
  f = open("j1.bin")
  sz = f.getFileSize() 
  echo f.readBuffer(memory[0].addr, sz)
  f.close()
  
  var w : uint16
  for i in 0..(sz shr 1 - 1):
    w = memory[i]
    echo fmt("{i*2:04x} {w:04x} ") & disassembled(w)

if isMainModule:
  main()