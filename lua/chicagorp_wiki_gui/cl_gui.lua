local HideHUD = false
local OpenMotherFrame = nil
local Dynamic = 0
local enabled = GetConVar("cl_chicagoRP_wikiGUI_enable"):GetBool()
local reddebug = Color(200, 10, 10, 150)
local whitecolor = Color(255, 255, 255, 255)
local blackcolor = Color(0, 0, 0, 255)
local blurMat = Material("pp/blurscreen")
local contenttable = {}

list.Set("DesktopWindows", "chicagoRP Wiki", {
    title = "Wiki",
    icon = "icon64/chicagorp_settings.png",
    init = function(icon, window)
        LocalPlayer():ConCommand("chicagoRP_wikiGUI")
    end
})

local function isempty(s)
    return s == nil or s == ''
end

local function BlurBackground(panel)
    if (!IsValid(panel) or !panel:IsVisible()) then return end
    local layers, density, alpha = 1, 1, 100
    local x, y = panel:LocalToScreen(0, 0)
    local FrameRate, Num, Dark = 1 / RealFrameTime(), 5, 0

    surface.SetDrawColor(255, 255, 255, alpha)
    surface.SetMaterial(blurMat)

    for i = 1, Num do
        blurMat:SetFloat("$blur", (i / layers) * density * Dynamic)
        blurMat:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end

    surface.SetDrawColor(0, 0, 0, Dark * Dynamic)
    surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
    Dynamic = math.Clamp(Dynamic + (1 / FrameRate) * 7, 0, 1)
end

local function PrettifyString(str)
    local cachestr = str
    if string.StartWith(str, "%u") then return str end

    local upperstr = string.gsub(cachestr, "^%l", string.upper)

    return upperstr
end

local function GetTextHeight(text, font)
    surface.SetFont(font)

    local height = select(2, surface.GetTextSize(text))

    return height
end

local function SmoothScrollBar(vbar) -- why
    vbar.nInit = vbar.Init
    function vbar:Init()
        self:nInit()
        self.DeltaBuffer = 0
    end

    vbar.nSetUp = vbar.SetUp
    function vbar:SetUp(_barsize_, _canvassize_)
        self:nSetUp(_barsize_, _canvassize_)
        self.BarSize = _barsize_
        self.CanvasSize = _canvassize_ - _barsize_
        if (1 > self.CanvasSize) then self.CanvasSize = 1 end
    end

    vbar.nAddScroll = vbar.AddScroll
    function vbar:AddScroll(dlta)
        self:nAddScroll(dlta)

        self.DeltaBuffer = OldScroll + (dlta * (self:GetSmoothScroll() && 75 || 50))
        if (self.DeltaBuffer < -self.BarSize) then self.DeltaBuffer = -self.BarSize end
        if (self.DeltaBuffer > (self.CanvasSize + self.BarSize)) then self.DeltaBuffer = self.CanvasSize + self.BarSize end
    end

    vbar.nSetScroll = vbar.SetScroll
    function vbar:SetScroll(scrll)
        self:nSetScroll(scrll)

        if (scrll > self.CanvasSize) then scrll = self.CanvasSize end
        if (0 > scrll ) then scrll = 0 end
        self.Scroll = scrll
    end

    function vbar:AnimateTo(scrll, length, delay, ease)
        self.DeltaBuffer = scrll
    end

    function vbar:GetDeltaBuffer()
        if (self.Dragging) then self.DeltaBuffer = self:GetScroll() end
        if (!self.Enabled) then self.DeltaBuffer = 0 end
        return self.DeltaBuffer
    end

    vbar.nThink = vbar.Think
    function vbar:Think()
        self:nThink()
        if (!self.Enabled) then return end

        local FrameRate = (self.CanvasSize / 10) > math.abs(self:GetDeltaBuffer() - self:GetScroll()) && 2 || 5
        self:SetScroll(Lerp(FrameTime() * (self:GetSmoothScroll() && FrameRate || 10), self:GetScroll(), self:GetDeltaBuffer()))

        if (self.CanvasSize > self.DeltaBuffer && self.Scroll == self.CanvasSize) then self.DeltaBuffer = self.CanvasSize end
        if (0 > self.DeltaBuffer && self.Scroll == 0) then self.DeltaBuffer = 0 end
    end
