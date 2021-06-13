-- groovecats
-- v1.0 @quixotic7
-- https://github.com/Quixotic7/groovecats
--
-- Experimental particle sequencer
-- 
-- ENC 1 select cat
-- ENC 2, ENC 2 move cat
-- KEY 2 shift mode
-- SHIFT + ENC 2 rotate cat
-- KEY 3 edit params for selected cat

-- Add the names of your favorite cats, max of 8
local cat_names = {"wednesday", "swisher", "franky", "tigger", "max", "kittenface", "colby", "max"}
local MAX_CATS = 8

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

local hsdelay = include('lib/halfsecond')
local MidiBangs = include('lib/midibangs')
local Grid_Events_Handler = include('lib/grid_events')

thebangs = include('thebangs/lib/thebangs_engine')
MusicUtil = require "musicutil"

engine.name = 'Thebangs'

g = grid.connect()

local particleEngine = nil
local physicsEngine = nil

-- local particles = {}

-- local particle_pool = {}

local physicsBodies = {}

local grooveCats = {}

local SYNTH_COUNT = 4
local MIDI_COUNT = 16


local is_playing = false


local x_min = 0
local x_max = 128

local y_min = 0
local y_max = 64

local prevTime = 0

local seqPos = 1
local octave = 0
local loopCount = 0

local scale_names = {}
local notes = {}
local active_notes = {}

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

function init()
    grid_events = Grid_Events_Handler.new() -- Handles grid events to differentiate press, click, double click, hold
    grid_events.grid_event = function (e) grid_event(e) end

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
    end
}

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
end
)

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
end
)

paramUtil:add_option("Sync Rate", 
function() return GrooveCat.SYNC_RATES[getCurrentCat().syncMode] end, 
function(d,d_raw) 
    local c = getCurrentCat()
    
    c:changeSyncMode(c.syncMode + d)
end
)

paramUtil:add_option("RotSpeed", 
function() return getCurrentCat().autoRotateSpeed end, 
function(d,d_raw) 
    local c = getCurrentCat()
    
    c.autoRotateSpeed = util.clamp(c.autoRotateSpeed + d_raw, -180, 180)
end
)

paramUtil:add_option("Probability", 
function() return getCurrentCat().probability end, 
function(d,d_raw) 
    local c = getCurrentCat()
    
    c.probability = util.clamp(c.probability + d_raw, 0, 100)
end
)

paramUtil:add_option("LSpeedMin", 
function() return getCurrentCat().lSpeedMin end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.lSpeedMin = util.clamp(c.lSpeedMin + d_raw, 1, 100)
end
)

paramUtil:add_option("LSpeedMax", 
function() return getCurrentCat().lSpeedMax end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.lSpeedMax = util.clamp(c.lSpeedMax + d_raw, 1, 100)
end
)

paramUtil:add_option("Octave", 
function() return getCurrentCat().octave end, 
function(d,d_raw) 
    local c = getCurrentCat()
    
    c.octave = util.clamp(c.octave + d_raw, -4, 4)
end
)

paramUtil:add_option("Launch Synth", 
function() 
    local c = getCurrentCat()
    if c.launch_synth == 0 then return "disabled" end
    return c.launch_synth
end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.launch_synth = util.clamp(c.launch_synth + d, 0, SYNTH_COUNT)
end
)

paramUtil:add_option("Bounce Synth", 
function() 
    local c = getCurrentCat()
    if c.bounce_synth == 0 then return "disabled" end
    return c.bounce_synth
end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.bounce_synth = util.clamp(c.bounce_synth + d, 0, SYNTH_COUNT)
end
)

paramUtil:add_option("Collision Synth", 
function() 
    local c = getCurrentCat()
    if c.collision_synth == 0 then return "disabled" end
    return c.collision_synth
end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.collision_synth = util.clamp(c.collision_synth + d, 0, SYNTH_COUNT)
end
)
paramUtil:add_option("Launch Midi", 
function() 
    local c = getCurrentCat()
    if c.launch_midi == 0 then return "disabled" end
    return c.launch_midi
end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.launch_midi = util.clamp(c.launch_midi + d, 0, MIDI_COUNT)
end
)
paramUtil:add_option("Bounce Midi", 
function() 
    local c = getCurrentCat()
    if c.bounce_midi == 0 then return "disabled" end
    return c.bounce_midi
end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.bounce_midi = util.clamp(c.bounce_midi + d, 0, MIDI_COUNT)
end
)
paramUtil:add_option("Collision Midi", 
function() 
    local c = getCurrentCat()
    if c.collision_midi == 0 then return "disabled" end
    return c.collision_midi
end, 
function(d,d_raw) 
    local c = getCurrentCat()
    c.collision_midi = util.clamp(c.collision_midi + d, 0, MIDI_COUNT)
end
)

