-- groovecats
-- v1.3.2 @quixotic7
-- https://norns.community/e/en/authors/quixotic7/groovecats
--
-- A weird cat sequencer thing

-- Add the names of your favorite cats, max of 8
local cat_names = {"Wednesday", "Swisher", "Franky", "Tigger", "Max", "Kittenface", "Colby"}

local version_number = "1.3.1"

local MAX_CATS = 7
local RND_MIDI_COUNT = 4 -- change to use more midi channels for randomize

Q7Util = include('lib/Q7Util')
ParamListUtil = include('lib/Q7ParamListUtil')
vector2d = include('lib/vector2d')
tabutil = include('lib/tabutil')
Particle = include('lib/particle')
ParticleEngine = include('lib/particleEngine')
PhysicsEngine = include('lib/physicsEngine')
PhysicsBody = include('lib/physicsBody')
GrooveCat = include('lib/grooveCat')
CollisionEvent = include('lib/collision_event')
GridFader = include('lib/gridfader')
NameSizer = include("lib/namesizer/namesizer")

local hsdelay = include('lib/halfsecond')
local MidiBangs = include('lib/midibangs')
local Grid_Events_Handler = include('lib/grid_events')

thebangs = include('thebangs/lib/thebangs_engine')
MusicUtil = require "musicutil"

engine.name = 'Thebangs'

local data_path = _path.data.."groovecats/"
local params_path = _path.data.."groovecats/params/"

g = grid.connect()

local controlSpecs = {}
controlSpecs.amp = controlspec.new(0, 1, 'lin', 0, 0.5, '')
controlSpecs.pan = controlspec.new(-1, 1, 'lin', 0, 0, '') 
controlSpecs.mod1 = controlspec.new(0, 1, 'lin', 0, 0.5, '%')
controlSpecs.mod2 = controlspec.new(0, 4, 'lin', 0, 1.0, '%')
controlSpecs.cutoff = controlspec.new(50, 5000, 'exp', 0, 800, 'hz')
-- controlSpecs.attack = controlspec.new(0.0001, 10, 'exp', 0, 0.01, 's')
-- controlSpecs.release = controlspec.new(0.0001, 10, 'exp', 0, 1.0, 's')
controlSpecs.attack = controlspec.new(0.005, 6, 'exp', 0, 0.01, 's')
controlSpecs.release = controlspec.new(0.005, 6, 'exp', 0, 1.0, 's')

-- controlSpecs.midiVelMin = controlspec.new(0, 127, 'lin', 1, 60, '')
-- controlSpecs.midiVelMax = controlspec.new(0, 127, 'lin', 1, 120, '')
controlSpecs.midiNoteLengthMin = controlspec.new(0, 16.0, 'lin', 0.01, 1/4, 'bt', 1/24/10)
controlSpecs.midiNoteLengthMax = controlspec.new(0, 16.0, 'lin', 0.01, 1/4, 'bt', 1/24/10)

local ui = {}
ui.drawCatBar = false
ui.catBarTime = util.time()
ui.overlay2 = nil

local settings = {}
settings.play = {x = 16, y = 1}
-- setup grid pages
settings.lightshow = {x = 16, y = 2}
settings.sequencer = {x = 16, y = 3}
settings.sequencer.octave = GridFader.new("horz", 9, 7, 7, false, true)
settings.sequencer.octave.get_updated_value = function ()
    return getCurrentCat().octave + 4
end
settings.sequencer.octave.on_value_changed = function (newVal) 
    local c = getCurrentCat()
    c.octave = newVal - 4
    show_overlay_message(c.octave, "Octave")
end
settings.sequencer.faders = {settings.sequencer.octave}

settings.soundout = {x = 16, y = 4}
settings.soundout.event_modes = {"launch", "bounce", "collision"}
settings.soundout.sound_event_ui = "launch"
settings.synths = {x = 16, y = 5}
settings.synths.selected = 1
settings.fileIO = {x = 16, y = 8}

function synth_overlay_message(name, value)
    show_overlay_message(util.round(value, 0.01), name)
end

-- settings.synths.mod1fader = GridFader.new("vert", 9, 8, 8, true)
-- algo
settings.synths.algoFader = GridFader.new("horz", 6, 1, 8, false, true)
settings.synths.algoFader.get_updated_value = function ()
    return params:get("algo_"..settings.synths.selected)
end
settings.synths.algoFader.on_value_changed = function (newVal) 
    -- print("Algo "..newVal)
    local pName = "algo_"..settings.synths.selected
    params:set(pName, newVal) 
    show_overlay_message(thebangs.options.algoNames[params:get(pName)], "Synth Algo")
end
-- amp
settings.synths.ampfader = GridFader.new("horz", 1, 2, 15, false)
settings.synths.ampfader.get_updated_value = function ()
    return controlSpecs.amp:unmap(params:get("amp_"..settings.synths.selected))
end
settings.synths.ampfader.on_value_changed = function (newVal) 
    local pName = "amp_"..settings.synths.selected
    params:set(pName, controlSpecs.amp:map(newVal)) 
    synth_overlay_message("Amp", params:get(pName))
end
-- pan
settings.synths.panfader = GridFader.new("horz", 1, 3, 15, true)
settings.synths.panfader.get_updated_value = function ()
    return controlSpecs.pan:unmap(params:get("pan_"..settings.synths.selected))
end
settings.synths.panfader.on_value_changed = function (newVal) 
    local pName = "pan_"..settings.synths.selected
    params:set(pName, controlSpecs.pan:map(newVal)) 
    synth_overlay_message("Pan", params:get(pName))
end
-- mod1
settings.synths.mod1fader = GridFader.new("horz", 1, 4, 15, false)
settings.synths.mod1fader.get_updated_value = function ()
    return controlSpecs.mod1:unmap(params:get("mod1_"..settings.synths.selected))
end
settings.synths.mod1fader.on_value_changed = function (newVal) 
    local pName = "mod1_"..settings.synths.selected
    params:set(pName, controlSpecs.mod1:map(newVal)) 
    synth_overlay_message("Mod1", params:get(pName))
end
-- mod2
settings.synths.mod2fader = GridFader.new("horz", 1, 5, 15, false)
settings.synths.mod2fader.get_updated_value = function ()
    return controlSpecs.mod2:unmap(params:get("mod2_"..settings.synths.selected))
end
settings.synths.mod2fader.on_value_changed = function (newVal) 
    local pName = "mod2_"..settings.synths.selected
    params:set(pName, controlSpecs.mod2:map(newVal)) 
    synth_overlay_message("Mod2", params:get(pName))
end
-- cutoff
settings.synths.cutoffFader = GridFader.new("horz", 1, 6, 15, false)
settings.synths.cutoffFader.get_updated_value = function ()
    return controlSpecs.cutoff:unmap(params:get("cutoff_"..settings.synths.selected))
end
settings.synths.cutoffFader.on_value_changed = function (newVal) 
    local pName = "cutoff_"..settings.synths.selected
    params:set(pName, controlSpecs.cutoff:map(newVal)) 
    synth_overlay_message("Cutoff", params:get(pName))
end
-- attack
settings.synths.attackFader = GridFader.new("horz", 1, 7, 15, false)
settings.synths.attackFader.get_updated_value = function ()
    return controlSpecs.attack:unmap(params:get("attack_"..settings.synths.selected))
end
settings.synths.attackFader.on_value_changed = function (newVal) 
    local pName = "attack_"..settings.synths.selected
    params:set(pName, controlSpecs.attack:map(newVal)) 
    synth_overlay_message("Attack", params:get(pName))
end
-- release
settings.synths.releaseFader = GridFader.new("horz", 1, 8, 15, false)
settings.synths.releaseFader.get_updated_value = function ()
    return controlSpecs.release:unmap(params:get("release_"..settings.synths.selected))
end
settings.synths.releaseFader.on_value_changed = function (newVal) 
    local pName = "release_"..settings.synths.selected
    params:set(pName, controlSpecs.release:map(newVal)) 
    synth_overlay_message("Release", params:get(pName))
end

