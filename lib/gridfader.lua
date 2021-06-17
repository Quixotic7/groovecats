-- Used to fade values with the grid

local Grid_Fader = {}
Grid_Fader.__index = Grid_Fader

function Grid_Fader.new(layout, pos_x, pos_y, size, centered, indexMode)
    local f = setmetatable({}, Grid_Fader)
    
    f.layout = layout
    f.pos_x = pos_x
    f.pos_y = pos_y
    f.size = size
    f.on_value_changed = nil
    f.get_updated_value = nil
    f.centered = centered and centered or false
    f.fadeSpeed = 0.25
    f.value = 0.5
    f.indexMode = indexMode or false
    f.targetValue = 0.5
    f.fadeEnabled = false
    f.pad_unit = 1.0 / size
    f.prev_time = util.time()
    
    -- print("pad_unit = "..f.pad_unit)
    
    return f
end

function move_to(val, target, dt, speed)
    local delta = target - val
    local sign = delta > 0 and 1 or -1
    local newVal = val + (speed * dt * sign)
    if (sign > 0 and newVal > target) or (sign < 0 and newVal < target) then newVal = target end
    return newVal
end

function Grid_Fader:set_value(newVal)
    self.value = newVal
    
    if self.indexMode then
        if self.on_value_changed then self.on_value_changed(util.round(self.value / self.pad_unit)) end
    else
        if self.on_value_changed then self.on_value_changed(newVal) end
    end
end

function Grid_Fader:grid_event(e)
    if self.layout == "horz" then
        if e.y == self.pos_y and e.x >= self.pos_x and e.x < (self.pos_x + self.size) then
            self:update_value(e, e.x, self.pos_x)
        end
    elseif self.layout == "vert" then
        local flippedY = 9 - e.y
        local flippedPos = 9 - self.pos_y
        -- print("Vert "..e.y.." "..flippedY)
        -- self:update_value(e, flippedY, 9 - self.pos_y)
        
        if e.x == self.pos_x and flippedY >= flippedPos and flippedY < (flippedPos + self.size) then
            self:update_value(e, flippedY, flippedPos)
        end
    end
end

function Grid_Fader:update_value(e, ei, pos_i)
    -- print("Update value "..ei.." "..pos_i)
    self.fadeEnabled = false
    
    if self.get_updated_value then self.value = self.get_updated_value() end

    if self.indexMode then 
        -- print("Index = ".. self.value)
        self.value = self.value * self.pad_unit 
        -- print("Value = ".. self.value)
    end
    
    if e.type == "click" then
        local i = (ei + 1) - pos_i
        
        if ei == pos_i then
            if self.value == 0 and not self.centered and not self.indexMode then
                self:set_value(i * self.pad_unit)
            elseif self.indexMode then
                self:set_value(self.pad_unit)
            else
                self:set_value(0)
            end
        else
            self:set_value(i * self.pad_unit)
        end
        -- print("Value = "..self.value)
    elseif e.type == "hold" then
        local i = (ei + 1) - pos_i
        
        if ei == pos_i then
            if self.indexMode then self.targetValue = self.pad_unit 
            else self.targetValue = 0 end
        else
            self.targetValue = i * self.pad_unit
        end
        self.fadeEnabled = true
    elseif e.type == "release" then
        self.fadeEnabled = false
    end
end

function Grid_Fader:fade_update()
    local dt = util.time() - self.prev_time
    self.prev_time = util.time()
    
    if self.fadeEnabled then
        self:set_value(move_to(self.value, self.targetValue, dt, self.fadeSpeed))
        -- print("Value = "..self.value)
    else
        if self.get_updated_value then self.value = self.get_updated_value() end

        if self.indexMode then 
            self.value = self.value * self.pad_unit 
        end
    end
end

function Grid_Fader:draw(grid)
    
    self:fade_update()
    
    local leds = self:get_led_array()
    
    if self.layout == "horz" then
        local i = 1
        for x = self.pos_x, (self.pos_x + self.size - 1) do
            grid:led(x, self.pos_y, leds[i])
            i = i + 1
        end
    elseif self.layout == "vert" then
        local i = 1
        local flippedPos = 9 - self.pos_y
        for y = flippedPos, (flippedPos + self.size - 1) do
            grid:led(self.pos_x, 9 - y, leds[i])
            i = i + 1
        end
    end
end

function Grid_Fader:get_led_array()
    local leds = {}
    
    for x = 1, self.size do
        leds[x] = self.indexMode and 4 or 1
    end
    
    if self.indexMode then
        grid_units = util.round(self.value / self.pad_unit)
        -- print("grid_units "..self.value.." "..grid_units)
        if grid_units > 0 then
            leds[grid_units] = 15
        end
    elseif self.centered then
        local centerPoint = util.round(0.5 / self.pad_unit)
        local grid_units = util.round(self.value / self.pad_unit)
        local gridPoint = grid_units
        
        if gridPoint < centerPoint then
            for x = gridPoint, centerPoint do
                leds[x] = 10
            end
        else
            for x = centerPoint, gridPoint do
                leds[x] = 10
            end
        end
        leds[centerPoint] = 15
        
    else
        if self.value == 0 then
            leds[1] = 3
        else
            local grid_units = util.round(self.value / self.pad_unit)
            
            for x = 1, grid_units do
                leds[x] = 10
            end
        end
    end
    
    return leds
end

return Grid_Fader