' Hourly News Switcher for Roku
'
' Entry point. Opens the single screen (NewsSwitcherScene) and keeps the app
' alive until the viewer presses Back to leave it.

sub Main()
    screen = CreateObject("roSGScreen")
    messagePort = CreateObject("roMessagePort")
    screen.SetMessagePort(messagePort)

    screen.CreateScene("NewsSwitcherScene")
    screen.Show()

    while true
        message = Wait(0, messagePort)
        if type(message) = "roSGScreenEvent" and message.IsScreenClosed()
            return
        end if
    end while
end sub
