--[[
@author Cotrino
@version 0.1
@noindex
--]]

local isPlaying = false
local playTime = 0 -- seconds
local chord = nil
local sysexBytesHeader = nil
local measure = {
  lengthInSeconds = 0,
  lengthInPPQs = 0
}

--------------------
-- MAIN FUNCTIONS --
--------------------

function getTake(takeName, length)

  local track = reaper.GetSelectedTrack(0, 0)
  if track == nil then
    msg("Select a track routed to your external MIDI device")
    return nil
  end
  local cursorPosition = reaper.GetCursorPosition()
  local item, take = _getMediaItemTakeAtPosition(track, cursorPosition)
  if take == nil then
    item = reaper.CreateNewMIDIItemInProj(track, cursorPosition, cursorPosition+8) -- max 8 measures long
    take = reaper.GetMediaItemTake(item, 0)
  else
    -- clear all MIDI events in take
    for i=0,reaper.MIDI_CountEvts(take)-1 do
      reaper.MIDI_DeleteEvt(take, 0)
    end
  end
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "EXT_" .. takeName, true)
  -- change length of the item to arpeggio length (even if switched off)
  reaper.SetActiveTake(take)
  measure.lengthInSeconds = _GetCurrentMeasureLengthInSeconds()
  measure.lengthInPPQs = _GetCurrentMeasureLengthInPPQ(take)
  --msg("Measure length: " .. measure.lengthInSeconds .. " s, " .. measure.lengthInPPQs .. " PPQs")
  reaper.SetMediaItemLength(item, length * measure.lengthInSeconds, true)
  return item, take
 
end

