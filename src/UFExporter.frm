VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} UFExporter 
   Caption         =   "Export Data Range"
   ClientHeight    =   4080
   ClientLeft      =   45
   ClientTop       =   375
   ClientWidth     =   4560
   OleObjectBlob   =   "UFExporter.frx":0000
   ShowModal       =   0   'False
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "UFExporter"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

' # ------------------------------------------------------------------------------
' # Name:        UFExporter.frm
' # Purpose:     Core UserForm for the CSV Exporter Excel VBA Add-In
' #
' # Author:      Brian Skinn
' #                bskinn@alum.mit.edu
' #
' # Created:     24 Jan 2016
' # Copyright:   (c) Brian Skinn 2016-2019
' # License:     The MIT License; see "LICENSE.txt" for full license terms.
' #
' #       http://www.github.com/bskinn/excel-csvexporter
' #
' # ------------------------------------------------------------------------------

Option Explicit

' ===== EVENT-ENABLED APPLICATION =====
Private WithEvents appn As Application
Attribute appn.VB_VarHelpID = -1


' =====  CONSTANTS  =====
Const NoFolderStr As String = "<none>"
Const InvalidSelStr As String = "<invalid selection>"


' =====  GLOBALS  =====
Dim WorkFolder As Folder
Dim fs As FileSystemObject
Dim ExportRange As Range
Dim HiddenByChart As Boolean


' =====  EVENT-ENABLED APPLICATION EVENTS  =====

Private Sub appn_SheetActivate(ByVal Sh As Object)
    ' Update the export range object, the
    ' export range reporting text, and the
    ' status of the 'Export' button any time a sheet
    ' is switched to
    
    ' Short-circuit drop-out if form is hidden, and not by
    ' navigation across a chart-sheet
    If Not HiddenByChart And Not UFExporter.Visible Then Exit Sub
    
    ' If a chartsheet is selected by the user, hide the form and
    ' sit quietly.
    If TypeOf Sh Is Chart Then
        ' Only set the hidden-by-chart flag if the form was visible
        ' when the chart was activated
        If UFExporter.Visible Then
            HiddenByChart = True
            UFExporter.Hide
        End If
        
        ' Always want to not update things when a chart sheet is selected
        Exit Sub
    Else
        ' Only need to do something special here if the form
        ' was hidden by navigation onto a chart, in which case
        ' it's desired to reset the flag and re-show the form.
        If HiddenByChart Then
            HiddenByChart = False
            UFExporter.Show
        End If
    End If
    
    setExportRange
    setExportRangeText
    setExportEnabled
    
End Sub

Private Sub appn_SheetSelectionChange(ByVal Sh As Object, ByVal Target As Range)
    ' Update the export range object, the
    ' export range reporting text, and the
    ' status of the 'Export' button any time
    ' a new cell selection is made
    
    ' Short-circuit drop-out if form is hidden. No need to check for
    ' HiddenByChart here(?)
    If Not UFExporter.Visible Then Exit Sub
    
    setExportRange
    setExportRangeText
    setExportEnabled
    
End Sub


' =====  FORM EVENTS  =====

Private Sub BtnClose_Click()
    ' Set the startup-position setting to 'Manual', so that the form
    '  will re-open where the user last placed it instead of in the
    '  center of the Excel window.
    ' Changing this setting here is somewhat inefficient, since it
    '  will get set every time 'Close' is clicked, but moving it
    '  to UserForm_Initialize results in the form starting in
    '  the top-left corner of the screen. Not desired.
    Me.StartUpPosition = 0  ' vbStartUpManual
    
    ' Hide the form without Unloading
    UFExporter.Hide
    
End Sub

