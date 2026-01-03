local Whistle = CreateFrame("Frame")

local WhistleSecureActionButton = CreateFrame("Button", "WhistleFrame", UIParent, "SecureActionButtonTemplate")
WhistleSecureActionButton:RegisterForClicks("AnyUp", "AnyDown")

_G["BINDING_NAME_CLICK WhistleFrame:LeftButton"] = "Whistle"

local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local defaultIcon = "Interface\\Icons\\Ability_Hunter_BeastTaming"

local dbDefaults = {
    profile = {
        minimap = {
            hide = false,
        },
    },
    char = {
        petNumber = nil,
    },
}

local petTable = {
    883, -- Call Pet 1
    83242, -- Call Pet 2
    83243, -- Call Pet 3
    83244, -- Call Pet 4
    83245, -- Call Pet 5
}

local function openMenu()
    local function isSelected(index)
        return index == Whistle.db.char.petNumber
    end

    local function setSelected(index)
        if InCombatLockdown() then
            Whistle:Print("Can't change pet in combat")
        else
            Whistle:UpdateLDB(index)
        end
    end

    local function addRadioButton(rootDescription, text, icon, i)
        local radio = rootDescription:CreateRadio(text, isSelected, setSelected, i)

        radio:AddInitializer(function(button, description, menu)
            local rightTexture = button:AttachTexture();
            rightTexture:SetSize(20, 20);
            rightTexture:SetPoint("RIGHT");
            rightTexture:SetTexture(icon);

            -- local fontString = button.fontString;
            -- fontString:SetWidth(fontString:GetUnboundedStringWidth() + 10)
        end)
    end

    MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, rootDescription)
        for i = 1, 5 do
            -- unsure this is needed, not max level hunter?
            local hasSpell = FindSpellBookSlotBySpellID(petTable[i]) and true or false

            if hasSpell then
                local petInfo = C_StableInfo.GetStablePetInfo(i)

                if petInfo then
                    addRadioButton(rootDescription, petInfo.name, petInfo.icon, i)
                else
                    addRadioButton(rootDescription, "Pet Slot "..i, defaultIcon, i)
                end
            end
        end
    end)
end

function Whistle:OnEvent(event, ...)
    self[event](self, ...)
end

function Whistle:ADDON_LOADED(addOnName)
    if addOnName == "Whistle" then

        local function classCheck()
            -- 1st var is localized
            local _, classFilename = UnitClass("player")
            if classFilename == "HUNTER" then
                return true
            else
                Whistle:UnregisterEvent("ADDON_LOADED")
                return false
            end
        end

        if classCheck() then
            -- init db
            self.db = LibStub("AceDB-3.0"):New("WhistleDB", dbDefaults, true)

            -- init LDB
            self.whistleLDB = LibDataBroker:NewDataObject("Whistle", {
                type = "data source",
                text = "Whistle",
                icon = defaultIcon,
                OnClick = openMenu,
                OnTooltipShow = function(tooltip) tooltip:AddLine("Whistle") end,
            })

            -- init icon
            LibDBIcon:Register("Whistle", self.whistleLDB, self.db.profile.minimap)

            if (self.db.char.petNumber) then
                self:UpdateLDB(self.db.char.petNumber)
            end
        end
    end
end

function Whistle:UpdateLDB(petNumber)
    local petInfo = C_StableInfo.GetStablePetInfo(petNumber)

    if petInfo then
        self.whistleLDB.icon = petInfo.icon
    else
        self.whistleLDB.icon = defaultIcon
    end

    self.db.char.petNumber = petNumber

    -- this used to be "type", "macro", but after 11.0 can no longer /click a button that runs a macro
    WhistleSecureActionButton:SetAttribute("type", "spell")
    WhistleSecureActionButton:SetAttribute("spell", petTable[petNumber])

    C_StableInfo.SetPetSlot(petNumber, petNumber)
end

function Whistle:Print(msg)
    print("Whistle:", msg)
end

SLASH_Whistle1 = "/whistle2"

SlashCmdList.Whistle = function(msg)
    if msg == "minimap" then
        if Whistle.db.profile.minimap.hide then
            LibDBIcon:Show("Whistle")
            Whistle.db.profile.minimap.hide = false
        else
            LibDBIcon:Hide("Whistle")
            Whistle.db.profile.minimap.hide = true
        end
    end

    if msg == "" then
        Whistle:Print("/whistle2 minimap (toggle minimap icon)")
    end
end

Whistle:RegisterEvent("ADDON_LOADED")

Whistle:SetScript("OnEvent", Whistle.OnEvent)
