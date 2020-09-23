VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "cGDIplusIDEsafe"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
' ///// FUNCTION WILL MAKE THE IDE SAFE FOR GDI+ USAGE ///////

' Problem? Yep. On WinXP and maybe Vista too.
' Tested on Win2K, NT4, Win98, WinME -- no errors
' Therefore, you don't need this class on those systems, but it doesn't hurt

' XP > When calling GdiplusStartup and GdiplusShutdown
' is not called, your IDE can and probably will crash. By calling
' those two functions each and every time you need GDI+, you can
' prevent the crash. However, it is more efficient and faster overall
' to call it once, then shut it down when your app closes.  However,
' executing an END statement, hitting VB toolbar's STOP button or
' hitting END in the Debug Error Message box will prevent shutdown if
' that shutdown code is in a Terminate or Unload event.

' How this function works.
' 1. It creates a hidden window that attaches itself to a hidden VB
'       top-level window that is always there
' 2. The window when it is created establishes a reference
'       to GDI+ so that VB cannot unload the DLL
' 3. When VB closes, so does the window and then GDI+ is released

' How to use this function?
' 1. Create a class: Dim cGDIplus As New cGDIplusIDEsafe
' 2. Call the function: cGDIplus.ManageGDIToken
' 3. That's all that is needed. The crash will no longer occur
' The class does not need to be maintained or kept alive. It can
' be called time and time again. If the GDI+ hack is in place, the
' ManageGDIToken function simply returns its window handle. Should
' it become necessary to prematurely terminate GDI+, simply use
' the API DestroyWindow on the returned window handle


Option Explicit

' GDI+ startup
Private Type GdiplusStartupInput
    GdiplusVersion           As Long
    DebugEventCallback       As Long
    SuppressBackgroundThread As Long
    SuppressExternalCodecs   As Long
End Type
Private Declare Function GdiplusStartup Lib "gdiplus" (Token As Long, inputbuf As GdiplusStartupInput, Optional ByVal outputbuf As Long = 0) As Long
Private Declare Sub GdiplusShutdown Lib "gdiplus" (ByVal Token As Long)
' ^^ shut down occurs in the thunk. See ManageGDIToken

' ***** THUNK APIs and VARIABLES
Private Declare Sub CopyMemory Lib "kernel32.dll" Alias "RtlMoveMemory" (ByRef Destination As Any, ByRef Source As Any, ByVal Length As Long)
Private Declare Function CreateWindowExA Lib "user32.dll" (ByVal dwExStyle As Long, ByVal lpClassName As String, ByVal lpWindowName As String, ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hWndParent As Long, ByVal hMenu As Long, ByVal hInstance As Long, ByRef lpParam As Any) As Long
Private Declare Sub RtlMoveMemory Lib "kernel32" (ByVal Destination As Long, ByVal Source As Long, ByVal Length As Long)
Private Declare Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As Long, ByVal dwSize As Long, ByVal flAllocationType As Long, ByVal flProtect As Long) As Long
Private Declare Function VirtualFree Lib "kernel32" (ByVal lpAddress As Long, ByVal dwSize As Long, ByVal dwFreeType As Long) As Long
Private Declare Function GetModuleHandleA Lib "kernel32" (ByVal lpModuleName As String) As Long
Private Declare Function GetProcAddress Lib "kernel32" (ByVal hModule As Long, ByVal lpProcName As String) As Long
Private Declare Function LoadLibrary Lib "kernel32.dll" Alias "LoadLibraryA" (ByVal lpLibFileName As String) As Long
Private Declare Function SetWindowLong Lib "user32.dll" Alias "SetWindowLongA" (ByVal hwnd As Long, ByVal nIndex As Long, ByVal dwNewLong As Long) As Long
Private Declare Function GetParent Lib "user32.dll" (ByVal hwnd As Long) As Long
Private Declare Function GetWindow Lib "user32.dll" (ByVal hwnd As Long, ByVal wCmd As Long) As Long
Private Declare Function FindWindowEx Lib "user32.dll" Alias "FindWindowExA" (ByVal hWnd1 As Long, ByVal hWnd2 As Long, ByVal lpsz1 As String, ByVal lpsz2 As String) As Long
Private Const GWL_WNDPROC As Long = -4
Private Const GW_OWNER As Long = 4
Private Const WS_CHILD As Long = &H40000000

