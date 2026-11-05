' Hourly News Switcher scene
'
' Plays a live news stream full screen and moves to the next channel in the
' channel list shortly before every clock hour.
'
' The schedule is worked out from the clock, not from when the app was
' opened, so every Roku running the app (and the web version) shows the same
' channel at the same time. Left/Right on the remote shift the whole rotation
' by one channel, and the channels menu (the * button) takes channels in and
' out of the rotation.

sub init()
    ' Where the app looks for the latest channel list. The copy bundled in the
    ' app is used until this arrives, and instead of it if GitHub can't be reached.
    m.channelListUrl = "https://raw.githubusercontent.com/RedNick/news-switcher-roku/main/channels.json"

    ' If a stream hasn't started playing this long after loading, treat the
    ' channel as not live right now and move on to the next one.
    m.streamStartTimeoutSeconds = 30

    m.secondsPerHour = 3600

    ' --- State ---
    m.newsChannels = []                ' Every channel in the channel list.
    m.disabledChannelNames = loadDisabledChannelNames() ' Channels taken out of the rotation.
    m.currentChannel = invalid         ' The m.newsChannels entry now playing.
    m.secondsBeforeHourToSwitch = 20   ' Overwritten by the channel list.
    m.currentHourSlot = invalid        ' Which hourly slot is currently showing.
    m.manualChannelOffset = 0          ' Added by Left/Right and by skipping dead streams.
    m.viewerWantsSound = false         ' Becomes true once the viewer unmutes.
    m.consecutiveFailedChannels = 0    ' Stops us skipping forever if nothing is live.
    m.allChannelsFailed = false        ' True while waiting for the next hour to retry.

    ' --- Screen elements ---
    m.newsVideo = m.top.findNode("newsVideo")
    m.infoBar = m.top.findNode("infoBar")
    m.channelNameLabel = m.top.findNode("channelNameLabel")
    m.channelStatusLabel = m.top.findNode("channelStatusLabel")
    m.nextChannelLabel = m.top.findNode("nextChannelLabel")
    m.countdownLabel = m.top.findNode("countdownLabel")
    m.versionLabel = m.top.findNode("versionLabel")
    m.sourcesMenu = m.top.findNode("sourcesMenu")
    m.sourceList = m.top.findNode("sourceList")

    m.newsVideo.observeField("state", "onVideoStateChanged")
    m.infoBar.visible = loadInfoBarVisiblePreference()
    m.versionLabel.text = "Version " + CreateObject("roAppInfo").GetVersion()
    m.sourceList.observeField("itemSelected", "onSourceTickChanged")

    ' Ticks once a second to update the countdown and switch on the hour.
    m.clockTimer = CreateObject("roSGNode", "Timer")
    m.clockTimer.duration = 1
    m.clockTimer.repeat = true
    m.clockTimer.observeField("fire", "onClockTick")

    ' Watchdog for streams that never start.
    m.streamStartTimer = CreateObject("roSGNode", "Timer")
    m.streamStartTimer.duration = m.streamStartTimeoutSeconds
    m.streamStartTimer.repeat = false
    m.streamStartTimer.observeField("fire", "onStreamStartTimedOut")

    applyChannelList(readBundledChannelList())
    startDownloadingLatestChannelList()
    renderSourceList()

    m.top.setFocus(true)
    showChannelForCurrentSlot()
    m.clockTimer.control = "start"
end sub

' --- Channel list -----------------------------------------------------------

function readBundledChannelList() as object
    return ParseJson(ReadAsciiFile("pkg:/channels.json"))
end function

' Uses a parsed channels.json. Returns true if the list was usable.
function applyChannelList(channelList as object) as boolean
    if channelList = invalid or channelList.channels = invalid or channelList.channels.Count() = 0
        return false
    end if

    m.newsChannels = channelList.channels
    if channelList.secondsBeforeHourToSwitch <> invalid
        m.secondsBeforeHourToSwitch = channelList.secondsBeforeHourToSwitch
    end if
    return true
end function

