local vector2d = require("particles/lib/vector2d")
local PhysicsEngine = include("particles/lib/physicsEngine")
local PhysicsBody = include("particles/lib/physicsBody")

local grooveCatImg = _path.code.."particles/img/"

-- local personalityImages = {"grooveCat2.png", }


local GrooveCat = {}
GrooveCat.__index = GrooveCat

GrooveCat.SYNC_RATES = {0.25, 0.5, 1, 2, 3, 4}
GrooveCat.PERONALITIES = {"Lively", "Bipolar", "Sleepy"}

function GrooveCat.new(physicsEngine, particleEngine)
    local c = setmetatable({}, GrooveCat)

    c.physicsEngine = physicsEngine
    c.particleEngine = particleEngine

    -- c.particleEngine = nil


    c.onMeow = nil

    c.personality = 1

    c.enabled = true

    c.bounce_seq = {
        pos = 0,
        length = 8,
        data = {1,3,5,7,8,7,5,3,0,0,0,0,0,0,0,0}
    }

    c.octave = 0

    c.lSpeedMin = 60
    c.lSpeedMax = 60
    c.probability = 50
    c.syncMode = 6
    c.syncTime = GrooveCat.SYNC_RATES[c.syncMode]

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

    c.launch_synth = 0
    c.bounce_synth = 1
    c.collision_synth = 2

    -- c.bounce_synth = {
    --     algo = 3,
    --     amp = 0.35,
    --     pw = 40,
    --     cutoff = 1800,
    --     attack = 0.01,
    --     release = 1.0
    -- }

    -- c.collision_synth = {
    --     algo = 4,
    --     amp = 0.45,
    --     pw = 60,
    --     cutoff = 2000,
    --     attack = 0.1,
    --     release = 2.0
    -- }

    c.physicsEngine:addCat(c)

    return c
end

function GrooveCat:changeSyncMode(newMode)
    self.syncMode = util.clamp(newMode, 1, #GrooveCat.SYNC_RATES)
    self.syncTime = GrooveCat.SYNC_RATES[self.syncMode]
end

-- start
function GrooveCat:purr()
    clock.run(function() GrooveCat.purr_loop(self) end)
end

function GrooveCat:purr_loop()
    self.purring = true

    while self.purring do
        clock.sync(self.syncTime)

        if self.enabled then
            if self.personality == 1 then
                if math.random(100) <= self.probability then
                    self:meow()
                end
            elseif self.personality == 2 then
                if self.awake then self:meow() end
            elseif self.personality == 3 then

            end
        end
    end
end

function GrooveCat:set_loop_data(step, val)
    self.bounce_seq.data[step] = val
end

-- advance a sequence whenever the furball bounces
function GrooveCat:bounce_step()
    local seq = self.bounce_seq
  
    seq.pos = seq.pos + 1
    if seq.pos > seq.length then seq.pos = 1 end

    if seq.data[seq.pos] > 0 then
        return seq.data[seq.pos]
        -- if math.random(100) <= self.probability then
        --     return seq.data[seq.pos]
        -- end
    end

    return 0
end

function GrooveCat:getNewPhysicsBody(x, y)
    local b = PhysicsBody.new(x, y)

    b.cat = self
    b.particleEngine = self.particleEngine

    b.noteIndex = self:bounce_step()
    b.octave = self.octave

    b.gravity = 5
    b.speed = math.random(self.lSpeedMin, self.lSpeedMax)
    b.angle = self.rotation

    return b
end


function GrooveCat:meow()

    local firePos = self.pos + self.forward * (self.sizeH + 2)

    local b = self:getNewPhysicsBody(firePos.x, firePos.y)

    b:recalc_velocity()
    self.physicsEngine:addBody(b)

    if self.onMeow ~= nil then self.onMeow(self, self.bounce_seq.data[self.bounce_seq.pos]) end
end

function GrooveCat:megaMeow()
    if util.time() - self.lastMegaMeowTime < self.timeBetweenMegaMeow then return end

    local f = self.forward:clone()
    local rIncrement = 90

    for i = 1, 4 do
        f:rotate((i-1) * rIncrement)

        local firePos = self.pos + f * self.sizeH

        local b = self:getNewPhysicsBody(firePos.x, firePos.y)

        b.angle = self.rotation + i * rIncrement
        b:recalc_velocity()

        self.physicsEngine:addBody(b)
    end

    if self.onMeow ~= nil then self.onMeow(self, self.bounce_seq.data[self.bounce_seq.pos]) end

    self.lastMegaMeowTime = util.time()
end

function GrooveCat:bodyCollided(physicsBody)
    if self.enabled == false then return end
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
    if self.enabled == false then return end

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

    -- if self.selected then
    --     screen.blend_mode(13)
    -- end

    screen.display_png(img..".png", -4, -6)

    -- screen.blend_mode(0)

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