function updateTake(item, take, state, demoChord, sysexHeader)

  --msg("Program: " .. state.programName .. ", MSB/LSB: " .. state.MSB .. "/" .. state.LSB .. ", program: " .. state.programNr, " .. arpeggio switch: " .. state.arpeggioSwitch .. ", arpeggio: " .. state.arpeggioName .. ", arpeggio nr: " .. state.arpeggioNr)
  
  chord = demoChord
  sysexBytesHeader = sysexHeader
  local selected = false
  local muted = false
  local channel = state.channel
  
  -- Voice select:
  -- 37 pp 01  MSB
  -- 37 pp 02  LSB
  -- 37 pp 03  PC
  -- Example: F0 43 10 7F 17 37 00 03 01 F7
  reaper.MIDI_InsertTextSysexEvt(take, selected, true, 1, 4, state.programName) -- write instrument name
  reaper.MIDI_InsertTextSysexEvt(take, selected, true, 2, 1, "MSB/LSB/programNR:"..state.MSB.."/"..state.LSB.."/"..state.programNr) -- write instrument details
  reaper.MIDI_InsertCC(take, selected, muted, 3, 0xB0, channel-1, 0, state.MSB)
  reaper.MIDI_InsertCC(take, selected, muted, 4, 0xB0, channel-1, 0x20, state.LSB)
  reaper.MIDI_InsertCC(take, selected, muted, 5, 0xC0, channel-1, state.programNr, 0)

  -- Arp SF1 Assign Type
  --   38 pp 3C 00 01  off, 001...999
  --   Example: F0 43 10 7F 17 38 00 3C 00 01 F7
  -- Melas: F0 43 10 7F 17 38 00 00 01 F7, 10 bytes, arpeggio switch on  
  -- Melas: F0 43 10 7F 17 36 30 00 00 F7, 10 bytes, arpeggio select ARP1
  -- Melas: F0 43 10 7F 17 36 30 00 01 F7, 10 bytes, arpeggio select ARP2
  -- Melas: F0 43 10 7F 17 36 30 00 02 F7, 10 bytes, arpeggio select ARP3
  local arpH = (state.arpeggioNr >> 7) & 0x7F
  local arpL = state.arpeggioNr & 0x7F
  --msg( arpNr .. " = " .. arpH .. " " .. arpL)
  --_sendSysex(take, 7, {0x38, channel-1, 0x06, 0x1} )
  --_sendSysex(take, 8, {0x38, channel-1, 0x07, 0x0} )
  reaper.MIDI_InsertTextSysexEvt(take, selected, true, 6, 8, state.arpeggioName) -- write arpeggio name
  reaper.MIDI_InsertTextSysexEvt(take, selected, true, 7, 1, "ArpeggioNr:"..state.arpeggioNr) -- write arpeggio details
  _sendSysex(take, 8, {0x38, channel-1, 0x3C, arpH, arpL} )

  -- Arp Switch:
  --   pp = part number
  --   38 pp 00 00 Off
  --   38 pp 00 01 On
  --   Example: F0 43 10 7F 17 38 00 00 01 F7
  -- Melas: choose arpeggio in SF1, 11 bytes, F0 43 10 7F 17 38 00 3C 00 1B F7   
  -- Melas: choose arpeggio in SF2, 11 bytes, F0 43 10 7F 17 38 00 3E 01 5B F7 
  local switch = 0
  if state.arpeggioSwitch then
    switch = 1
  end
  reaper.MIDI_InsertTextSysexEvt(take, selected, true, 9, 1, "Arpeggio switch:"..switch)
  _sendSysex(take, 10, {0x38, channel-1, 0x00, switch} ) -- on:1, off:0

  -- Arp MIDI Out
  local arpOut = 0
  if state.arpeggioOut then
    arpOut = 1
  end
  reaper.MIDI_InsertTextSysexEvt(take, selected, true, 11, 1, "Arpeggio output to channel 16:"..arpOut)
  _sendSysex(take, 12, {0x38, channel-1, 0x01, arpOut} ) -- on:1, off:0
  _sendSysex(take, 13, {0x38, channel-1, 0x02, 0x0F} ) -- channel 16

  -- Drum Pattern:
  --reaper.MIDI_InsertTextSysexEvt(take, selected, true, 11, 1, "Drum pattern:")
  --_sendSysex(take, 12, {0x00, 0x05, 0x0B, 0x1} ) -- external MIDI clock
  --_sendSysex(take, 13, {0x36, 0x00, 0x49, 0x0} ) -- on:1, off:0
  --reaper.MIDI_InsertCC(take, selected, muted, 13, 0xFA, 0, 0, 0) -- play

  -- insert demo notes
  if state.insertedNotes then
    --local noteLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local noteLength = measure.lengthInPPQs * state.arpeggioLength
    for i=1, #chord do
      reaper.MIDI_InsertNote(take, false, false, 20, noteLength, channel-1, chord[i].pitch, chord[i].vel)
    end
  end

  -- play to send Sysex data
  playTime = measure.lengthInSeconds * state.arpeggioLength
  --msg("Playing " .. playTime .. " seconds")
  _playTake(item, channel, state.insertedNotes)
  
end

function MIDISendProgram(channel, state)

  reaper.StuffMIDIMessage(0, 0xB0+channel-1, 0x00, state.MSB)
  reaper.StuffMIDIMessage(0, 0xB0+channel-1, 0x20, state.LSB)
  reaper.StuffMIDIMessage(0, 0xC0+channel-1, state.programNr, 0x00)
  
end

--------------------
-- HELPERS --
--------------------

function _GetCurrentMeasureLengthInPPQ(take)
  local cursor_pos = _GetPlayOrEditCursorPos() -- from edit cursor or play position
  local startPPQ = reaper.MIDI_GetPPQPos_StartOfMeasure(take, 0)
  local endPPQ = reaper.MIDI_GetPPQPos_EndOfMeasure(take, 1)
  return endPPQ-startPPQ
end

-- https://forum.cockos.com/showthread.php?t=176536
function _GetCurrentMeasureLengthInSeconds()
  local cursor_pos = _GetPlayOrEditCursorPos() -- from edit cursor or play position
  local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(0, cursor_pos)
  local current_measure = reaper.TimeMap2_beatsToTime(0, fullbeats)
  local next_measure = reaper.TimeMap2_beatsToTime(0, fullbeats + cml)
  return next_measure - current_measure
end

function _GetPlayOrEditCursorPos()
  local play_state = reaper.GetPlayState()
  local cursor_pos
  if play_state == 1 then
    cursor_pos = reaper.GetPlayPosition()
  else
    cursor_pos = reaper.GetCursorPosition()
  end
  return cursor_pos
end