end

local function WrapText(text, font, maxwidth)
    local words = string.Explode(" ", text) -- Split the text into words
    local lines = {} -- Table to store lines of text

    local line = "" -- Current line of text being built
    local textHeight = GetTextHeight(" ", font) -- Get the height of the text

    surface.SetFont(font)

    for _, word in ipairs(words) do -- Loop through each word
        local width = surface.GetTextSize(line .. word .. " ") -- Calculate the size of the text if the current word is added to the current line

        if width > maxwidth then -- If the width of the text exceeds maxwidth, add the current line to the table of lines and start a new line with the current word
            table.insert(lines, line)
            line = word .. " "
        else -- Otherwise, add the current word to the current line
            line = line .. word .. " "
        end
    end

    table.insert(lines, line) -- Add the last line to the table of lines

    return lines

    -- -- Loop through each line and draw it on the screen
    -- for i, Line in ipairs(lines) do
    --     draw.DrawText(Line, font, x, y + (i - 1) * textHeight, color_black, align)
    -- end
end

local function ContentButton(parent, index, text, w, h)
    local contentButton = parent:Add("DButton")
    contentButton:Dock(TOP)
    contentButton:DockMargin(0, 0, 10, 0)
    contentButton:SetSize(w, h)
    contentButton:SetText(text)

    contentButton:SizeToContents()

    contentindex.Index = index

    function contentButton:Paint(w, h)
        draw.DrawText(index .. ": " .. text, "chicagoRP_NPCShop", 0, 0, Color(20, 200, 20, 255), TEXT_ALIGN_LEFT)

        return nil
    end

    return contentButton
end

local function ContentsPanel(parent, x, y, w, h)
    local contentsScrPanel = vgui.Create("DScrollPanel", parent)
    contentsScrPanel:SetPos(x, y)
    contentsScrPanel:SetSize(w, h)

    function contentsScrPanel:Paint(w, h)
        return nil
    end

    local contentsScrollBar = contentsScrPanel:GetVBar()
    contentsScrollBar:SetHideButtons(true)
    function contentsScrollBar:Paint(w, h)
        if contentsScrollBar.btnGrip:IsHovered() then
            draw.RoundedBox(2, 0, 0, w, h, Color(42, 40, 35, 66))
        end
    end
    function contentsScrollBar.btnGrip:Paint(w, h)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(76, 76, 74, 100))
        end
    end

    SmoothScrollBar(contentsScrollBar)

    return contentsScrPanel
end

local function WikiTextPanel(parent, sectionname, contents, w, h, x, y, infopanelW, infopanelcoord)
    local wikiTxtPanel = vgui.Create("DLabel", parent)
    wikiTxtPanel:SetPos(x, y)
    wikiTxtPanel:SetSize(w, h)
    -- wikiTxtPanel:Dock(TOP)
    -- wikiTxtPanel:DockMargin(0, 0, 5, 5)

    wikiTxtPanel.Think = nil

    wikiTxtPanel:SetWrap(true)
    wikiTxtPanel:SetAutoStretchVertical(true)

    local wrappedlines = WrapText(contents, "Default", w)

    function wikiTxtPanel:Paint(w, h)
        draw.DrawText(sectionname, "Default", 0, 0, blackcolor, TEXT_ALIGN_LEFT)
        draw.RoundedBox(2, 0, 10, 100, 4, blackColor)
        -- draw.DrawText(contents, "Default", 20, 0, blackcolor, TEXT_ALIGN_LEFT)

        for i, line in ipairs(wrappedlines) do
            draw.DrawText(line, font, x, y + (i - 1) * textHeight, color_black, align)
        end

        return nil
    end

    wikiTxtPanel:SizeToContents(5)

    local newsizeW, newsizeH = wikiTxtPanel:GetSize()
    local newposX, newposY = wikiTxtPanel:GetPos()

    if infopanelcoord => newposY then
        wikiTxtPanel:SetSize(newsizeW - infopanelW - 10, newsizeH)
        wrappedlines = WrapText(contents, "Default", newsizeW - infopanelW - 10)
    end

    return wikiTxtPanel
