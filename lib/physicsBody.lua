local vector2d = require("particles/lib/vector2d")

local PhysicsBody = {}
PhysicsBody.__index = PhysicsBody


function PhysicsBody.new(x,y)
    local p = setmetatable({}, PhysicsBody)

    p.cat = nil
    p.mass = 1
    p.noteIndex = 0
    p.octave = 0
    p.pos = vector2d.new(x, y)
    p.start_life = 2
    p.shape = 1 -- circle, box
    -- p.radius = math.random(1,3)

    p.radius = 2
    p.life = 4
    p.bounce = 1
    p.collisionBounce = 1
    p.speed = 20
    p.angle = math.random() * 2 * math.pi
    p.gravity = 4
    p.brightness = 15
    p.destroy = false
    p.trail = true

    p.particleEngine = nil

    p.vel = vector2d.new(0,0)

    -- p.vel.x = p.speed * math.cos(p.angle)
    -- p.vel.y = p.speed * math.sin(p.angle)

    p.prevPos = p.pos

    p.prevDeltaT = 0.01

    p.collision = false
    p.bounceOccured = false
    p.catCollision = false



    p.emissionRate = 10
    p.emissionTimer = 0

    p.burstCount = 20

    -- print("new physics obj "..x.." "..y)

    p:recalc_velocity()

    return p
end

function PhysicsBody:recalc_velocity()

    self.vel = vector2d(1,0):rotate(util.degs_to_rads(self.angle)) * self.speed

    -- self.vel.x = self.speed * math.cos(self.angle)
    -- self.vel.y = self.speed * math.sin(self.angle)
end

function PhysicsBody:burstParticles()
    if self.particleEngine == nil then return end

    local velMag = self.vel:getmag()

    for i = 1, self.burstCount do
        local p = self.particleEngine:GetNewParticle()

        p.x = self.pos.x
        p.y = self.pos.y

        p.size = util.linlin(0,1,1,4,math.random())
        p.gravity = 1
        p.start_life = util.linlin(0,1,0.5,2,math.random())
        p.life = p.start_life
        p.speed = velMag * math.random()

        p:calc_velocity()

        self.particleEngine:AddParticle(p)
    end
end

function PhysicsBody:emitParticles(deltaTime)
    if self.particleEngine == nil or self.trail == false then return end

    self.emissionTimer = self.emissionTimer + deltaTime

    if self.emissionTimer >= 1 / self.emissionRate then
        self.emissionTimer = 0

        local p = self.particleEngine:GetNewParticle()

        p.x = self.pos.x
        p.y = self.pos.y

        p.size = 1
        p.gravity = 0
        p.start_life = 0.2
        p.life = 0.2
        p.speed = self.vel:getmag() * 0.1

        p:calc_velocity()

        self.particleEngine:AddParticle(p)
    end
end

function PhysicsBody:update(deltaTime)
    -- self.vel.x = self.vel.x * 0.99
    -- self.vel.y = self.vel.y * 0.99 - self.gravity
    self.prevDeltaT = deltaTime

    -- self.vel = self.vel * 0.98

    self.vel.y = self.vel.y - self.gravity

    self.prevPos = self.pos:clone()

    self.pos = self.pos + self.vel * deltaTime

    -- self.x = self.x + self.vel.x * deltaTime
    -- self.y = self.y + self.vel.y * deltaTime

    if self.pos.x - self.radius < 0 or self.pos.x + self.radius > 128 then
        self.vel.x = self.vel.x * -self.bounce
        self.bounceOccured = true
    end

    if self.pos.y - self.radius < 0 then
        self.pos.y = self.radius
        self.vel.y = self.vel.y * -self.bounce
        -- print("Floor collision")
        self.bounceOccured = true
    end

    self.life = self.life - deltaTime;

    self:emitParticles(deltaTime)

    self.catCollision = false


    -- self.brightness = util.round(util.linlin(self.start_life, 0, self.start_brightness, self.end_brightness, self.life))
end

function PhysicsBody:postCollisionUpdate(deltaTime)
    self.bounceOccured = false

    if self.collision then
        self.life = 0
        self.collision = false

        self:burstParticles()

        self.pos = self.prevPos
        self.pos = self.pos + self.vel * deltaTime
    end

    self.catCollision = false
end

function PhysicsBody:pointIntersection(point)
    if point == nil then print("Point is nil") end
    return self.pos:dist(point) <= self.radius
end

function PhysicsBody.circleIntersection(a, b, r1, r2)
    local r = r1 + r2
    return r * r > a:dist2(b)
end

function PhysicsBody:resolveCollision(b2)
    -- local toB2 = b2.pos - self.pos

    -- toB2:norm()
    -- local intersectionP = self.pos + (toB2 * self.radius)

    if PhysicsBody.circleIntersection(self.pos, b2.pos, self.radius, b2.radius) then
        local fromB2 = self.pos - b2.pos
        local normal = fromB2:clone():norm()

        local velAlongNormal = self.vel:dot(normal)
        local impulse = velAlongNormal * normal * self.collisionBounce

        self.vel = self.vel - impulse

        -- self.pos = self.pos + self.vel * self.prevDeltaT

        self.collision = true

        -- -- Calculate relative velocity
        -- local rv = b2.vel - self.vel

        -- -- Calculate relative velocity in terms of the normal direction
        -- local velAlongNormal = rv:dot(normal)
        
        -- -- Do not resolve if velocities are separating
        -- if velAlongNormal > 0 then return end
        
        -- -- Calculate restitution
        -- -- float e = min( A.restitution, B.restitution)
        -- local e = self.bounce
        
        -- -- Calculate impulse scalar
        -- local j = -(1 + e) * velAlongNormal
        -- -- j /= 1 / A.mass + 1 / B.mass
        -- -- j = j / 1
        
        -- -- Apply impulse
        -- local impulse = j * normal

        -- -- if impulse == 0 then impulse = 0.00001 end

        -- self.vel = self.vel - impulse

        -- -- A.velocity -= 1 / A.mass * impulse
        -- -- B.velocity += 1 / B.mass * impulse

        -- -- self.pos = self.prevPos
        -- -- self.vel = self.vel * -1
    end
end

function PhysicsBody:resolveCatCollision(c)
    local fromC = self.pos - c.pos
    local normal = fromC:norm()


    if PhysicsBody.circleIntersection(self.pos, c.pos, self.radius, c.size) then
        

        -- local velAlongNormal = self.vel:dot(normal)
        -- local impulse = velAlongNormal * normal * self.collisionBounce

        -- self.vel = self.vel - impulse

        -- Vnew = b * ( -2*(V dot N)*N + V ) -- b == bounce


        -- resolve by reflecting velocity around normal
        self.vel = (-2 * (self.vel:dot(normal)) * normal + self.vel) * self.bounce

        if c.personality == 2 or c.personality == 3 then
            self.life = 0
        end

        c:bodyCollided(self)

        self.catCollision = true
    end
end

function PhysicsBody:redraw()
    screen.level(self.brightness)

    -- local hw = self.radius * 0.5

    screen.circle(self.pos.x, 64 - self.pos.y, self.radius)
    -- screen.rect(self.x - hw, 64 - self.y - hw, self.radius, self.radius)
    -- screen.pixel(self.x, 64 - self.y)
    screen.fill()
end

return PhysicsBody