--[[
@description MIDI HW Synth Program Browser
@author Cotrino
@about
  # External MIDI Synth Program & Arpeggio Browser

  A UI for selecting programs and arpeggios in your external hardware synthesizer.
  Selections including MIDI messages are inserted as media items into your project, 
  so that they can be freely moved within the song to change instruments on the fly. 

  UI loosely based on the Fast FX Finder: https://forum.cockos.com/showthread.php?t=229807
  
@version 0.1
@changelog
  0.1
  + First usable version, only tested with a Yamaha MX88
@provides
  REQ/midi_hardware_functions.lua
  REQ/preset_reader_functions.lua

--]]

-- HARD-CODED SETTINGS
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local REABANK_FILE = script_path .. "Yamaha_MX49.reabank"
local ARPEGGIOS_FILE = script_path .. "Yamaha_MX88_Arpeggios.csv"
local SYSEX_HEADER = { 0x43, 0x10, 0x7F, 0x17 } -- settings for Yamaha MX49/MX61/MX88. Check your manual
local DEMO_CHORD = { {pitch=48, vel=96}, {pitch=51, vel=96}, {pitch=56, vel=96} }

--
-- TODO Settings are hard-code. Load  and save external settings file
-- TODO Accelerate scrolls if scrolling frequently
-- TODO Tab with drum-kit and rhythm pattern, with checkbox "Enable drum pattern"
-- TODO Ratings (+1, -1) to sort instruments and arpeggios: buttons to rate, list adding "+" or "-" as prefix
-- FIXME Wrong listbox shadow after height change
--

--
-- ~\AppData\Roaming\REAPER\Scripts\ReaTeam Scripts\Development\Scythe library v3
--
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local Math = require("public.math")

-- functions to read presets for programs and arpeggios
package.path = package.path .. ";" .. script_path .. "?.lua"
require("REQ.preset_reader_functions")
require("REQ.midi_hardware_functions")

local infoFrameContent = "External HW Synth Program Browser\n";
function msg(message)

  infoFrameContent = infoFrameContent .. "\n" .. tostring(message)
  local info = GUI.findElementByName("InfoFrame")
  if info == nil then
    --reaper.ShowConsoleMsg(tostring(message) .. "\n")
  else
    info:val( infoFrameContent )
    -- scroll to bottom
    local len = info:getVerticalLength()
    info.windowPosition.y = len - info.windowH + 1
  end
  
end

local loaded = false
local programUI = {
  listUI = nil,
  tableData = {},
  fullListData = {},
  filteredListData = {},
  filteredListMapping = {},
  listSelected = 1,
  searchBox = nil,
  searchText = ""
}
local arpeggioUI = {
  listUI = nil,
  tableData = {},
  fullListData = {},
  filteredListData = {},
  filteredListMapping = {},
  listSelected = 1,
  searchBox = nil,
  searchText = ""
}
local lastState = {
 MSB = 0,
 LSB = 0,
 programNr = 0,
 programName = "",
 arpeggioSwitch = true,
 arpeggioNr = 1,
 arpeggioName = "",
 arpeggioLength = 1,
 arpeggioOut = false,
 insertedNotes = false,
 channel = 1
}

function loadPresets()

  -- read list of MIDI synth programs
  programUI.tableData = readReaBank(REABANK_FILE)
  --table.sort(tProgramData, sortByRating)
  for i = 1, #programUI.tableData do
    programUI.fullListData[i] = programUI.tableData[i].desc
  end
  programUI.listUI = GUI.findElementByName("ProgramList")
  _filterList(programUI, "")
  programUI.listUI:val(programUI.listSelected)
  
  -- read list of MIDI synth arpeggios
  arpeggioUI.tableData = readArpeggioBank(ARPEGGIOS_FILE)
  --table.sort(tProgramData, sortByRating)
  for i = 1, #arpeggioUI.tableData do
    arpeggioUI.fullListData[i] = arpeggioUI.tableData[i].desc
  end
  arpeggioUI.listUI = GUI.findElementByName("ArpeggioList")
  _filterList(arpeggioUI, "")
  arpeggioUI.listUI:val(arpeggioUI.listSelected)
  
  _resizeLists()
  
  local optionCheckboxes = GUI.findElementByName("Options")
  local options = {}
  options[1]=lastState.arpeggioSwitch
  options[2]=lastState.insertedNotes
  options[3]=lastState.arpeggioOut
  optionCheckboxes:val( options )
  
  local channelList = GUI.findElementByName("ChannelList")
  channelList:val( lastState.channel )
  
  msg("\nHow to: \n"
   .."1) Arm track for recording\n"
   .."2) Route track to your external MIDI device\n"
   .."3) Choose Input MIDI: All MIDI Inputs -> All channels (or choose the correct channel)\n"
   .."4) Record monitoring: On\n"
   .."5) Select track\n")

