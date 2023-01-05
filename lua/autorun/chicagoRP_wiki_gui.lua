AddCSLuaFile()

for i, f in pairs(file.Find("chicagorp_wiki_gui/*.lua", "LUA")) do
    if string.Left(f, 3) == "sv_" then
        if SERVER then 
            include("chicagorp_wiki_gui/" .. f) 
        end
    elseif string.Left(f, 3) == "cl_" then
        if CLIENT then
            include("chicagorp_wiki_gui/" .. f)
        else
            AddCSLuaFile("chicagorp_wiki_gui/" .. f)
        end
    elseif string.Left(f, 3) == "sh_" then
        AddCSLuaFile("chicagorp_wiki_gui/" .. f)
        include("chicagorp_wiki_gui/" .. f)
    else
        print("chicagoRP Wiki GUI detected unaccounted for lua file '" .. f .. "' - check prefixes!")
    end
    print("chicagoRP Wiki GUI successfully loaded!")
end
