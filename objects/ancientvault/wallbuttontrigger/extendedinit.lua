local oldUpdate = update

function update(dt)
    dt = config.getParameter("scriptDelta")
    script.setUpdateDelta(0)
    if not config.getParameter("managerUid") then

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
    if not oldUpdate then
        update = function() end
    else
        script.setUpdateDelta(dt)
        update = oldUpdate
    end
end

function onInteractHook(args)
    self.interactData = config.getParameter("interactData")
    self.interactData.gameState = storage.gameState
    self.interactData.objectOwner = config.getParameter("owner")
    self.interactData.sourceId = args.sourceId
    self.interactData.sourcePosition = args.sourcePosition
    return {"ScriptPane", self.interactData}
end