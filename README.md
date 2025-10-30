> [!NOTE]
> This tool was entirely vibe coded.

# CharComboViewer

A simple macOS application to quickly look up key combinations for special characters.

https://github.com/user-attachments/assets/ef35828c-8b3f-4c8a-b341-738d01fc058e

## Running the Application
If you are not a developer or don't have Xcode, you can download the latest pre-built version of the application from the [releases page](https://github.com/axkoro/CharComboViewer/releases).

### How to Run the Downloaded App
Because this app is not signed with an Apple Developer ID (which would cost me $99/year), macOS will block it from opening by default to protect your system.

**To run the app, you only need to do this once:**
1. Try to open `CharComboViewer.app` (e.g., from your Downloads folder) by double-clicking it.
2. macOS will show a warning that the app cannot be opened.
3. Open **System Settings** > **Privacy & Security**.
4. Scroll down to the **Security** section.
5. You'll see a message about CharComboViewer being blocked. Click **"Open Anyway"**.
6. Confirm by clicking **"Open"** in the dialog that appears.

After you do this once, you can launch the app normally from then on.

### Running from Source

If you are a developer and want to run the application from source, follow these steps:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/axkoro/CharComboViewer.git
    ```
2.  **Open the project in Xcode**
3.  **Run the application:**
      - Press the "Run" button (or `Cmd+R`) in Xcode to build and run the application.
