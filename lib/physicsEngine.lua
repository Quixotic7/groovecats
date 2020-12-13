local PhysicsEngine = {}
PhysicsEngine.__index = PhysicsEngine

function PhysicsEngine.new()
    local e = setmetatable({}, PhysicsEngine)

    e.iterations = 5
    e.physicsBodies = {}
    e.collisionFunc = nil
    e.bounceFunc = nil

    return e
end

function PhysicsEngine:addBody(b)
    table.insert(self.physicsBodies, b)
end

function PhysicsEngine:update(deltaTime)
    local n = #self.physicsBodies

    local collisions = {}
    local collisionsB = {}

    for i = 1, n do
        self.physicsBodies[i]:update(deltaTime)
        if self.physicsBodies[i].bounceOccured then
            if self.bounceFunc ~= nil then
                self.bounceFunc(self.physicsBodies[i])
            end
        end
    end

    for i = 1, self.iterations do
        for i, b1 in pairs(self.physicsBodies) do
            for j, b2 in pairs(self.physicsBodies) do
                if b1 ~= nil and b2 ~= nil and i ~= j then
                    b1:resolveCollision(b2)

                    if b1.collision then
                        if collisionsB[j] ~= 1 then
                            local c = {b1, b2}
                            collisions[i] = c
                            collisionsB[j] = 1
                        end
                    end

                    -- if self.collisionFunc ~= nil and b1.collision then 
                    --     self.collisionFunc(b1)
                    -- end
                end
            end
        end

        for i, b in pairs(self.physicsBodies) do
            b:postCollisionUpdate(deltaTime)
        end
    end

    if self.collisionFunc ~= nil then
        for i, c in pairs(collisions) do
            self.collisionFunc(c.b1, c.b2)
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