updateSelectedCat()

clock.run(screen_redraw_clock)
clock.run(grid_redraw_clock) 

toggle_playback()
end

function addSynthParams(id)
    local num_params = 8
    params:add_group("Synth " .. id, num_params)
    
    params:add{ type = "option", id = "algo_"..id, name = "Algo", options = thebangs.options.algoNames, default = 3 }
    params:add{ type = "control", id = "amp_"..id, name = "Amp",controlspec = controlspec.new(0, 1, 'lin', 0, 0.5, '') }
    params:add{ type = "control", id = "pan_"..id, name = "Pan",controlspec = controlspec.new(-1, 1, 'lin', 0, 0, '') }
    params:add{ type = "control", id = "mod1_"..id, name = "Mod1",controlspec = controlspec.new(0, 1, 'lin', 0, 0.5, '%') }
    params:add{ type = "control", id = "mod2_"..id, name = "Mod2",controlspec = controlspec.new(0, 4, 'lin', 0, 1.0, '%') }
    params:add{ type = "control", id = "cutoff_"..id, name = "Cutoff",controlspec = controlspec.new(50, 5000, 'exp', 0, 800, 'hz') }
    params:add{ type = "control", id = "attack_"..id, name = "Attack",controlspec = controlspec.new(0.0001, 10, 'exp', 0, 0.01, 's') }
    -- controlspec.new(0.1,3.2,'lin',0,1.2,'s')
    params:add{ type = "control", id = "release_"..id, name = "Release",controlspec = controlspec.new(0.0001, 10, 'exp', 0, 1.0, 's') }
end

function addMidiParams(id)
    local num_params = 6
    params:add_group("Midi " .. id, num_params)
    
    params:add{type="number", id="midiDevice_"..id, name="Device", min = 1, max = 4, default = 1 }
    params:add{type="number", id="midiChannel_"..id, name="Channel", min = 0, max = 16, default = id }
    params:add{type="number", id="midiVelMin_"..id, name="Vel Min", min = 0, max = 127, default = 60 }
    params:add{type="number", id="midiVelMax_"..id, name="Vel Max", min = 0, max = 127, default = 120 }
    -- params:add{type = "control", id = "midiNoteLength_"..id, name = "Note Length", controlspec = controlspec.new(0.0001, 16.0, 'exp', 1/24, 0.25, 'bt')}
    
    params:add{type = "control", id = "midiNoteLengthMin_"..id, name = "Length Min", controlspec = controlspec.new(0, 16.0, 'lin', 0.01, 1/4, 'bt', 1/24/10)}
    params:add{type = "control", id = "midiNoteLengthMax_"..id, name = "Length Max", controlspec = controlspec.new(0, 16.0, 'lin', 0.01, 1/4, 'bt', 1/24/10)}
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
        print("Stop purring")
        clock.transport.stop()
    else
        print("Start purring")
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
end

function toggle_cat_enable(cat_id)
    if cat_id < 1 or cat_id > MAX_CATS then return end
    
    grooveCats[cat_id].enabled = not grooveCats[cat_id].enabled
end

function updateSelectedCat()
    if selected_cat ~= prevSelectedCat then
        local c = grooveCats[prevSelectedCat]
        if c ~= nil then c.selected = false end
        
        getCurrentCat().selected = true
    end
    
    prevSelectedCat = selected_cat
    
end

function add_default_cats()
    for i = 1, MAX_CATS do
        
        local c =  GrooveCat.new(physicsEngine, particleEngine)
        
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

function build_scale()
    notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
    local num_to_add = 16 - #notes
    for i = 1, num_to_add do
        table.insert(notes, notes[16 - num_to_add])
    end
end

function bang_note(synthId, midiId, noteNumber)
    if noteNumber < 0 or noteNumber > 127 then return end
    
    if synthId > 0 then
        updateSynth(synthId)
        local freq = MusicUtil.note_num_to_freq(noteNumber)
        engine.hz(freq)
    end
    if midiId > 0 then
        local deviceId = params:get("midiDevice_"..midiId)
        local vel = math.random(params:get("midiVelMin_"..midiId), params:get("midiVelMax_"..midiId))
        local length = util.linlin(0,1, params:get("midiNoteLengthMin_"..midiId), params:get("midiNoteLengthMax_"..midiId), math.random())
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
    intern_add_collision_event(collision_events_full, 1, 16, 1, 8, pos_x, pos_y)
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