end

local function OptimizedSpawnIcon(parent, model, x, y, w, h)
    local SpawnIc = vgui.Create("ModelImage", parent) -- or DPanel
    SpawnIc:SetPos(x, y)
    SpawnIc:SetSize(w, h)
    SpawnIc:SetModel(model) -- Model we want for this spawn icon

    -- local iconmat = 

    -- function SpawnIc:Paint(w, h)
    --     surface.SetMaterial(IMaterial material)
    --     surface.DrawTexturedRectRotated(0, 0, w, h, 0)

    --     return nil
    -- end

    return SpawnIc
end

local function InfoTextPanel(parent, text, color, w, h)
    local textScrPanel = vgui.Create("DPanel", parent)
    itemScrPanel:SetSize(w, h)
    itemScrPanel:Dock(TOP)
    itemScrPanel:DockMargin(0, 0, 5, 5)

    local colortrue = IsColor(color)

    if colortrue then color.a = 50 end

    function itemScrPanel:Paint(w, h)
        draw.DrawText(text, "chicagoRP_NPCShop", 0, 0, whitecolor, TEXT_ALIGN_LEFT)

        if colortrue then
            surface.SetDrawColor(color)
            surface.DrawRect(0, 0, w, h)

            return true
        else
            return nil
        end
    end

    return itemScrPanel
end

local function InfoParentPanel(parent, itemtbl, x, y, w, h)
    local parentScrPanel = vgui.Create("DScrollPanel", parent)
    parentScrPanel:SetPos(x, y)
    parentScrPanel:SetSize(w, h)

    function parentScrPanel:Paint(w, h)
        return nil
    end

    local parentScrollBar = parentScrPanel:GetVBar()
    parentScrollBar:SetHideButtons(true)
    function parentScrollBar:Paint(w, h)
        if parentScrollBar.btnGrip:IsHovered() then
            draw.RoundedBox(2, 0, 0, w, h, Color(42, 40, 35, 66))
        end
    end
    function parentScrollBar.btnGrip:Paint(w, h)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(96, 96, 94, 100))
        else
            draw.RoundedBox(8, 0, 0, w, h, Color(76, 76, 74, 100))
        end
    end

    SmoothScrollBar(parentScrollBar)

    return parentScrPanel
end

local function WikiInfoPanel(parent, infotable, x, y, w, h)
    if infotable == nil or !IsValid(parent) then return end

    local itemButton = vgui.Create("DPanel", parent)
    itemButton:SetSize(w, h)
    itemButton:SetPos(x, y)

    local printname = infotable.printname

    function itemButton:Paint(w, h)
        draw.DrawText(printname, "chicagoRP_NPCShop", (w / 2) - 10, 10, whitecolor, TEXT_ALIGN_LEFT)
        draw.RoundedBox(4, 0, 0, w, h, graycolor)

        return true
    end

    local spawnicon = OptimizedSpawnIcon(itemButton, infotable.model, 100, 50, 64, 64)

    spawnicon.Think = nil

    local statPanel = InfoParentPanel(parent, itemtbl, 2, 100, w - 4, 100)

    infotable["printname"] = nil

    for _, v in ipairs(infotable) do
        if isempty(v) then continue end

        InfoTextPanel(parent, v, whitecolor, (w / 2) - 4, 25)
    end

    return itemButton
end

local function WikiImagePanel()
end

