local DataStoreID = "MainData"

local function ProfileTemplate()
	return {
	
		['Scrap'] = 0,
		['Kills'] = 1,
		['Deaths'] = 1,
		['Inventory'] = {}

	}
end

local MainStore = game:GetService("DataStoreService"):GetDataStore(DataStoreID)
local Promise = require(script.Promise)
local CurrentData = {}


local function UpdateData(player, DataName, Updater)
	CurrentData[player.UserId][DataName] = Updater(CurrentData[player.UserId][DataName])
	local DataObj = player.Profile:FindFirstChild(DataName) 
	if DataObj ~= nil then
		DataObj.Value = CurrentData[player.UserId][DataName] 
	end
end

local function GetData(player)
	return CurrentData[player.UserId]
end

script.UpdateData.OnInvoke = UpdateData
script.GetData.OnInvoke = GetData



game.Players.PlayerAdded:Connect(function(player) 
	local Template = ProfileTemplate()
	local Trys = 0
	local function SetProfileObjs()
		local cProfile = script.Profile:Clone()
		cProfile.Name = "Profile"
	
		for _,Obj in pairs(cProfile:GetChildren()) do
			Obj.Value = CurrentData[player.UserId][Obj.Name]
			Obj.Changed:Connect(function(val)
				CurrentData[player.UserId][Obj.Name] = val
			end)
		end
		
		cProfile.Parent = player
	end
	local function LoadProfile()
		if player.Parent == nil then return end
		Promise.new(function(resolve)
			MainStore:UpdateAsync(player.UserId, function(Old)
				if Old == nil then
					local NewData = {SessonLock = true, Data =  Template}
					CurrentData[player.UserId] = NewData
					return NewData
				else
					if Old.SessionLock and Trys < 10 then
						task.spawn(function() 
							task.wait(2)
							print("Retrying to load data")
							Trys += 1
							LoadProfile()
						end)
						
						return Old
					else
						local NewData = {}
						for entry, value in pairs(Template) do
			 				if Old.Data[entry] == nil then
								NewData[entry] = value
							else
								NewData[entry] = Old.Data[entry]
							end
							
						end
						
						CurrentData[player.UserId] = NewData
						return {SessonLock = true, Data = NewData}
					end
				end	
				
			end)
			resolve()
		end):andThen(function() 
			warn(player.Name, "data has been loaded")
			print(CurrentData[player.UserId])
			SetProfileObjs()
		
		end):catch(function(err)
			print(err)
			task.spawn(function() 
				task.wait(2)
				print("Retrying to load data")
				Trys += 1
				LoadProfile()
			end)
		end)
	end
	
	LoadProfile()
	


	
end)

game.Players.PlayerRemoving:Connect(function(player)
	if CurrentData[player.UserId] == nil  then return end

	local function SaveData()
		Promise.new(function(resolve)
			MainStore:UpdateAsync(player.UserId, function(Old)
				print("data saved")
				return {SessionLock = false, Data = CurrentData[player.UserId]}
			end)
			CurrentData[player.UserId] = nil
			warn("saved "..player.Name.."'s data")
			resolve()
		end):catch(function() 
			task.spawn(function() 
				task.wait(1)
				print("Retrying to save data")
				
				SaveData()
			end)
		end)
	end
	
	SaveData()
end)

game:BindToClose(function() 
	local function IsNoData()
		local Count = 0

		for _,v in  pairs(CurrentData) do
			Count+=1
		end
		
		if Count == 0 then return true else return false end 
	end
	
	repeat
		task.wait(0.1)	
	until IsNoData()
	
end)