-- https://forum.cockos.com/showthread.php?t=178334
function _MIDISendNote(channel)

--  local deferCount2 = 0
--    
--  function _MIDISendNoteOffs()
--  
--    for i=1, #chord do
--      reaper.StuffMIDIMessage(0, 0x80+chord[i].chan-1, chord[i].pitch, chord[i].vel)
--    end
--    
--  end
--  
--  function _MIDIWaitForNoteOffs()
--  
--    local seconds = 5
--    if deferCount2 > 30*seconds then -- wait ~0.5s before sending the "noteoff" -event
--      _MIDISendNoteOffs()
--    else
--      reaper.defer(_MIDIWaitForNoteOffs)
--      deferCount2 = deferCount2+1
--    end
--    
--  end
  
  for i=1, #chord do
    reaper.StuffMIDIMessage(0, 0x90+channel-1, chord[i].pitch, chord[i].vel)
  end
--  _MIDIWaitForNoteOffs()
  
end

function _MIDISendNoteOffs(channel)

  for i=1, #chord do
    reaper.StuffMIDIMessage(0, 0x80+channel-1, chord[i].pitch, chord[i].vel)
  end
  
end

function _getMediaItemTakeAtPosition(track, cursorPosition)

  local itemCount = reaper.CountTrackMediaItems(track)
  for i = 0, itemCount-1 do
    item = reaper.GetTrackMediaItem(track, i)
    startPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION");
    endPosition = startPosition + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    if cursorPosition >= startPosition and cursorPosition <= endPosition then
      local take = reaper.GetMediaItemTake(item, 0)
      local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      if name:find("^EXT_") then
        return item, take
      end
    end
  end
  return nil

end

-- play take for a very short time
function _playTake(item, channel, insertedNotes)

  local deferCount = 0
  local secondsToStartNote = 0.1
  local secondsToStopNote = playTime
  local isNotePlaying = false
  
  function _stopTake()
    
    if not insertedNotes then
      _MIDISendNoteOffs(channel)
    end
    reaper.CSurf_OnStop()
    --reaper.CSurf_OnPause()
    --_setCursorToItemStart(item)
    isPlaying = false
    
  end
  
  function _waitForTakePlay()
  
    if deferCount > 30*secondsToStartNote and not insertedNotes and not isNotePlaying then
      _MIDISendNote(channel)
      isNotePlaying = true
    end
    
    if deferCount > 32*secondsToStopNote then
      _stopTake()
    else
      --reaper.UpdateTimeline()
      reaper.defer(_waitForTakePlay)
      deferCount = deferCount+1
    end
  
  end
  
  if isPlaying then
    _stopTake()
  end 
  _setCursorToItemStart(item)
  reaper.CSurf_OnPlay()
  isPlaying = true
  _waitForTakePlay()

end

function _setCursorToItemStart(item)
  local startPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION");
  reaper.SetEditCurPos(startPosition, false, false)
end

function _sendSysex(take, position, data)
  --F0 [...] F7
  --Change parameter: 
  --  F0  Start
  --  43   Yamaha ID
  --  1n   Device/Channel 0-F
  --  7F   Model ID
  --  17   Model ID
  --  aa  Address high
  --  aa  Address mid
  --  aa  Address low
  --  dd  Data
  local sysexBytes = {}
  for i = 1, #sysexBytesHeader do
    sysexBytes[i] = sysexBytesHeader[i]
  end
  local sysexString = ""
  local sysexMessage = ""
  -- add sysex message to header
  for i = 1, #data do
    sysexBytes[#sysexBytes+1] = data[i]
  end
  -- convert sysex byte array to string
  for i = 1, #sysexBytes do
    sysexString = sysexString .. string.char(sysexBytes[i])
    sysexMessage = sysexMessage .. string.format("%02x", sysexBytes[i]) .. " "
  end
  -- insert into take
  --msg("Sysex: " .. sysexMessage )
  -- boolean reaper.MIDI_InsertTextSysexEvt(MediaItem_Take take, boolean selected, boolean muted, number ppqpos, integer type, string bytestr)
  reaper.MIDI_InsertTextSysexEvt(take, true, false, position, -1, sysexString)
end

