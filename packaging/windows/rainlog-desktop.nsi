Unicode true

!include MUI2.nsh
!include LogicLib.nsh
!include WinVer.nsh
!include x64.nsh

!ifndef VERSION
  !define VERSION "1.0.1"
!endif
!ifndef VERSION_BASE
  !define VERSION_BASE "1.0.1"
!endif
!ifndef DIST_DIR
  !define DIST_DIR "..\..\deploy\bin"
!endif
!ifndef VC_REDIST
  !define VC_REDIST "..\..\vc_redist.x64.exe"
!endif
!ifndef OUTFILE
  !define OUTFILE "RainLog-Desktop-v${VERSION}-windows-x64.exe"
!endif

Name "Rain Log Desktop ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\Rain Log Desktop"
InstallDirRegKey HKLM "Software\Rain Log Desktop" "Install_Dir"
RequestExecutionLevel admin
ShowInstDetails show
ShowUnInstDetails show

VIProductVersion ${VERSION_BASE}.0
VIAddVersionKey "ProductName" "Rain Log Desktop"
VIAddVersionKey "FileDescription" "Rain Log Desktop installer"
VIAddVersionKey "CompanyName" "Captain Reginald"
VIAddVersionKey "FileVersion" "${VERSION_BASE}.0"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Copyright (c) 2026 Captain Reginald. Licensed under GPLv3\0"

!define MUI_ABORTWARNING
!define MUI_ICON "..\rainlog-desktop.ico"
!define MUI_UNICON "..\rainlog-desktop.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\rainlog-desktop.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Rain Log Desktop"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Function EnsureAppClosed
  ; The installer cannot overwrite the running application's DLLs. Ask the
  ; user to close it before extracting anything, rather than starting an
  ; install that fails midway through.
  retry:
    nsExec::ExecToStack /OEM '$SYSDIR\cmd.exe /c tasklist /FI "IMAGENAME eq rainlog-desktop.exe" /NH | findstr /I "rainlog-desktop.exe"'
    Pop $0
    Pop $1
    ${If} $1 != ""
        MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION "Rain Log Desktop is currently running.$\r$\n$\r$\nClose Rain Log Desktop, then choose OK to retry.$\r$\n$\r$\nChoose Cancel to stop the installation." IDOK retry IDCANCEL install_aborted
    ${EndIf}
  Return

  install_aborted:
    Abort
FunctionEnd

Function un.EnsureAppClosed
  un_retry:
    nsExec::ExecToStack /OEM '$SYSDIR\cmd.exe /c tasklist /FI "IMAGENAME eq rainlog-desktop.exe" /NH | findstr /I "rainlog-desktop.exe"'
    Pop $0
    Pop $1
    ${If} $1 != ""
        MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION "Rain Log Desktop is currently running.$\r$\n$\r$\nClose Rain Log Desktop, then choose OK to retry.$\r$\n$\r$\nChoose Cancel to stop the uninstall." IDOK un_retry IDCANCEL un_install_aborted
    ${EndIf}
  Return

  un_install_aborted:
    Abort
FunctionEnd

Function .onInit
  SetShellVarContext all
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Rain Log Desktop requires a 64-bit Windows installation."
    Abort
  ${EndIf}
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP "Rain Log Desktop requires Windows 10 or later."
    Abort
  ${EndIf}
  Call EnsureAppClosed
FunctionEnd

Section "Rain Log Desktop" SecMain
  SetOverwrite on

  ; Qt for MSVC is built against the Visual C++ runtime. Run Microsoft's
  ; official redistributable instead of copying individual runtime DLLs.
  SetOutPath "$TEMP"
  File "${VC_REDIST}"
  ExecWait '"$TEMP\vc_redist.x64.exe" /install /quiet /norestart' $0
  ${If} $0 != 0
  ${AndIf} $0 != 3010
    MessageBox MB_ICONSTOP "The Microsoft Visual C++ runtime could not be installed. Error $0."
    Abort
  ${EndIf}
  Delete "$TEMP\vc_redist.x64.exe"

  SetOutPath "$INSTDIR"
  File /r "${DIST_DIR}\*.*"

  CreateDirectory "$SMPROGRAMS\Rain Log Desktop"
  CreateShortCut "$SMPROGRAMS\Rain Log Desktop\Rain Log Desktop.lnk" "$INSTDIR\rainlog-desktop.exe" "" "$INSTDIR\rainlog-desktop.exe" 0
  CreateShortCut "$DESKTOP\Rain Log Desktop.lnk" "$INSTDIR\rainlog-desktop.exe" "" "$INSTDIR\rainlog-desktop.exe" 0

  WriteRegStr HKLM "Software\Rain Log Desktop" "Install_Dir" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "DisplayName" "Rain Log Desktop"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "Publisher" "Captain Reginald"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "DisplayIcon" "$INSTDIR\rainlog-desktop.exe,0"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "UninstallString" "$INSTDIR\Uninstall Rain Log Desktop.exe"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop" "NoRepair" 1
  WriteUninstaller "$INSTDIR\Uninstall Rain Log Desktop.exe"
SectionEnd

Section "Uninstall"
  SetShellVarContext all
  Call un.EnsureAppClosed
  ; Do not remove user rainfall data or settings from Documents/%APPDATA%.
  Delete "$DESKTOP\Rain Log Desktop.lnk"
  Delete "$SMPROGRAMS\Rain Log Desktop\Rain Log Desktop.lnk"
  RMDir "$SMPROGRAMS\Rain Log Desktop"

  RMDir /r "$INSTDIR"

  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rain Log Desktop"
  DeleteRegKey HKLM "Software\Rain Log Desktop"
SectionEnd