local function ExpandedImagePanel(image)
    if type(image) != "material" then return end

    local imageW, imageH = image:Width(), image:Height()

    local motherFrame = vgui.Create("DFrame")
    motherFrame:SetSize(screenwidth / 2, screenheight / 2)
    motherFrame:SetVisible(true)
    motherFrame:SetDraggable(false)
    motherFrame:ShowCloseButton(false)
    motherFrame:SetTitle("")
    motherFrame:ParentToHUD()

    chicagoRP.PanelFadeIn(motherFrame, 0.15)

    motherFrame:MakePopup()
    motherFrame:Center()

    function motherFrame:OnKeyCodePressed(key)
        if key == KEY_ESCAPE or key == KEY_Q then
            chicagoRP.PanelFadeOut(motherFrame, 0.15)

            timer.Simple(0.15, function()
                if IsValid(self) then
                    self:Close()
                end
            end)
        end
    end

    function motherFrame:OnMousePressed(mouseCode)
        if mouseCode == MOUSE_FIRST then
            chicagoRP.PanelFadeOut(motherFrame, 0.15)

            timer.Simple(0.15, function()
                if IsValid(self) then
                    self:Close()
                end
            end)
        end
    end

    function motherFrame:Paint(w, h)
        surface.SetDrawColor(50, 50, 50, 100)
        surface.DrawRect(0, 0, w, h)

        -- BlurBackground(self)
    end

    local imagePanel = vgui.Create("DPanel", parent)
    imagePanel:SetSize(imageW, imageH)

    imagePanel:Center()

    function imagePanel:Paint(w, h)
        surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, 1, 1)

        return nil
    end

    return motherFrame, imagePanel
end

surface.CreateFont("chicagoRP_wikiGUI", {
    font = "Roboto",
    size = 36,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true
})

hook.Add("HUDShouldDraw", "chicagoRP_wikiGUI_HideHUD", function()
    if HideHUD == true then
        return false
    end
end)

