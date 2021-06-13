local Collision_Event = {}
Collision_Event.__index = Collision_Event

local LED_LEVELS = {15, 5, 2, 1, 0}

function Collision_Event.new()
    local c = setmetatable({}, Collision_Event)
    
    c:reset()
    
    return c
end

function Collision_Event:reset()
    self.position = 1
    self.led_level = LED_LEVELS[self.position]
end

function Collision_Event:update()
    self.position = self.position + 1
    if self.position <= #LED_LEVELS then
        self.led_level = LED_LEVELS[self.position]
    else
        self.led_level = 0
    end
end

function Collision_Event:is_complete()
    return self.position > #LED_LEVELS
end

return Collision_Event