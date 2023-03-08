local Players = game:GetService("Players")

local Fusion = UIX.Require:get("Fusion")
local createPackage = UIX.Inline.Require:get("createPackage")

local Maid = UIX.Inline.Maid

return function()
    local package = createPackage("*")
    
    local chatlogsCommand = package:createCommand("chatlogs")(function(self)
        self.Shown = Fusion.State(false)
        self.SpyOnSelf = false

        local chatHistorySet = Fusion.State({}) do
            local TEXT_SIZE = 16
            
            local getmsg = game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("OnMessageDoneFiltering")

            local function createUIPadding(a, b, c, d)
                if b and (not d and not c) then b = d end
                if a and (not c and not d) then c = a end
            
                return Fusion.New "UIPadding" {
                    PaddingLeft = UDim.new(0, a),
                    PaddingRight = UDim.new(0, b),
                    PaddingTop = UDim.new(0, c),
                    PaddingBottom = UDim.new(0, d),
                }
            end

            local function getLocalTimeNow()
                return DateTime.now():FormatLocalTime('LTS', 'en-us')
            end

            local function getChatStatus(msg, sender)
                local status = Instance.new("BindableEvent")
                task.spawn(function()
                    local startTime = tick()
                    local success = false

                    local conn; conn = getmsg.OnClientEvent:Connect(function(packet,channel)
                        if packet.SpeakerUserId == sender.UserId and packet.Message== msg:sub(#msg-#packet.Message+1) and (channel == "All" or (channel == "Team" and Players[packet.FromSpeaker].Team == Players.LocalPlayer.Team)) then
                            conn:Disconnect()
                            success = true
                            status:Fire(false)
                            status:Destroy()
                        end
                    end)
                    while tick() - startTime < 1 do task.wait() end
                    if not success then
                        status:Fire(true)
                        status:Destroy()
                    end
                end)
                return status.Event:Wait()
            end

            local function parseLogInfo(logInfo)
                local filteredOrHidden = getChatStatus(logInfo.msg, logInfo.sender)
                return {
                    Color = if filteredOrHidden then Color3.fromRGB(158, 125, 228) else Color3.fromRGB(235, 235, 235),
                    Message = string.format('[%s] %s', getLocalTimeNow(), logInfo.msg),
                }
            end

            Fusion.New "ScreenGui" {
                DisplayOrder = 1000,
                Name = "InlineChatlogs",
                ResetOnSpawn = false,
                AutoLocalize = false,
                Enabled = true,
                Parent = if gethui then gethui() else game:GetService("CoreGui"),
                
                [Fusion.Children] = {
                    Fusion.New "Frame" {
                        Name = "InlineConsoleWindow",
        
                        BackgroundTransparency = 0.4,
                        BackgroundColor3 = Color3.fromRGB(17, 17, 17),
                        BorderSizePixel = 0,
                        Size = UDim2.new(0, 200, 0, 200),
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.fromScale(1, 0.5),
        
                        Visible = Fusion.Computed(function()
                            return self.Shown:get()
                        end),
        
                        [Fusion.Children] = {
                            createUIPadding(5, 5, 5, 5),
                            Fusion.New "ScrollingFrame" {
                                BackgroundTransparency = 1,
        
                                Size = UDim2.fromScale(1, 1),
                                AnchorPoint = Vector2.new(0.5, 0),
                                Position = UDim2.fromScale(0.5, 0),
        
                                ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
                                ScrollBarThickness = 5,
        
                                CanvasSize = UDim2.fromScale(0, 0),
                                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                                
                                [Fusion.Children] = {
                                    createUIPadding(2, 2),
                                    Fusion.New "UIListLayout" {
                                        Padding = UDim.new(0, 1),
                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                        FillDirection = Enum.FillDirection.Vertical,
                                        VerticalAlignment = Enum.VerticalAlignment.Top,
                                    },
                                    Fusion.ComputedPairs(chatHistorySet, function(_, info)
                                        info = parseLogInfo(info)
                                        return Fusion.New "Frame" {
                                            Name = "LogContent",
        
                                            BackgroundTransparency = 1,
                                            Size = UDim2.fromScale(1, 0),
                                            AnchorPoint = Vector2.new(0.5, 0.5),
                                            AutomaticSize = Enum.AutomaticSize.Y,
                                            
                                            [Fusion.Children] = {
                                                Fusion.New "TextLabel" {
                                                    Name = "LogLabel",
        
                                                    BackgroundTransparency = 1,
                                                    Size = UDim2.fromScale(1, 0),
                                                    Position = UDim2.fromScale(0.5, 0.5),
                                                    AnchorPoint = Vector2.new(0.5, 0.5),
        
                                                    Text = info.Message,
                                                    TextSize = TEXT_SIZE,
                                                    TextColor3 = info.Color,
        
                                                    TextXAlignment = Enum.TextXAlignment.Left,
                                                    TextYAlignment = Enum.TextYAlignment.Top,
                                                }
                                            }
                                        }
                                    end, function(element)
                                        element:Destroy()
                                    end)
                                }
                            },
                        }
                    },
                }
            }
        end

        local function onPlayerChatted(message: string, sender: Player)
            local newSet = chatHistorySet:get()
            table.insert(newSet, {
                msg = message:gsub("[\n\r]",''):gsub("\t",' '):gsub("[ ]+",' '),
                sender = sender,
            })
            chatHistorySet:set(newSet, true)
        end
        for _, player in ipairs(Players:GetPlayers()) do
            player.Chatted:Connect(function(msg)
                onPlayerChatted(msg, player)
            end)
        end
        Maid:GiveTask(Players.PlayerAdded:Connect(function(player)
            player.Chatted:Connect(function(msg)
                onPlayerChatted(msg, player)
            end)
        end))
    end)

    chatlogsCommand:createArguments(
        {
            "showLogs",
            "boolean",
            true,
        }
    )

    chatlogsCommand:setCallback(function()
        
    end)
end