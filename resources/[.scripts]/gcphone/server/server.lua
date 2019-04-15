--====================================================================================
-- #Author : Jonathan D @Gannon
-- #Version 2.0
-- #Edited by : gassastsina
--====================================================================================

----------------------------------------------ESX--------------------------------------------------------
ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local function NumberAlreadyExist(num)
    local result = MySQL.Sync.fetchAll("SELECT users.phone_number FROM users", {})
    for i=1, #result, 1 do
    	if result[i].phone_number == num then
    		return true
		end
    end
	return false
end

-- Generation Alétoire des numero
--- Modifier ici le format
function getPhoneRandomNumber()
    local numBase0 = math.random(0,999)
    local numBase1 = math.random(0,9999)
    local num = string.format("%03d-%04d", 555, numBase1)
	while NumberAlreadyExist(num) do
		Wait(10)
		num = string.format("%03d-%04d", 555, numBase1)
	end
    return num
end


--====================================================================================
--  Utils
--====================================================================================
function getSourceFromIdentifier(identifier, cb)
    TriggerEvent("es:getPlayers", function(users)
        for k , user in pairs(users) do
            if (user.getIdentifier ~= nil and user.getIdentifier() == identifier) or (user.identifier == identifier) then
                cb(k)
                return
            end
        end
    end)
    cb(nil)
end
function getNumberPhone(identifier)
    local result = MySQL.Sync.fetchAll("SELECT users.phone_number FROM users WHERE users.identifier = @identifier", {
        ['@identifier'] = identifier
    })
    if result[1] ~= nil then
        return result[1].phone_number
    end
    return nil
end
function getIdentifierByPhoneNumber(phone_number) 
    local result = MySQL.Sync.fetchAll("SELECT users.identifier FROM users WHERE users.phone_number = @phone_number", {
        ['@phone_number'] = phone_number
    })
    if result[1] ~= nil then
        return result[1].identifier
    end
    return nil
end
function getPlayerID(source)
    local identifiers = GetPlayerIdentifiers(source)
    local player = getIdentifiant(identifiers)
    return player
end
function getIdentifiant(id)
    for _, v in ipairs(id) do
        return v
    end
end
--====================================================================================
--  Contacts
--====================================================================================
function getContacts(identifier)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_users_contacts WHERE phone_users_contacts.identifier = @identifier", {
        ['@identifier'] = identifier
    })
    return result
end
function addContact(source, identifier, number, display)
    local sourcePlayer = tonumber(source)
    MySQL.Async.insert("INSERT INTO phone_users_contacts (`identifier`, `number`,`display`) VALUES(@identifier, @number, @display)", {
        ['@identifier'] = identifier,
        ['@number'] = number,
        ['@display'] = display,
    },function()
        notifyContactChange(sourcePlayer, identifier)
    end)
end
function updateContact(source, identifier, id, number, display)
    local sourcePlayer = tonumber(source)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_users_contacts WHERE phone_users_contacts.id = @id", {
        ['@id'] = id
    })
	TriggerEvent('logs:writeServerOnly', "A modifié le contact ("..result[1].display.." - "..result[1].number..") en ("..display.." - "..number..")", sourcePlayer)
    MySQL.Async.insert("UPDATE phone_users_contacts SET number = @number, display = @display WHERE id = @id", { 
        ['@number'] = number,
        ['@display'] = display,
        ['@id'] = id,
    },function()
        notifyContactChange(sourcePlayer, identifier)
    end)
end
function deleteContact(source, identifier, id)
    local sourcePlayer = tonumber(source)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_users_contacts WHERE `identifier` = @identifier AND `id` = @id", {
        ['@identifier'] = identifier,
        ['@id'] = id
    })
	TriggerEvent('logs:writeServerOnly', "A supprimé le contact ("..result[1].display.." - "..result[1].number..")", sourcePlayer)
    MySQL.Sync.execute("DELETE FROM phone_users_contacts WHERE `identifier` = @identifier AND `id` = @id", {
        ['@identifier'] = identifier,
        ['@id'] = id
    })
    notifyContactChange(sourcePlayer, identifier)
end
function deleteAllContact(identifier)
    MySQL.Sync.execute("DELETE FROM phone_users_contacts WHERE `identifier` = @identifier", {
        ['@identifier'] = identifier
    })
