-- local Q7Util = include("gridstep/lib/Q7Util")
local Particle = include("particles/lib/particle")

local p = nil

local particles = {}

local particle_pool = {}


local x_min = 0
local x_max = 128

local y_min = 0
local y_max = 64

local prevTime = 0

function init()
    clock.run(spawn_particle_clock)
    clock.run(screen_redraw_clock)
end

function GetNewParticle()
    if #particle_pool > 0 then
        local p = table.remove(particle_pool, 1)
        p:reset()
        return p

        -- for i = 1, #particle_pool do
        --     if particle_pool[i] ~= nil then
        --         local p = particle_pool[i]
        --         particle_pool[i] = nil
        --         p:reset()
        --         return p
        --     end
        -- end
    end

    return Particle.new()
end

function spawn_particle_clock()
    while true do
        local n = math.random(2,80)

        local spawn_x = math.random(x_min, x_max)
        local spawn_y = math.random(y_min, y_max)

        local spawn_speed = math.random()

        for i = 1, n do
            local p = GetNewParticle()
            p.x = spawn_x
            p.y = spawn_y

            p.speed = math.random(5,100) * spawn_speed
            p:calc_velocity()

            table.insert(particles, p)
        end
        
        clock.sleep(util.linlin(0.0,1.0,0.3,1.0,math.random()))
    end
end

function screen_redraw_clock()
    prevTime = util.time()
    while true do
        clock.sleep(1/30)

        local currentTime = util.time()
        local deltaTime = currentTime - prevTime
        prevTime = currentTime

        update(deltaTime)
        redraw()
    end
end

function update(deltaTime)
    local n = #particles

    for i = 1, n do
        particles[i]:update(deltaTime)

        if particles[i].life <= 0 then
            table.insert(particle_pool, particles[i])
            particles[i] = nil
        end
    end

    -- cleanup table
    local j=0
    for i = 1, n do
        if particles[i] ~= nil then
            j = j + 1
            particles[j] = particles[i]
        end
    end

    for i = j + 1, n do
        particles[i] = nil
    end
end

function redraw()
    screen.clear()
    screen.aa(0)

    for i = 1, #particles do
        particles[i]:redraw();
    end

    screen.update()
end

