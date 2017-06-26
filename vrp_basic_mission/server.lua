
local Tunnel = require("resources/vrp/lib/Tunnel")
local Proxy = require("resources/vrp/lib/Proxy")
local Lang = require("resources/vrp/lib/Lang")
local cfg = require("resources/vrp_basic_mission/cfg/missions")

-- load global and local languages
local glang = Lang.new(require("resources/vrp/cfg/lang/"..cfg.lang) or {})
local lang = Lang.new(require("resources/vrp_basic_mission/cfg/lang/"..cfg.lang) or {})

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","vRP_basic_mission")

-- load item definitions for the delivery config
local item_defs = {}
SetTimeout(5000,function()
  for k,v in pairs(cfg.delivery) do
    for l,w in pairs(v.items) do
      if item_defs[l] == nil then
        item_defs[l] = {}
        vRP.getItemDefinition({l},function(name,desc,weight)
          item_defs[l] = {name,desc,weight}
        end)
      end
    end
  end
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
              if math.random(1,v.chance+1) == 1 then -- chance check
                -- build mission
                local mdata = {}
                mdata.name = lang.repair({v.title})
                mdata.steps = {}

                -- build steps
                for i=1,v.steps do
                  local step = {
                    text = lang.repair({v.title}).."<br />"..lang.reward({v.reward}),
                    onenter = function(player, area)
                      vRP.tryGetInventoryItem({user_id,"repairkit",1,true},function(ok)
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
                        end
                      end)
                    end,
                    position = v.positions[math.random(1,#v.positions+1)]
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
                local amount = math.random(data[1],data[2]+1)
                if amount > 0 then
                  delivery_items[idname] = amount
                  todo = todo+1
                end
              end

              local step = {
                text = "",
                onenter = function(player, area)
                  for idname,amount in pairs(delivery_items) do
                    if amount > 0 then -- check if not done
                      vRP.tryGetInventoryItem({user_id,idname,amount,true},function(ok)
                        if ok then -- deliver
                          local reward = v.items[idname][3]*amount
                          vRP.giveMoney({user_id,reward})
                          vRPclient.notify(player,{glang.money.received({reward})})
                          todo = todo-1
                          delivery_items[idname] = 0
                          if todo == 0 then -- all received, finish mission
                            vRP.nextMissionStep({player})
                          end
                        end
                      end)
                    end
                  end
                end,
                position = v.positions[math.random(1,#v.positions+1)]
              }

              -- mission display
              for idname,amount in pairs(delivery_items) do
                step.text = step.text..lang.delivery.item({item_defs[idname][1],amount}).."<br />"
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
