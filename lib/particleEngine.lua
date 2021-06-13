local ParticleEngine = {}
ParticleEngine.__index = ParticleEngine

function ParticleEngine.new()
    local e = setmetatable({}, ParticleEngine)

    e.iterations = 5
    e.particles = {}
    e.particle_pool = {}

    return e
end

function ParticleEngine:GetNewParticle()
    if #self.particle_pool > 0 then
        local p = table.remove(self.particle_pool, 1)
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

function ParticleEngine:AddParticle(p)
    table.insert(self.particles, p)
end

function ParticleEngine:update(deltaTime)
    local n = #self.particles

    for i = 1, n do
        self.particles[i]:update(deltaTime)

        if self.particles[i].life <= 0 then
            table.insert(self.particle_pool, self.particles[i])
            self.particles[i] = nil
        end
    end

    -- cleanup table
    local j=0
    for i = 1, n do
        if self.particles[i] ~= nil then
            j = j + 1
            self.particles[j] = self.particles[i]
        end
    end

    for i = j + 1, n do
        self.particles[i] = nil
    end
end

function ParticleEngine:draw()
    for i, p in pairs(self.particles) do
        p:redraw()
    end
end

return ParticleEngine