function grid_draw_collision_events(eventsTable, x_max, y_max)
    for x = 1, x_max do
        for y = 1, y_max do
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

function redraw()
    screen.clear()
    screen.aa(0)
    
    if param_edit then
        screen.move(64, 10)
        screen.level(15)
        screen.text_center(cat_names[selected_cat])
        
        paramUtil:redraw()
    else
        for i,c in pairs(grooveCats) do
            c:draw()
        end
        
        screen.blend_mode('add')
        particleEngine:draw()
        screen.blend_mode(0)
        
        physicsEngine:draw()
        
        
    end
    
    screen.update()
end

function getCurrentCat()
    return grooveCats[selected_cat]
end

function set_grid_dirty()
    grid_dirty = true
end

function g.key(x, y, z)
    grid_events:key(x,y,z)
end

function grid_event(e)
    local c = getCurrentCat()
    
    if ui_mode == "lightshow" then
        
        -- toggle playback
        if e.x == 16 and e.y == 8 and e.type == "press" then
            toggle_playback()
        end
        
        -- LightShow!!!
        if e.x == 15 and e.y == 8 and e.type == "press" then
            ui_mode = "main"
        end
        
    else
        
        -- cats
        if e.y == 1 and e.x > 8 then
            local cat_id = e.x - 8
            if e.type == "press" then
                select_cat(cat_id)
            elseif e.type == "double_click" then
                toggle_cat_enable(cat_id)
            elseif e.type == "hold" then
                ui_mode = "cat"
            elseif e.type == "release" and cat_id == selected_cat then
                ui_mode = "main"
            end
        end
        
        if ui_mode == "cat" then
            
            if e.x <= 8 and e.type == "press" then
                local pos_x, pos_y = get_pos_from_grid(1,8,1,8,e.x,e.y)
                
                c.pos.x = pos_x
                c.pos.y = pos_y
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
            
            -- toggle playback
            if e.x == 16 and e.y == 8 and e.type == "press" then
                toggle_playback()
            end
            
            -- LightShow!!!
            if e.x == 15 and e.y == 8 and e.type == "press" then
                ui_mode = "lightshow"
            end
        end
    end
    
    set_grid_dirty()
end

function grid_redraw()
    local grid_h = g.rows
    g:all(0)
    
    local c = getCurrentCat()
    
    if ui_mode == "lightshow" then
        grid_draw_scene(1,16,1,8, collision_events_full)
        
        g:led(15,8, 4) -- exit lightshow
        g:led(16,8, is_playing and 4 or 2) -- play button
    else
        -- cat selection
        for x = 9, 16 do
            local cat_id = x - 8
            local trackCat = grooveCats[cat_id]
            
            g:led(x, 1, get_cat_led_level(cat_id))
        end
        
        
        if ui_mode == "main" then
            -- sequencer
            for x = 1, 8 do
                if c.bounce_seq.data[x] > 0 then g:led(x, 9 - c.bounce_seq.data[x], 5) end
            end
            
            if c.bounce_seq.pos > 0 and c.bounce_seq.data[c.bounce_seq.pos] > 0 then
                g:led(c.bounce_seq.pos, 9-c.bounce_seq.data[c.bounce_seq.pos], 15)
            else
                g:led(c.bounce_seq.pos, 1, 3)
            end
            
            -- Play button
            g:led(16,8, is_playing and 15 or 2)
            
        elseif ui_mode == "cat" then
            grid_draw_scene(1,8,1,8, collision_events_half)
        end 
    end
    
    g:refresh()
end

-- draws the scene to the grid
function grid_draw_scene(x_min, x_max, y_min, y_max, collisionEventsTable)
    physicsEngine:grid_draw(g, x_min, x_max, y_min, y_max)

    grid_draw_collision_events(collisionEventsTable, x_max, y_max)
    
    for cat_id = 1, 8 do
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
                local c = getCurrentCat()
                c.enabled = not c.enabled
            elseif n == 3 and v == 1 then
                addNewCat()
            end
        else
            if n == 2 then
                shift2_down = v == 1
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
        updateSelectedCat()
    end
    
    if param_edit then
        paramUtil:enc(n, d)
    else
        
        
        local current_cat = getCurrentCat()
        
        if current_cat == nil then return end
        
        if shift2_down then
            if n == 2 then
                current_cat:rotate(d * 5)
            elseif n == 3 then
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

