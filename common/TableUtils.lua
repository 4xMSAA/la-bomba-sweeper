local TableUtils = {}
local random = Random.new()

local function recursion(t, wT)
    for key, object in pairs(t) do
        if type(object) == "table" then
            if not wT[key] then
                wT[key] = {}
            end
            recursion(object, wT[key])
        else
            wT[key] = object
        end
    end
end

function TableUtils.count(t)
    local count = 0
    for _,_ in pairs(t) do
        count = count + 1
    end
    return count
end

---Get a random value from a table
---@param t table The table to pick an input from
---@param filter function The filtering function to go with
---@return any The value from an array
function TableUtils.random(t, filter)
    if not type(filter) == "function" then
        error("expected function, got " .. type(filter))
    end
    if filter then
        local trackedEntries = {}
        while true do
            local val = random:NextInteger(1, #t)
            local entry = t[val]
            if filter(entry) then
                return entry, val
            end
            trackedEntries[entry] = true
            if TableUtils.getSize(trackedEntries) == #t then
                warn("table entries exceeded, no result")
                return nil
            end
        end
    end
    local val = random:NextInteger(1, #t)
    return t[val], val
end

---Shuffle an array with Fisher–Yates shuffling
---@param t table The array to shuffle
---@return table Same array, but shuffled
function TableUtils.shuffle(t)
    for i = 1, #t - 1 do
        local r = random:NextInteger(i, #t)
        local prevValue = t[r]
        t[r] = t[i]
        t[i] = prevValue
    end
    return t
end

function TableUtils.overwrite(t0, t1)
    for key, value in pairs(t1) do
        t0[key] = value
    end
end

---Ignores tables and only writes values
function TableUtils.recursiveOverwrite(t0, t1)
    recursion(t0, t1)
end

---Convert an array table to a list table (dictionary)
---@param t table The array to convert
---@param callback function Define special behaviour. Passed arguments: (table) result, (userdata) value, (float) index
---@return table List styled as {value = index}
function TableUtils.toList(t, callback)
    local result = {}
    for i, v in pairs(t) do
        if callback then
            callback(result, v, i)
        else
            result[v] = i
        end
    end

    return result
end

-- TODO: move this out of TableUtils
---Makes an Enumerable type which you can index by ID if called
function TableUtils.toEnumList(name, t)
    -- Convert {"EnumName", "Desc", ExtraData} to
    -- [EnumName] = {Description = "Desc", Name = "EnumName", ID = index}
    local idMap = {}
    local enumList =
        TableUtils.toList(
        t,
        function(result, val, key)
            result[val[1]] = {
                Name = val[1],
                Description = val[2],
                ExtraData = val[3],
                ID = key
            }
            idMap[key] = result[val[1]]
        end
    )

    local enumWrapper = {}
    function enumWrapper:__index(key)
        return error("did not find enum " .. key .. " in GameEnum." .. name, 2)
    end

    function enumWrapper:__call(key)
        if type(key) ~= "number" then
            error("index must be integer", 2)
        end
        return idMap[key] or error("no entry with index " .. key, 2)
    end

    setmetatable(enumList, enumWrapper)

    return enumList
end

---Get the size of a table by element count
---@param t table The table to iterate over
---@return table Size of the table (by element count)
function TableUtils.getSize(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

---Bubble sort an array based on values
---@param array table The array to sort
---@param key string Optional, if array has objects, index with key for value
---@return table Array with sorted values
function TableUtils.valueBubblesort(array, key)
    local result = {}
    for _, val in ipairs(array) do
        table.insert(result, val)
    end

    -- Bubblesort swaps elements
    local function swap(list, index1, index2)
        local index2Val = list[index2]

        list[index2] = list[index1]
        list[index1] = index2Val
    end

    -- Repeat until there's nothing left to sort
    local count = #result
    repeat
        local newn = 1
        for i = 2, count do
            if (key and result[i - 1][key] > result[i][key]) or not key and result[i - 1] > result[i] then
                -- Swap the two values and set the index as the new count
                swap(result, i - 1, i)
                newn = i
            end
        end
        count = newn
    until count == 1

    return result
end

return TableUtils