end
function notifyContactChange(source, identifier)
    local sourcePlayer = tonumber(source)
    local identifier = identifier
    if sourcePlayer ~= nil then 
        TriggerClientEvent("gcPhone:contactList", sourcePlayer, getContacts(identifier))
    end
end

RegisterServerEvent('gcPhone:addContact')
AddEventHandler('gcPhone:addContact', function(display, phoneNumber)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    addContact(sourcePlayer, identifier, phoneNumber, display)
end)

RegisterServerEvent('gcPhone:updateContact')
AddEventHandler('gcPhone:updateContact', function(id, display, phoneNumber)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    updateContact(sourcePlayer, identifier, id, phoneNumber, display)
end)

RegisterServerEvent('gcPhone:deleteContact')
AddEventHandler('gcPhone:deleteContact', function(id)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    deleteContact(sourcePlayer, identifier, id)
end)

--====================================================================================
--  Messages
--====================================================================================
function getMessages(identifier)
    local result = MySQL.Sync.fetchAll("SELECT phone_messages.* FROM phone_messages LEFT JOIN users ON users.identifier = @identifier WHERE phone_messages.receiver = users.phone_number", {
         ['@identifier'] = identifier
    })
    return result
    --return MySQLQueryTimeStamp("SELECT phone_messages.* FROM phone_messages LEFT JOIN users ON users.identifier = @identifier WHERE phone_messages.receiver = users.phone_number", {['@identifier'] = identifier})
end


function _internalAddMessage(transmitter, receiver, message, owner)
    local Query = "INSERT INTO phone_messages (`transmitter`, `receiver`,`message`, `isRead`,`owner`) VALUES(@transmitter, @receiver, @message, @isRead, @owner);"
    local Query2 = 'SELECT * from phone_messages WHERE `id` = (SELECT LAST_INSERT_ID());'
	local Parameters = {
        ['@transmitter'] = transmitter,
        ['@receiver'] = receiver,
        ['@message'] = message,
        ['@isRead'] = owner,
        ['@owner'] = owner
    }
	return MySQL.Sync.fetchAll(Query .. Query2, Parameters)[1]
end

function addMessage(source, identifier, phone_number, message)
    local sourcePlayer = tonumber(source)
    local otherIdentifier = getIdentifierByPhoneNumber(phone_number)
    local myPhone = getNumberPhone(identifier)
    if otherIdentifier ~= nil then 
        local tomess = _internalAddMessage(myPhone, phone_number, message, 0)
        getSourceFromIdentifier(otherIdentifier, function (osou)
            if tonumber(osou) ~= nil then 
                -- TriggerClientEvent("gcPhone:allMessage", osou, getMessages(otherIdentifier))
                TriggerClientEvent("gcPhone:receiveMessage", tonumber(osou), tomess, getContactName(otherIdentifier, myPhone), myPhone, message)
            end
        end) 
    end
    local memess = _internalAddMessage(phone_number, myPhone, message, 1)
    TriggerClientEvent("gcPhone:receiveMessage", sourcePlayer, memess, getContactName(otherIdentifier, myPhone), myPhone, message)
end

function getContactName(identifier, phone_number)
    local contacts = getContacts(identifier)
    for i=1, #contacts, 1 do
    	if contacts[i]['number'] == phone_number then
    		return contacts[i]['display']
    	end
    end
    return 'Inconnu'
end

function setReadMessageNumber(identifier, num)
    local mePhoneNumber = getNumberPhone(identifier)
    MySQL.Sync.execute("UPDATE phone_messages SET phone_messages.isRead = 1 WHERE phone_messages.receiver = @receiver AND phone_messages.transmitter = @transmitter", { 
        ['@receiver'] = mePhoneNumber,
        ['@transmitter'] = num
    })
end

function deleteMessage(msgId)
    MySQL.Sync.execute("DELETE FROM phone_messages WHERE `id` = @id", {
        ['@id'] = msgId
    })
end

