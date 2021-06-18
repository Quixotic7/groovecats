local grooveCatImg = _path.code.."groovecats/img/"

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

    c.name = "MrCat"

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

    c.launch_midi = 0
    c.bounce_midi = 0
    c.collision_midi = 0


    -- c.midi_device = 1
    -- c.launch_midi_channel = 0
    -- c.bounce_midi_channel = 0
    -- c.collision_midi_channel = 0

    -- c.launch_midi_length = 0.25
    -- c.bounce_midi_length = 0.25
    -- c.collision_midi_length = 0.25



    c.clock_id = nil

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

function GrooveCat:get_serialized()
    local d = {}

    d.name = self.name
    d.personality = self.personality
    d.enabled = self.enabled
    d.bounce_seq = self.bounce_seq
    d.octave = self.octave

    d.lSpeedMin = self.lSpeedMin
    d.lSpeedMax = self.lSpeedMax
    d.probability = self.probability
    d.syncMode = self.syncMode

    d.pos = { x = self.pos.x, y = self.pos.y }
    d.size = self.size
    d.rotation = self.rotation
    d.forward = {x = self.forward.x, y = self.forward.y}
    d.autoRotateSpeed = self.autoRotateSpeed

    d.timeBetweenMegaMeow = self.timeBetweenMegaMeow
    d.launch_synth = self.launch_synth
    d.bounce_synth = self.bounce_synth
    d.collision_synth = self.collision_synth

    d.launch_midi = self.launch_midi
    d.bounce_midi = self.bounce_midi
    d.collision_midi = self.collision_midi

    return d
end

function GrooveCat:load_serialized(data)
    self.name = data.name
    self.personality = data.personality
    self.enabled = data.enabled
    self.bounce_seq = data.bounce_seq
    self.octave = data.octave

    self.lSpeedMin = data.lSpeedMin
    self.lSpeedMax = data.lSpeedMax
    self.probability = data.probability
    self:changeSyncMode(data.syncMode)

    self.pos = vector2d(data.pos.x, data.pos.y)
    self.size = data.size
    self.rotation = data.rotation
    self.forward = vector2d(data.forward.x, data.forward.y) 
    self.autoRotateSpeed = data.autoRotateSpeed

    self.timeBetweenMegaMeow = data.timeBetweenMegaMeow
    self.launch_synth = data.launch_synth
    self.bounce_synth = data.bounce_synth
    self.collision_synth = data.collision_synth

    self.launch_midi = data.launch_midi
    self.bounce_midi = data.bounce_midi
    self.collision_midi = data.collision_midi
end

function GrooveCat:changeSyncMode(newMode)
    self.syncMode = util.clamp(newMode, 1, #GrooveCat.SYNC_RATES)
    self.syncTime = GrooveCat.SYNC_RATES[self.syncMode]
end

-- start
function GrooveCat:purr()
    self.clock_id = clock.run(function() GrooveCat.purr_loop(self) end)
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

function GrooveCat:stop_purring()
    self.purring = false

    if self.clock_id ~= nil then
        clock.cancel(self.clock_id)
    end
    
    self.clock_id = nil
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

    local speedMin, speedMax = Q7Util.get_min_max(self.lSpeedMin, self.lSpeedMax)

    b.speed = math.random(speedMin, speedMax)
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