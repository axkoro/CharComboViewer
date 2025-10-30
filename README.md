> [!NOTE]
> This tool was entirely vibe coded.

# CharComboViewer

A simple macOS application to quickly look up key combinations for special characters.

## Purpose

This tool was built to provide a quick and easy way to see the characters that can be typed with different keyboard modifier combinations (Option, Shift, etc.). It displays a visual representation of your current keyboard layout and updates the characters in real-time as you press and hold modifier keys.

## Running the Application

If you are not a developer or don't have Xcode, you can download the latest pre-built version of the application from the [releases page](https://github.com/axkoro/CharComboViewer/releases).

### How to Run the Downloaded App

Because this app is not officially registered with Apple, your Mac will show a security warning the first time you try to open it.

**To run the app, you only need to do this once:**

1.  Find the `CharComboViewer.app` file (e.g., in your Downloads folder).
2.  **Right-click** (or Control-click) the app icon.
3.  Select **"Open"** from the menu that appears.
4.  A new dialog will pop up. This time, it will have an "Open" button. Click it.

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