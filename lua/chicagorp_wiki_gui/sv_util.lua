util.AddNetworkString("chicagoRP_wikiGUI")

hook.Add("PlayerSay", "chicagoRPwikiGUI_PLAYERSAY", function(ply, txt)
    if !IsValid(ply) then return end
    local lowerTxt = string.lower(txt)

    if lowerTxt == "*wiki*" or lowerTxt == "*help*" or lowerTxt == "*info*" or lowerTxt == "*quickstart*" then
        net.Start("chicagoRP_wikiGUI")
        net.Send(ply)

        return ""
    end
end)

concommand.Add("chicagoRP_wikiGUI", function(ply)
    if !IsValid(ply) then return end
    net.Start("chicagoRP_wikiGUI")
    net.Send(ply)
end)