sub startDownloadingLatestChannelList()
    m.channelListLoader = CreateObject("roSGNode", "ChannelListLoader")
    m.channelListLoader.channelListUrl = m.channelListUrl
    m.channelListLoader.observeField("channelList", "onLatestChannelListDownloaded")
    m.channelListLoader.control = "run"
end sub

sub onLatestChannelListDownloaded()
    previousChannelsAsText = FormatJson(m.newsChannels)
    if not applyChannelList(m.channelListLoader.channelList) then return

    ' Only restart the stream if the list actually changed.
    if FormatJson(m.newsChannels) <> previousChannelsAsText
        m.consecutiveFailedChannels = 0
        renderSourceList()
        showChannelForCurrentSlot()
    end if
end sub

' --- Which channels are in the rotation ------------------------------------

function isChannelInRotation(newsChannel as object) as boolean
    return not m.disabledChannelNames.DoesExist(newsChannel.name)
end function

function countChannelsInRotation() as integer
    channelsInRotation = 0
    for each newsChannel in m.newsChannels
        if isChannelInRotation(newsChannel) then channelsInRotation = channelsInRotation + 1
    end for
    return channelsInRotation
end function

function getActiveChannels() as object
    activeChannels = []
    for each newsChannel in m.newsChannels
        if isChannelInRotation(newsChannel) then activeChannels.Push(newsChannel)
    end for
    ' Never let the rotation be empty: fall back to every channel.
    if activeChannels.Count() = 0 then return m.newsChannels
    return activeChannels
end function

' Finds a channel's position in a list by name, or -1 if it isn't there.
function findChannelIndex(channels as object, newsChannel as object) as integer
    for channelIndex = 0 to channels.Count() - 1
        if channels[channelIndex].name = newsChannel.name then return channelIndex
    end for
    return -1
end function

' Sets the offset so the current slot lands on the given channel. The
' rotation then carries on in order from there.
sub pointRotationAt(newsChannel as object)
    activeIndex = findChannelIndex(getActiveChannels(), newsChannel)
    if activeIndex <> -1
        m.manualChannelOffset = activeIndex - m.currentHourSlot
    end if
end sub

' --- Schedule maths ---------------------------------------------------------

function getCurrentTimeInSeconds() as integer
    return CreateObject("roDateTime").AsSeconds()
end function

' Hourly slots begin secondsBeforeHourToSwitch before each clock hour.
' Slot numbers count up from the Unix epoch, so they're the same everywhere.
function getHourSlotAt(timeInSeconds as integer) as integer
    return Int((timeInSeconds + m.secondsBeforeHourToSwitch) / m.secondsPerHour)
end function

function getSlotStartTime(hourSlot as integer) as integer
    return hourSlot * m.secondsPerHour - m.secondsBeforeHourToSwitch
end function

' Wraps any whole number (including negatives) into the range 0..count-1.
function wrapIndex(index as integer, count as integer) as integer
    return ((index mod count) + count) mod count
end function

function getChannelForSlot(hourSlot as integer) as object
    activeChannels = getActiveChannels()
    return activeChannels[wrapIndex(hourSlot + m.manualChannelOffset, activeChannels.Count())]
end function

' --- Playing a channel ------------------------------------------------------

sub showChannelForCurrentSlot()
    m.currentHourSlot = getHourSlotAt(getCurrentTimeInSeconds())
    m.allChannelsFailed = false
    playChannel(getChannelForSlot(m.currentHourSlot))
end sub

sub playChannel(newsChannel as object)
    m.currentChannel = newsChannel

    streamContent = CreateObject("roSGNode", "ContentNode")
    streamContent.url = newsChannel.streamUrl
    streamContent.title = newsChannel.name
    streamContent.streamFormat = "hls"
    streamContent.live = true

    m.newsVideo.control = "stop"
    m.newsVideo.content = streamContent
    m.newsVideo.mute = not m.viewerWantsSound
    m.newsVideo.control = "play"

    m.channelNameLabel.text = newsChannel.name
    m.channelStatusLabel.text = "Loading..."
    updateNextChannelLabel()

    m.streamStartTimer.control = "stop"
    m.streamStartTimer.control = "start"