function deleteAllMessageFromPhoneNumber(source, identifier, phone_number)
    local source = source
    local identifier = identifier
    local mePhoneNumber = getNumberPhone(identifier)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_messages WHERE `receiver` = @mePhoneNumber and `transmitter` = @phone_number", {
        ['@mePhoneNumber'] = mePhoneNumber,
        ['@phone_number'] = phone_number
    })
	TriggerEvent('logs:writeServerOnly', "A supprimé tout les messages du numéro "..phone_number.." : "..json.encode(result), source)
    MySQL.Sync.execute("DELETE FROM phone_messages WHERE `receiver` = @mePhoneNumber and `transmitter` = @phone_number", {
    	['@mePhoneNumber'] = mePhoneNumber,
    	['@phone_number'] = phone_number}
    )
end

function deleteAllMessage(identifier)
    local mePhoneNumber = getNumberPhone(identifier)
    MySQL.Sync.execute("DELETE FROM phone_messages WHERE `receiver` = @mePhoneNumber", {
        ['@mePhoneNumber'] = mePhoneNumber
    })
end

RegisterServerEvent('gcPhone:sendMessage')
AddEventHandler('gcPhone:sendMessage', function(phoneNumber, message)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    addMessage(sourcePlayer, identifier, phoneNumber, message)
end)

RegisterServerEvent('gcPhone:deleteMessage')
AddEventHandler('gcPhone:deleteMessage', function(msgId)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_messages WHERE `id` = @id", {
        ['@id'] = msgId
    })
	TriggerEvent('logs:writeServerOnly', "A supprimé le message : "..result[1].message, source)
    deleteMessage(msgId)
end)

RegisterServerEvent('gcPhone:deleteMessageNumber')
AddEventHandler('gcPhone:deleteMessageNumber', function(number)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    deleteAllMessageFromPhoneNumber(sourcePlayer,identifier, number)
    -- TriggerClientEvent("gcphone:allMessage", sourcePlayer, getMessages(identifier))
end)

RegisterServerEvent('gcPhone:deleteAllMessage')
AddEventHandler('gcPhone:deleteAllMessage', function()
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    deleteAllMessage(identifier)
end)

RegisterServerEvent('gcPhone:setReadMessageNumber')
AddEventHandler('gcPhone:setReadMessageNumber', function(num)
    local identifier = getPlayerID(source)
    setReadMessageNumber(identifier, num)
end)

RegisterServerEvent('gcPhone:deleteALL')
AddEventHandler('gcPhone:deleteALL', function()
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    deleteAllMessage(identifier)
    deleteAllContact(identifier)
    appelsDeleteAllHistorique(identifier)
    TriggerClientEvent("gcPhone:contactList", sourcePlayer, {})
    TriggerClientEvent("gcPhone:allMessage", sourcePlayer, {})
    TriggerClientEvent("appelsDeleteAllHistorique", sourcePlayer, {})
end)

--====================================================================================
--  Gestion des appels
--====================================================================================
local AppelsEnCours = {}
local lastIndexCall = 10

function getHistoriqueCall (num)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_calls WHERE phone_calls.owner = @num ORDER BY time DESC LIMIT 120", {
        ['@num'] = num
    })
    return result
end

function sendHistoriqueCall (src, num) 
    local histo = getHistoriqueCall(num)
    TriggerClientEvent('gcPhone:historiqueCall', src, histo)
end

function saveAppels (appelInfo)
	if appelInfo.job ~= nil then
	    local result = MySQL.Sync.fetchAll("SELECT * FROM jobs WHERE `name`=@name", {
	        ['@name'] = appelInfo.job
	    })
	    for i=1, #result, 1 do
	    	if result[i].name == appelInfo.job then
	    		appelInfo.job = result[i].label
	    		break
	    	end
	    end
	end
    MySQL.Async.insert("INSERT INTO phone_calls (`owner`, `num`,`incoming`, `accepts`) VALUES(@owner, @num, @incoming, @accepts)", {
        ['@owner'] = appelInfo.transmitter_num,
        ['@num'] = appelInfo.job or appelInfo.receiver_num,
        ['@incoming'] = 1,
        ['@accepts'] = appelInfo.is_accepts
    }, function()
        notifyNewAppelsHisto(appelInfo.transmitter_src, appelInfo.transmitter_num)
    end)
    if appelInfo.is_valid == true then
        local num = appelInfo.transmitter_num
        if appelInfo.hidden == true then
            num = appelInfo.job or "###-####"
        end
        MySQL.Async.insert("INSERT INTO phone_calls (`owner`, `num`,`incoming`, `accepts`) VALUES(@owner, @num, @incoming, @accepts)", {
            ['@owner'] = appelInfo.receiver_num,
            ['@num'] = num,
            ['@incoming'] = 0,
            ['@accepts'] = appelInfo.is_accepts
        }, function()
            if appelInfo.receiver_src ~= nil then
                notifyNewAppelsHisto(appelInfo.receiver_src, appelInfo.receiver_num)
            end
        end)
    end
