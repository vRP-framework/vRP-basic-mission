
local Tunnel = require("resources/vrp/lib/Tunnel")
local Proxy = require("resources/vrp/lib/Proxy")
local Lang = require("resources/vrp/lib/Lang")
local cfg = require("resources/vrp_basic_mission/cfg/missions")

-- load global and local languages
local glang = Lang.new(require("resources/vrp/cfg/lang/"..cfg.lang) or {})
local lang = Lang.new(require("resources/vrp_basic_mission/cfg/lang/"..cfg.lang) or {})

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","vRP_basic_mission")

local items = {}
SetTimeout(5000,function()
  vRP.getInventoryItemDefinitions({},function(defs)
    items = defs
  end)
end)

function task_mission()
  -- REPAIR
  for k,v in pairs(cfg.repair) do -- each repair perm def
    -- add missions to users
    vRP.getUsersByPermission({k},function(users)
      for l,w in pairs(users) do
        local user_id = w
        vRP.getUserSource({user_id},function(player)
          vRP.hasMission({player},function(has_mission)
            if not has_mission then
              if math.random(1,v.chance) == 1 then -- chance check
                -- build mission
                local mdata = {}
                mdata.name = lang.repair({v.title})
                mdata.steps = {}

                -- build steps
                for i=1,v.steps do
                  local step = {
                    text = lang.repair({v.title}).."<br />"..lang.reward({v.reward}),
                    onenter = function(player, area)
                      vRP.tryGetInventoryItem({user_id,"repairkit",1},function(ok)
                        if ok then -- repair
                          vRPclient.playAnim(player,{false,{task="WORLD_HUMAN_WELDING"},false})
                          SetTimeout(15000, function()
                            vRP.nextMissionStep({player})
                            vRPclient.stopAnim(player,{false})

                            -- last step
                            if i == v.steps then
                              vRP.giveMoney({user_id,v.reward})
                              vRPclient.notify(player,{glang.money.received({v.reward})})
                            end
                          end)
                        else
                          local name = "repairkit"
                          if items[name] ~= nil then
                            name = items[name].name
                          end
                          vRPclient.notify(player,{glang.inventory.missing({name,1})})
                        end
                      end)
                    end,
                    position = v.positions[math.random(1,#v.positions)]
                  }

                  table.insert(mdata.steps, step)
                end

                vRP.startMission({player,mdata})
              end
            end
          end)
        end)
      end
    end)
  end

  -- DELIVERY
  for k,v in pairs(cfg.delivery) do -- each repair perm def
    -- add missions to users
    vRP.getUsersByPermission({k},function(users)
      for l,w in pairs(users) do
        local user_id = w
        vRP.getUserSource({user_id},function(player)
          vRP.hasMission({player},function(has_mission)
            if not has_mission then
              -- build mission
              local mdata = {}
              mdata.name = lang.delivery.title()

              -- generate items
              local todo = 0
              local delivery_items = {}
              for idname,data in pairs(v.items) do
                local item = items[idname]
                if item then
                  local amount = math.random(data[1],data[2])
                  if amount > 0 then
                    delivery_items[idname] = amount
                    todo = todo+1
                  end
                end
              end

              local step = {
                text = "",
                onenter = function(player, area)
                  for idname,amount in pairs(delivery_items) do
                    if amount > 0 then -- check if not done
                      local name = idname
                      if items[idname] ~= nil then
                        name = items[idname].name
                      end

                      vRP.tryGetInventoryItem({user_id,idname,amount},function(ok)
                        if ok then -- deliver
                          local reward = v.items[idname][3]*amount
                          vRP.giveMoney({user_id,reward})
                          vRPclient.notify(player,{glang.money.received({reward})})
                          todo = todo-1
                          delivery_items[idname] = 0
                          if todo == 0 then -- all received, finish mission
                            vRP.nextMissionStep({player})
                          end
                        else
                          vRPclient.notify(player,{glang.inventory.missing({name,amount})})
                        end
                      end)
                    end
                  end
                end,
                position = v.positions[math.random(1,#v.positions)]
              }

              -- mission display
              for idname,amount in pairs(delivery_items) do
                local item = items[idname]
                if item then
                  step.text = step.text..lang.delivery.item({item.name,amount}).."<br />"
                end
              end

              mdata.steps = {step}

              if todo > 0 then
                vRP.startMission({player,mdata})
              end
            end
          end)
        end)
      end
    end)
  end

  SetTimeout(60000,task_mission)
end
task_mission()