end sub

sub onVideoStateChanged()
    videoState = m.newsVideo.state
    if videoState = "playing"
        m.streamStartTimer.control = "stop"
        m.consecutiveFailedChannels = 0
        updateStatusLabel()
    else if videoState = "buffering"
        m.channelStatusLabel.text = "Loading..."
    else if videoState = "error" or videoState = "finished"
        ' A live stream only "finishes" if the broadcaster stopped it.
        skipToNextChannelAfterFailure()
    end if
end sub

sub onStreamStartTimedOut()
    skipToNextChannelAfterFailure()
end sub

' Moves the rotation on by one, unless every channel has already failed in
' a row, in which case we wait and try again at the next switch.
sub skipToNextChannelAfterFailure()
    m.streamStartTimer.control = "stop"
    m.consecutiveFailedChannels = m.consecutiveFailedChannels + 1

    if m.consecutiveFailedChannels >= getActiveChannels().Count()
        m.newsVideo.control = "stop"
        m.allChannelsFailed = true
        m.channelNameLabel.text = "No channels are playing"
        m.channelStatusLabel.text = "Trying again at the next switch."
        m.infoBar.visible = true
        return
    end if

    m.manualChannelOffset = m.manualChannelOffset + 1
    showChannelForCurrentSlot()
end sub

' --- Clock ------------------------------------------------------------------

sub onClockTick()
    now = getCurrentTimeInSeconds()
    hourSlotNow = getHourSlotAt(now)

    if hourSlotNow <> m.currentHourSlot
        m.consecutiveFailedChannels = 0
        showChannelForCurrentSlot()
    end if

    secondsUntilSwitch = getSlotStartTime(m.currentHourSlot + 1) - now
    m.countdownLabel.text = "Switching in " + formatMinutesAndSeconds(secondsUntilSwitch)
end sub

function formatMinutesAndSeconds(totalSeconds as integer) as string
    if totalSeconds < 0 then totalSeconds = 0
    minutes = Int(totalSeconds / 60)
    seconds = totalSeconds mod 60
    secondsText = seconds.ToStr()
    if seconds < 10 then secondsText = "0" + secondsText
    return minutes.ToStr() + ":" + secondsText
end function

' --- Labels -----------------------------------------------------------------

sub updateNextChannelLabel()
    nextChannel = getChannelForSlot(m.currentHourSlot + 1)
    m.nextChannelLabel.text = "Next: " + nextChannel.name
end sub

sub updateStatusLabel()
    if m.allChannelsFailed then return
    if m.viewerWantsSound
        m.channelStatusLabel.text = "Live"
    else
        m.channelStatusLabel.text = "Live, muted. Press OK for sound."
    end if
end sub

' --- Remote control ---------------------------------------------------------

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    ' While the channels menu is open, the list handles Up, Down and OK
    ' itself, so only the other keys reach here.
    if m.sourcesMenu.visible
        if key = "options" or key = "back"
            setSourcesMenuOpen(false)
        else if key = "play"
            watchChannelNow(m.newsChannels[m.sourceList.itemFocused])
            setSourcesMenuOpen(false)
        end if
        return true
    end if

    if key = "options"
        setSourcesMenuOpen(true)
        return true
    else if key = "right"
        changeChannelManually(1)
        return true
    else if key = "left"
        changeChannelManually(-1)
        return true
    else if key = "OK" or key = "play"
        m.viewerWantsSound = not m.viewerWantsSound
        m.newsVideo.mute = not m.viewerWantsSound
        updateStatusLabel()
        return true
    else if key = "up" or key = "down"
        m.infoBar.visible = not m.infoBar.visible
        saveInfoBarVisiblePreference(m.infoBar.visible)
        return true
    end if

    ' Anything else, including Back, is left to Roku (Back leaves the app).
    return false
end function

sub changeChannelManually(channelStep as integer)
    m.manualChannelOffset = m.manualChannelOffset + channelStep
    m.consecutiveFailedChannels = 0
    showChannelForCurrentSlot()
