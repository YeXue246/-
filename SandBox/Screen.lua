local M = {}

local PrintString = UE.UKismetSystemLibrary.PrintString

function M.Print(text, duration, color, bPrintToLog)
    color = color or UE.FLinearColor(1, 1, 1, 1)
    duration = duration or 10
    bPrintToLog = bPrintToLog or false
    bPrintToLog = duration > 0
    PrintString(nil, text, true, bPrintToLog, UE.FLinearColor(1, 0, 0, 1), duration)
end


return M
