sub init()
    m.top.functionName = "downloadChannelList"
end sub

sub downloadChannelList()
    request = CreateObject("roUrlTransfer")
    request.SetUrl(m.top.channelListUrl)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()

    ' Give up on GitHub after this long and use the copy bundled in the app.
    downloadTimeoutMilliseconds = 8000

    responsePort = CreateObject("roMessagePort")
    request.SetMessagePort(responsePort)

    downloadedList = invalid
    if request.AsyncGetToString()
        response = Wait(downloadTimeoutMilliseconds, responsePort)
        if type(response) = "roUrlEvent" and response.GetResponseCode() = 200
            downloadedList = ParseJson(response.GetString())
        else
            request.AsyncCancel()
        end if
    end if

    m.top.channelList = downloadedList
end sub
