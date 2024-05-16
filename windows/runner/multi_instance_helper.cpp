#include "multi_instance_helper.hpp"

namespace
{
    const LPCTSTR SlotName = TEXT("\\\\.\\mailslot\\beatsaber_song_manager_rpc");

    HWND mainWindow;
    HANDLE slotHandle = INVALID_HANDLE_VALUE;
    HANDLE listenThread = 0; // INVALID_HANDLE_VALUE has a special meaning for threads
    MiMessageCallback notifyCallback;
    uint8_t* readBuffer;
    uint32_t maxBufferSize;

    // This is not concurrency-safe but for us it's good enough
    bool tryToOpenExistingMailslot()
    {
        slotHandle = CreateFile(SlotName,
                           GENERIC_WRITE,
                           FILE_SHARE_READ,
                           (LPSECURITY_ATTRIBUTES)NULL,
                           OPEN_EXISTING,
                           FILE_ATTRIBUTE_NORMAL,
                           (HANDLE)NULL);

        if (slotHandle == INVALID_HANDLE_VALUE)
        {
            return false;
        }

        return true;
    }

    bool createRootMailslot()
    {
        slotHandle = CreateMailslot(SlotName,
                               maxBufferSize,                            
                               MAILSLOT_WAIT_FOREVER,        
                               (LPSECURITY_ATTRIBUTES)NULL); 

        if (slotHandle == INVALID_HANDLE_VALUE)
        {
            return false;
        }
        
        return true;
    }

    DWORD messageListenerThread(LPVOID lpThreadParameter) 
    {
        while (slotHandle != INVALID_HANDLE_VALUE)
        {
            DWORD read = 0;
            if (ReadFile(slotHandle, readBuffer, maxBufferSize, &read, NULL))
            {
                if (notifyCallback)
                {
                    // Null-terminate just in case
                    readBuffer[maxBufferSize] = 0;
                    notifyCallback(readBuffer);
                    if (mainWindow)
                    {
                        if (IsIconic(mainWindow)) ShowWindow(mainWindow, SW_RESTORE);
                        SetForegroundWindow(mainWindow);
                        SetFocus(mainWindow);
                        SetActiveWindow(mainWindow);
                    }
                }
            }
        }
        return 0;
    }
}

MiInitResult MiInitialize(MiMessageCallback onMessageEvent, uint32_t maxBuffer, HWND mainProgramWindow)
{
    if (slotHandle != INVALID_HANDLE_VALUE)
        return MiInitResult::FAIL;

    mainWindow = mainProgramWindow;
    maxBufferSize = maxBuffer;
    readBuffer = (uint8_t*)GlobalAlloc(GPTR, maxBufferSize);
    notifyCallback = onMessageEvent;

    if (tryToOpenExistingMailslot())
        return MiInitResult::IS_CHILD;

    if (createRootMailslot())
    {
        listenThread = CreateThread(NULL, 0, messageListenerThread, NULL, 0, NULL);
        if (!listenThread)
        {
            goto fail;
        }

        return MiInitResult::IS_PARENT;
    }

    // This may happen in the rare case where two instances of the program are launched at the same time
fail:
    MiTerminate();
    return MiInitResult::FAIL;
}

void MiTerminate()
{
    notifyCallback = nullptr;

    if (slotHandle != INVALID_HANDLE_VALUE) 
    {
        CloseHandle(slotHandle);
        slotHandle = INVALID_HANDLE_VALUE;
    }

    if (listenThread)
    {
        WaitForSingleObject(listenThread, (DWORD)-1);
        CloseHandle(listenThread);
        listenThread = 0;
    }

    if (readBuffer)
    {
        GlobalFree(readBuffer);
        readBuffer = nullptr;
    }

    maxBufferSize = 0;
}

bool MiSendMessage(const uint8_t *buffer, uint32_t bufferSize)
{
    DWORD written;
    return WriteFile(slotHandle, buffer, bufferSize, &written, nullptr); 
}
