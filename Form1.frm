VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "Form1"
   ClientHeight    =   3165
   ClientLeft      =   60
   ClientTop       =   375
   ClientWidth     =   4680
   LinkTopic       =   "Form1"
   ScaleHeight     =   3165
   ScaleWidth      =   4680
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton cmdUnsafeIDE 
      Caption         =   "NOT IDE Safe GDI+"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   600
      Left            =   990
      TabIndex        =   1
      Top             =   1605
      Width           =   2535
   End
   Begin VB.CommandButton cmdSafeIDE 
      Caption         =   "IDE Safe GDI+"
      Height          =   645
      Left            =   990
      TabIndex        =   0
      Top             =   375
      Width           =   2535
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

' GDI+ startup
Private Type GdiplusStartupInput
    GdiplusVersion           As Long
    DebugEventCallback       As Long
    SuppressBackgroundThread As Long
    SuppressExternalCodecs   As Long
End Type
Private Declare Function GdiplusStartup Lib "gdiplus" (Token As Long, inputbuf As GdiplusStartupInput, Optional ByVal outputbuf As Long = 0) As Long

Private Declare Function DestroyWindow Lib "user32.dll" (ByVal hwnd As Long) As Long

Private Sub cmdSafeIDE_Click()

    Dim g As New cGDIplusIDEsafe
    If g.ManageGDIToken(Me.hwnd) = 0& Then
        MsgBox "Failed to initialize GDI+. Is it installed?", vbExclamation + vbOKOnly, "Error"
        Exit Sub
    End If
    
    ' the function returns a handle to a window.
    ' Call DestroyWindow on that handle to shut down
    ' GDI+ at any time
    
    MsgBox "When this message box closes, the app will close and return to IDE." & vbCrLf & vbCrLf & _
        "Then open new instance of Internet Explorer. No crash should occur", vbInformation + vbOKOnly, "Test"
        
    End
    
End Sub

Private Sub cmdUnsafeIDE_Click()
    
    Dim gSI As GdiplusStartupInput
    Dim gToken As Long
    Dim hGDIplus As Long
    
    Dim g As New cGDIplusIDEsafe
    
    gSI.GdiplusVersion = 1
    GdiplusStartup gToken, gSI
    
    ' if you already created a GDI+Safe monitor, then we can't crash even if we try.
    ' Therefore, we will release it for this test
    hGDIplus = g.ManageGDIToken(Me.hwnd)
    DestroyWindow hGDIplus
    
    MsgBox "When this message box closes, the app will close and return to IDE." & vbCrLf & vbCrLf & _
        "Then open a new instance of Internet Explorer and you will then crash " & vbCrLf & _
        "because GDI+ was not shut down properly.", vbInformation + vbOKOnly, "Testing"
        
    End
    
End Sub

