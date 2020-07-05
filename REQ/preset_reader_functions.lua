--[[
@author Cotrino
@version 0.1
@noindex
--]]

function readReaBank(preset_file_name) 

  local i = 0
  local n = 1
  local tResult = {} -- the resulting table 
  local tLookup = {} -- reversed table where tLookup["name"] = index in tResult

  if not reaper.file_exists(preset_file_name) then
    msg("Preset file does not exist: " .. preset_file_name)
    return tResult
  end

  local lastMSB = 0
  local lastLSB = 0
  
  for line in io.lines(preset_file_name) do

      local sName = line:match(":%s*(.+)") or false
      local sTypePart = line:match("%s+([%w%.]+):")
      local sProgram = line:match("^(%d+)%s+")
      local sNumber = line:match("^%d+%s+(%d+)%s+")
      
      local sBank = line:match("^Bank") or false
      local sMSB = line:match("^Bank (%d+)")
      local sLSB = line:match("^Bank %d+%s+(%d+)")
      
      if sBank then
        lastMSB = tonumber(sMSB)
        lastLSB = tonumber(sLSB)
        --msg("Bank " .. lastMSB)
      elseif sName and sTypePart then -- sName ~= "<SHELL>"
        --msg(sName .. " " .. sTypePart .. " " .. sNumber)

          -- Get rating
          local iRating = 1 --_getRating(tRatingsData, sName)
          local universalName = sTypePart .. ": " .. sName
          local program = {
            name = universalName,
            desc = universalName, 
            bankMSB = lastMSB, 
            bankLSB = lastLSB, 
            programNr = tonumber(sProgram), 
            line = i, 
            instrument = sTypePart, 
            runningNr = n,
            rating = iRating
          }
          if not tLookup[universalName] then
            table.insert(tResult, program)
            tLookup[universalName] = #tResult
            n = n + 1
          end

      end
 
    i = i + 1
  end
  
  table.sort( tResult, _sortByRating )
  msg("- " .. n .. " presets found")
  return tResult

end

function readArpeggioBank(preset_file_name) 

  local i = 0
  local n = 1
  local tResult = {} 
  local tLookup = {} 

  if not reaper.file_exists(preset_file_name) then
    msg("Preset file does not exist: " .. preset_file_name)
    return tResult
  end

  for line in io.lines(preset_file_name) do
    
    if i == 0 then
    
      -- do nothing
      
    else
      local fields = line:split(";")
      local sType = fields[1] --line:match("^(%w+);") or false
      --local sNumber = fields[2] --line:match("^%w+;(%d+);")
      local sName = fields[3] --line:match("^%w+;%d+;(%w+)")

      if sName then
      
          local universalName = sType .. ": " .. sName
          local iRating = 1 --_getRating(tRatingsData, universalName)
          local arpeggio = {
            name = universalName,
            desc = universalName .. " ("..tonumber(fields[5]).." bars,"..tonumber(fields[6]).." BPM)",
            arpeggioNr = tonumber(fields[2]),
            signature = fields[4],
            length = tonumber(fields[5]),
            tempo = tonumber(fields[6]),
            line = i, 
            runningNr = n,
            rating = iRating
          }
          -- Get rating
          if not tLookup[universalName] then
            table.insert(tResult, arpeggio)
            tLookup[universalName] = #tResult
            n = n + 1
          end
          
      end
    end
 
    i = i + 1
  end
  
  table.sort( tResult, _sortByRating )
  msg("- " .. n .. " arpeggios found")
  return tResult

end

function _sortByRating(a, b)
  if a.rating > b.rating then
    return true
  elseif a.rating == b.rating then
    return a.name < b.name
  else
    return false
  end
end

