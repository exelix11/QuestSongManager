#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include "multi_instance_helper.hpp"

FlutterWindow::FlutterWindow(const flutter::DartProject &project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

static HWND rootWindowhandle;

static void RpcHandler(const flutter::MethodCall<> &call, std::unique_ptr<flutter::MethodResult<>> result)
{
  if (!std::holds_alternative<flutter::EncodableList>(*call.arguments()))
  {
    result->NotImplemented();
    return;
  }

  auto& args = std::get<flutter::EncodableList>(*call.arguments());

  if (call.method_name() == "initializeMultiInstance")
  {
    auto buffer_size = std::get<int32_t>(args[0]);
    auto callback_addr = args[1].LongValue();

    auto msg = MiInitialize((MiMessageCallback)callback_addr, (uint32_t)buffer_size, rootWindowhandle);

    result->Success((int32_t)msg);
  }
  else if (call.method_name() == "terminateMultiInstance")
  {
    MiTerminate();
    result->Success((int32_t)0);
  }
  else if (call.method_name() == "sendRpcMessage")
  {
    auto str = std::get<std::string>(args[0]);
    result->Success((int32_t)MiSendMessage((const uint8_t *)str.data(), (uint32_t)str.size()));
  }
  else
  {
    result->NotImplemented();
  }
}

bool FlutterWindow::OnCreate()
{
  if (!Win32Window::OnCreate())
  {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view())
  {
    return false;
  }

  RegisterPlugins(flutter_controller_->engine());

  flutter::MethodChannel<> channel(flutter_controller_->engine()->messenger(), "songmanager/rpc", &flutter::StandardMethodCodec::GetInstance());

  rootWindowhandle = this->GetHandle();
  channel.SetMethodCallHandler(RpcHandler);

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]()
                                                      { this->Show(); });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy()
{
  if (flutter_controller_)
  {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept
{
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_)
  {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result)
    {
      return *result;
    }
  }

  switch (message)
  {
  case WM_FONTCHANGE:
    flutter_controller_->engine()->ReloadSystemFonts();
    break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
