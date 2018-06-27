oldUpdate = update
function update(dt)
    if not config.getParameter("managerUid") then

        dt = config.getParameter("scriptDelta")
        script.setUpdateDelta(0)
        self.interactData = config.getParameter("interactData")

        message.setHandler("saveState", function(_, _, state)
            storage.gameState = state
        end)

        message.setHandler("setConfigParam", function(_,_, jsonPath, value)
            object.setConfigParam(jsonPath, value)
        end)
        
        message.setHandler("accessStorageParam", function(_,_, method, jsonPath, data)
            if method == 'get' then
                return storage[jsonPath]
            elseif method == 'put' then
                storage[jsonPath] = data
            elseif method == 'update' then
                storage[jsonPath] = sb.jsonMerge(storage[jsonPath] or {}, data)
            elseif method == 'delete' then
                storage[jsonPath] = nil
            end
        end)
        onInteraction = onInteractHook
    end
    update = oldUpdate
end

function onInteractHook(args)
    self.interactData.gameState = storage.gameState
    self.interactData.objectOwner = config.getParameter("owner")
    self.interactData.sourceId = args.sourceId
    self.interactData.sourcePosition = args.sourcePosition
    return {"ScriptPane", self.interactData}
end

function uninit()
    script.setUpdateDelta(1)
end