end

function notifyNewAppelsHisto (src, num) 
    sendHistoriqueCall(src, num)
end

RegisterServerEvent('gcPhone:getHistoriqueCall')
AddEventHandler('gcPhone:getHistoriqueCall', function()
    local sourcePlayer = tonumber(source)
    local srcIdentifier = getPlayerID(source)
    local srcPhone = getNumberPhone(srcIdentifier)
    sendHistoriqueCall(sourcePlayer, num)
end)

RegisterServerEvent('gcPhone:startCall')
AddEventHandler('gcPhone:startCall', function(phone_number, job)
    if phone_number == nil then 
        print('BAD CALL NUMBER IS NIL')
        return
    end
    local hidden = string.sub(phone_number, 1, 1) == '#'
    if hidden == true then
        phone_number = string.sub(phone_number, 2)
    end

    local indexCall = lastIndexCall
    lastIndexCall = lastIndexCall + 1

    local sourcePlayer = tonumber(source)
    local srcIdentifier = getPlayerID(source)
    local srcPhone = getNumberPhone(srcIdentifier)
    local destPlayer = getIdentifierByPhoneNumber(phone_number)
    local is_valid = destPlayer ~= nil and destPlayer ~= srcIdentifier
    local job = {label = nil, name = job}
	if job ~= nil then
	    local result = MySQL.Sync.fetchAll("SELECT * FROM jobs WHERE `name`=@name", {
	        ['@name'] = job.name
	    })
	    for i=1, #result, 1 do
	    	if result[i].name == job.name then
	    		job.label = result[i].label
	    		break
	    	end
	    end
	end
    AppelsEnCours[indexCall] = {
        id = indexCall,
        transmitter_src = sourcePlayer,
        transmitter_num = srcPhone,
        receiver_src = nil,
        receiver_num = job.label or phone_number,
        is_valid = destPlayer ~= nil,
        is_accepts = false,
        hidden = hidden,
        job = job.name
    }

    if is_valid == true then
        getSourceFromIdentifier(destPlayer, function (srcTo)
            if srcTo ~= nill then
                AppelsEnCours[indexCall].receiver_src = srcTo
                TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall])
                TriggerClientEvent('gcPhone:waitingCall', srcTo, AppelsEnCours[indexCall])
            else
                TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall])
            end
        end)
    else
        TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall])
    end

end)




RegisterServerEvent('gcPhone:acceptCall')
AddEventHandler('gcPhone:acceptCall', function(infoCall)
    local id = infoCall.id
    if AppelsEnCours[id] ~= nil then
        if AppelsEnCours[id].transmitter_src ~= nil and AppelsEnCours[id].receiver_src ~= nil then
            AppelsEnCours[id].is_accepts = true
            TriggerClientEvent('gcPhone:acceptCall', AppelsEnCours[id].transmitter_src, AppelsEnCours[id])
            TriggerClientEvent('gcPhone:acceptCall', AppelsEnCours[id].receiver_src, AppelsEnCours[id])
            saveAppels(AppelsEnCours[id])
        end
    end
end)


RegisterServerEvent('gcPhone:rejectCall')
AddEventHandler('gcPhone:rejectCall', function (infoCall)
    local id = infoCall.id
    if AppelsEnCours[id] ~= nil then
        if AppelsEnCours[id].transmitter_src ~= nil then
            TriggerClientEvent('gcPhone:rejectCall', AppelsEnCours[id].transmitter_src)
        end
        if AppelsEnCours[id].receiver_src ~= nil then
            TriggerClientEvent('gcPhone:rejectCall', AppelsEnCours[id].receiver_src)
        end

        if AppelsEnCours[id].is_accepts == false then 
            saveAppels(AppelsEnCours[id])
        end
        AppelsEnCours[id] = nil
    end
end)