end

function selectProgramAndArpeggio()

  local programMapping = programUI.filteredListMapping[programUI.listSelected]
  local program = programUI.tableData[programMapping]
  local arpeggioMapping = arpeggioUI.filteredListMapping[arpeggioUI.listSelected]
  local arp = arpeggioUI.tableData[arpeggioMapping]
  local optionCheckboxes = GUI.findElementByName("Options")
  local options = optionCheckboxes:val()
  lastState.arpeggioSwitch = options[1]
  lastState.insertedNotes = options[2]
  lastState.arpeggioOut = options[3]
  local channelList = GUI.findElementByName("ChannelList")
  lastState.channel = channelList:val()
  lastState.programName = program.desc
  lastState.programNr = program.programNr
  lastState.MSB = program.bankMSB
  lastState.LSB = program.bankLSB 
  lastState.arpeggioName = arp.desc
  lastState.arpeggioNr = arp.arpeggioNr
  lastState.arpeggioLength = arp.length
  
  local item, take = getTake( lastState.programName, lastState.arpeggioLength )
  if take == nil then
    return
  end

  updateTake( item, take, lastState, DEMO_CHORD, SYSEX_HEADER )
  
end

------------------------------------
-------- GUI Elements --------------
------------------------------------

local sizeRow1 = 112
local sizeRow2 = 64
local sizeRow3 = 20
local sizeRow4 = 352
local padding = 25
local window = GUI.createWindow({
  name = "External HW Synth Program Browser",
  w = 512,
  h = sizeRow1+sizeRow2+sizeRow3+sizeRow4+padding*3
})

local layer = GUI.createLayer({name = "MainLayer"})

