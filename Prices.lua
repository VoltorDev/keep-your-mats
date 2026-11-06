local addonName, ns = ...

-- Precios e inventario para el plan de subida. Solo informa: nada compra ni publica en la subasta.
--
-- Orden: con Auctionator, el menor entre su precio de subasta y el de mercader que haya visto
-- (Auctionator.API.v1.GetAuctionPriceByItemID / GetVendorPriceByItemID, firma leída en su código:
-- (callerID, itemID) -> cobre o nil). Sin Auctionator, el precio de tienda de la DB2 (BuyPrice),
-- que es solo una referencia: muchos materiales no los vende ningún mercader.
local Prices = {}
ns.Prices = Prices

local function AuctionatorAPI()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and type(api.GetAuctionPriceByItemID) == "function" then
        return api
    end
end

function Prices.HasAuctionator()
    return AuctionatorAPI() ~= nil
end

local function Ask(fn, itemID)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn, addonName, itemID)
    if ok and type(value) == "number" and value > 0 then
        return value
    end
end

-- Devuelve cobre y fuente ("auction", "vendor", "reference") o nil si no hay precio.
function Prices.Get(itemID)
    local api = AuctionatorAPI()
    if api then
        local auction = Ask(api.GetAuctionPriceByItemID, itemID)
        local vendor = Ask(api.GetVendorPriceByItemID, itemID)
        if auction and (not vendor or auction <= vendor) then
            return auction, "auction"
        elseif vendor then
            return vendor, "vendor"
        end
    end
    local reference = ns.BUY_PRICE and ns.BUY_PRICE[itemID]
    if reference and reference > 0 then
        return reference, "reference"
    end
end

-- Lo que tienes en bolsas, banco (si lo has abierto alguna vez) y bancos de reactivos y de cuenta.
function Prices.Have(itemID)
    if not (C_Item and C_Item.GetItemCount) then
        return 0
    end
    local count = ns.Readable(C_Item.GetItemCount(itemID, true, false, true, true), 0)
    return type(count) == "number" and count or 0
end