RegisterServerEvent('gcPhone:rejectCallFromService')
AddEventHandler('gcPhone:rejectCallFromService', function (infoCall)
    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
    	local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer.job.name == infoCall.job and infoCall.transmitter_src ~= xPlayers[i] and infoCall.receiver_src ~= xPlayers[i] then
            TriggerClientEvent('gcPhone:rejectCall', xPlayers[i], infoCall)
        end
    end
end)

RegisterServerEvent('gcPhone:appelsDeleteHistorique')
AddEventHandler('gcPhone:appelsDeleteHistorique', function (numero)
    local sourcePlayer = tonumber(source)
    local srcIdentifier = getPlayerID(source)
    local srcPhone = getNumberPhone(srcIdentifier)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_calls WHERE `owner` = @owner AND `num` = @num", {
        ['@owner'] = srcPhone,
        ['@num'] = numero
    })
	TriggerEvent('logs:writeServerOnly', "A supprimé l'historique d'appels du "..numero.." : "..json.encode(result), sourcePlayer)
    MySQL.Sync.execute("DELETE FROM phone_calls WHERE `owner` = @owner AND `num` = @num", {
        ['@owner'] = srcPhone,
        ['@num'] = numero
    })
end)

function appelsDeleteAllHistorique(srcIdentifier)
    local srcPhone = getNumberPhone(srcIdentifier)
    MySQL.Sync.execute("DELETE FROM phone_calls WHERE `owner` = @owner", {
        ['@owner'] = srcPhone
    })
end

RegisterServerEvent('gcPhone:appelsDeleteAllHistorique')
AddEventHandler('gcPhone:appelsDeleteAllHistorique', function ()
    local sourcePlayer = tonumber(source)
    local srcIdentifier = getPlayerID(source)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_calls WHERE `owner`=@owner", {
        ['@owner'] = srcPhone
    })
	TriggerEvent('logs:writeServerOnly', "A supprimé tout l'historique d'appels : "..json.encode(result), sourcePlayer)
    appelsDeleteAllHistorique(srcIdentifier)
end)





function getOrGeneratePhoneNumber (sourcePlayer, identifier, cb)
    local sourcePlayer = sourcePlayer
    local identifier = identifier
    local myPhoneNumber = getNumberPhone(identifier)
    if myPhoneNumber == '0' then
        local randomNumberPhone = getPhoneRandomNumber(identifier)
        MySQL.Async.insert("UPDATE users SET phone_number = @randomNumberPhone WHERE identifier = @identifier", { 
            ['@randomNumberPhone'] = randomNumberPhone,
            ['@identifier'] = identifier
        }, function ()
            getOrGeneratePhoneNumber(sourcePlayer, identifier, cb)
        end)
    else
        cb(myPhoneNumber)
    end
end

--====================================================================================
--  OnLoad
--====================================================================================
AddEventHandler('es:playerLoaded',function(source)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    getOrGeneratePhoneNumber(sourcePlayer, identifier, function (myPhoneNumber)
        TriggerClientEvent("gcPhone:myPhoneNumber", sourcePlayer, myPhoneNumber)
        TriggerClientEvent("gcPhone:contactList", sourcePlayer, getContacts(identifier))
        TriggerClientEvent("gcPhone:allMessage", sourcePlayer, getMessages(identifier))
    end)
end)

-- Just For reload
RegisterServerEvent('gcPhone:allUpdate')
AddEventHandler('gcPhone:allUpdate', function()
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    local num = getNumberPhone(identifier)
    TriggerClientEvent("gcPhone:myPhoneNumber", sourcePlayer, num)
    TriggerClientEvent("gcPhone:contactList", sourcePlayer, getContacts(identifier))
    TriggerClientEvent("gcPhone:allMessage", sourcePlayer, getMessages(identifier))
    TriggerClientEvent('gcPhone:getBourse', sourcePlayer, getBourse())
    sendHistoriqueCall(sourcePlayer, num)
end)


AddEventHandler('onMySQLReady', function ()
    MySQL.Async.fetchAll("DELETE FROM phone_messages WHERE (DATEDIFF(CURRENT_DATE,time) > 10)")
end)