layer:addElements( GUI.createElements(
  {
    name = "InfoFrame", type = "TextEditor",
    x = 0.0, y = 0.0, w = 512, h = sizeRow1,
    text = infoFrameContent,
    textColor = "white"
  },
  {
    name = "ChannelList", type = "Listbox",
    x = 64.0, y = sizeRow1+padding, w = 64, h = sizeRow2,
    list = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"},
    multi = false,
    caption = "Channel"
  },
  {
    name = "Options", type = "Checklist",
    x = 256.0, y = sizeRow1+padding-16, w = 128, h = sizeRow2,
    caption = "",
    options = {"Enable arpeggio", "Insert notes", "Output arpeggio to ch16"},
    frame = false
  },
  {
    name = "ProgramSearch", type = "Textbox",
    x = 0.0, y = sizeRow1+sizeRow2+padding*2, w = 256, h = sizeRow3,
    caption = "Program search", captionPosition = "top"
  },
  {
    name = "ArpeggioSearch", type = "Textbox",
    x = 256.0, y = sizeRow1+sizeRow2+padding*2, w = 256, h = sizeRow3,
    caption = "Arpeggio search", captionPosition = "top"
  },
  {
    name = "ProgramList", type = "Listbox",
    x = 0.0, y = sizeRow1+sizeRow2+sizeRow3+padding*3, w = 256, h = sizeRow4,
    list = programUI.fullListData,
    multi = false, caption = "",
    -- select program
    onMouseDown = function()
      local state = window.state
      local list = GUI.findElementByName("ProgramList")
      if state.preventDefault then return end
      -- If over the scrollbar, or we came from :onDrag with an origin point
      -- that was over the scrollbar...
      if list:isOverScrollBar(state.mouse.x) then
        local windowCenter = Math.round(
          ((state.mouse.y - list.y) / list.h) * #list.list
        )
        list.windowY = math.floor(Math.clamp(
          1,
          windowCenter - (list.windowH / 2),
          #list.list - list.windowH + 1
        ))
        list:redraw()
      else
        programUI.listSelected = list:getListItem(state.mouse.y)
        selectProgramAndArpeggio()
      end
    end,
    -- speed up scrolling
    onWheel = function()
      local state = window.state
      local list = GUI.findElementByName("ProgramList")
      if state.preventDefault then return end
      local dir = state.mouse.wheelInc > 0 and -1 or 1
      -- Scroll up/down X lines
      list.windowY = Math.clamp(1, list.windowY + dir*10, math.max(#list.list - list.windowH + 1, 1) )
      list:redraw()
    end
  },
  {
    name = "ArpeggioList", type = "Listbox",
    x = 256.0, y = sizeRow1+sizeRow2+sizeRow3+padding*3, w = 256, h = sizeRow4,
    list = arpeggioUI.fullListData,
    multi = false, caption = "",
    -- select arpeggio
    onMouseDown = function()
      local state = window.state
      local list = GUI.findElementByName("ArpeggioList")
      if state.preventDefault then return end
      -- If over the scrollbar, or we came from :onDrag with an origin point
      -- that was over the scrollbar...
      if list:isOverScrollBar(state.mouse.x) then
        local windowCenter = Math.round(
          ((state.mouse.y - list.y) / list.h) * #list.list
        )
        list.windowY = math.floor(Math.clamp(
          1,
          windowCenter - (list.windowH / 2),
          #list.list - list.windowH + 1
        ))
        list:redraw()
      else
        arpeggioUI.listSelected = list:getListItem(state.mouse.y)
        selectProgramAndArpeggio()
      end
    end,
    -- speed up scrolling
    onWheel = function()
      local state = window.state
      local list = GUI.findElementByName("ArpeggioList")
      if state.preventDefault then return end
      local dir = state.mouse.wheelInc > 0 and -1 or 1
      -- Scroll up/down X lines
      list.windowY = Math.clamp(1, list.windowY + dir*10, math.max(#list.list - list.windowH + 1, 1) )
      list:redraw()
    end
  }
))

function _resizeLists()

  local programList = GUI.findElementByName("ProgramList")
  local arpeggioList = GUI.findElementByName("ArpeggioList")

  window.h = gfx.h
  programList.h = window.h - programList.y
  arpeggioList.h = window.h - programList.y
  
  programList:recalculateWindow()
  arpeggioList:recalculateWindow()
    
end

function _filterList(element, searchText)

  if searchText == "" then
    element.filteredListData = element.fullListData
    element.filteredListMapping = {}
    for i = 1, #element.fullListData do
      element.filteredListMapping[i] = i
    end
  else
    --msg("Filtering to " .. searchText)
    element.filteredListData = {}
    element.filteredListMapping = {}
    local n = 1
    for i = 1, #element.fullListData do
      local text = element.fullListData[i]
      if text:lower():find(element.searchText, 1, true) then
        element.filteredListData[n] = text
        element.filteredListMapping[n] = i
        n = n + 1
      end
    end
  end
  element.listUI.list = element.filteredListData
  element.listUI:redraw()
    
end

-- This will be run on every update loop of the GUI script; anything you would put
-- inside a reaper.defer() loop should go here. (The function name doesn't matter)
local function Main()

  if not window == nil and loaded == false then
    loadPresets()
    loaded = true
  end
  
  -- Prevent the user from resizing the window
  if window.state.resized then
    _resizeLists()
  end
  
  -- Check if typing in search window
  if programUI.searchBox == nil or arpeggioUI.searchBox == nil then
    programUI.searchBox = GUI.findElementByName("ProgramSearch")
    arpeggioUI.searchBox = GUI.findElementByName("ArpeggioSearch")
  else
    local programText = programUI.searchBox:val()
    if programText ~= programUI.searchText then
      programUI.searchText = programText:lower()
      _filterList(programUI, programUI.searchText)
    end
    local arpeggioText = arpeggioUI.searchBox:val()
    if arpeggioText ~= arpeggioUI.searchText then
      arpeggioUI.searchText = arpeggioText:lower()
      _filterList(arpeggioUI, arpeggioUI.searchText)
    end
  end
  
end

-- Open the script window and initialize a few things
window:addLayers(layer)
window:open()

-- Tell the GUI library to run Main on each update loop
-- Individual elements are updated first, then GUI.func is run, then the GUI is redrawn
GUI.func = Main

-- How often (in seconds) to run GUI.func. 0 = every loop.
GUI.funcTime = 0

-- Start the main loop
GUI.Main()
loadPresets()