end sub

' --- Channels menu ----------------------------------------------------------

sub setSourcesMenuOpen(menuIsOpen as boolean)
    m.sourcesMenu.visible = menuIsOpen
    if menuIsOpen
        renderSourceList()
        m.sourceList.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

' Rebuilds the menu: one row per channel, ticked if it's in the rotation.
' The channel playing now is marked with a dot.
sub renderSourceList()
    listContent = CreateObject("roSGNode", "ContentNode")
    tickStates = []
    for each newsChannel in m.newsChannels
        listRow = listContent.CreateChild("ContentNode")
        listRow.title = newsChannel.name
        if m.currentChannel <> invalid and newsChannel.name = m.currentChannel.name
            listRow.title = newsChannel.name + "  " + Chr(9679)
        end if
        tickStates.Push(isChannelInRotation(newsChannel))
    end for

    focusedRow = m.sourceList.itemFocused
    m.sourceList.content = listContent
    m.sourceList.checkedState = tickStates
    if focusedRow > 0 and focusedRow < m.newsChannels.Count()
        m.sourceList.jumpToItem = focusedRow
    end if
end sub

' The list has already flipped the tick on the row the viewer pressed OK on.
sub onSourceTickChanged()
    rowIndex = m.sourceList.itemSelected
    newsChannel = m.newsChannels[rowIndex]
    setChannelInRotation(newsChannel, m.sourceList.checkedState[rowIndex])
end sub

sub setChannelInRotation(newsChannel as object, isInRotation as boolean)
    if isInRotation
        m.disabledChannelNames.Delete(newsChannel.name)
    else
        m.disabledChannelNames[newsChannel.name] = true
        ' Keep at least one channel in the rotation.
        if countChannelsInRotation() = 0
            m.disabledChannelNames.Delete(newsChannel.name)
        end if
    end if
    saveDisabledChannelNames()

    ' Keep the current channel playing if it's still in the rotation;
    ' otherwise move on to whatever the rotation now gives for this hour.
    if m.currentChannel <> invalid and isChannelInRotation(m.currentChannel)
        pointRotationAt(m.currentChannel)
        updateNextChannelLabel()
    else
        m.consecutiveFailedChannels = 0
        showChannelForCurrentSlot()
    end if
    renderSourceList()
end sub

' Plays the chosen channel now and continues the rotation from it. A channel
' picked to watch is put back in the rotation if it was out.
sub watchChannelNow(newsChannel as object)
    if not isChannelInRotation(newsChannel)
        m.disabledChannelNames.Delete(newsChannel.name)
        saveDisabledChannelNames()
    end if
    m.consecutiveFailedChannels = 0
    pointRotationAt(newsChannel)
    showChannelForCurrentSlot()
end sub

' --- Saved preferences ------------------------------------------------------

' Channels are remembered by name, so the setting survives stream link changes.
function loadDisabledChannelNames() as object
    savedSettings = CreateObject("roRegistrySection", "newsSwitcher")
    disabledChannelNames = {}
    savedNames = ParseJson(savedSettings.Read("disabledChannelNames"))
    if type(savedNames) = "roArray"
        for each channelName in savedNames
            disabledChannelNames[channelName] = true
        end for
    end if
    return disabledChannelNames
end function

sub saveDisabledChannelNames()
    savedSettings = CreateObject("roRegistrySection", "newsSwitcher")
    savedSettings.Write("disabledChannelNames", FormatJson(m.disabledChannelNames.Keys()))
    savedSettings.Flush()
end sub


function loadInfoBarVisiblePreference() as boolean
    savedSettings = CreateObject("roRegistrySection", "newsSwitcher")
    return savedSettings.Read("infoBarVisible") <> "false"
end function

sub saveInfoBarVisiblePreference(isVisible as boolean)
    savedSettings = CreateObject("roRegistrySection", "newsSwitcher")
    if isVisible
        savedSettings.Write("infoBarVisible", "true")
    else
        savedSettings.Write("infoBarVisible", "false")
    end if
    savedSettings.Flush()
end sub
