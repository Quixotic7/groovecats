local vector2d = require("particles/lib/vector2d")
local PhysicsEngine = include("particles/lib/physicsEngine")
local PhysicsBody = include("particles/lib/physicsBody")

local grooveCatImg = _path.code.."particles/img/"

-- local personalityImages = {"grooveCat2.png", }


local GrooveCat = {}
GrooveCat.__index = GrooveCat

function GrooveCat.new(physicsEngine, particleEngine)
    local c = setmetatable({}, GrooveCat)

    c.physicsEngine = physicsEngine
    c.particleEngine = particleEngine

    -- c.particleEngine = nil


    c.onMeow = nil

    c.personality = 1

    c.syncTime = 4

    c.pos = vector2d(32, 32)
    c.size = 4
    c.sizeH = c.size * 0.5
    c.rotation = 0
    c.forward = vector2d(1,0)

    c.selected = false

    c.purring = false

    c.awake = false -- for sleepy cat

    c.postUpdateMeow = false

    c.autoRotateSpeed = 45

    c.timeBetweenMegaMeow = 4
    c.lastMegaMeowTime = util.time()

    c.bounceAlgo = 3
    c.bounceAmp = 0.1
    c.bouncePW = 50
    c.bounceAttack = 0.0001
    c.bounceRelease = 1.0

    c.physicsEngine:addCat(c)

    return c
end

-- start
function GrooveCat:purr()
    clock.run(function() GrooveCat.purr_loop(self) end)
end

function GrooveCat:purr_loop()
    self.purring = true

    while self.purring do
        clock.sync(self.syncTime)

        if self.personality == 1 then
            self:meow()
        elseif self.personality == 2 then
            if self.awake then self:meow() end
        elseif self.personality == 3 then

        end
    end
end

function GrooveCat:meow()
    local firePos = self.pos + self.forward * self.sizeH

    local b = PhysicsBody.new(firePos.x, firePos.y)

    b.cat = self
    b.particleEngine = self.particleEngine

    b.gravity = 5
    b.speed = 60
    b.angle = self.rotation
    b:recalc_velocity()

    self.physicsEngine:addBody(b)

    -- if self.onMeow ~= nil then self.onMeow(self) end
end

function GrooveCat:megaMeow()
    if util.time() - self.lastMegaMeowTime < self.timeBetweenMegaMeow then return end

    local f = self.forward:clone()
    local rIncrement = 90

    for i = 1, 4 do
        f:rotate((i-1) * rIncrement)

        local firePos = self.pos + f * self.sizeH

        local b = PhysicsBody.new(firePos.x, firePos.y)

        b.cat = self
        b.particleEngine = self.particleEngine

        b.gravity = 5
        b.speed = 80
        b.angle = self.rotation + i * rIncrement
        b:recalc_velocity()

        self.physicsEngine:addBody(b)
    end

    if self.onMeow ~= nil then self.onMeow(self) end

    self.lastMegaMeowTime = util.time()
end

function GrooveCat:bodyCollided(physicsBody)
    self.postUpdateMeow = true;

    -- if self.personality == 2 then
    --     self.awake = not self.awake
    --     if self.awake then self:meow() end
    -- elseif self.personality == 3 then
    --     self:megaMeow()
    -- end
end

function GrooveCat:postUpdate(deltaTime)

    -- do this after physics update or problems can arise when meowing
    -- since we modify array
    if self.postUpdateMeow then
        if self.personality == 2 then
            self.awake = not self.awake
            if self.awake then self:meow() end
        elseif self.personality == 3 then
            self:megaMeow()
        end
    end

    self.postUpdateMeow = false

end

function GrooveCat:update(deltaTime)
    self:rotate(self.autoRotateSpeed * deltaTime)
end

function GrooveCat:rotate(d)
    local rotAmt = d

    self.rotation = (self.rotation + rotAmt) % 360
    self.forward = vector2d(1,0):rotate(util.degs_to_rads(self.rotation))
    -- self.forward.x = math.cos(util.degs_to_rads(self.rotation))
    -- self.forward.y = math.sin(util.degs_to_rads(self.rotation))
end

function GrooveCat:translate(x,y)
    self.pos.x = self.pos.x + x
    self.pos.y = self.pos.y + y

    self.pos.x = util.clamp(self.pos.x, self.sizeH, 128 - self.sizeH)
    self.pos.y = util.clamp(self.pos.y, self.sizeH, 64 - self.sizeH)
end

function GrooveCat:draw()

    screen.move(self.pos.x, 64 - self.pos.y)

    local lineTo = self.pos + self.forward * 10

    -- screen.line(lineTo.x, 64 - lineTo.y)
    -- screen.level(15)
    -- screen.stroke()


    screen.save()
    screen.translate(self.pos.x, 64 - self.pos.y)
    screen.rotate(util.degs_to_rads(self.rotation))

    -- screen.rect(self.pos.x - self.sizeH, 64 - self.pos.y - self.sizeH, self.size, self.size)

    local img = grooveCatImg
    
    if self.personality == 1 then
        img = grooveCatImg.."grooveCat2"
    elseif self.personality == 2 then
        img = self.awake and (grooveCatImg.."sleepyCatAwake") or (grooveCatImg.."sleepyCat")
    elseif self.personality == 3 then
        if util.time() - self.lastMegaMeowTime < self.timeBetweenMegaMeow then
            img = grooveCatImg.."scaredCat"
        else
            img = grooveCatImg.."sleepyCat"
        end
    end

    if self.selected then img = img.."_selected" end

    screen.display_png(img..".png", -4, -6)

    -- screen.rect(-self.sizeH, -self.sizeH, self.size, self.size)
    -- screen.level(0)
    -- screen.fill()
    -- screen.rect(-self.sizeH, -self.sizeH, self.size, self.size)
    -- -- screen.rect(self.pos.x - self.sizeH, 64 - self.pos.y - self.sizeH, self.size, self.size)
    -- screen.level(15)
    -- screen.stroke()

    screen.translate(-self.pos.x, -(64 - self.pos.y))
    screen.restore()

end

return GrooveCat