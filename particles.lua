-- local Q7Util = include("gridstep/lib/Q7Util")
local ParticleEngine = include("particles/lib/particleEngine")
local PhysicsEngine = include("particles/lib/physicsEngine")
local Particle = include("particles/lib/particle")
local PhysicsBody = include("particles/lib/physicsBody")

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


function init()
    particleEngine = ParticleEngine.new()
    physicsEngine = PhysicsEngine.new()


    clock.run(spawn_particle_clock)
    clock.run(screen_redraw_clock)
end



function spawn_particle_clock()
    while true do

        local b = PhysicsBody.new(math.random(x_min, x_max),math.random(y_min, y_max))

        b.particleEngine = particleEngine

        physicsEngine:addBody(b)

        -- print("Spawning physics body "..b.x)

        clock.sleep(1)





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
        clock.sleep(1/30)

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

