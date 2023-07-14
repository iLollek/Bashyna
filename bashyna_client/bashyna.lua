-- BASHYNA RECEIVER 
-- MADE BY ILOLLEK
-- USING KIWICLIENT (https://github.com/jks-prv/kiwiclient)
-- USING AUKIT (https://github.com/MCJack123/AUKit)

local aukit = require "aukit"

local serverURL = "localhost" -- You need to put in your server.py's IP-Address or Domain
local playbackSpeed = 0.17 -- Change this to higher and it should sound "better", but the pauses in between getting new chunks will be longer.
local minFrequency = 1
local maxFrequency = 30000
receivedChunks = 0
playedChunks = 0
requestsSent = 0

function validateFrequency(frequency)
    local khz = tonumber(frequency)
    if khz and khz >= minFrequency and khz <= maxFrequency then
        return khz
    else
        return false
    end
end

function startup()
    local loadingText = "BASHYNA RECEIVER - STARTING"
    local dots = ""
    local delay = math.random(3, 10)
    counter = 0
  
    while counter ~= delay do
        counter = counter + 0.5
        term.clear()
        term.setCursorPos(1, 1)
        print(loadingText .. dots)
        print([[
        ,-.
        / \  `.  __..-,O
       :   \ --''_..-'.'
       |    . .-' `. '.
       :     .     .`.'
        \     `.  /  ..
         \      `.   ' .
          `,       `.   \
         ,|,`.        `-.\
        '.||  ``-...__..-`
         |  |
         |__|
         /||\
        //||\\
       // || \\
    __//__||__\\__
   Made by iLollek]])
        dots = dots .. "."
        sleep(0.5)
        if #dots > 3 then
            dots = ""
        end
    end

    term.clear()
    term.setCursorPos(1, 1)

    local frequency
    repeat
        print("Input the Frequency in kHz that you want to receive:")
        frequency = read()
        frequency = validateFrequency(frequency)
        if not frequency then
            print("Frequency must be between " .. minFrequency .. " and " .. maxFrequency .. " kHz.")
        end
    until frequency

    return frequency
end

local frequency = startup()

function printRSSI()
    local rssi = 80
    local startTime = os.epoch("utc")
    while true do
        local currentTime = os.epoch("utc")
        local elapsedTime = (currentTime - startTime) / 1000
        rssi = 80 + math.sin(elapsedTime) * 25 -- Vary RSSI value using sine function
        term.clear()
        term.setCursorPos(1, 1)
        print("FREQ: " .. frequency .. " kHz")
        print("RSSI: -" .. string.format("%.1f", rssi))
        print("REQS-CHUNKS: " .. requestsSent)
        print("RECV-CHUNKS: " .. receivedChunks)
        print("PLAY-CHUNKS: " .. playedChunks)
        print("MODE: USB")
        print("WF MAX: -10 db")
        print("WF MIN: -110db")
        print("WF RATE: fast")
        print("SPEC: IIR")
        sleep(0.1)
    end
end

function get_file()
    print("SENDING POST, PLEASE WAIT")
    http.request {
        url = serverURL,
        method = "POST",
        body = "frequency=" .. frequency .. "&filename=filename_" .. math.random(1000, 9999),
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded"
        },
        redirect = true,
        timeout = 10
    }
    requestsSent = requestsSent + 1 
end

get_file()

function download_audio()
    local event, url, handle
    repeat
        event, url, handle = os.pullEvent("http_success")
    until url == serverURL
    local wav_data = http.get(handle.readAll(), nil, true)
    receivedChunks = receivedChunks + 1
    return wav_data.readAll()
end

function playAudio(wav_data)
    local audio = aukit.wav(wav_data)
    local modifiedAudio = aukit.effects.speed(audio, playbackSpeed)
    aukit.play(modifiedAudio:stream(131072), peripheral.find("speaker"))
    playedChunks = playedChunks + 1
end

parallel.waitForAny(printRSSI, function()
    while true do
        local wav_data = download_audio()
        get_file()
        playAudio(wav_data)
    end
end)
