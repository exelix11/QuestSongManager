#pragma once
#include <Windows.h>
#include <cstdint>

enum MiInitResult {
    // If we ever see 0 here it's a bug :)
    FAIL = 1,
    IS_PARENT = 2,
    IS_CHILD = 3
};

typedef void (*MiMessageCallback)(const uint8_t* buffer);

MiInitResult MiInitialize(MiMessageCallback onMessageEvent, uint32_t maxBufferSize, HWND mainWindow);

void MiTerminate();

bool MiSendMessage(const uint8_t* buffer, uint32_t bufferSize);
