-- local Q7Util = include("gridstep/lib/Q7Util")
local ParticleEngine = include("particles/lib/particleEngine")
local PhysicsEngine = include("particles/lib/physicsEngine")
local Particle = include("particles/lib/particle")
local PhysicsBody = include("particles/lib/physicsBody")
local GrooveCat = include("particles/lib/grooveCat")
local ParamListUtil = include("gridstep/lib/Q7ParamListUtil")
local hsdelay = include("gridstep/lib/halfsecond")

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

-- local cat_names = {"wednesday", "swisher", "franky", "tiger"}

local cat_names = {"wednesday", "swisher"}

-- local selected_grooveCat = 1

local prevSelectedCat = 0

local shift2_down = false

local param_edit = false

local paramUtil = {}

function init()
    physicsEngine = PhysicsEngine.new()
    particleEngine = ParticleEngine.new()

    grooveCats[1] = GrooveCat.new(physicsEngine, particleEngine)
    grooveCats[2] = GrooveCat.new(physicsEngine, particleEngine)

    grooveCats[1].autoRotateSpeed = 0
    grooveCats[1]:changeSyncMode(2)
    grooveCats[1].pos.x = 80
    grooveCats[1].pos.y = 40

    grooveCats[2].personality = 3

    for i, c in pairs(grooveCats) do
        c.onMeow = onMeow
        c.gravity = gravity
    end
    

    for i = 1, #MusicUtil.SCALES do
        table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
    end

    physicsEngine.collisionFunc = onCollision
    physicsEngine.bounceFunc = onBounce

    params:add{type = "option", id = "selected_cat", name = "selected cat",
    options = cat_names, default = 1,
    action = function() updateSelectedCat() end}

    hsdelay.init()
    params:set("delay_enabled", 2)

    params:add_separator()
    -- thebangs.add_additional_synth_params()

    params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 5,
    action = function() build_scale() end}
    params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end}

    -- cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
    -- params:add{type="control",id="amp",controlspec=cs_AMP,
    --     action=function(x) engine.amp(x) end}

    -- cs_PW = controlspec.new(0,100,'lin',0,50,'%')
    -- params:add{type="control",id="pw",controlspec=cs_PW,
    --     action=function(x) engine.pw(x/100) end}

    -- cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
    -- params:add{type="control",id="release",controlspec=cs_REL,
    --     action=function(x) engine.release(x) end}

    -- cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
    -- params:add{type="control",id="cutoff",controlspec=cs_CUT,
    --     action=function(x) engine.cutoff(x) end}

    -- cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
    -- params:add{type="control",id="gain",controlspec=cs_GAIN,
    --     action=function(x) engine.gain(x) end}
    
    -- cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
    -- params:add{type="control",id="pan",controlspec=cs_PAN,
    --     action=function(x) engine.pan(x) end}

    
  
    params:add_separator()
    thebangs.add_voicer_params()

    build_scale()

    paramUtil = ParamListUtil.new()

    paramUtil.delta_speed = 0.6

    paramUtil:add_option("Gravity", 
        function() return physicsEngine.gravity end, 
        function(d,d_raw) 
            physicsEngine.gravity = util.clamp(physicsEngine.gravity + d_raw * 0.25, -20, 20)
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

            c.autoRotateSpeed = util.clamp(c.autoRotateSpeed + d_raw, -90, 90)
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

            c.octave = util.clamp(c.octave + d_raw, -2, 2)
        end
    )

    paramUtil:add_option("bounce algo", 
        function() return thebangs.options.algoNames[getCurrentCat().bounce_synth.algo] end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.bounce_synth.algo = util.clamp(c.bounce_synth.algo + d, 1, #thebangs.options.algoNames)
        end
    )
    paramUtil:add_option("bounce amp", 
    function() return getCurrentCat().bounce_synth.amp end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.bounce_synth.amp = util.clamp(c.bounce_synth.amp + d_raw * 0.05, 0, 1)
        end
    )
    paramUtil:add_option("bounce pw", 
    function() return getCurrentCat().bounce_synth.pw end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.bounce_synth.pw = util.clamp(c.bounce_synth.pw + d_raw, 0,100)
        end
    )
    paramUtil:add_option("bounce cutoff", 
    function() return getCurrentCat().bounce_synth.cutoff end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.bounce_synth.cutoff = util.clamp(c.bounce_synth.cutoff + d_raw * 25, 50, 5000)
        end
    )
    paramUtil:add_option("bounce attack", 
    function() return getCurrentCat().bounce_synth.attack end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.bounce_synth.attack = util.clamp(c.bounce_synth.attack + d_raw * 0.05, 0.0001, 1)
        end
    )
    paramUtil:add_option("bounce release", 
    function() return getCurrentCat().bounce_synth.release end,  
        function(d,d_raw) 
            local c = getCurrentCat()
            c.bounce_synth.release = util.clamp(c.bounce_synth.release + d_raw * 0.05, 0.1, 3.2)
        end
    )

    paramUtil:add_option("col algo", 
        function() return thebangs.options.algoNames[getCurrentCat().collision_synth.algo] end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.collision_synth.algo = util.clamp(c.collision_synth.algo + d, 1, #thebangs.options.algoNames)
        end
    )
    paramUtil:add_option("col amp", 
    function() return getCurrentCat().collision_synth.amp end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.collision_synth.amp = util.clamp(c.collision_synth.amp + d_raw * 0.05, 0, 1)
        end
    )
    paramUtil:add_option("col pw", 
    function() return getCurrentCat().collision_synth.pw end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.collision_synth.pw = util.clamp(c.collision_synth.pw + d_raw, 0,100)
        end
    )
    paramUtil:add_option("col cutoff", 
    function() return getCurrentCat().collision_synth.cutoff end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.collision_synth.cutoff = util.clamp(c.collision_synth.cutoff + d_raw * 25, 50, 5000)
        end
    )
    paramUtil:add_option("col attack", 
    function() return getCurrentCat().collision_synth.attack end, 
        function(d,d_raw) 
            local c = getCurrentCat()
            c.collision_synth.attack = util.clamp(c.collision_synth.attack + d_raw * 0.05, 0.0001, 1)
        end
    )
    paramUtil:add_option("col release", 
    function() return getCurrentCat().collision_synth.release end,  
        function(d,d_raw) 
            local c = getCurrentCat()
            c.collision_synth.release = util.clamp(c.collision_synth.release + d_raw * 0.05, 0.1, 3.2)
        end
    )

    updateSelectedCat()

    -- params:set("algo", 4)

    -- clock.run(spawn_particle_clock)
    clock.run(screen_redraw_clock)

    for i, c in pairs(grooveCats) do
        c:purr()
    end

    gridredraw()
end

function updateSelectedCat()
    local i = params:get("selected_cat")

    if i ~= prevSelectedCat then
        local c = grooveCats[prevSelectedCat]
        if c ~= nil then c.selected = false end

        getCurrentCat().selected = true
    end

    prevSelectedCat = i

end

function build_scale()
    notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
    local num_to_add = 16 - #notes
    for i = 1, num_to_add do
      table.insert(notes, notes[16 - num_to_add])
    end
  end

function onCollision(b1, b2)

    local n = seqPos

    if b1 == nil then print("b1 is nil") end
    if b2 == nil then print("b2 is nil") end


    -- params:set("algo", 6)
    -- params:set("release", util.linlin(0,1,0.6,2.0, math.random()))

    updateSynth(b1.cat.collision_synth)

    local n1 = b1.cat:bounce_step()
    local n2 = b2.cat:bounce_step()
 
    local note_num = notes[n1 + n2]

    local freq = MusicUtil.note_num_to_freq(note_num)
    engine.hz(freq)

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

function updateSynth(synthParams)
    engine.algoIndex(synthParams.algo)
    engine.amp(synthParams.amp)
    engine.pw(synthParams.pw/100)
    engine.cutoff(synthParams.cutoff)
    engine.attack(synthParams.attack)
    engine.release(synthParams.release)
end

function onBounce(physicsBody)
    -- params:set("release", 0.25)
    -- params:set("algo", 2)

    -- engine.algoIndex(2)

    local c = physicsBody.cat

    local note_index = c:bounce_step()

    if note_index > 0 then
        updateSynth(c.bounce_synth)

        local note_num = notes[note_index] + 12 * c.octave
        local freq = MusicUtil.note_num_to_freq(note_num)
        engine.hz(freq)

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

    gridredraw()
end

function onMeow(grooveCat)
    engine.algoIndex(6)
    engine.amp(0.3)
    engine.attack(0.01)
    engine.release(util.linlin(0,1,0.2,3.0,math.random()))

    local note_num = notes[seqPos] + 12 * octave
    local freq = MusicUtil.note_num_to_freq(note_num)
    engine.hz(freq)

    gridredraw()
end

function screen_redraw_clock()
    prevTime = util.time()
    while true do
        clock.sleep(1/15)

        local currentTime = util.time()
        local deltaTime = currentTime - prevTime
        prevTime = currentTime

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

function redraw()
    screen.clear()
    screen.aa(0)

    if param_edit then
        screen.move(64, 10)
        screen.level(15)
        screen.text_center(cat_names[params:get("selected_cat")])

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
    return grooveCats[params:get("selected_cat")]
end

function g.key(x, y, z)
    local grid_h = g.rows
    local c = getCurrentCat()

    if z > 0 then
        if c.bounce_seq.data[x] == 9-y then
            c:set_loop_data(x, 0)
        else
            c:set_loop_data(x, 9 - y)
        end
        
        gridredraw()
    end
end

function gridredraw()
    local grid_h = g.rows
    g:all(0)

    local c = getCurrentCat()

    for x = 1, 16 do
        if c.bounce_seq.data[x] > 0 then g:led(x, 9 - c.bounce_seq.data[x], 5) end
    end

    if c.bounce_seq.pos > 0 and c.bounce_seq.data[c.bounce_seq.pos] > 0 then
        g:led(c.bounce_seq.pos, 9-c.bounce_seq.data[c.bounce_seq.pos], 15)
    else
        g:led(c.bounce_seq.pos, 1, 3)
    end
    
    g:refresh()
end

function key(n, v)
    if param_edit then
        paramUtil:key(n, v)

        if n == 2 and v == 1 then
            param_edit = false
        end
    else
        if n == 2 then
            shift2_down = v == 1 and true or false
        elseif n == 3 and v == 1 then
            param_edit = true
        end
    end
end

function enc(n, d)
    if n == 1 then
        params:delta("selected_cat", d)
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