net.Receive("chicagoRP_wikiGUI", function()
    local ply = LocalPlayer()
    if IsValid(OpenMotherFrame) then OpenMotherFrame:Close() return end
    if !IsValid(ply) then return end
    if !enabled then return end

    local screenwidth = ScrW()
    local screenheight = ScrH()
    local motherFrame = vgui.Create("DFrame")
    motherFrame:SetSize(screenwidth / 2, screenheight / 2)
    motherFrame:SetVisible(true)
    motherFrame:SetDraggable(false)
    motherFrame:ShowCloseButton(true)
    motherFrame:SetTitle("")
    motherFrame:ParentToHUD()
    HideHUD = true

    chicagoRP.PanelFadeIn(motherFrame, 0.15)

    motherFrame:MakePopup()
    motherFrame:Center()

    function motherFrame:OnClose()
        if IsValid(self) then
            chicagoRP.PanelFadeOut(motherFrame, 0.15)
        end

        HideHUD = false
    end

    function motherFrame:OnKeyCodePressed(key)
        if key == KEY_ESCAPE or key == KEY_Q then
            surface.PlaySound("chicagoRP_settings/back.wav")
            timer.Simple(0.15, function()
                if IsValid(self) then
                    self:Close()
                end
            end)
        end
    end

    function motherFrame:Paint(w, h)
        BlurBackground(self)
    end

    contenttable = {}

	local sheet = vgui.Create("DPropertySheet", frame)
	sheet:Dock(FILL)
	sheet:AddSheet("Weapons", weaponsCategoryList, "icon16/cross.png")
	-- sheet:AddSheet("Items", panel2, "icon16/tick.png")

    local weaponsCategoryList = vgui.Create("DCategoryList", motherFrame)
    weaponsCategoryList:SetPos(50, 50)
    weaponsCategoryList:SetSize(920, 500)

    local wikiPageFrame = vgui.Create("DScrollPanel", parent)
    wikiPageFrame:SetSize(1300, 700)
    wikiPageFrame:SetPos(100, 200)

    local wikiFrameScrollBar = wikiPageFrame:GetVBar()

    SmoothScrollBar(wikiFrameScrollBar)

    local wikiPageW, wikiPageH = wikiPageFrame:GetSize()

    function wikiPageFrame:Paint(w, h)
        return nil
    end

    function wikiPageFrame:InvalidateLayout()
        for _, v in ipairs(self:GetChildren()) do
            v:Remove()
        end
    end

	local weaponsCategoryListCollapsor = weaponsCategoryList:Add("Weapons (remove this with paint)")
	local AKMbutton = weaponsCategoryListCollapsor:Add("AKM")
	local Glockbutton = weaponsCategoryListCollapsor:Add("Glock 17")

    function AKMbutton:DoClick()
        contenttable = {}

        print("AKM was clicked.")

        local infopanel = WikiInfoPanel(wikiPageFrame, v, wikiPageW - 50, wikiPageH - 100, 400, 1200)
        local contentpanel = ContentsPanel(parent, 100, wikiPageH - 150, 200, 300)

        local sanitizedtbl = chicagoRP_Wiki.akm[1] = nil
        local contentindex = 0

        local textpanelY = wikiPageH - 200

        local mainpanelW, mainpanelH = WikiInfoPanel:GetSize()
        local mainpanelY = select(2, WikiInfoPanel:GetPos())

        local infoPanelfinalcoord = mainpanelH + mainpanelY

        for _, v in ipairs(sanitizedtbl) do
            PrintTable(v)
            local txtpanel = WikiTextPanel(wikiPageFrame, v.sectionname, v.contents, wikiPageW - 100, 100, 100, textpanelY, mainpanelW, infoPanelfinalcoord)
            contentindex = contentindex + 1
            table.insert(contenttable, txtpanel)

            local contentbutton = ContentButton(contentpanel, contentindex, v.sectionname, 40, 20)

            function contentbutton:DoClick()
                local _, contentPos = contenttable[self.Index]:GetPos()

                print(contentPos)

                wikiFrameScrollBar:AnimateTo(contentPos, 0.5, 0, -1)
            end

            local txtpanelH = select(2, txtpanel:GetSize())

            textpanelY = textpanelY + txtpanelH + 50
        end
    end

	function Glockbutton:DoClick()
        contenttable = {}

	    print("Glock was clicked.")

	    local infopanel = WikiInfoPanel(wikiPageFrame, v, wikiPageW - 50, wikiPageH - 100, 400, 1200)
        local contentpanel = ContentsPanel(parent, 100, wikiPageH - 150, 200, 300)

        local sanitizedtbl = chicagoRP_Wiki.glock17[1] = nil
        local contentindex = 0

        local textpanelX = wikiPageH - 200

        local mainpanelW, mainpanelH = WikiInfoPanel:GetSize()
        local mainpanelX, mainpanelY = WikiInfoPanel:GetPos()

        local infoPanelfinalcoord = mainpanelH + mainpanelY

        for _, v in ipairs(sanitizedtbl) do
            PrintTable(v)
            local txtpanel = WikiTextPanel(wikiPageFrame, v.sectionname, v.contents, textpanelX, 100, mainpanelW, infoPanelfinalcoord)
            contentindex = contentindex + 1
            table.insert(contenttable, txtpanel)

            local contentbutton = ContentButton(contentpanel, contentindex, v.sectionname, 40, 20)

            function contentbutton:DoClick()
                local _, contentPos = contenttable[self.Index]:GetPos()

                print(contentPos)

                wikiFrameScrollBar:AnimateTo(contentPos, 0.5, 0, -1)
            end

            local _, txtpanelH = txtpanelH:GetSize()

            textpanelX = textpanelX + txtpanelH + 50
        end
	end

    -- function weaponsCategoryList:Paint(w, h)
    --     return nil
    -- end

	-- local panel2 = vgui.Create("DPanel", sheet)
	-- function panel2:Paint(w, h)
	--     draw.RoundedBox(4, 0, 0, w, h, Color(255, 128, 0, self:GetAlpha()))
	-- end

    OpenMotherFrame = motherFrame
end)

print("chicagoRP Wiki GUI loaded!")

-- to-do:
-- create image panel (dynamically create and remove materials, do NOT cache them forever)
-- create expanded image panel (set clamp on max panel size based on ScrW and ScrH)
-- set wrap maxwidth to -5 where image panel is
-- bulleted lists
-- clickable links (create invisible DButton parented to the DLabel, lay it over the word that needs to be clickable)