settings.synths.faders = {
    settings.synths.algoFader,
    settings.synths.ampfader,
    settings.synths.panfader, 
    settings.synths.mod1fader, 
    settings.synths.mod2fader,
    settings.synths.cutoffFader,  
    settings.synths.attackFader,  
    settings.synths.releaseFader
}

settings.lightshow.name = "Petting Zoo"
settings.sequencer.name = "Meowquencer"
settings.soundout.name = "Cat Config"
settings.synths.name = "Synths"
settings.fileIO.name = "File IO"

local grid_pages = {settings.lightshow, settings.sequencer, settings.soundout, settings.synths, settings.fileIO }
local active_page = settings.sequencer

local particleEngine = nil
local physicsEngine = nil

-- local particles = {}

-- local particle_pool = {}

local physicsBodies = {}

local grooveCats = {}

local SYNTH_COUNT = 4
local MIDI_COUNT = 16


local is_playing = false


-- local x_min = 0
-- local x_max = 128

-- local y_min = 0
-- local y_max = 64

local prevTime = 0

local seqPos = 1
-- local octave = 0
-- local loopCount = 0

local scale_names = {}
local notes = {}
-- local active_notes = {}

local all_midibangs = {}

-- local cat_names = {"wednesday", "swisher", "franky", "tiger"}
-- local selected_grooveCat = 1

local selected_cat = 1
local selected_cat_d = 1

local prevSelectedCat = 0

local shift1_down = false
local shift2_down = false

local param_edit = false

local prev_bpm = 0

local paramUtil = {}

local grid_events = nil

local grid_dirty = false

local blink_counter = 0
local blink_on = false

local ui_mode = "main"

local wall_padding = 5
local wall_left = wall_padding
local wall_right = 128 - wall_padding
local wall_up = wall_padding
local wall_down = 64 - wall_padding

local collision_events_full = {}
local collision_events_half = {}

local cats_on_grid = {}

local overlay = nil

local fileIO_active = false

local random_hold = false
local random_hold_time = 0

