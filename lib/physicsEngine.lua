local PhysicsEngine = {}
PhysicsEngine.__index = PhysicsEngine

function PhysicsEngine.new()
    local e = setmetatable({}, PhysicsEngine)

    e.iterations = 5
    e.physicsBodies = {}

    return e
end

function PhysicsEngine:addBody(b)
    table.insert(self.physicsBodies, b)
end

function PhysicsEngine:update(deltaTime)
    local n = #self.physicsBodies

    for i = 1, n do
        self.physicsBodies[i]:update(deltaTime)

        
    end

    

    for i = 1, self.iterations do
        for i, b1 in pairs(self.physicsBodies) do
            for j, b2 in pairs(self.physicsBodies) do
                if b1 ~= nil and b2 ~= nil and i ~= j then
                    b1:resolveCollision(b2)
                end
            end
        end

        for i, b in pairs(self.physicsBodies) do
            b:postCollisionUpdate(deltaTime)
        end
    end

    -- check if bodies are dead
    for i = 1, n do
        if self.physicsBodies[i].life <= 0 then
            self.physicsBodies[i] = nil
        end
    end

    -- cleanup table
    local j = 0
    for i = 1, n do
        if self.physicsBodies[i] ~= nil then
            j = j + 1
            self.physicsBodies[j] = self.physicsBodies[i]
        end
    end

    for i = j + 1, n do
        self.physicsBodies[i] = nil
    end
end

function PhysicsEngine:draw()
    for i, b in pairs(self.physicsBodies) do
        b:redraw()
    end
end

return PhysicsEngine