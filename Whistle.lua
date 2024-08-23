local Whistle = CreateFrame("Frame")
_G.Whistle = Whistle

BINDING_HEADER_WHISTLE = "Whistle"
_G["BINDING_NAME_CLICK WhistleFrame:LeftButton"] = "Whistle Key"

local L = LibStub("AceLocale-3.0"):GetLocale("Whistle")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
local icon = LibStub("LibDBIcon-1.0", true)
local defaultIcon = "Interface\\Icons\\Ability_Hunter_BeastTaming"
local pName = UnitName("player")
local GetStablePetInfo = C_StableInfo.GetStablePetInfo

local call_pet = {
    [1] = 883, -- Call Pet 1
    [2] = 83242, -- Call Pet 2
    [3] = 83243, -- Call Pet 3
    [4] = 83244, -- Call Pet 4
    [5] = 83245, -- Call Pet 5
}

local function EasyMenu_Initialize( frame, level, menuList )
    for index = 1, #menuList do
        local value = menuList[index]
        if (value.text) then
            value.index = index;
            UIDropDownMenu_AddButton( value, level );
        end
    end
end

local function EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay )
    if ( displayMode == "MENU" ) then
        menuFrame.displayMode = displayMode;
    end
    UIDropDownMenu_Initialize(menuFrame, EasyMenu_Initialize, displayMode, nil, menuList);
    ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay);
end

local function classCheck()
    local class = select(2,UnitClass("player"))
    if class == "HUNTER" then return true
    else
        Whistle:UnregisterEvent("ADDON_LOADED")
        Whistle:UnregisterEvent("PLAYER_LOGIN")
        Whistle:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        return false
    end
end

local WGLDB = nil
if ldb and classCheck() then
    WGLDB = ldb:NewDataObject("Whistle", {
        type = "data source",
        text = "Whistle",
        icon = defaultIcon,
    })
end

Whistle:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)

function Whistle:ADDON_LOADED(addon)
    if addon:lower() ~= "whistle" then return end

    classCheck()

    self.db = LibStub("AceDB-3.0"):New("WhistleDB", {
        profile = {
            minimap = {
                hide = false,
            },
        },
        char = {
            pet_number = nil,
        },
    }, true)

    if icon and WGLDB then
        icon:Register("Whistle", WGLDB, self.db.profile.minimap)
    end

    if IsLoggedIn() then self:PLAYER_LOGIN() end
end

function Whistle:PLAYER_LOGIN()
    local pet_number = Whistle.db.char.pet_number
    if pet_number then Whistle:UpdateLDB(pet_number) end
end

function Whistle:COMBAT_LOG_EVENT_UNFILTERED(...)
    local _,event,_,_,sourceName,_,_,_,destName,_,_,spellId = ...
    if event == "SPELL_SUMMON" and sourceName == pName then
        for i=1, 5 do
            if call_pet[i] == spellId then
               Whistle:UpdateLDB(i)
            end
        end
    end
end

function Whistle:CallPetSpellCheck(pet_number)
    if FindSpellBookSlotBySpellID(call_pet[pet_number]) then return true end
end

function Whistle:UpdateLDB(pet_number)
    local petInfo = GetStablePetInfo(pet_number)

    if petInfo then
        WGLDB.icon, WGLDB.text = petInfo.icon, petInfo.name
    else
        WGLDB.icon, WGLDB.text = defaultIcon, L["Pet Slot"].." "..pet_number
    end

    Whistle.db.char.pet_number = pet_number

    -- this used to be "type", "macro", but after 11.0 can no longer /click a button that runs a macro
    WhistleFrame:SetAttribute("type", "spell")
    WhistleFrame:SetAttribute("spell", (L["Call Pet %d"]):format(pet_number))

    C_StableInfo.SetPetSlot(pet_number, pet_number)
end

local function Print(msg)
    print("|c00FF0000Whistle|r: "..msg)
end

if WGLDB then
    local popupFrame = CreateFrame("Frame", "WhistleMenu", UIParent, "UIDropDownMenuTemplate")
    --https://wowpedia.fandom.com/wiki/UI_Object_UIDropDownMenu#The_info_table
    local menu = {}

    local function menuSorter(a, b)
        return a.text > b.text
    end

    local function updateMenu()
        menu = wipe(menu)
        for i = 1, 5 do
            if Whistle:CallPetSpellCheck(i) then
                local petInfo = GetStablePetInfo(i)
                if petInfo then
                    menu[#menu + 1] = {
                        text = petInfo.name,
                        func = function()
                            if InCombatLockdown() then
                                Print(L["Can't change pet in combat"])
                            else
                                Whistle:UpdateLDB(i)
                            end
                            --can't really use secure functions from here can we now...
                            --Whistle:KeyOnClick()
                            --WhistleFrame:GetScript("OnClick")("WhistleFrame", "LeftButton")
                        end,
                        icon = petInfo.icon or nil,
                    }
                else
                    menu[#menu + 1] = {
                        text = L["Pet Slot"].." "..i,
                        func = function()
                            if InCombatLockdown() then
                                Print(L["Can't change pet in combat"])
                            else
                                Whistle:UpdateLDB(i)
                            end
                        end,
                        icon = defaultIcon,
                    }
                end
            end
        end
        --table.sort(menu, menuSorter)
        menu[#menu + 1] = {
            text = L["Show/Hide minimap"],
            func = function()
                if Whistle.db.profile.minimap.hide then
                    icon:Show("Whistle")
                    Whistle.db.profile.minimap.hide = false
                else
                    icon:Hide("Whistle")
                    Whistle.db.profile.minimap.hide = true
                end
            end
        }
        --set selected pet
        local pet_number = Whistle.db.char.pet_number
        if pet_number then
            menu[pet_number].checked = true
        end
    end

    function WGLDB.OnClick(self, button)
        updateMenu()
        EasyMenu(menu, popupFrame, self, 20, 4, "MENU")
    end

    function WGLDB.OnTooltipShow(tt)
        tt:AddLine("Whistle")
    end
end

Whistle:RegisterEvent("ADDON_LOADED")
Whistle:RegisterEvent("PLAYER_LOGIN")
Whistle:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local WhistleFrame = CreateFrame("Button", "WhistleFrame", UIParent, "SecureActionButtonTemplate")
WhistleFrame:RegisterForClicks("AnyUp", "AnyDown")
