local lang = vRP.lang
local Luang = module("vrp", "lib/Luang")

local basic_mission = class("basic_mission", vRP.Extension)

function basic_mission:__construct()
  vRP.Extension.__construct(self)

  self.cfg = module("vrp_basic_mission", "cfg/missions")

  -- load lang
  self.luang = Luang()
  self.luang:loadLocale(vRP.cfg.lang, module("vrp_basic_mission", "cfg/lang/"..vRP.cfg.lang))
  self.lang = self.luang.lang[vRP.cfg.lang]

  self.paychecks_elapsed = {} -- map of paycheck permission => elapsed mission ticks

  -- task: mission
  local function task_mission()
    SetTimeout(60000,task_mission)
    self:taskMission()
  end
  async(function()
    task_mission()
  end)
end

function basic_mission:taskMission()
  -- PAYCHECK
  for perm,mission in pairs(self.cfg.paycheck) do -- each repair perm def
    local ticks = (self.paychecks_elapsed[perm] or 0)+1
    if ticks >= mission.interval then
      ticks = 0
      -- add missions to users
      local users = vRP.EXT.Group:getUsersByPermission(perm)
      for _,user in pairs(users) do
        if user.spawns > 0 and not user:hasMission() then
          -- build mission
          local mdata = {}
          mdata.name = self.lang.paycheck.title()

          local step = {
            text = self.lang.paycheck.text({mission.reward}),
            onenter = function(user)
              user:giveWallet(mission.reward)
              vRP.EXT.Base.remote._notify(user.source,lang.money.received({mission.reward}))
              user:nextMissionStep()
            end,
            position = mission.position
          }

          mdata.steps = {step}

          user:startMission(mdata)
        end
      end
    end

    self.paychecks_elapsed[perm] = ticks
  end

  -- REPAIR
  for perm,mission in pairs(self.cfg.repair) do -- each repair perm def
    -- add missions to users
    local users = vRP.EXT.Group:getUsersByPermission(perm)
    for _, user in pairs(users) do
      if user.spawns > 0 and not user:hasMission() then -- check spawned without mission
        if math.random(1,mission.chance) == 1 then -- chance check
          -- build mission
          local mdata = {}
          mdata.name = self.lang.repair({mission.title})
          mdata.steps = {}

          -- build steps
          for i=1,mission.steps do
            local step = {
              text = self.lang.repair({mission.title}).."<br />"..self.lang.reward({mission.reward}),
              onenter = function(user)
                if user:tryTakeItem("repairkit",1) then
                  vRP.EXT.Base.remote._playAnim(user.source,false,{task="WORLD_HUMAN_WELDING"},false)
                  SetTimeout(15000, function()
                    user:nextMissionStep()
                    vRP.EXT.Base.remote._stopAnim(user.source,false)

                    -- last step
                    if i == mission.steps then
                      user:giveWallet(mission.reward)
                      vRP.EXT.Base.remote._notify(user.source, lang.money.received({mission.reward}))
                    end
                  end)
                end
              end,
              position = mission.positions[math.random(1,#mission.positions)]
            }

            table.insert(mdata.steps, step)
          end

          user:startMission(mdata)
        end
      end
    end
  end

  -- DELIVERY
  for perm,mission in pairs(self.cfg.delivery) do -- each repair perm def
    -- add missions to users
    local users = vRP.EXT.Group:getUsersByPermission(perm)
    for _,user in pairs(users) do
      if user.spawns > 0 and not user:hasMission() then
        -- build mission
        local mdata = {}
        mdata.name = self.lang.delivery.title()

        -- generate items
        local todo = 0
        local delivery_items = {}
        for fullid,data in pairs(mission.items) do
          local amount = math.random(data[1],data[2])
          if amount > 0 then
            delivery_items[fullid] = amount
            todo = todo+1
          end
        end

        local step = {
          text = "",
          onenter = function(user)
            for fullid,amount in pairs(delivery_items) do
              if amount > 0 then -- check if not done
                if user:tryTakeItem(fullid,amount) then
                  local reward = mission.items[fullid][3]*amount
                  user:giveWallet(reward)
                  vRP.EXT.Base.remote._notify(user.source,lang.money.received({reward}))
                  todo = todo-1
                  delivery_items[fullid] = 0
                  if todo == 0 then -- all received, finish mission
                    user:nextMissionStep()
                  end
                end
              end
            end
          end,
          position = mission.positions[math.random(1,#mission.positions)]
        }

        -- mission display
        for fullid,amount in pairs(delivery_items) do
          local citem = vRP.EXT.Inventory:computeItem(fullid)
          if citem then
            step.text = step.text..self.lang.delivery.item({citem.name,amount}).."<br />"
          end
        end

        mdata.steps = {step}

        if todo > 0 then
          user:startMission(mdata)
        end
      end
    end
  end

end

vRP:registerExtension(basic_mission)
