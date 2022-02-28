MacGDBp                                                               CHANGE LOG
================================================================================

2.1.1
---------------------
- Fix: Constrain the minimum size of the debugger split views, so that panes
  cannot be permanently hidden.

2.1
---------------------
- New: Native support for Apple Silicon.
- Fix: #266  Plain text fallback source display does not paint the ruler.
- New: #266  Add preference for PHP binary path for syntax highlighting.
- Fix: When debugging and selecting a breakpoint in a different file, the
  current line would be incorrectly highlighted.
- Fix: Small visual tweaks for macOS 12.

2.0.3
---------------------
- Fix: #265  Variables holding scalars would not display a value.
- Change: Reorganized the Window main menu.
- Fix: Speculative fix for a crash when connecting.

2.0.2
---------------------
- Fix: Crash when selecting stack frames after disconnecting.
- Fix: Expanded variables would not reliably re-open after debugger steps.
- Fix: Would not consistently scroll to the active line.
- Fix: #262  Autoupdate would fail to run.

2.0.1
---------------------
- Change: Draw the source view gutter in a way that is dark-mode compatible.
- Change: Make the Remote Paths preferences pane larger.
- Fix: #260  Use macOS standard colors for syntax highlighting for better dark-
  mode compatibility.
- Change: Improve toolbar buttons under dark mode.
- Fix: #261  Large source files would fail to load.

2.0 Beta 1
---------------------
- New: Unified UI with integrated debugger, breakpoints, and eval panels.
- Change: More robust protocol layer communication, which allows loading more
  properties on long arrays and deep objects.
- New: #203  Function call/symbolic breakpoints.
- Fix: #255  "Could not open socket" failures due to socket reuse.
- Fix: #187  Non-ASCII characters would not display correctly in the source
  pane.
- Fix: #224  Spaces in file paths were double-escaped.
- Fix: #230  Long array of objects in variable pane wraps index back to 0
  after every 32 items.
- Fix: #245  Attaching/Detaching is not always reliable.
- Fix: #246  Replace non-breaking spaces in source viewer with normal spaces.
- Fix: #244  Crashing when pressing Run after execution has completed.
- Fix: #249  Property list has duplicate sub-properties.
- Fix: #238  Clicking the Attached checkbox a couple of times crashes.


1.5
---------------------
- New: Now a 64-bit binary (along with x86 and PPC)
- Fix: #128  Clicking on the line number will now always set the correct
  breakpoint
- New: #190  Evaluation of arbitrary script/code fragments
- New: #168  Recursively display objects and arrays in the variable inspector
- Fix: #223  Unable to reattach debugger in certain circumstances
- Fix: #236  Crash when adding breakpoints on 10.8 (patch from Paul Mitchell
  and Sam Fleming)


1.4.1
---------------------
- Fix: Objects with nested objects wouldn't always load their child keys
- Fix: #213  Crash when unchecking "Attached" when the debugger is inactive
- Fix: #219  Crash when highlighting source fails


1.4 Beta 2
---------------------
- Fix: After clicking on a stack frame with a virtual file, the debugger front
  end would hang
- Fix: Crash on clicking "Install & Relaunch" from Sparkle
- New: #210, #195  Add a "Stop" button to detach the debugger from the current
  session
- New: #209  Drag a file onto the source view in the Breakpoints window to load
  the contents
- Fix: #197  Add a menu item and keyboard shortcut for the "Attached" control
- Fix: #208  Variable selection and expansion state not saved across steps
- Fix: The attached state is now remembered in preferences


1.4 Beta 1
---------------------
- Change: #164  Upon disconnecting, the program counter line will no longer be
  highlighted
- Fixed: Preferences jumps around when opening
- New: #165  "Reconnect" is now removed and instead the debugger is either
  attached or detached
- Change: MacGDBp should no longer become unresponsive while waiting for Xdebug
  data
- Change: MacGDBp should no longer corrupt text data returned from Xdebug


1.3
---------------------
- New: #155  Add a variable inspector to display the full, untruncated value
- Change: The Window->Breakpoints (Cmd+Shift+B) will now toggle the visibility
- Fix: All breakpoint markers will now be displayed in the active code debugger
- New: When stepping through code, the selection in the variable list will be
retained
- Fix: #160  The code pane could be unpopulated after debugging the same script
a subsequent time
- Fix: #163  Breakpoints with a space in the pathname would not be set
- Fix: Code would not display if the pathname to the file contained a space
- Fix: #157  After using the run command, the stack will now be properly updated
- New: A preference has been added to disable automatic stepping into the
first line of execution
- Fix: MacGDBp should no longer throw incomplete packet error messages


1.2.1
---------------------
- Fix: The temporary file used for highlighting source code is now saved as UTF8
so files with non-ASCII characters will now be highlighted
- Fix: #152  MacGDBp would crash/segfault if you stepped at the end of a script
- Change: Updated Sparkle to the latest bzr version


1.2
---------------------
- Change: The "File" column now shows the tail rather than the head of the
value, allowing you to see the last part of the path URI
- Fix: #129  Debugging files on a remote server will now work if the remote path
does not exist on the local debugging client
- Change: The debugger will automatically step in to the first frame when the
connection is made
- New: #147  Show super globals (and variables in other contexts) in the
variable viewer
- New: Selecting different stack frames will now show the variables for that
frame, as opposed to only showing the current frame's variables
- New: The breakpoints window will now remember its visible state across
application launches
- New: #129  Created a path replacements preference panel to make creating
breakpoints possible on remote servers


1.1.2
---------------------
- Fix: #140  Saved breakpoints for non-existent files would cause an immediate 
crash on launch
- New: #139  Windows now remember their size and location


1.1.1
---------------------
- Fix: Breakpoints that were removed would come back, multiplied upon relaunch
- New: Allow multiple selection of breakpoints


1.1
---------------------
- New: Add preferences that allow changing of the Xdebug IDE key and port number
- Change: Improved software updater via Sparkle
- Fix: Packets from the Xdebug extension would be incorrectly handled in some
situations, causing the display to break or crash
- New: #123  Add menu items and keyboard shortcuts for the debugger commands
- Fix: Several memory leaks that could, under certain conditions, would cause 
crashes (thanks to Ciarán Walsh)
- Change: #130  If MacGDBp can't highlight the source code, it will default to 
using just plain text
- New: Breakpoints are saved into preferences so that they are recreated at 
launch time


1.0.1
---------------------
- New: Source code is now highlighted via the PHP binary (thanks Ciarán Walsh)
- New: The breakpoints window is now visible on launch
- Fixed: #125  Some installations would receive a "Stopping" status that MacGDBp 
did not handle correctly
- Fixed: #125  Crash when adding breakpoints