--====================================================================================
--  App bourse
--====================================================================================
function getBourse()
    --  Format
    --  Array 
    --    Object
    --      -- libelle type String    | Nom
    --      -- price type number      | Prix actuelle
    --      -- difference type number | Evolution 
    -- 
    -- local result = MySQL.Sync.fetchAll("SELECT * FROM `recolt` LEFT JOIN `items` ON items.`id` = recolt.`treated_id` WHERE fluctuation = 1 ORDER BY price DESC",{})
    local result = {
        {
            libelle = 'Google',
            price = 125.2,
            difference =  -12.1
        },
        {
            libelle = 'Microsoft',
            price = 132.2,
            difference = 3.1
        },
        {
            libelle = 'Amazon',
            price = 120,
            difference = 0
        }
    }
    return result
end

--====================================================================================
--  App ... WIP
--====================================================================================

function MsgAllEmployee(reason,pos) 
    --print("Reason : "..json.encode(reason))
    local tabinfo = stringsplit(reason,"/")
    --print("tabInfo : "..json.encode(tabinfo))

    local results = MySQL.Sync.fetchAll("SELECT phone_number FROM users WHERE job = @job AND phone_number IS NOT NULL", {
        ['@job'] = tabinfo[1]
    })
    Citizen.Trace('callentreprise : '..json.encode(results))
    --sendMessage("5552829", "Appel mecano : "..message['type'])


    local mysource = source
    local identifier = GetPlayerIdentifiers(source)[1]
    
    for k,v in pairs(results) do
        addMessageEntreprise(source, identifier, v.phone_number, tabinfo[2])
        if tabinfo[3] == "1" then
            addMessageEntreprise(source, identifier, v.phone_number, pos)
        end
    end
    
    return nil
end

RegisterServerEvent('gcphone:callEntrepriseService')
AddEventHandler('gcphone:callEntrepriseService', function(reason, pos)
    MsgAllEmployee(reason,pos)
end)

ESX.RegisterServerCallback('gcphone:jobMemberChecker', function(source, cb, job)
    local member = 0
    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
        if ESX.GetPlayerFromId(xPlayers[i]).job.name == job then
            member = member + 1
        end
    end
    cb(member)
end)


RegisterServerEvent('PanicButton:Code99')
AddEventHandler('PanicButton:Code99', function(message)
    local _source = source
    local identifier = getPlayerID(_source)
    local result = MySQL.Sync.fetchAll("SELECT * FROM users WHERE identifier=@identifier", {
        ['@identifier'] = identifier
    })

    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer.job.name == 'police' then
            TriggerClientEvent('PanicButton:notification', xPlayers[i], result[1].firstname.." "..result[1].lastname, ESX.GetPlayerFromId(_source).getCoords())
            addMessage(_source, identifier, getNumberPhone(xPlayer.getIdentifier()), message)
        end
    end
end)

ESX.RegisterServerCallback('gcphone:getItemAmount', function(source, cb, item)
    cb(ESX.GetPlayerFromId(source).getInventoryItem(item).count)
end)

RegisterServerEvent('gcphone:sendToJob')
AddEventHandler('gcphone:sendToJob', function(job)
    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
    	local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer.job.name == job then
            TriggerClientEvent('gcPhone:sendToClientStartCall', source, getNumberPhone(xPlayer.identifier), job)
        end
    end
end)

RegisterServerEvent('gcPhone:sendGPSToService')
AddEventHandler('gcPhone:sendGPSToService', function(job, message)
    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
    	local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer.job.name == job then
            addMessage(source, getPlayerID(source), getNumberPhone(xPlayer.getIdentifier()), message)
        end
    end
end)


RegisterServerEvent('gcphone:ChangeNum')
AddEventHandler('gcphone:ChangeNum', function(player)
	local identifier = ESX.GetPlayerFromId(player).identifier
	local NewNum = getPhoneRandomNumber(identifier)
	TriggerClientEvent('esx:showNotification', player, "Votre nouveau numéro de téléphone est le : "..NewNum)
    MySQL.Async.insert("UPDATE users SET phone_number=@randomNumberPhone WHERE identifier=@identifier", { 
        ['@randomNumberPhone'] = NewNum,
        ['@identifier'] = identifier
    }, function ()
    end)
end)