Private Sub BtnExport_Click()
    
    Dim filePath As String, tStrm As TextStream, mode As IOMode
    Dim errNum As Long
    
    ' Should only ever be possible to click if form is in a good state for exporting
    
    ' Store full file path
    filePath = fs.BuildPath(WorkFolder.Path, TxBxFilename.Value)
    
    ' Convert append setting to IOMode
    If ChBxAppend.Value Then
        mode = ForAppending
    Else
        mode = ForWriting
    End If
    
    ' Bind the text stream, with error handling
    On Error Resume Next
        Set tStrm = fs.OpenTextFile(filePath, mode, True, TristateUseDefault)
    errNum = Err.Number: Err.Clear: On Error GoTo 0
    
    If errNum <> 0 Then
        MsgBox "File cannot be written at this location." & _
                Chr(10) & Chr(10) & _
                "Check if file/folder is set to read-only.", _
            vbOKOnly + vbCritical, _
            "Error"
        
        Exit Sub
    End If
    
    ' Ready to go. Pass info to writing function
    writeCSV ExportRange, tStrm, TxBxFormat.Value, TxBxSep.Value
    
    ' Close the stream
    tStrm.Close
    
End Sub

Private Sub BtnSelectFolder_Click()

    Dim fd As FileDialog
    Dim result As Long, errNum As Long
    
    Set fd = Application.FileDialog(msoFileDialogFolderPicker)
    
    With fd
        .AllowMultiSelect = False
        .ButtonName = "Select"
        .Title = "Choose Output Folder"
        If InStr(UCase(.InitialFileName), "SYSTEM32") Then
            .InitialFileName = Environ("USERPROFILE") & "\Documents"
        End If
        
        result = .Show
    End With
    
    ' Drop if box cancelled
    If result = 0 Then Exit Sub
    
    ' Made it here; try updating the linked folder, with error handling
    On Error Resume Next
        Set WorkFolder = fs.GetFolder(fd.SelectedItems(1))
    errNum = Err.Number: Err.Clear: On Error GoTo 0
    
    If errNum <> 0 Then
        MsgBox "Invalid folder selection", _
                vbOKOnly + vbCritical, _
                "Error"
        Exit Sub
    End If
    
    ' Update display textbox
    TxBxFolder.Value = WorkFolder.Path
    
    ' Update the Export button
    setExportEnabled

End Sub

Private Sub TxBxFilename_Change()

    ' If filename is nonzero-length and valid, set color black.
    ' Else, complain by setting color red
    If validFilename(TxBxFilename.Value) Then
        TxBxFilename.ForeColor = RGB(0, 0, 0)
    Else
        TxBxFilename.ForeColor = RGB(255, 0, 0)
    End If
    
    ' Update the Export button
    setExportEnabled
    
End Sub

Private Sub TxBxFormat_Change()
    setExportEnabled
End Sub

Private Sub TxBxSep_Change()
    setExportEnabled
End Sub

Private Sub UserForm_Activate()
    ' Always update the export range info box when
    ' focus is gained, unless a show/focus attempt
    ' is made when a chart-sheet is active, in which case
    ' re-hide the form and suppress the update.
    
    If TypeOf ActiveSheet Is Chart Then
        UFExporter.Hide
        Exit Sub
    End If
    
    setExportRange
    setExportRangeText
    
End Sub

Private Sub UserForm_Initialize()
    ' Set to no folder selected
    TxBxFolder.Value = NoFolderStr
    
    ' Link filesystem
    Set fs = CreateObject("Scripting.FileSystemObject")
    
    ' Link Application for events
    Set appn = Application
    
    ' Default is for filename to be empty; thus disable export button
    BtnExport.Enabled = False
    
    ' Comma is default separator
    TxBxSep.Value = ","
    
    ' General is default number format
    TxBxFormat.Value = "@"
    
End Sub


' =====  FORM MANAGEMENT ROUTINES  =====

Private Sub setExportEnabled()
    ' Helper to evaluate the status of the form and enable/disable
    ' the 'Export' button appropriately
    
    If ( _
        Len(TxBxSep.Value) > 0 And _
        validFilename(TxBxFilename.Value) And _
        Len(TxBxFormat.Value) > 0 And _
        (Not WorkFolder Is Nothing) And _
        (Not ExportRange Is Nothing) _
    ) Then
        BtnExport.Enabled = True
    Else
        BtnExport.Enabled = False
    End If
    
