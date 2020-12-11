local Particle = {}
Particle.__index = Particle

function Particle.new(width,height)
    local p = setmetatable({}, Particle)

    p.x = 0
    p.y = 0
    p.start_life = 2
    p.size = 0
    p.life = 0
    p.speed = 0
    p.angle = 0
    p.gravity = 1
    p.start_brightness = 15
    p.end_brightness = 0
    p.brightness = p.start_brightness
    p.destroy = false

    p.vel = {x = 0, y = 0}

    p:reset()

    return p
end

function Particle:reset()
    self.x = 0
    self.y = 0
    self.life = self.start_life
    self.size = util.linlin(0,1,1,4,math.random())
    self.speed = 1
    self.gravity = 2
    self.angle = math.random() * 2 * math.pi
    self.destroy = false

    self.start_brightness = math.random(2,15)
    self.brightness = self.start_brightness

    -- self.vel.x = 0
    -- self.vel.y = 0
end

function Particle:calc_velocity()
    self.vel.x = self.speed * math.cos(self.angle)
    self.vel.y = self.speed * math.sin(self.angle)
end

function Particle:update(deltaTime)

    -- self.vel.x = self.speed * math.cos(self.angle)
    -- self.vel.y = self.speed * math.sin(self.angle)

    self.vel.x = self.vel.x * 0.99
    self.vel.y = self.vel.y * 0.99 - self.gravity

    self.x = self.x + self.vel.x * deltaTime
    self.y = self.y + self.vel.y * deltaTime

    self.life = self.life - deltaTime;

    self.brightness = util.round(util.linlin(self.start_life, 0, self.start_brightness, self.end_brightness, self.life))
end

function Particle:redraw()
    screen.level(self.brightness)

    local hw = self.size * 0.5

    screen.rect(self.x - hw, 64 - self.y - hw, self.size, self.size)
    -- screen.pixel(self.x, 64 - self.y)
    screen.fill()
end

return Particle