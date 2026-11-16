-- Catch A KPOP Idol - Delta Android / experimental 6-lane autoplay
-- Normal notes only. No remote code, network calls or holds.
-- IMPORTANT: Requires notes to be GuiObjects in PlayerGui and an input-injection API.

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local player = Players.LocalPlayer
local pg = player:WaitForChild('PlayerGui')

if _G.KPOP_DELTA_STOP then pcall(_G.KPOP_DELTA_STOP) end
local alive, enabled = true, false
local track, lastHit = {}, {0,0,0,0,0,0}
local count, movingCount = 0, 0
local leadPx, cooldownMs, hitY = 18, 12, 777/927
local xs = {585/1650,681/1650,777/1650,873/1650,970/1650,1066/1650}
local keys = {Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.F,Enum.KeyCode.J,Enum.KeyCode.K,Enum.KeyCode.L}
local laneRadius = 0.032
local vim
pcall(function() vim = game:GetService('VirtualInputManager') end)

local gui = Instance.new('ScreenGui')
gui.Name='KPOP_Autoplay_Delta'
gui.ResetOnSpawn=false
gui.DisplayOrder=200
local ok = pcall(function() gui.Parent=CoreGui end)
if not ok then gui.Parent=pg end

local panel = Instance.new('Frame')
panel.Name='Panel'; panel.Size=UDim2.fromOffset(275,204)
panel.Position=UDim2.new(0,15,0.18,0)
panel.BackgroundColor3=Color3.fromRGB(29,27,45)
panel.BorderSizePixel=0; panel.Parent=gui
Instance.new('UICorner',panel).CornerRadius=UDim.new(0,10)

local function label(str,y,height)
 local l=Instance.new('TextLabel');l.Size=UDim2.new(1,-12,0,height or 24)
 l.Position=UDim2.fromOffset(6,y);l.BackgroundTransparency=1
 l.Text=str;l.TextColor3=Color3.new(1,1,1)
 l.Font=Enum.Font.Gotham;l.TextSize=13;l.TextWrapped=true;l.Parent=panel
 return l
end
label('KPOP AutoPlay | Delta (SEM HOLDS)',7,24)
local status=label('Desligado',31,22)
local stats=label('Notas móveis: 0 | Toques: 0',54,22)

local function button(str,x,y,w)
 local b=Instance.new('TextButton');b.Size=UDim2.fromOffset(w,32)
 b.Position=UDim2.fromOffset(x,y);b.BackgroundColor3=Color3.fromRGB(89,68,158)
 b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold
 b.TextSize=13;b.Text=str;b.Parent=panel
 Instance.new('UICorner',b).CornerRadius=UDim.new(0,6)
 return b
end
local toggle=button('LIGAR',8,82,126)
local stop=button('FECHAR',141,82,126)
local minus=button('-5',8,125,65)
local plus=button('+5',201,125,66)
local timing=label('Antecipação: 18 px',130,25)
label('6 colunas S D F J K L | Toques curtos',164,24)

-- Drag panel on touch or mouse.
local drag,dragStart,basePos
panel.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
  drag=true;dragStart=input.Position;basePos=panel.Position
 end
end)
UIS.InputChanged:Connect(function(input)
 if drag and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
  local d=input.Position-dragStart
  panel.Position=UDim2.new(basePos.X.Scale,basePos.X.Offset+d.X,basePos.Y.Scale,basePos.Y.Offset+d.Y)
 end
end)
UIS.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)

local function tap(lane)
 local key=keys[lane]
 local worked=false
 if vim then
  worked=pcall(function() vim:SendKeyEvent(true,key,false,game) end)
  if worked then task.delay(0.012,function() pcall(function() vim:SendKeyEvent(false,key,false,game) end) end) end
 end
 if not worked and type(keypress)=='function' and type(keyrelease)=='function' then
  -- Some executors accept the numerical ASCII codes.
  local ascii=({83,68,70,74,75,76})[lane]
  worked=pcall(function() keypress(ascii) end)
  if worked then task.delay(0.012,function() pcall(function() keyrelease(ascii) end) end) end
 end
 if worked then count=count+1 else status.Text='Sem acesso a teclas virtuais no Delta' end
end

local function screen()
 local v=workspace.CurrentCamera.ViewportSize
 return math.max(v.X,1), math.max(v.Y,1)
end
local function laneFor(x,w)
 local result,dist=nil,1
 for i,cx in ipairs(xs) do
  local d=math.abs(x/w-cx)
  if d<dist then dist=d;result=i end
 end
 if dist<laneRadius then return result end
end
local function visibleNote(obj)
 if not obj:IsA('GuiObject') or not obj.Visible then return false end
 if obj:IsDescendantOf(gui) then return false end
 if obj.AbsoluteSize.X<5 or obj.AbsoluteSize.Y<4 then return false end
 local hasVisual = (obj:IsA('ImageLabel') or obj:IsA('ImageButton')) and obj.ImageTransparency<0.95
 if not hasVisual then
  hasVisual=(obj:IsA('Frame') or obj:IsA('TextButton')) and obj.BackgroundTransparency<0.9
 end
 return hasVisual
end

local accumulator=0
local heartbeat=RunService.Heartbeat:Connect(function(dt)
 if not alive or not enabled then return end
 accumulator=accumulator+dt
 if accumulator<1/60 then return end
 accumulator=0
 local w,h=screen()
 local target=hitY*h-leadPx*(h/927)
 local now=os.clock()
 movingCount=0
 local seen={}
 -- GuiObjects, rather than pixel colors, must be the actual descending notes.
 for _,obj in ipairs(pg:GetDescendants()) do
  if visibleNote(obj) then
   local p,s=obj.AbsolutePosition,obj.AbsoluteSize
   local x,y=p.X+s.X/2,p.Y+s.Y/2
   local lane=laneFor(x,w)
   if lane and y>h*0.12 and y<h*0.94 and s.Y<h*0.20 and s.X<w*0.13 then
    seen[obj]=true
    local previous=track[obj]
    if previous then
     local dy=y-previous.y
     if dy>0.1 and dy<h*0.12 then
      previous.moving=true
      movingCount=movingCount+1
      if previous.y<target and y>=target then
       if (now-lastHit[lane])*1000>=cooldownMs then
        lastHit[lane]=now
        tap(lane)
       end
      end
     end
     previous.y=y;previous.last=now
    else track[obj]={y=y,last=now,moving=false} end
   end
  end
 end
 for obj,t in pairs(track) do
  if not seen[obj] or now-t.last>0.2 then track[obj]=nil end
 end
 stats.Text=('Notas móveis: %d | Toques: %d'):format(movingCount,count)
end)

local function stopAll()
 enabled=false;alive=false
 pcall(function() heartbeat:Disconnect() end)
 pcall(function() gui:Destroy() end)
 _G.KPOP_DELTA_STOP=nil
end
_G.KPOP_DELTA_STOP=stopAll

toggle.MouseButton1Click:Connect(function()
 enabled=not enabled
 if enabled then
  track={};lastHit={0,0,0,0,0,0}
  toggle.Text='PAUSAR';status.Text='Ativo - lendo notas da interface'
 else
  toggle.Text='LIGAR';status.Text='Pausado'
 end
end)
stop.MouseButton1Click:Connect(stopAll)
minus.MouseButton1Click:Connect(function() leadPx=math.max(0,leadPx-5);timing.Text='Antecipação: '..leadPx..' px' end)
plus.MouseButton1Click:Connect(function() leadPx=math.min(100,leadPx+5);timing.Text='Antecipação: '..leadPx..' px' end)