End Sub

Private Sub setExportRange()
    ' Proofing of Selection, to see if it's valid -- plus,
    ' implementing the reduction of the export range to
    ' Intersect(UsedRange, Selection) when whole rows/columns
    ' are selected.
    '
    ' Note that if whole rows/columns are selected in a way that
    ' doesn't intersect UsedRange, then ExportRange will also
    ' be set to Nothing, which twigs the error-state check in
    ' setExportEnabled and setExportRangeText
    
    If Selection.Areas.Count <> 1 Then
        Set ExportRange = Nothing
    Else
        If Selection.Address = Selection.EntireRow.Address Or _
                Selection.Address = Selection.EntireColumn.Address Then
            Set ExportRange = Intersect(Selection, Selection.Parent.UsedRange)
        Else
            Set ExportRange = Selection
        End If
    End If
    
End Sub

Private Sub setExportRangeText()
    ' Helper to encapsulate setting the export range reporting text in
    ' 'LblExportRg'
    
    Dim workStr As String
    
    If Not TypeOf Selection Is Range Then Exit Sub
    
    workStr = "  Worksheet: " _
        & Selection.Parent.Name _
        & Chr(10) _
        & "  Range: " _
        & getExportRangeAddress
    
    LblExportRg.Caption = workStr
    
End Sub

Private Function getExportRangeAddress() As String
    ' Helper for concise generation of the export range address
    ' without dollar signs.
    '
    ' Or, if ExportRange Is Nothing, which represents some sort of
    ' selection error state, then report the invalid selection string
    
    If ExportRange Is Nothing Then
        getExportRangeAddress = InvalidSelStr
    Else
        getExportRangeAddress = ExportRange.Address(RowAbsolute:=False, _
                                                    ColumnAbsolute:=False)
    End If
    
End Function


' =====  HELPER FUNCTIONS  =====

Private Sub writeCSV(dataRg As Range, tStrm As TextStream, nFormat As String, _
                    Separator As String)
    
    ' Encapsulates the process of actually writing the selected data to
    ' CSV on-disk.
    ' Assumes suitable TextStream already opened and dataRg proofed to only
    '  contain one Area.
    ' DOES **NOT** close the TextStream after writing!
    '
    ' dataRg     -- Single-area Range of the data to export
    ' tStrm      -- TextStream object opened in ForWriting or ForAppending mode
    ' nFormat    -- Number format to use when writing the CSV
    ' Separator  -- String to use to separate values in the CSV

    Dim cel As Range
    Dim idxRow As Long, idxCol As Long
    Dim workStr As String
    Dim errNum As Long

    
    ' Loop
    For idxRow = 1 To dataRg.Rows.Count
        ' Reset the working string
        workStr = ""
        
        For idxCol = 1 To dataRg.Columns.Count
            ' Tag on the value and a separator
            workStr = workStr & Format(dataRg.Cells(idxRow, idxCol).Value, nFormat)
            workStr = workStr & Separator
        Next idxCol
        
        ' Cull the trailing separator
        workStr = Left(workStr, Len(workStr) - Len(Separator))
        
        ' Write the line, with error-handling
        On Error Resume Next
            tStrm.WriteLine workStr
        errNum = Err.Number: Err.Clear: On Error GoTo 0
        
        If errNum <> 0 Then
            MsgBox "Unknown error occurred while writing data line", _
                    vbOKOnly + vbCritical, _
                    "Error"
            
            Exit Sub
        End If
        
    Next idxRow
    
End Sub

Function validFilename(fName As String) As Boolean
    ' Helper to confirm that an entered filename is valid.
    ' Checks for nonzero length, and no characters that are
    ' invalid for Windows filenames.
    
    Dim rxChrs As New RegExp
    
    With rxChrs
        .Global = True
        .IgnoreCase = True
        .MultiLine = False
        .Pattern = "[\\/:*?""<>|]"
        
        validFilename = (Len(fName) >= 1 And (Not .Test(fName)))
    End With
    
End Function



