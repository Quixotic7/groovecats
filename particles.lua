-- local Q7Util = include("gridstep/lib/Q7Util")
local ParticleEngine = include("particles/lib/particleEngine")
local PhysicsEngine = include("particles/lib/physicsEngine")
local Particle = include("particles/lib/particle")
local PhysicsBody = include("particles/lib/physicsBody")

thebangs = include('thebangs/lib/thebangs_engine')
MusicUtil = require "musicutil"

engine.name = 'Thebangs'

local particleEngine = nil
local physicsEngine = nil

-- local particles = {}

-- local particle_pool = {}

local physicsBodies = {}


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


function init()
    particleEngine = ParticleEngine.new()
    physicsEngine = PhysicsEngine.new()


    

    for i = 1, #MusicUtil.SCALES do
        table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
    end

    physicsEngine.collisionFunc = onCollision
    physicsEngine.bounceFunc = onBounce


    params:add_separator()
    thebangs.add_additional_synth_params()

    params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 5,
    action = function() build_scale() end}
    params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end}

    cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
    params:add{type="control",id="amp",controlspec=cs_AMP,
        action=function(x) engine.amp(x) end}

    cs_PW = controlspec.new(0,100,'lin',0,50,'%')
    params:add{type="control",id="pw",controlspec=cs_PW,
        action=function(x) engine.pw(x/100) end}

    cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
    params:add{type="control",id="release",controlspec=cs_REL,
        action=function(x) engine.release(x) end}

    cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
    params:add{type="control",id="cutoff",controlspec=cs_CUT,
        action=function(x) engine.cutoff(x) end}

    cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
    params:add{type="control",id="gain",controlspec=cs_GAIN,
        action=function(x) engine.gain(x) end}
    
    cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
    params:add{type="control",id="pan",controlspec=cs_PAN,
        action=function(x) engine.pan(x) end}

    
  
    params:add_separator()
    thebangs.add_voicer_params()

    build_scale()

    params:set("algo", 4)

    clock.run(spawn_particle_clock)
    clock.run(screen_redraw_clock)
end

function build_scale()
    notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
    local num_to_add = 16 - #notes
    for i = 1, num_to_add do
      table.insert(notes, notes[16 - num_to_add])
    end
  end

function onCollision(b1, b2)

    local n = math.random(1,8)

    -- params:set("algo", 6)
    -- params:set("release", util.linlin(0,1,0.6,2.0, math.random()))

    engine.algoIndex(6)
    local note_num = notes[n]
    local freq = MusicUtil.note_num_to_freq(note_num)
    engine.hz(freq)

    -- for i = 1, 3 do
    --     local note_num = notes[((i-1) * 2) + 1 + n]
    --     local freq = MusicUtil.note_num_to_freq(note_num)
    --     engine.hz(freq)
    -- end
end

function onBounce(physicsBody)
    -- params:set("release", 0.25)
    -- params:set("algo", 2)

    -- engine.algoIndex(2)

    -- local note_num = notes[math.random(1,16)]
    -- local freq = MusicUtil.note_num_to_freq(note_num)
    -- engine.hz(freq)
end


function spawn_particle_clock()
    while true do

        local b = PhysicsBody.new(math.random(x_min, x_max),math.random(y_min, y_max))

        b.particleEngine = particleEngine

        physicsEngine:addBody(b)

        -- params:set("algo", math.random(1, #thebangs.options.algoNames))
        -- params:set("pw", math.random(1,100))
        -- params:set("release", util.linlin(0,1,0.1,1.0, math.random()))


        engine.algoIndex(2)
        local note_num = notes[seqPos] + 12 * octave
        local freq = MusicUtil.note_num_to_freq(note_num)
        engine.hz(freq)

        -- seqPos = (seqPos % 8) + 2

        seqPos = seqPos + 2
        if seqPos > 8 then
            seqPos = 1
            loopCount = (loopCount + 1) % 4
            if loopCount == 0 then
                octave = (octave + 1) % 2
            end
        end

        -- print("Spawning physics body "..b.x)

        clock.sync(1)





        -- local n = math.random(2,80)

        -- local spawn_x = math.random(x_min, x_max)
        -- local spawn_y = math.random(y_min, y_max)

        -- local spawn_speed = math.random()

        -- for i = 1, n do
        --     local p = GetNewParticle()
        --     p.x = spawn_x
        --     p.y = spawn_y

        --     p.speed = math.random(5,100) * spawn_speed
        --     p:calc_velocity()

        --     table.insert(particles, p)
        -- end
        
        -- clock.sleep(util.linlin(0.0,1.0,0.3,1.0,math.random()))
    end
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
        redraw()
    end
end

function redraw()
    screen.clear()
    screen.aa(0)

    particleEngine:draw()
    physicsEngine:draw()

    screen.update()
end