function init()
    grid_events = Grid_Events_Handler.new() -- Handles grid events to differentiate press, click, double click, hold
    grid_events.grid_event = function (e) grid_event(e) end
    
    change_active_grid_page(settings.lightshow)
    
    for x = 1, 16 do
        collision_events_full[x] = {}
    end
    
    for x = 1, 8 do
        collision_events_half[x] = {}
    end
    
    physicsEngine = PhysicsEngine.new()
    particleEngine = ParticleEngine.new()
    
    for i = 1, 4 do
        all_midibangs[i] = MidiBangs.new(i)
    end
    
    add_default_cats()
    
    for i = 1, #MusicUtil.SCALES do
        table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
    end
    
    physicsEngine.collisionFunc = onCollision
    physicsEngine.bounceFunc = onBounce
    
    -- params:add{type = "option", id = "selected_cat", name = "selected cat",
    -- options = cat_names, default = 1,
    -- action = function() updateSelectedCat() end}
    
    -- params:add_separator()
    -- thebangs.add_additional_synth_params()
    
    -- FILE IO GROUP --
    params:add_group("FileIO", 4)
    params:add{type = "text", id = "FileIO_name", name = "Filename"}
    params:add{type = "trigger", id = "FileIO_rndName", name = "Rnd Name", action = function(value)
        local rndName = NameSizer.rnd()
        params:set("FileIO_name", rndName)
    end}
    params:add{type = "trigger", id = "FileIO_save", name = "Save", action = function(value)
        local fileName = params:get("FileIO_name")
        save_project_params(fileName)
    end}
    params:add{type = "file", path = data_path, id = "FileIO_load", name = "Load", action = function(value)
        load_project_params(value)
    end}
    
    
    
    
    params:add_separator()
    params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 5,
    action = function() build_scale() end}
    params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end}
    
    -- params:add_separator()
    
    params:add{ type = "control", id = "gravity", controlspec = controlspec.new(-50.0, 50.0, 'lin', 0, 5, '', 0.0025),
    action=function(value)
        physicsEngine.gravity = value
    end }
    
    params:add_separator()
    hsdelay.init()
    params:set("delay_enabled", 2)
    
    -- params:add_separator()
    for i = 1,SYNTH_COUNT do addSynthParams(i) end
    for i = 1,MIDI_COUNT do addMidiParams(i) end
    
    params:add_separator()
    thebangs.add_voicer_params()
    
    build_scale()
    
    paramUtil = ParamListUtil.new()
    
    paramUtil.delta_speed = 0.6
    
    paramUtil:add_option("Enabled", 
    function() return getCurrentCat().enabled and "true" or "false" end, 
    function(d,d_raw) 
        getCurrentCat().enabled = not getCurrentCat().enabled
    end)
    
    -- paramUtil:add_option("Gravity", 
    --     function() return physicsEngine.gravity end, 
    --     function(d,d_raw) 
    --         physicsEngine.gravity = util.clamp(physicsEngine.gravity + d_raw * 0.25, -20, 20)
    --     end
    -- )
    
    paramUtil:add_option("Personality", 
    function() return GrooveCat.PERONALITIES[getCurrentCat().personality] end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        
        c.personality = util.clamp(c.personality + d, 1, #GrooveCat.PERONALITIES)
    end)
    
    paramUtil:add_option("Sync Rate", 
    function() return GrooveCat.SYNC_RATES[getCurrentCat().syncMode] end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        
        c:changeSyncMode(c.syncMode + d)
    end)
    
    paramUtil:add_option("RotSpeed", 
    function() return getCurrentCat().autoRotateSpeed end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        
        c.autoRotateSpeed = util.clamp(c.autoRotateSpeed + d_raw, -180, 180)
    end)
    
    paramUtil:add_option("Probability", 
    function() return getCurrentCat().probability end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        
        c.probability = util.clamp(c.probability + d_raw, 0, 100)
    end)
    
    paramUtil:add_option("LSpeedMin", 
    function() return getCurrentCat().lSpeedMin end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.lSpeedMin = util.clamp(c.lSpeedMin + d_raw, 1, 100)
    end)
    
    paramUtil:add_option("LSpeedMax", 
    function() return getCurrentCat().lSpeedMax end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.lSpeedMax = util.clamp(c.lSpeedMax + d_raw, 1, 100)
    end)
    
    paramUtil:add_option("Octave", 
    function() return getCurrentCat().octave end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        
        c.octave = util.clamp(c.octave + d_raw, -4, 4)
    end)
    
    paramUtil:add_option("Launch Synth", 
    function() 
        local c = getCurrentCat()
        if c.launch_synth == 0 then return "disabled" end
        return c.launch_synth
    end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.launch_synth = util.clamp(c.launch_synth + d, 0, SYNTH_COUNT)
    end)
    
    paramUtil:add_option("Bounce Synth", 
    function() 
        local c = getCurrentCat()
        if c.bounce_synth == 0 then return "disabled" end
        return c.bounce_synth
    end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.bounce_synth = util.clamp(c.bounce_synth + d, 0, SYNTH_COUNT)
    end)
    
    paramUtil:add_option("Collision Synth", 
    function() 
        local c = getCurrentCat()
        if c.collision_synth == 0 then return "disabled" end
        return c.collision_synth
    end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.collision_synth = util.clamp(c.collision_synth + d, 0, SYNTH_COUNT)
    end)
    paramUtil:add_option("Launch Midi", 
    function() 
        local c = getCurrentCat()
        if c.launch_midi == 0 then return "disabled" end
        return c.launch_midi
    end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.launch_midi = util.clamp(c.launch_midi + d, 0, MIDI_COUNT)
    end)
    paramUtil:add_option("Bounce Midi", 
    function() 
        local c = getCurrentCat()
        if c.bounce_midi == 0 then return "disabled" end
        return c.bounce_midi
    end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.bounce_midi = util.clamp(c.bounce_midi + d, 0, MIDI_COUNT)
    end)
    paramUtil:add_option("Collision Midi", 
    function() 
        local c = getCurrentCat()
        if c.collision_midi == 0 then return "disabled" end
        return c.collision_midi
    end, 
    function(d,d_raw) 
        local c = getCurrentCat()
        c.collision_midi = util.clamp(c.collision_midi + d, 0, MIDI_COUNT)
    end)
    
    updateSelectedCat()
    
    -- Make data directories
    if not util.file_exists(data_path) then
        util.make_dir(data_path)
        print("Made data path directory")
    end
    
    if not util.file_exists(params_path) then
        util.make_dir(params_path)
        print("Made params directory")
    end
    
    load_last_project()
    
    clock.run(screen_redraw_clock)
    clock.run(grid_redraw_clock) 
    
    toggle_playback()
end

function addSynthParams(id)
    local num_params = 8
    params:add_group("Synth " .. id, num_params)
    
    params:add{ type = "option", id = "algo_"..id, name = "Algo", options = thebangs.options.algoNames, default = 3 }
    params:add{ type = "control", id = "amp_"..id, name = "Amp",controlspec = controlSpecs.amp }
    params:add{ type = "control", id = "pan_"..id, name = "Pan",controlspec = controlSpecs.pan }
    params:add{ type = "control", id = "mod1_"..id, name = "Mod1",controlspec = controlSpecs.mod1 }
    params:add{ type = "control", id = "mod2_"..id, name = "Mod2",controlspec = controlSpecs.mod2 }
    params:add{ type = "control", id = "cutoff_"..id, name = "Cutoff",controlspec = controlSpecs.cutoff }
    params:add{ type = "control", id = "attack_"..id, name = "Attack",controlspec = controlSpecs.attack }
    -- controlspec.new(0.1,3.2,'lin',0,1.2,'s')
    params:add{ type = "control", id = "release_"..id, name = "Release",controlspec = controlSpecs.release }
end

function addMidiParams(id)
    local num_params = 6
    params:add_group("Midi " .. id, num_params)
    
    params:add{type="number", id="midiDevice_"..id, name="Device", min = 1, max = 4, default = 1 }
    params:add{type="number", id="midiChannel_"..id, name="Channel", min = 0, max = 16, default = id }
    -- params:add{type="number", id="midiVelMin_"..id, name="Vel Min", min = 0, max = 127, default = 60 }
    -- params:add{type="number", id="midiVelMax_"..id, name="Vel Max", min = 0, max = 127, default = 120 }
    -- params:add{type = "control", id = "midiNoteLength_"..id, name = "Note Length", controlspec = controlspec.new(0.0001, 16.0, 'exp', 1/24, 0.25, 'bt')}
    
    -- params:add{type = "control", id = "midiNoteLengthMin_"..id, name = "Length Min", controlspec = controlspec.new(0, 16.0, 'lin', 0.01, 1/4, 'bt', 1/24/10)}
    -- params:add{type = "control", id = "midiNoteLengthMax_"..id, name = "Length Max", controlspec = controlspec.new(0, 16.0, 'lin', 0.01, 1/4, 'bt', 1/24/10)}
    
    -- params:add{type="number", id="midiVelMin_"..id, name="Vel Min", controlspec = controlSpecs.midiVelMin }
    -- params:add{type="number", id="midiVelMax_"..id, name="Vel Max", controlspec = controlSpecs.midiVelMax }
    
    params:add{type="number", id="midiVelMin_"..id, name="Vel Min", min = 0, max = 127, default = 60 }
    params:add{type="number", id="midiVelMax_"..id, name="Vel Max", min = 0, max = 127, default = 120 }
    params:add{type = "control", id = "midiNoteLengthMin_"..id, name = "Length Min", controlspec = controlSpecs.midiNoteLengthMin}
    params:add{type = "control", id = "midiNoteLengthMax_"..id, name = "Length Max", controlspec = controlSpecs.midiNoteLengthMax}
end

function updateSynth(id)
    if id < 1 then return end
    engine.algoIndex(params:get("algo_"..id))
    engine.amp(params:get("amp_"..id))
    engine.pan(params:get("pan_"..id))
    engine.mod1(params:get("mod1_"..id))
    engine.mod2(params:get("mod2_"..id))
    engine.hz2(params:get("cutoff_"..id))
    engine.attack(params:get("attack_"..id))
    engine.release(params:get("release_"..id))
end

function on_tempo_changed(newTempo)
    newTempo = newTempo or clock.get_tempo()
    prev_bpm = newTempo
    hsdelay.tempo_changed(newTempo)
end

function toggle_playback()
    if is_playing then
        show_overlay_message("Hiss")
        -- print("Stop purring")
        clock.transport.stop()
    else
        show_overlay_message("Purr")
        -- print("Start purring")
        clock.transport.start()
    end
end

function clock.transport.start()
    if is_playing then return end
    
    is_playing = true
    
    on_tempo_changed(clock.get_tempo())
    
    for i, c in pairs(grooveCats) do
        c:purr()
    end
end

function clock.transport.stop()
    if is_playing == false then return end
    
    is_playing = false
    
    for i, c in pairs(grooveCats) do
        c:stop_purring()
    end
end

function cycle(value,min,max)
    if value > max then
        return min
    elseif value < min then
        return max
    else
        return value
    end
end

function select_cat(cat_id)
    if cat_id < 1 or cat_id > MAX_CATS then return end
    
    print("select cat"..cat_id)
    
    
    selected_cat = cat_id
    selected_cat_d = selected_cat
    updateSelectedCat()
    
    local c = getCurrentCat()
    show_overlay_message(c.name)
end

function toggle_cat_enable(cat_id)
    if cat_id < 1 or cat_id > MAX_CATS then return end
    
    grooveCats[cat_id].enabled = not grooveCats[cat_id].enabled
    
    if grooveCats[cat_id].enabled then
        show_overlay_message("Meow")
    else
        show_overlay_message("Poof")
    end
end

function updateSelectedCat()
    if selected_cat ~= prevSelectedCat then
        local c = grooveCats[prevSelectedCat]
        if c ~= nil then c.selected = false end
        
        getCurrentCat().selected = true
    end
    
    prevSelectedCat = selected_cat
    
end

function randomize_all()
    randomize_petting_zoo()
    randomize_cat_config()
    randomize_synths()
    -- randomize_midis()
    
    for i = 1, #grooveCats do
        local c = grooveCats[i]
        
        c:randomize_loop()
    end
end

function randomize_petting_zoo()
    for i = 1, #grooveCats do
        randomize_petting_zoo_cat(i)
    end
end

function randomize_petting_zoo_cat(catIndex)
    local c = grooveCats[catIndex]
    local pos_x, pos_y = get_pos_from_grid(1,15,2,8, math.random(1,15), math.random(2,8))
    c.pos.x = pos_x
    c.pos.y = pos_y
    
    c.enabled = (math.random() > 0.6) and true or false
    
    c.personality = math.random(1,#GrooveCat.PERONALITIES)
    c.probability = math.random(10, 100)
    c.octave = math.random(-3, 3)
    c.lSpeedMin = math.random(10, 60)
    c.lSpeedMax = math.random(60, 100)
    c:changeSyncMode(math.random(1, #GrooveCat.SYNC_RATES))
    c.autoRotateSpeed = math.random(-180, 180)
end

function randomize_cat_config()
    for i = 1, #grooveCats do
        randomize_cat_config_cat(i)
    end
end

function randomize_cat_config_cat(catIndex)
    local c = grooveCats[catIndex]
    
    c:changeSyncMode(math.random(1, #GrooveCat.SYNC_RATES))
    
    c.launch_synth = math.random(0, SYNTH_COUNT)
    c.bounce_synth = math.random(0, SYNTH_COUNT)
    c.collision_synth = math.random(0, SYNTH_COUNT)
    
    c.launch_midi = math.random(0, RND_MIDI_COUNT)
    c.bounce_midi = math.random(0, RND_MIDI_COUNT)
    c.collision_midi = math.random(0, RND_MIDI_COUNT)
    
    c:changeSyncMode(math.random(1, #GrooveCat.SYNC_RATES))
    c.probability = math.random(10, 100)
    
    -- c:printValues()
end

function randomize_synths()
    for i = 1, SYNTH_COUNT do
        randomize_synth(i)
    end
end

function randomize_synth(synthIndex)
    params:set("algo_"..synthIndex, math.random(1, #thebangs.options.algoNames))
    -- params:set("amp_"..synthIndex, controlSpecs.amp:map(math.random()))
    params:set("pan_"..synthIndex, controlSpecs.pan:map(math.random()))
    params:set("mod1_"..synthIndex, controlSpecs.mod1:map(math.random()))
    params:set("mod2_"..synthIndex, controlSpecs.mod2:map(math.random()))
    params:set("cutoff_"..synthIndex, controlSpecs.cutoff:map(math.random()))
    params:set("attack_"..synthIndex, controlSpecs.attack:map(math.random()))
    params:set("release_"..synthIndex, controlSpecs.release:map(math.random()))
end

function randomize_midis()
    for i = 1, MIDI_COUNT do
        randomize_midi(i)
    end
end

function randomize_midi(midiIndex)
    params:set("midiVelMin_"..midiIndex, math.random(0, 127))
    params:set("midiVelMax_"..midiIndex, math.random(0, 127))
    
    params:set("midiNoteLengthMin_"..midiIndex, controlSpecs.midiNoteLengthMin:map(math.random()))
    params:set("midiNoteLengthMax_"..midiIndex, controlSpecs.midiNoteLengthMax:map(math.random()))
end

function add_default_cats()
    for i = 1, MAX_CATS do
        
        local c =  GrooveCat.new(physicsEngine, particleEngine)
        
        c.name = cat_names[i]
        c.autoRotateSpeed = 0
        c:changeSyncMode(3)
        c.pos.x = math.random(wall_left, wall_right)
        c.pos.y = math.random(wall_up, wall_down)
        c.onMeow = onMeow
        c.enabled = false
        
        c.bounce_synth = math.random(1, SYNTH_COUNT)
        c.collision_synth = math.random(1, SYNTH_COUNT)
        
        grooveCats[i] = c
        
        -- c:purr()
        
        -- selected_cat = #grooveCats
        -- selected_cat_d = selected_cat
        -- updateSelectedCat()
        
        -- grooveCats[1] = GrooveCat.new(physicsEngine, particleEngine)
        -- grooveCats[2] = GrooveCat.new(physicsEngine, particleEngine)
        
        -- grooveCats[1].autoRotateSpeed = 0
        -- grooveCats[1]:changeSyncMode(2)
        -- grooveCats[1].pos.x = 80
        -- grooveCats[1].pos.y = 40
        
        -- grooveCats[2].personality = 3
    end
    
    print("Added "..#grooveCats.." cats")
    
    grooveCats[1].enabled = true
end

function addNewCat()
    -- if #grooveCats >= #cat_names then return end -- too many cats!
    
    -- local c =  GrooveCat.new(physicsEngine, particleEngine)
    
    -- c.autoRotateSpeed = 0
    -- c:changeSyncMode(6)
    -- c.pos.x = math.random(5, 128-5)
    -- c.pos.y = math.random(5, 64-5)
    -- c.onMeow = onMeow
    
    -- table.insert(grooveCats, c)
    
    -- c:purr()
    
    -- selected_cat = #grooveCats
    -- selected_cat_d = selected_cat
    -- updateSelectedCat()
end

function build_cats_on_grid()
    cats_on_grid = {}
    for x = 1, 15 do
        cats_on_grid[x] = {}
    end
    
    for i,c in pairs(grooveCats) do
        local grid_x, grid_y = get_grid_pos(1, 15, 2, 8, c.pos.x, c.pos.y)
        
        if cats_on_grid[grid_x][grid_y] == nil then
            cats_on_grid[grid_x][grid_y] = {}
        end
        
        table.insert(cats_on_grid[grid_x][grid_y], i)
    end
end

function build_scale()
    notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
    local num_to_add = 16 - #notes
    for i = 1, num_to_add do
        table.insert(notes, notes[16 - num_to_add])
    end
end

function bang_note(synthId, midiId, noteNumber, velocity)
    if noteNumber < 0 or noteNumber > 127 then return end
    
    if synthId > 0 then
        updateSynth(synthId)
        local freq = MusicUtil.note_num_to_freq(noteNumber)
        engine.hz(freq)
    end
    if midiId > 0 then
        local deviceId = params:get("midiDevice_"..midiId)
        
        local velMin, velMax = Q7Util.get_min_max(params:get("midiVelMin_"..midiId), params:get("midiVelMax_"..midiId))
        local vel = math.random(velMin, velMax)
        local lengthMin, lengthMax = Q7Util.get_min_max(params:get("midiNoteLengthMin_"..midiId), params:get("midiNoteLengthMax_"..midiId))
        local length = util.linlin(0,1, lengthMin, lengthMax, math.random())
        all_midibangs[deviceId]:bang(noteNumber, vel, length, params:get("midiChannel_"..midiId))
    end
end

function onCollision(b1, b2)
    
    local n = seqPos
    
    if b1 == nil then print("b1 is nil") end
    if b2 == nil then print("b2 is nil") end
    
    if b1.cat.collision_synth < 1 and b1.cat.collision_midi < 1 then return end
    
    
    -- params:set("algo", 6)
    -- params:set("release", util.linlin(0,1,0.6,2.0, math.random()))
    
    local n1 = b1.cat:bounce_step()
    local n2 = b2.cat:bounce_step()
    
    if n1 + n2 < 1 then return end
    
    local note_num = notes[n1 + n2]
    bang_note(b1.cat.collision_synth, b1.cat.collision_midi, note_num)
    
    add_collision_event(b1.pos.x, b1.pos.y)
    
    -- updateSynth(b1.cat.collision_synth)
    
    -- local note_num = notes[n1 + n2]
    
    -- local freq = MusicUtil.note_num_to_freq(note_num)
    -- engine.hz(freq)
    
    -- engine.algoIndex(4)
    -- engine.amp(0.2)
    -- engine.attack(0.2)
    -- engine.release(1.0)
    
    -- local note_num = notes[n]
    -- local freq = MusicUtil.note_num_to_freq(note_num)
    -- engine.hz(freq)
    
    -- for i = 1, 3 do
    --     -- local note_num = notes[((i-1) * 2) + 1 + n]
    
    --     local note_num = notes[n1 + n2] + ((i-1) * 4) 
    
    --     local freq = MusicUtil.note_num_to_freq(note_num)
    --     engine.hz(freq)
    -- end
end

function add_collision_event(pos_x, pos_y)
    intern_add_collision_event(collision_events_half, 1, 8, 1, 8, pos_x, pos_y)
    intern_add_collision_event(collision_events_full, 1, 15, 2, 8, pos_x, pos_y)
end

function intern_add_collision_event(eventsTable, x_min, x_max, y_min, y_max, pos_x, pos_y)
    local grid_x, grid_y = get_grid_pos(x_min, x_max, y_min, y_max, pos_x, pos_y)
    
    if eventsTable[grid_x][grid_y] == nil then
        eventsTable[grid_x][grid_y] = CollisionEvent.new()
    else
        eventsTable[grid_x][grid_y]:reset()
    end
end

function update_collision_events()
    intern_update_collision_events(collision_events_half, 8, 8)
    intern_update_collision_events(collision_events_full, 16, 8)
end

function intern_update_collision_events(eventsTable, x_max, y_max)
    for x = 1, x_max do
        for y = 1, y_max do
            if eventsTable[x][y] ~= nil then
                eventsTable[x][y]:update()
                if eventsTable[x][y]:is_complete() then
                    eventsTable[x][y] = nil
                end
            end
        end
    end
end

function grid_draw_collision_events(eventsTable, x_min, x_max, y_min, y_max)
    for x = x_min, x_max do
        for y = y_min, y_max do
            if eventsTable[x][y] ~= nil then
                g:led(x, y, eventsTable[x][y].led_level)
            end
        end
    end
end

function onBounce(physicsBody)
    -- params:set("release", 0.25)
    -- params:set("algo", 2)
    
    -- engine.algoIndex(2)
    
    local c = physicsBody.cat
    
    local note_index = c:bounce_step()
    
    if note_index > 0 then
        local note_num = notes[note_index] + 12 * c.octave
        bang_note(c.bounce_synth, c.bounce_midi, note_num)
        
        -- updateSynth(c.bounce_synth)
        
        -- local freq = MusicUtil.note_num_to_freq(note_num)
        -- engine.hz(freq)
        
        -- -- local note_num = notes[math.random(1,16)]
        -- local note_num = notes[seqPos] + 12 * octave
        -- local freq = MusicUtil.note_num_to_freq(note_num)
        -- engine.hz(freq)
        
        -- seqPos = seqPos + 2
        -- if seqPos > 8 then
        --     seqPos = 1
        --     loopCount = (loopCount + 1) % 4
        --     if loopCount == 0 then
        --         octave = (octave + 1) % 2
        --     end
        -- end
    end
    
    set_grid_dirty()
end

function onMeow(grooveCat, nId)
    if nId > 0 then
        local note_num = notes[nId] + 12 * grooveCat.octave
        bang_note(grooveCat.launch_synth, grooveCat.launch_midi, note_num)
        
        -- updateSynth(grooveCat.launch_synth)
        
        -- local note_num = notes[nId] + 12 * grooveCat.octave
        -- local freq = MusicUtil.note_num_to_freq(note_num)
        -- engine.hz(freq)
    end
    -- engine.algoIndex(6)
    -- engine.amp(0.3)
    -- engine.attack(0.01)
    -- engine.release(util.linlin(0,1,0.2,3.0,math.random()))
    
    -- local note_num = notes[seqPos] + 12 * octave
    -- local freq = MusicUtil.note_num_to_freq(note_num)
    -- engine.hz(freq)
    
    set_grid_dirty()
end

function screen_redraw_clock()
    prevTime = util.time()
    while true do
        clock.sleep(1/15)
        
        local currentTime = util.time()
        local deltaTime = currentTime - prevTime
        prevTime = currentTime
        
        if clock.get_tempo() ~= prev_bpm then
            on_tempo_changed(prev_bpm)
        end
        
        -- updateParticles(deltaTime)
        -- updatePhysicsBodies(deltaTime)
        
        physicsEngine:update(deltaTime)
        particleEngine:update(deltaTime)
        
        for i, c in pairs(grooveCats) do
            c:update(deltaTime)
        end
        redraw()
    end
end

function grid_redraw_clock() -- our grid redraw clock
    while true do -- while it's running...
        
        -- used to blink leds
        blink_counter = (blink_counter + 1) % 2
        
        if blink_counter == 0 then
            blink_on = not blink_on
            set_grid_dirty()
        end
        
        if grid_dirty then
            -- grid_redraw()
            grid_dirty = false
        end
        
        update_collision_events()
        
        grid_redraw()
        
        clock.sleep(1/15) -- refresh rate
    end
end

-- Big message completely covers screen
function show_overlay_message(h1, h2, time)
    h1 = h1 and h1 or ""
    h2 = h2 and h2 or ""
    time = time and time or 2
    
    -- print(h1.." "..h2)
    
    overlay = {text="",subtext="",time=0}
    overlay.text = h1
    overlay.subtext = h2
    overlay.time = util.time()+(time)
end

-- small message, drawn on top of screen
function show_overlay2(message, message2, time)
    message = message and message or ""
    message2 = message2 and message2 or ""
    time = time and time or 2
    
    ui.overlay2 = {text = message, text2 = message2, time = util.time() + time}
end

function redraw()
    screen.clear()
    screen.aa(0)
    
    if overlay then
        -- TEXT
        screen.level(15)
        screen.font_size(16)
        screen.move(64,40)
        screen.text_center(overlay.text)
        -- SUBTEXT
        if overlay.subtext then
            screen.level(2)
            screen.font_size(8)
            screen.move(64,56)
            screen.text_center(overlay.subtext)
        end
        -- REMOVE OVERLAY
        if util.time() > overlay.time then overlay = nil end
    else
        if param_edit then
            screen.move(64, 10)
            screen.level(15)
            screen.text_center(getCurrentCat().name)
            
            paramUtil:redraw()
        else
            for i,c in pairs(grooveCats) do
                c:draw()
            end
            
            screen.blend_mode('add')
            particleEngine:draw()
            screen.blend_mode(0)
            
            physicsEngine:draw()
            
            if ui.drawCatBar then
                
                local lineStep = util.round(128 / #grooveCats)
                local linePad = 1
                
                screen.line_width(1)
                
                for i = 1, #grooveCats do
                    local xPos = (i - 1) * lineStep
                    screen.move(xPos + linePad, 1)
                    screen.level(i == selected_cat and 15 or (grooveCats[i].enabled and 7 or 2))
                    screen.line(xPos + lineStep - linePad, 1)
                    screen.stroke()
                end
                
                if util.time() > ui.catBarTime then ui.drawCatBar = false end
            end
            
            if ui.overlay2 then
                -- TEXT
                screen.blend_mode('add')
                screen.level(5)
                screen.font_size(8)
                screen.move(64,10)
                screen.text_center(ui.overlay2.text)
                screen.move(64,20)
                screen.text_center(ui.overlay2.text2)
                screen.blend_mode(0)
                -- REMOVE OVERLAY
                if util.time() > ui.overlay2.time then ui.overlay2 = nil end
            end
        end
    end
    
    screen.update()
end

function getCurrentCat()
    return grooveCats[selected_cat]
end

function set_grid_dirty()
    grid_dirty = true
end

function change_active_grid_page(page)
    if page == nil then return end
    active_page = page
    
    if active_page.init then active_page.init() end
    if active_page.name then show_overlay_message(active_page.name) end
end

function g.key(x, y, z)
    grid_events:key(x,y,z)
end

function is_event_at_position(e, pos)
    return (e.x == pos.x and e.y == pos.y)
end

function grid_event(e)
    active_page.grid_event(e)
    
    toolbar_grid_event(e)
    
    set_grid_dirty()
end

function toolbar_grid_event(e)
    -- toggle playback
    if is_event_at_position(e, settings.play) and e.type == "press" then toggle_playback() end
    
    for i, p in pairs(grid_pages) do
        if is_event_at_position(e, p) and e.type == "press" then change_active_grid_page(p) end
    end
    
    -- randomize
    if e.x == 16 and e.y == 7 then
        if e.z == 1 then
            random_hold = true
            random_hold_time = util.time() + 1.0
        elseif e.z == 0 then
            random_hold = false
        end
        
        if e.type == "press" then
            show_overlay2("double click to randomize", "long hold to randomize all")
        elseif e.type == "double_click" then
            if active_page.randomize then active_page.randomize() end
        end
    end
    
    -- if is_event_at_position(e, settings.sequencer) and e.type == "press" then change_active_grid_page(settings.sequencer) end
    
    -- -- LightShow!!!
    -- if is_event_at_position(e, settings.lightshow) and e.type == "press" then change_active_grid_page(settings.lightshow) end
end

function cat_grid_event(e)
    local c = getCurrentCat()
    
    if e.x <= 8 then
        if e.type == "press" then
            if e.y == 1 then
                c.personality = util.clamp(e.x, 1, #GrooveCat.PERONALITIES)
                show_overlay_message("Personality", GrooveCat.PERONALITIES[c.personality])
            elseif e.y == 2 then
                c:changeSyncMode(e.x)
                show_overlay_message("Sync", GrooveCat.SYNC_RATES[c.syncMode])
            end
        end
    end
end

function grid_draw_cat_settings()
    local c = getCurrentCat()
    local ledOn = 10
    local ledOff = 4
    
    for x = 1, #GrooveCat.PERONALITIES do
        g:led(x, 1, x == c.personality and ledOn or ledOff)
    end
    
    for x = 1, #GrooveCat.SYNC_RATES do
        g:led(x, 2, x == c.syncMode and ledOn or ledOff)
    end
end



settings.sequencer.grid_event = function(e)
    grid_event_cat_selection(e)
    
    local c = getCurrentCat()
    
    if ui_mode == "cat" then
        if e.x <= 8 and e.type == "press" then
            cat_grid_event(e)
            -- local pos_x, pos_y = get_pos_from_grid(1,8,1,8,e.x,e.y)
            
            -- c.pos.x = pos_x
            -- c.pos.y = pos_y
        end
    elseif ui_mode == "main" then
        -- sequencer
        if e.x <= 8 and e.type == "press" then
            if c.bounce_seq.data[e.x] == 9-e.y then
                c:set_loop_data(e.x, 0)
            else
                c:set_loop_data(e.x, 9 - e.y)
            end
        end
        
        -- randomize sequence
        if e.x == 9 and e.y == 8 and e.z == 1 then
            c:randomize_loop()
            show_overlay_message("Randomize")
        elseif e.x == 10 and e.y == 8 and e.z == 1 then
            c:shuffle_loop()
            show_overlay_message("Shuffle")
        elseif e.x == 11 and e.y == 8 and e.z == 1 then
            c.autoShuffle = not c.autoShuffle
            show_overlay_message(c.autoShuffle and "AutoShuffle On" or "AutoShuffle off")
        end
        
        for i, f in pairs(settings.sequencer.faders) do
            f:grid_event(e)
        end
    end
end

settings.lightshow.randomize = function()
    local c = getCurrentCat()
    local enabled = c.enabled
    randomize_petting_zoo_cat(selected_cat)
    c.enabled = enabled
    show_overlay2("randomize cat")
end

settings.lightshow.randomize_all = function()
    randomize_petting_zoo()
    show_overlay2("randomize all cats")
end

settings.sequencer.randomize = function()
    local c = getCurrentCat()
    c:randomize_loop()
    c.octave = math.random(-3, 3)
    show_overlay2("randomize seq")
end

settings.sequencer.randomize_all = function()
    for i = 1, #grooveCats do
        local c = grooveCats[i]
        c:randomize_loop()
        c.octave = math.random(-3, 3)
    end
    show_overlay2("randomize all seqs")
end

settings.soundout.randomize = function()
    randomize_cat_config_cat(selected_cat)
    show_overlay2("randomize cat")
end

settings.soundout.randomize_all = function()
    randomize_cat_config()
    show_overlay2("randomize all cats")
end

settings.synths.randomize = function()
    randomize_synth(settings.synths.selected)
    show_overlay2("randomize synth")
end

settings.synths.randomize_all = function()
    randomize_synths()
    show_overlay2("randomize all synths")
end

settings.lightshow.grid_event = function(e)
    grid_event_cat_selection(e)
    
    if ui_mode == "cat" then
        if e.x <= 8 and e.type == "press" then
            cat_grid_event(e)
        end
    elseif ui_mode == "main" then
        build_cats_on_grid()
        
        local c = getCurrentCat()
        
        if e.x < 16 and e.y > 1 then
            local catIndex = -1
            if e.type == "press" then
                -- look for cats at grid position
                local cats = cats_on_grid[e.x][e.y]
                
                if cats ~= nil then
                    for i = 1, #cats do
                        local j = cats[i]
                        
                        if j ~= selected_cat and grooveCats[j].enabled then
                            catIndex = j
                            break
                        end
                    end
                end
                
                if catIndex >= 0 then -- select the cat
                    select_cat(catIndex)
                else -- move selected cat
                    local pos_x, pos_y = get_pos_from_grid(1,15,2,8,e.x,e.y)
                    
                    c.pos.x = pos_x
                    c.pos.y = pos_y
                end
            elseif e.type == "double_click" then
                local cats = cats_on_grid[e.x][e.y]
                
                -- toggle state of cat if its the selected cat
                if cats ~= nil then
                    for i = 1, #cats do
                        if cats[i] == selected_cat then
                            grooveCats[cats[i]].enabled = not grooveCats[cats[i]].enabled
                            break
                        end
                    end
                end
            end
        end
    end
end

settings.soundout.grid_event = function(e)
    grid_event_cat_selection(e)
    
    if ui_mode == "cat" then
        if e.x <= 8 and e.type == "press" then
            cat_grid_event(e)
        end
    elseif ui_mode == "main" then
        
        if e.y == 1 and e.x <= #settings.soundout.event_modes and e.type == "press" then
            settings.soundout.sound_event_ui = settings.soundout.event_modes[e.x]
            show_overlay_message(settings.soundout.event_modes[e.x])
        end
        
        local c = getCurrentCat()
        local ui = settings.soundout.sound_event_ui
        
        if ui == "launch" then
            if e.type == "press" then
                if e.y == 2 and e.x == 1 then 
                    c.launch_synth = 0
                    show_overlay_message("Launch Synth", "Off")
                elseif e.y == 3 and e.x <= SYNTH_COUNT then
                    c.launch_synth = e.x
                    show_overlay_message("Launch Synth", c.launch_synth)
                elseif e.y == 4 and e.x == 1 then 
                    c.launch_midi = 0
                    show_overlay_message("Launch Midi", "Off")
                elseif e.y == 5 and e.x <= 8 then
                    c.launch_midi = e.x
                    show_overlay_message("Launch Midi", c.launch_midi)
                elseif e.y == 6 and e.x <= 8 then
                    c.launch_midi = e.x + 8
                    show_overlay_message("Launch Midi", c.launch_midi)
                end
            end
        elseif ui == "bounce" then
            if e.type == "press" then
                if e.y == 2 and e.x == 1 then 
                    c.bounce_synth = 0
                    show_overlay_message("Bounce Synth", "Off")
                elseif e.y == 3 and e.x <= SYNTH_COUNT then
                    c.bounce_synth = e.x
                    show_overlay_message("Bounce Synth", c.bounce_synth)
                elseif e.y == 4 and e.x == 1 then 
                    c.bounce_midi = 0
                    show_overlay_message("Bounce Midi", "Off")
                elseif e.y == 5 and e.x <= 8 then
                    c.bounce_midi = e.x
                    show_overlay_message("Bounce Midi", c.bounce_midi)
                elseif e.y == 6 and e.x <= 8 then
                    c.bounce_midi = e.x + 8
                    show_overlay_message("Bounce Midi", c.bounce_midi)
                end
            end
        elseif ui == "collision" then
            if e.type == "press" then
                if e.y == 2 and e.x == 1 then 
                    c.collision_synth = 0
                    show_overlay_message("Collision Synth", "Off")
                elseif e.y == 3 and e.x <= SYNTH_COUNT then
                    c.collision_synth = e.x
                    show_overlay_message("Collision Synth", c.collision_synth)
                elseif e.y == 4 and e.x == 1 then 
                    c.collision_midi = 0
                    show_overlay_message("Collision Midi", "Off")
                elseif e.y == 5 and e.x <= 8 then
                    c.collision_midi = e.x
                    show_overlay_message("Collision Midi", c.collision_midi)
                elseif e.y == 6 and e.x <= 8 then
                    c.collision_midi = e.x + 8
                    show_overlay_message("Collision Midi", c.collision_midi)
                end
            end
        end
        
        if e.type == "press" and e.y == 8 and e.x < 16 then
            -- c.probability = util.linlin(1, 16, 0, 100, e.x)
            
            if e.x == 1 and c.probability > 0 then
                c.probability = 0
            else
                c.probability = util.round(e.x * (100.0 / 15.0))
            end
            
            show_overlay_message("Probability", c.probability)
        end
        
        -- Sync Rates
        if e.type == "press" and e.x > 8 and e.x < 16 and e.y > 1 and e.y - 1 <= #GrooveCat.SYNC_RATES then
            local gcatIndex = e.x - 8
            grooveCats[gcatIndex]:changeSyncMode(e.y - 1)
            show_overlay_message("Sync", GrooveCat.SYNC_RATES[grooveCats[gcatIndex].syncMode])
        end
    end
end

settings.soundout.grid_redraw = function()
    
    grid_draw_cat_selection()
    
    if ui_mode == "main" then
        local ledOn = 10
        local ledOff = 5
        
        for x = 1, #settings.soundout.event_modes do
            g:led(x, 1, settings.soundout.event_modes[x] == settings.soundout.sound_event_ui and ledOn or ledOff)
        end
        
        local c = getCurrentCat()
        local ui = settings.soundout.sound_event_ui
        
        if ui == "launch" then
            if c.launch_synth == 0 then g:led(1, 2, ledOn) end
            
            for x = 1, SYNTH_COUNT do
                g:led(x, 3, c.launch_synth == x and ledOn or ledOff)
            end
            
            if c.launch_midi == 0 then g:led(1, 4, ledOn) end
            
            for x = 1, 8 do
                g:led(x, 5, c.launch_midi == x and ledOn or ledOff)
                
                g:led(x, 6, c.launch_midi == x + 8 and ledOn or ledOff)
            end
        elseif ui == "bounce" then
            if c.bounce_synth == 0 then g:led(1, 2, ledOn) end
            
            for x = 1, SYNTH_COUNT do
                g:led(x, 3, c.bounce_synth == x and ledOn or ledOff)
            end
            
            if c.bounce_midi == 0 then g:led(1, 4, ledOn) end
            
            for x = 1, 8 do
                g:led(x, 5, c.bounce_midi == x and ledOn or ledOff)
                
                g:led(x, 6, c.bounce_midi == x + 8 and ledOn or ledOff)
            end
        elseif ui == "collision" then
            if c.collision_synth == 0 then g:led(1, 2, ledOn) end
            
            for x = 1, SYNTH_COUNT do
                g:led(x, 3, c.collision_synth == x and ledOn or ledOff)
            end
            
            if c.collision_midi == 0 then g:led(1, 4, ledOn) end
            
            for x = 1, 8 do
                g:led(x, 5, c.collision_midi == x and ledOn or ledOff)
                
                g:led(x, 6, c.collision_midi == x + 8 and ledOn or ledOff)
            end
        end
        
        -- probabilities
        
        -- for x = 9, 15 do
        --     local gcat = grooveCats[x-8]
        
        --     local grid_prob = util.linlin(0, 100, 0, 7, gcat.probability)
        
        --     for y = 1, grid_prob do
        --         g:led(x, 9 - y, gcat.enabled and 10 or 2)
        --     end
        -- end
        
        local grid_prob = util.round(c.probability / (100.0 / 15.0))
        -- local grid_prob = util.linlin(0, 100, 1, 16, c.probability)
        
        for x = 1, grid_prob do
            g:led(x, 8, ledOn)
        end
        
        -- sync Rates
        for x = 9, 15 do
            local gcat = grooveCats[x-8]
            
            for j = 1, #GrooveCat.SYNC_RATES do
                g:led(x, j + 1, gcat.syncMode == j and 10 or 2)
            end
        end
    elseif ui_mode == "cat" then
        grid_draw_cat_settings()
    end
end

settings.synths.grid_event = function(e)
    if e.y == 1 and e.x <= SYNTH_COUNT and e.type == "press" then
        settings.synths.selected = e.x
        show_overlay_message("Synth "..e.x)
    end
    
    for i, f in pairs(settings.synths.faders) do
        f:grid_event(e)
    end
end

settings.synths.grid_redraw = function(e)
    local ledOn = 10
    local ledOff = 5
    
    for x = 1, SYNTH_COUNT do
        g:led(x, 1, settings.synths.selected == x and ledOn or ledOff)
    end
    
    for i, f in pairs(settings.synths.faders) do
        f:draw(g)
    end
end

function grid_event_cat_selection(e)
    if e.y == 1 and e.x > 8 and e.x < 16 then
        local cat_id = e.x - 8
        if e.type == "press" then
            select_cat(cat_id)
        elseif e.type == "double_click" then
            toggle_cat_enable(cat_id)
        elseif e.type == "hold" then
            ui_mode = "cat"
            show_overlay_message("Cat Settings")
        elseif e.type == "release" and cat_id == selected_cat then
            ui_mode = "main"
        end
    end
end

function grid_draw_cat_selection()
    for x = 9, 15 do
        local cat_id = x - 8
        local trackCat = grooveCats[cat_id]
        
        g:led(x, 1, get_cat_led_level(cat_id))
    end
end

function grid_redraw()
    local grid_h = g.rows
    g:all(0)
    
    active_page.grid_redraw()
    grid_draw_toolbar()
    
    g:refresh()
end

function grid_draw_toolbar()
    
    g:led(settings.play.x, settings.play.y, is_playing and 10 or 2) -- play button
    
    local activePageLED = 10
    local inactivePageLED = 2
    
    for i, p in pairs(grid_pages) do
        g:led(p.x, p.y, is_page_active(p) and activePageLED or inactivePageLED)
    end
    
    -- random button
    g:led(16,7,4)
    
    if random_hold and util.time() > random_hold_time then
        random_hold = false
        if active_page.randomize_all then active_page.randomize_all() end
    end
    
    -- g:led(settings.sequencer.x, settings.sequencer.y, is_page_active(settings.sequencer) and activePageLED or inactivePageLED)
    -- g:led(settings.lightshow.x, settings.lightshow.y, is_page_active(settings.lightshow) and activePageLED or inactivePageLED)
end

function is_page_active(page)
    return page == active_page
end

settings.sequencer.grid_redraw = function()
    grid_draw_cat_selection()
    
    local c = getCurrentCat()
    
    if ui_mode == "main" then
        -- sequencer
        for x = 1, 8 do
            if c.bounce_seq.data[x] > 0 then g:led(x, 9 - c.bounce_seq.data[x], 5) end
        end

        local prevSeqPos = c.bounce_seq.pos - 1
        if prevSeqPos < 1 then prevSeqPos = c.bounce_seq.length end -- use prevPos since pos advances right after note is triggered. 
        
        if c.bounce_seq.data[prevSeqPos] > 0 then
            g:led(prevSeqPos, 9-c.bounce_seq.data[prevSeqPos], 15)
        else
            g:led(prevSeqPos, 1, 3)
        end
        
        g:led(9,8,10) -- randomize
        g:led(10,8,10) -- shuffle

        g:led(11,8, c.autoShuffle and 15 or 4) -- shuffle
        
        for i, f in pairs(settings.sequencer.faders) do
            f:draw(g)
        end
    elseif ui_mode == "cat" then
        grid_draw_cat_settings()
    end
end

settings.lightshow.grid_redraw = function()
    grid_draw_cat_selection()
    
    if ui_mode == "main" then
        grid_draw_scene(1,15,2,8, collision_events_full)
    elseif ui_mode == "cat" then
        grid_draw_cat_settings()
    end
end

-- draws the scene to the grid
function grid_draw_scene(x_min, x_max, y_min, y_max, collisionEventsTable)
    physicsEngine:grid_draw(g, x_min, x_max, y_min, y_max)
    
    grid_draw_collision_events(collisionEventsTable, x_min, x_max, y_min, y_max)
    
    for cat_id = 1, MAX_CATS do
        local gridCat = grooveCats[cat_id]
        
        if gridCat.enabled or gridCat.selected then 
            local grid_x, grid_y = get_grid_pos(x_min, x_max, y_min, y_max, gridCat.pos.x, gridCat.pos.y)
            g:led(grid_x, grid_y, get_cat_led_level(cat_id))
        end
    end
end

function get_cat_led_level(cat_id)
    local ledLevel = 2
    local cat = grooveCats[cat_id]
    
    if cat.enabled and cat.selected then ledLevel = (blink_on and 15 or 10)
    elseif not cat.enabled and cat.selected then ledLevel = (blink_on and 4 or 2)
    elseif cat.enabled and not cat.selected then ledLevel = 10 end
    return ledLevel
end

function get_grid_pos(x_min, x_max, y_min, y_max, pos_x, pos_y)
    local grid_x = util.round(util.linlin(wall_left, wall_right, x_min, x_max, pos_x))
    local grid_y = util.round(util.linlin(wall_up, wall_down, y_max, y_min, pos_y))
    
    return grid_x, grid_y
end

function get_pos_from_grid(x_min, x_max, y_min, y_max, grid_x, grid_y)
    local pos_x = util.round(util.linlin(x_min, x_max, wall_left, wall_right, grid_x))
    local pos_y = util.round(util.linlin(y_min, y_max, wall_down, wall_up, grid_y))
    
    return pos_x, pos_y
end

function key(n, v)
    
    if n == 1 then
        shift1_down = v == 1
    end
    
    if param_edit then
        paramUtil:key(n, v)
        
        if n == 2 and v == 1 then
            param_edit = false
        end
    else
        if shift1_down then
            if n == 2 and v == 1 then
                toggle_playback()
                -- local c = getCurrentCat()
                -- c.enabled = not c.enabled
                -- elseif n == 3 and v == 1 then
                --     addNewCat()
            elseif n == 3 and v == 1 then
                randomize_all()
            end
        else
            if n == 2 and v == 1 then
                local c = getCurrentCat()
                c.enabled = not c.enabled
                
                show_overlay2((c.enabled and "Meow" or "Poof"))
                -- shift2_down = v == 1
            elseif n == 3 and v == 1 then
                param_edit = true
                shift2_down = false
            end
        end
    end
end

function enc(n, d)
    if n == 1 then
        selected_cat_d = util.clamp(selected_cat_d + d * 0.25, 1, #grooveCats)
        -- selected_cat = cycle((selected_cat + util.clamp(d,-1,1)), 1, #grooveCats)
        selected_cat = util.round(selected_cat_d)
        ui.drawCatBar = true
        ui.catBarTime = util.time() + 1
        updateSelectedCat()
    end
    
    if param_edit then
        paramUtil:enc(n, d)
    else
        local current_cat = getCurrentCat()
        
        if current_cat == nil then return end
        
        if shift1_down then
            if n == 2 then
                current_cat:rotate(d * 5)
            elseif n == 3 then
                current_cat.autoRotateSpeed = util.clamp(current_cat.autoRotateSpeed + d, -180, 180)
                show_overlay2("AutoRotate: "..util.round(current_cat.autoRotateSpeed, 0.1))
            end
        else
            if n == 2 then
                current_cat:translate(d, 0)
            elseif n == 3 then
                current_cat:translate(0, -d)
            end
        end
    end
end


settings.fileIO.mode = "save"
settings.fileIO.projNum = 1
settings.fileIO.availableProjects = {}

settings.fileIO.init = function()
    settings.fileIO.availableProjects = {}
    
    for i = 1, (15 * 7) do
        settings.fileIO.availableProjects[i] = is_project_available(i)
    end
end

settings.fileIO.grid_redraw = function()    
    if settings.fileIO.mode == "save" then
        g:led(1, 1, 15)
        g:led(2, 1, 8)
    elseif settings.fileIO.mode == "load" then
        g:led(1, 1, 8)
        g:led(2, 1, 15)
    end
    
    for x = 1, 15 do
        for y = 2, 8 do
            local projNum = x + ((y - 2) * 15)
            
            g:led(x, y, settings.fileIO.availableProjects[projNum] and 10 or 0)
            
            if projNum == settings.fileIO.projNum then
                g:led(x,y,15)
            end
        end
    end
end

settings.fileIO.grid_event = function(e)
    
    if e.x == 1 and e.y == 1 and e.type == "press" then
        settings.fileIO.mode = "save"
        show_overlay_message("Save")
    elseif e.x == 2 and e.y == 1 and e.type == "press" then
        settings.fileIO.mode = "load"
        show_overlay_message("Load")
    end
    
    if e.x < 16 and e.y > 1 and e.type == "press" then
        local projNum = e.x + ((e.y - 2) * 15)
        if settings.fileIO.mode == "save" then
            save_project(projNum)
            settings.fileIO.init()
        elseif settings.fileIO.mode == "load" then
            load_project(projNum)
        end
    end
end

function load_last_project()
    local load_path = data_path.."catbrain"..".txt"
    
    local file = io.open(load_path)
    if file ~= nil then  
        io.close(file)
        
        local catbrain tab.load(load_path)
        if catbrain then load_project(catbrain.projNum) end
    end
end

function is_project_available(projNum)
    local load_path = data_path..projNum..".txt"
    return util.file_exists(load_path)
end

-- function GetFileName(path)
--     return path:match("^.+/(.+)$")
-- end

function GetFilename(path)   
    local start, finish = path:find('[%w%s!-={-|]+[_%.].+')   
    return path:sub(start,#path) 
end

function GetFileExtension(path)
    return path:match("^.+(%..+)$")
end

function SplitFilename(strFilename)
    -- Returns the Path, Filename, and Extension as 3 values
    return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
end

function load_project_params(fullPath)
    if fileIO_active then return end
    print("Load "..fullPath)
    fileIO_active = true
    local file = io.open(fullPath)
    
    if file ~= nil then  
        io.close(file)
        
        load_serialized_table(tab.load(fullPath))
        
        local pathname,filename,ext=string.match(fullPath,"(.-)([^\\/]-%.?([^%.\\/]*))$")
        
        filename = filename:match("(.+)%..+")
        -- local filename = GetFilename(fullPath)
        
        print("pathname "..pathname)
        print("filename "..filename)
        print("ext "..ext)
        
        local pset_path = params_path..filename.."_params.pset"
        
        print("pset_path "..pset_path)
        
        if util.file_exists(pset_path) then
            params:read(pset_path) 
            print("Presets loaded")
        end
        
        settings.fileIO.projNum = 1
        
        params:set("FileIO_name", filename, true)
        params:set("FileIO_load", "", true)
    else
        print("Cannot load, bad path. "..fullPath)
    end
    fileIO_active = false
end

function save_project_params(fileName)
    if fileIO_active then return end
    if not fileName then return end
    if #fileName == 0 then
        print("Cannot save. Filename is empty")
        return 
    end
    
    fileIO_active = true
    local save_path = data_path..fileName..".txt"
    
    params:set("FileIO_load", "", true)
    
    params:write(params_path..fileName.."_params.pset")
    tab.save(get_serialized_table(), save_path)
    
    local catbrain = {}
    catbrain.lastProjNum = settings.fileIO.projNum
    tab.save(catbrain, data_path.."catbrain"..".txt")
    
    print("saved to "..save_path)
    show_overlay_message("Saved "..fileName)
    
    redraw()
    
    fileIO_active = false
end

function load_project(projNum)
    if fileIO_active then return end
    projNum = projNum and projNum or 1
    local load_path = data_path..projNum..".txt"
    
    fileIO_active = true
    
    local file = io.open(load_path)
    if file ~= nil then  
        io.close(file)
        
        load_serialized_table(tab.load(load_path))
        
        local pset_path = params_path..projNum.."_params.pset"
        
        if util.file_exists(pset_path) then
            params:read(pset_path) 
            print("Presets loaded")
        end
        
        settings.fileIO.projNum = projNum
        
        show_overlay_message("Loaded "..projNum)
        
        params:set("FileIO_name", (""..projNum), true)
        params:set("FileIO_load", "", true)
    else
        print("Cannot load, bad path. "..load_path)
    end
    
    fileIO_active = false
end

function save_project(projNum)
    if fileIO_active then return end
    -- if saveName == nil then return end
    -- if saveName == "" then 
    --     print("Cannot save file without a name")
    --     return
    -- end
    
    -- project_name = saveName
    -- show_temporary_notification(project_name.." saved")
    
    fileIO_active = true
    
    local save_path = data_path..projNum..".txt"
    
    -- print("Save: "..path)
    
    params:set("FileIO_name", (""..projNum), true)
    params:set("FileIO_load", "", true)
    
    params:write(params_path..projNum.."_params.pset")
    tab.save(get_serialized_table(), save_path)
    
    local catbrain = {}
    catbrain.lastProjNum = projNum
    tab.save(catbrain, data_path.."catbrain"..".txt")
    
    print("saved to "..save_path)
    show_overlay_message("Saved "..projNum)
    
    redraw()
    
    fileIO_active = false
end

function get_serialized_table()
    local d = {}
    
    d.version = version_number
    
    d.grooveCats = {}
    
    for i = 1, #grooveCats do
        d.grooveCats[i] = grooveCats[i]:get_serialized()
    end
    
    return d
end

function load_serialized_table(d)
    if d == nil then
        print("Error: Bad serialized data")
        return
    end
    
    version_number = d.version
    
    for i = 1, #d.grooveCats do
        grooveCats[i]:load_serialized(d.grooveCats[i])
    end
end