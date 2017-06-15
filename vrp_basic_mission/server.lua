
local Tunnel = require("resources/vrp/lib/Tunnel")
local Proxy = require("resources/vrp/lib/Proxy")
local Lang = require("resources/vrp/lib/Lang")
local cfg = require("resources/vrp_basic_mission/cfg/missions")

-- load global and local languages
local glang = Lang.new(require("resources/vrp/cfg/lang/"..cfg.lang) or {})
local lang = Lang.new(require("resources/vrp_basic_mission/cfg/lang/"..cfg.lang) or {})

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","vRP_basic_mission")

local repairkit_name = "repairkit"
SetTimeout(5000,function()
  vRP.getInventoryItemDefinition({"repairkit"},function(def)
    repairkit_name = def.name
  end)
end)

function task_mission()
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
                              vRP.giveMoney({player,v.reward})
                              vRPclient.notify(player,{glang.money.received({v.reward})})
                            end
                          end)
                        else
                          vRPclient.notify(player,{glang.inventory.missing({repairkit_name,1})})
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

  SetTimeout(60000,task_mission)
end
task_mission()