Public Function ManageGDIToken(ByVal projectHwnd As Long) As Long
        
    ' Parameters
    ' projectHwnd :: any hWnd within your current project
        
    ' Return value is an hWnd to the GDI+ IDE-safe monitor.
    ' If return value is zero, then GDI+ is not installed on the O/S
        
    ' So this function will create (if needed) only one API window for the entire
    ' VB instance and remains as long as VB is opened. The API window is a child
    ' of a hidden VB top-level window and when that window closes, so will the
    ' API window which then will release GDI+. By keeping its own reference to
    ' the GDI+ library, there is no way for that library to be unloaded without
    ' the API window closing.
        
    If projectHwnd = 0& Then Exit Function
    
    Dim hwndGDIsafe     As Long                 'API window to monitor IDE shutdown
    
    ' find the hidden VB owner window. All VB apps have this (run-time & design-time).
    Do
        hwndGDIsafe = GetParent(projectHwnd)
        If Not hwndGDIsafe = 0& Then projectHwnd = hwndGDIsafe
    Loop Until hwndGDIsafe = 0&
    ' ok, got the highest level parent, now find highest level owner
    Do
        hwndGDIsafe = GetWindow(projectHwnd, GW_OWNER)
        If Not hwndGDIsafe = 0& Then projectHwnd = hwndGDIsafe
    Loop Until hwndGDIsafe = 0&
    
    hwndGDIsafe = FindWindowEx(projectHwnd, 0&, "Static", "GDI+Safe Patch")
    If hwndGDIsafe Then
        ManageGDIToken = hwndGDIsafe    ' we already have a manager running for this VB instance
        Exit Function                   ' can abort
    End If
    
    Dim gdiSI           As GdiplusStartupInput  'GDI+ startup info
    Dim gToken          As Long                 'GDI+ instance token
    
    On Error Resume Next
    gdiSI.GdiplusVersion = 1                    ' attempt to start GDI+
    GdiplusStartup gToken, gdiSI
    If gToken = 0& Then                         ' failed to start
        If Err Then Err.Clear
        Exit Function
    End If
    On Error GoTo 0

    Dim z_ScMem         As Long                 'Thunk base address
    Dim z_Code()        As Long                 'Thunk machine-code initialised here
    Dim nAddr           As Long                 'hwndGDIsafe prev window procedure

    Const WNDPROC_OFF   As Long = &H30          'Offset where window proc starts from z_ScMem
    Const PAGE_RWX      As Long = &H40&         'Allocate executable memory
    Const MEM_COMMIT    As Long = &H1000&       'Commit allocated memory
    Const MEM_RELEASE   As Long = &H8000&       'Release allocated memory flag
    Const MEM_LEN       As Long = &HD4          'Byte length of thunk
        
    z_ScMem = VirtualAlloc(0, MEM_LEN, MEM_COMMIT, PAGE_RWX) 'Allocate executable memory
    If z_ScMem <> 0 Then                                     'Ensure the allocation succeeded
        
        ' we make the api window a child so we can use FindWindowEx to locate it easily
        hwndGDIsafe = CreateWindowExA(0&, "Static", "GDI+Safe Patch", WS_CHILD, 0&, 0&, 0&, 0&, projectHwnd, 0&, App.hInstance, ByVal 0&)
        If hwndGDIsafe <> 0 Then
        
            ReDim z_Code(0 To MEM_LEN \ 4 - 1)
        
            z_Code(12) = &HD231C031: z_Code(13) = &HBBE58960: z_Code(14) = &H12345678: z_Code(15) = &H3FFF631: z_Code(16) = &H74247539: z_Code(17) = &H3075FF5B: z_Code(18) = &HFF2C75FF: z_Code(19) = &H75FF2875
            z_Code(20) = &H2C73FF24: z_Code(21) = &H890853FF: z_Code(22) = &HBFF1C45: z_Code(23) = &H2287D81: z_Code(24) = &H75000000: z_Code(25) = &H443C707: z_Code(26) = &H2&: z_Code(27) = &H2C753339: z_Code(28) = &H2047B81: z_Code(29) = &H75000000
            z_Code(30) = &H2C73FF23: z_Code(31) = &HFFFFFC68: z_Code(32) = &H2475FFFF: z_Code(33) = &H681C53FF: z_Code(34) = &H12345678: z_Code(35) = &H3268&: z_Code(36) = &HFF565600: z_Code(37) = &H43892053: z_Code(38) = &H90909020: z_Code(39) = &H10C261
            z_Code(40) = &H562073FF: z_Code(41) = &HFF2453FF: z_Code(42) = &H53FF1473: z_Code(43) = &H2873FF18: z_Code(44) = &H581053FF: z_Code(45) = &H89285D89: z_Code(46) = &H45C72C75: z_Code(47) = &H800030: z_Code(48) = &H20458B00: z_Code(49) = &H89145D89
            z_Code(50) = &H81612445: z_Code(51) = &H4C4&: z_Code(52) = &HC63FF00

            z_Code(1) = 0                                                   ' shutDown mode; used internally by ASM
            z_Code(2) = zFnAddr("user32", "CallWindowProcA")                ' function pointer CallWindowProc
            z_Code(3) = zFnAddr("kernel32", "VirtualFree")                  ' function pointer VirtualFree
            z_Code(4) = zFnAddr("kernel32", "FreeLibrary")                  ' function pointer FreeLibrary
            z_Code(5) = gToken                                              ' Gdi+ token
            z_Code(10) = LoadLibrary("gdiplus")                             ' library pointer (add reference)
            z_Code(6) = GetProcAddress(z_Code(10), "GdiplusShutdown")       ' function pointer GdiplusShutdown
            z_Code(7) = zFnAddr("user32", "SetWindowLongA")                 ' function pointer SetWindowLong
            z_Code(8) = zFnAddr("user32", "SetTimer")                       ' function pointer SetTimer
            z_Code(9) = zFnAddr("user32", "KillTimer")                      ' function pointer KillTimer
        
            z_Code(14) = z_ScMem                                            ' ASM ebx start point
            z_Code(34) = z_ScMem + WNDPROC_OFF                              ' subclass window procedure location
        
            RtlMoveMemory z_ScMem, VarPtr(z_Code(0)), MEM_LEN               'Copy the thunk code/data to the allocated memory
        
            nAddr = SetWindowLong(hwndGDIsafe, GWL_WNDPROC, z_ScMem + WNDPROC_OFF) 'Subclass our API window
            RtlMoveMemory z_ScMem + 44, VarPtr(nAddr), 4& ' Add prev window procedure to the thunk
            gToken = 0& ' zeroize so final check below does not release it
            
            ManageGDIToken = hwndGDIsafe    ' return handle of our GDI+ manager
        
        Else
        
            VirtualFree z_ScMem, 0, MEM_RELEASE     ' failure - release memory
            z_ScMem = 0&
            'MsgBox "Failed to create monitoring window", vbExclamation + vbOKOnly, "Error"
            
        End If
    
    Else
        
      VirtualFree z_ScMem, 0, MEM_RELEASE           ' failure - release memory
      z_ScMem = 0&
      'MsgBox "Failed to initialize thunk memory", vbExclamation + vbOKOnly, "Error"
        
    End If
    
    If gToken Then GdiplusShutdown gToken       ' release token if error occurred
    
End Function

Private Function zFnAddr(ByVal sDLL As String, ByVal sProc As String) As Long
'Return the address of the specified DLL/procedure

  zFnAddr = GetProcAddress(GetModuleHandleA(sDLL), sProc)  'Get the specified procedure address
  Debug.Assert zFnAddr                                     'In the IDE, validate that the procedure address was located
  ' ^^ FYI VB5 users. Search for zFnAddr("vba6", "EbMode") and replace with zFnAddr("vba5", "EbMode")

End Function



