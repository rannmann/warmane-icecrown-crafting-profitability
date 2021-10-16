local path = string.gsub(debug.getinfo(1).source, "^@(.+/)[^/]+$", "%1")
path = path .. "JSON.lua"

JSON = (loadfile(path))() -- http://regex.info/blog/lua/json
--JSON = (loadfile('JSON.lua'))()
--data = loadfile "Auc-ScanData.lua"

function convertToJson(input)
    -- Convert input string to parsed AucScanData variable
    load(load(input))()

    local itemKeys = {
        LINK = 1, -- Used
        ILEVEL = 2, -- Used
        ITYPE = 3, -- Used
        ISUB = 4, -- Used
        IEQUIP = 5, -- Deleted
        PRICE = 6, -- Used
        TLEFT = 7, -- Used
        TIME = 8, -- Used
        NAME = 9, -- Used
        TEXTURE = 10, -- Used
        COUNT = 11, -- Used
        QUALITY = 12, -- Used
        CANUSE = 13, -- Deleted
        ULEVEL = 14, -- Deleted
        MINBID = 15, -- Used
        MININC = 16, -- Deleted
        BUYOUT = 17, -- Used
        CURBID = 18, -- Used
        AMHIGH = 19, -- Deleted
        SELLER = 20, -- Used
        FLAG = 21, -- Deleted
        ID = 22, -- Deleted
        ITEMID = 23, -- used
        SUFFIX = 24, -- Used
        FACTOR = 25, -- Deleted
        ENCHANT = 26, -- Used
        SEED = 27 -- Deleted
    }

    local AucMaxTimes = {
        1800,  -- 30 mins
        7200,  -- 2 hours
        43200, -- 12 hours
        172800 -- 48 hours
    }
    local AucMinTimes = {
        0,
        1800, -- 30 mins
        7200, -- 2 hours
        43200, -- 12 hours
    }

    local result = {}

    -- Ensure input ScanData is expected format
    if AucScanData["Version"] ~= 1.3 then
        print("Expected Auc-ScanData version 1.3, got version " .. AucScanData["Version"] .. ".\n")
        return
    end

    for realmName,realmData in pairs(AucScanData["scans"]) do
        result[realmName] = {}

        for factionName,factionData in pairs(realmData) do
            --io.write("Parsing ",#factionData["ropes"]," ropes for ",realmName," - ",factionName,"\n")

            result[realmName][factionName] = {scan={}}

            for _,v in pairs(factionData["ropes"]) do
                -- Execute string as code to get the value
                local rope = load(v)()

                -- Loop through every item and key the table by item link to de-duplicate
                for _,itemData in pairs(rope) do
                    local itemKey = itemData[itemKeys.LINK]
                    if result[realmName][factionName]["scan"][itemKey] == nil then
                        -- Init metadata values
                        result[realmName][factionName]["scan"][itemKey] = {
                            meta={
                                -- Most of this data is duplicate information from item definitions, which we can look up using the id.
                                --ilvl=itemData[itemKeys.ILEVEL],
                                --type=itemData[itemKeys.ITYPE],
                                --sub_type=itemData[itemKeys.ISUB],
                                name=itemData[itemKeys.NAME],
                                --texture=itemData[itemKeys.TEXTURE],
                                id=itemData[itemKeys.ITEMID],
                                --quality=itemData[itemKeys.QUALITY]
                            },
                            scans={}
                        }

                        -- Only include enchant information if something is enchanted.
                        if itemData[itemKeys.ENCHANT] ~= 0 then
                            result[realmName][factionName]["scan"][itemKey].meta.enchant = itemData[itemKeys.ENCHANT]
                        end

                        -- Only include suffix information if it exists
                        if itemData[itemKeys.SUFFIX] ~= 0 then
                            result[realmName][factionName]["scan"][itemKey].meta.suffix = itemData[itemKeys.SUFFIX]
                        end
                    end
                    -- Unset the metadata values we already saved
                    itemData[itemKeys.ENCHANT] = nil
                    itemData[itemKeys.SUFFIX] = nil -- suffix id (random ench such as "of the X")
                    itemData[itemKeys.ITEMID] = nil -- item id
                    itemData[itemKeys.AMHIGH] = nil -- Current user is high-bidder boolean
                    itemData[itemKeys.TEXTURE] = nil -- item icon
                    itemData[itemKeys.NAME] = nil -- item name
                    itemData[itemKeys.IEQUIP] = nil -- CoreConst::EquipEncode constant
                    itemData[itemKeys.ISUB] = nil -- sub-category (ex: Leather)
                    itemData[itemKeys.ITYPE] = nil -- category (ex: Armor)
                    itemData[itemKeys.ILEVEL] = nil -- iLvl
                    itemData[itemKeys.LINK] = nil -- itemLink
                    itemData[itemKeys.QUALITY] = nil
                    itemData[itemKeys.FLAG] = nil -- Flags are only useful for the addon
                    itemData[itemKeys.CANUSE] = nil -- This is always = 1
                    itemData[itemKeys.ULEVEL] = nil -- We don't care about an item's level requirements to use
                    itemData[itemKeys.MININC] = nil -- Amount next bid must increase by. We can calculate this by doing: bid_next - bid_cur.
                    itemData[itemKeys.ID] = nil -- Internal incrementing identifier from last scan
                    itemData[itemKeys.FACTOR] = nil -- uniqueId in item string (typically a reference to who made it)
                    itemData[itemKeys.SEED] = nil -- Same value as above for some reason

                    itemData["ts"] = itemData[itemKeys.TIME]
                    itemData[itemKeys.TIME] = nil

                    itemData["seller"] = itemData[itemKeys.SELLER]
                    itemData[itemKeys.SELLER] = nil

                    -- Price bidding started at
                    itemData["bid_min"] = itemData[itemKeys.MINBID]
                    itemData[itemKeys.MINBID] = nil

                    -- Price to outbid the previous bid.
                    itemData["bid_next"] = itemData[itemKeys.PRICE]
                    itemData[itemKeys.PRICE] = nil

                    -- Last bid someone paid.  0 if nobody has bid.
                    itemData["bid_cur"] = itemData[itemKeys.CURBID]
                    itemData[itemKeys.CURBID] = nil

                    itemData["bo"] = itemData[itemKeys.BUYOUT]
                    itemData[itemKeys.BUYOUT] = nil

                    itemData["count"] = itemData[itemKeys.COUNT]
                    itemData[itemKeys.COUNT] = nil

                    itemData["max_ttl"] = AucMaxTimes[itemData[itemKeys.TLEFT]]
                    itemData["min_ttl"] = AucMinTimes[itemData[itemKeys.TLEFT]]
                    itemData[itemKeys.TLEFT] = nil

                    -- Push the formatted data to our scan records
                    local existingCount = #result[realmName][factionName]["scan"][itemKey]["scans"]
                    result[realmName][factionName]["scan"][itemKey]["scans"][existingCount+1] = itemData
                end
            end
        end
    end

    --return JSON:encode_pretty(result) -- For debugging. Doubles file size with whitespace.
    return JSON:encode(result)
end

-- Testing via files
--local file = io.open("Auc-ScanData.json", "w+")
--io.output(file)
--io.write(convertToJson(data))
--io.close(file)
--print('File processed successfully')
